import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/movement_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/movement_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/ocr_service.dart';
import '../theme/app_theme.dart';

class ValidationFormScreen extends ConsumerStatefulWidget {
  final ExtractedReceiptData data;
  final MovementType initialType;

  const ValidationFormScreen({super.key, required this.data, this.initialType = MovementType.expense});

  @override
  ConsumerState<ValidationFormScreen> createState() => _ValidationFormScreenState();
}

class _ValidationFormScreenState extends ConsumerState<ValidationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _descCtrl;
  late TextEditingController _grossCtrl;
  late TextEditingController _netCtrl;
  late TextEditingController _vatCtrl;
  late TextEditingController _invoiceNumberCtrl;

  late MovementType _selectedType;
  CostCenter _selectedCostCenter = CostCenter.Administracion;
  PaymentMethod _selectedPayment = PaymentMethod.cash;
  String _selectedInvoiceType = 'Ticket';
  double _selectedVatRate = 0.21;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _selectedInvoiceType = widget.data.invoiceType;
    _descCtrl = TextEditingController(); // Razón Social/Descripción stays manual
    
    // Auto-calculate the IVA rate Dropdown based on the OCR result
    if (widget.data.netAmount > 0 && widget.data.vat > 0) {
      double rate = widget.data.vat / widget.data.netAmount;
      if (rate > 0.15) {
        _selectedVatRate = 0.21;
      } else if (rate > 0.05) {
        _selectedVatRate = 0.105;
      } else {
        _selectedVatRate = 0.0;
      }
    }
    
    _grossCtrl = TextEditingController(text: widget.data.grossAmount > 0 ? widget.data.grossAmount.toStringAsFixed(2) : '');
    _netCtrl = TextEditingController(text: widget.data.netAmount > 0 ? widget.data.netAmount.toStringAsFixed(2) : '');
    _vatCtrl = TextEditingController(text: widget.data.vat > 0 ? widget.data.vat.toStringAsFixed(2) : '');
    _invoiceNumberCtrl = TextEditingController(text: widget.data.invoiceNumber ?? '');
    
    _grossCtrl.addListener(_onGrossOrVatChange);
  }

  void _onGrossOrVatChange() {
    if (_selectedType == MovementType.expense && _selectedInvoiceType == 'Factura A') {
      final gross = _parseAmount(_grossCtrl.text);
      if (gross > 0) {
        final net = gross / (1 + _selectedVatRate);
        final vat = gross - net;
        _netCtrl.text = net.toStringAsFixed(2);
        _vatCtrl.text = vat.toStringAsFixed(2);
      }
    } else {
      final gross = _parseAmount(_grossCtrl.text);
      _netCtrl.text = gross.toStringAsFixed(2);
      _vatCtrl.text = '0.00';
    }
  }

  double _parseAmount(String val) {
    if (val.isEmpty) return 0.0;
    String cleaned = val.trim().replaceAll(r'$', '').replaceAll(' ', '');
    // Simple parsing for standard float format. 
    // If needed more complex AR format handling can be added here.
    cleaned = cleaned.replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  @override
  void dispose() {
    _grossCtrl.removeListener(_onGrossOrVatChange);
    _descCtrl.dispose();
    _grossCtrl.dispose();
    _netCtrl.dispose();
    _vatCtrl.dispose();
    _invoiceNumberCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true); // Brief feedback
    
    final userId = ref.read(currentUserIdProvider);
    final userRepo = ref.read(userRepositoryProvider);
    final movementRepo = ref.read(movementRepositoryProvider);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    
    final description = _descCtrl.text;
    final movementId = const Uuid().v4();
    final gross = _parseAmount(_grossCtrl.text);
    final net = _parseAmount(_netCtrl.text);
    final vat = _parseAmount(_vatCtrl.text);

    final movement = MovementModel(
      id: movementId,
      userId: userId,
      type: _selectedType,
      netAmount: net,
      grossAmount: gross,
      vat: vat,
      invoiceType: _selectedInvoiceType,
      invoiceNumber: _invoiceNumberCtrl.text.isNotEmpty ? _invoiceNumberCtrl.text : null,
      description: description,
      costCenter: _selectedCostCenter,
      paymentMethod: _selectedPayment,
      date: DateTime.now(),
      imageUrl: null,
    );

    // 1. FIRE-AND-FORGET SAVE: We do not await Firestore writes. This entirely prevents
    // the "infinite loop" on web where promises hang due to IndexedDb or network caching.
    userRepo.saveMovementWithBalanceUpdate(movement).then((_) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Registro guardado exitosamente ✓'),
          backgroundColor: AppTheme.incomeGreen,
          duration: Duration(seconds: 3),
        ),
      );
    }).catchError((e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error guardando en la nube: $e'), backgroundColor: AppTheme.expenseRed),
      );
    });
      
    // 2. Upload async if image exists
    if (widget.data.bytes != null) {
      _uploadInBackground(userId, movementId, widget.data.bytes!, widget.data.isPdf, movementRepo, movement, scaffoldMessenger);
    }

    // 3. Immediately close the form screen and return to Dashboard
    navigator.pop();
  }

  void _uploadInBackground(String userId, String id, Uint8List bytes, bool isPdf, MovementRepository repo, MovementModel original, ScaffoldMessengerState messenger) async {
    try {
      final ext = isPdf ? 'pdf' : 'jpg';
      final storageRef = FirebaseStorage.instance.ref().child('receipts/$userId/$id.$ext');
      final metadata = SettableMetadata(contentType: isPdf ? 'application/pdf' : 'image/jpeg');
      final uploadTask = await storageRef.putData(bytes, metadata);
      final url = await uploadTask.ref.getDownloadURL();
      
      // Use a targeted .update() so only imageUrl changes, avoiding race conditions
      await repo.updateImageUrl(id, url);
      print('>>> Upload done, imageUrl set: $url');
    } catch (e) {
      print('>>> Upload error: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Aviso: Tu servidor Firebase bloquea subidas (CORS). El egreso se guardó sin adjunto.'), backgroundColor: AppTheme.expenseRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Validar Datos')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.data.imagePath.isNotEmpty)
                    Container(
                      height: 150,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundWhite,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: widget.data.isPdf 
                        ? const Center(child: Icon(Icons.picture_as_pdf, size: 48, color: AppTheme.expenseRed))
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: kIsWeb 
                                ? Image.network(widget.data.imagePath, fit: BoxFit.cover)
                                : Image.file(io.File(widget.data.imagePath), fit: BoxFit.cover),
                          ),
                    ),

                  SegmentedButton<MovementType>(
                    segments: const [
                      ButtonSegment(value: MovementType.expense, label: Text('Egreso')),
                      ButtonSegment(value: MovementType.income, label: Text('Ingreso')),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (val) => setState(() {
                      _selectedType = val.first;
                      _onGrossOrVatChange();
                    }),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(labelText: 'Descripción / Razón Social'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  if (_selectedType == MovementType.expense) ...[
                    TextFormField(
                      controller: _invoiceNumberCtrl,
                      decoration: const InputDecoration(labelText: 'Número de Factura'),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 16),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _grossCtrl,
                          decoration: InputDecoration(labelText: _selectedType == MovementType.income ? 'Monto' : 'Total'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      if (_selectedType == MovementType.expense) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedInvoiceType,
                            decoration: const InputDecoration(labelText: 'Tipo'),
                            items: ['Ticket', 'Factura A', 'Factura B', 'Factura C'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setState(() {
                                _selectedInvoiceType = v!;
                                _onGrossOrVatChange();
                            }),
                          ),
                        ),
                      ]
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_selectedType == MovementType.expense && _selectedInvoiceType == 'Factura A') ...[
                     Row(
                       children: [
                         Expanded(
                           child: TextFormField(
                             controller: _netCtrl,
                             decoration: const InputDecoration(labelText: 'Sub-Total (Monto sin IVA)'),
                             keyboardType: TextInputType.number,
                             validator: (v) => v!.isEmpty ? 'Requerido' : null,
                           ),
                         ),
                         const SizedBox(width: 16),
                         Expanded(
                           child: TextFormField(
                             controller: _vatCtrl,
                             decoration: const InputDecoration(labelText: 'IVA Aplicado'),
                             keyboardType: TextInputType.number,
                             validator: (v) => v!.isEmpty ? 'Requerido' : null,
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 16),
                     DropdownButtonFormField<double>(
                       value: _selectedVatRate,
                       decoration: const InputDecoration(labelText: 'IVA % (Aplica sobre Monto Final)'),
                       items: [0.0, 0.105, 0.21, 0.27].map((r) => DropdownMenuItem(value: r, child: Text('${(r*100).toStringAsFixed(1)}%'))).toList(),
                       onChanged: (v) => setState(() {
                         _selectedVatRate = v!;
                         _onGrossOrVatChange();
                       }),
                     ),
                     const SizedBox(height: 16),
                  ],

                  if (_selectedType == MovementType.expense) ...[
                    DropdownButtonFormField<CostCenter>(
                      value: _selectedCostCenter,
                      decoration: const InputDecoration(labelText: 'Centro de Costo'),
                      items: CostCenter.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                      onChanged: (v) => setState(() => _selectedCostCenter = v!),
                    ),
                    const SizedBox(height: 16),
                  ],

                  DropdownButtonFormField<PaymentMethod>(
                    value: _selectedPayment,
                    decoration: const InputDecoration(labelText: 'Método'),
                    items: PaymentMethod.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                    onChanged: (v) => setState(() => _selectedPayment = v!),
                  ),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlack, foregroundColor: Colors.white),
                      child: const Text('Confirmar y Guardar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            )
        ],
      ),
    );
  }
}
