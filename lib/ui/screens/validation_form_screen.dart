import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:petty_cash_app/models/movement_model.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:petty_cash_app/repositories/movement_repository.dart';
import 'package:petty_cash_app/repositories/user_repository.dart';
import 'package:petty_cash_app/services/ocr_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';

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
      userId: userId ?? 'unknown',
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
      _uploadInBackground(userId ?? 'unknown', movementId, widget.data.bytes!, widget.data.isPdf, movementRepo, movement, scaffoldMessenger);
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
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(_selectedType == MovementType.income ? 'Nuevo Ingreso' : 'Validar Egreso'),
        backgroundColor: AppTheme.pureWhite,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Receipt Preview (Only for Expense with Image)
                  if (_selectedType == MovementType.expense && widget.data.imagePath.isNotEmpty)
                    _buildReceiptPreview(),

                  // Description Field
                  _buildSectionHeader('INFORMACIÓN BÁSICA'),
                  _buildTextField(
                    controller: _descCtrl,
                    label: 'Descripción / Razón Social',
                    icon: Icons.description_outlined,
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 20),

                  // Amount and Type Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _grossCtrl,
                          label: 'Monto Total',
                          icon: Icons.payments_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      if (_selectedType == MovementType.expense) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdown<String>(
                            value: _selectedInvoiceType,
                            label: 'Tipo Comprobante',
                            icon: Icons.receipt_outlined,
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
                  const SizedBox(height: 20),

                  // Specific Fields for Expense
                  if (_selectedType == MovementType.expense) _buildExpenseFields(),

                  // Assignment (Establishment)
                  _buildSectionHeader('ASIGNACIÓN'),
                  _buildDropdown<CostCenter>(
                    value: _selectedCostCenter,
                    label: 'Establecimiento',
                    icon: Icons.business_outlined,
                    items: CostCenter.values.map((c) => DropdownMenuItem(
                      value: c, 
                      child: Text(_getEstablishmentCode(c)),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedCostCenter = v!),
                  ),
                  const SizedBox(height: 20),

                  // Payment Method
                  _buildDropdown<PaymentMethod>(
                    value: _selectedPayment,
                    label: 'Método de Pago',
                    icon: Icons.account_balance_wallet_outlined,
                    items: PaymentMethod.values.map((p) => DropdownMenuItem(
                      value: p, 
                      child: Text(p == PaymentMethod.cash ? 'Efectivo' : 'Tarjeta / Débito'),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedPayment = v!),
                  ),
                  
                  const SizedBox(height: 48),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: AppTheme.pureBlack,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _isLoading ? 'GUARDANDO...' : 'CONFIRMAR Y GUARDAR',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, letterSpacing: 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
            )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 12),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppTheme.textGrey,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppTheme.primaryOrange),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.05))),
        labelStyle: GoogleFonts.montserrat(color: AppTheme.textGrey, fontWeight: FontWeight.w500, fontSize: 13),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      icon: const Icon(Icons.expand_more, color: Colors.black26),
      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textDark),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppTheme.primaryOrange),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.05))),
        labelStyle: GoogleFonts.montserrat(color: AppTheme.textGrey, fontWeight: FontWeight.w500, fontSize: 13),
      ),
    );
  }

  Widget _buildReceiptPreview() {
    return Container(
      height: 180,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: widget.data.isPdf 
              ? const Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf, size: 48, color: AppTheme.expenseRed),
                    SizedBox(height: 8),
                    Text('DOCUMENTO PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                  ],
                ))
              : kIsWeb 
                  ? Image.network(widget.data.imagePath, width: double.infinity, fit: BoxFit.cover)
                  : Image.file(io.File(widget.data.imagePath), width: double.infinity, fit: BoxFit.cover),
          ),
          Positioned(
            top: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.primaryOrange, borderRadius: BorderRadius.circular(20)),
              child: const Text('VISTA PREVIA', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildExpenseFields() {
    return Column(
      children: [
        _buildTextField(
          controller: _invoiceNumberCtrl,
          label: 'Número de Factura / Ticket',
          icon: Icons.tag,
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 20),
        if (_selectedInvoiceType == 'Factura A') ...[
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _netCtrl,
                  label: 'Sub-Total',
                  icon: Icons.remove_circle_outline,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _vatCtrl,
                  label: 'IVA Total',
                  icon: Icons.add_circle_outline,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDropdown<double>(
            value: _selectedVatRate,
            label: 'Alícuota IVA',
            icon: Icons.percent,
            items: [0.0, 0.105, 0.21, 0.27].map((r) => DropdownMenuItem(value: r, child: Text('${(r*100).toStringAsFixed(1)}%'))).toList(),
            onChanged: (v) => setState(() {
              _selectedVatRate = v!;
              _onGrossOrVatChange();
            }),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  String _getEstablishmentCode(CostCenter c) {
    switch (c) {
      case CostCenter.Administracion: return 'ADM';
      case CostCenter.PuestoDeLuna: return 'PL';
      case CostCenter.FeedLot: return 'FL';
      case CostCenter.SanIsidro: return 'SI';
      case CostCenter.LaCarlota: return 'LC';
      case CostCenter.LaHuella: return 'LH';
      case CostCenter.ElSiete: return 'E7';
      case CostCenter.ElMoro: return 'EM';
      default: return 'OTR';
    }
  }
}
