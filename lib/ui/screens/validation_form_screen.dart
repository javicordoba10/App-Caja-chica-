import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/models/movement_model.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:petty_cash_app/repositories/movement_repository.dart';
import 'package:petty_cash_app/repositories/user_repository.dart';
import 'package:petty_cash_app/services/ocr_service.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';

// ─── Full-name labels for cost centers ──────────────────────────────
const Map<CostCenter, String> _costCenterNames = {
  CostCenter.Administracion: 'Administración',
  CostCenter.PuestoDeLuna:   'Puesto de Luna',
  CostCenter.FeedLot:        'Feed Lot',
  CostCenter.SanIsidro:      'San Isidro',
  CostCenter.LaCarlota:      'La Carlota',
  CostCenter.LaHuella:       'La Huella',
  CostCenter.ElSiete:        'El Siete',
  CostCenter.ElMoro:         'El Moro',
};

// ─── VAT rate data ───────────────────────────────────────────────────
class _VatSlot {
  final TextEditingController amountCtrl;
  double rate;
  _VatSlot({required this.amountCtrl, this.rate = 0.21});
}

class ValidationFormScreen extends ConsumerStatefulWidget {
  final ExtractedReceiptData data;
  final MovementType initialType;
  final bool isReadOnly;
  final MovementModel? existingMovement;

  const ValidationFormScreen({
    super.key,
    required this.data,
    this.initialType = MovementType.expense,
    this.isReadOnly = false,
    this.existingMovement,
  });

  @override
  ConsumerState<ValidationFormScreen> createState() => _ValidationFormScreenState();
}

class _ValidationFormScreenState extends ConsumerState<ValidationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _descCtrl;
  late TextEditingController _grossCtrl;
  late TextEditingController _netCtrl;
  late TextEditingController _invoiceNumberCtrl;
  late TextEditingController _dateCtrl;

  // Dual-IVA support
  final List<_VatSlot> _vatSlots = [];

  late MovementType _selectedType;
  CostCenter _selectedCostCenter = CostCenter.Administracion;
  PaymentMethod _selectedPayment = PaymentMethod.cash;
  String _selectedInvoiceType = 'Ticket';
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  static const List<double> _vatRates = [0.0, 0.105, 0.21, 0.27];

  // ── init ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final d = widget.data;
    final em = widget.existingMovement;
    
    _selectedType = em?.type ?? widget.initialType;
    _selectedInvoiceType = em?.invoiceType ?? d.invoiceType;
    _selectedCostCenter = em?.costCenter ?? CostCenter.Administracion;
    _selectedPayment = em?.paymentMethod ?? PaymentMethod.cash;

    // Controllers
    _descCtrl          = TextEditingController(text: em?.description ?? '');
    _grossCtrl         = TextEditingController(text: (em?.grossAmount ?? d.grossAmount) > 0 ? (em?.grossAmount ?? d.grossAmount).toStringAsFixed(2) : '');
    _netCtrl           = TextEditingController(text: (em?.netAmount ?? d.netAmount) > 0 ? (em?.netAmount ?? d.netAmount).toStringAsFixed(2) : '');
    _invoiceNumberCtrl = TextEditingController(text: em?.invoiceNumber ?? d.invoiceNumber ?? '');

    // Date logic
    if (em != null) {
      _selectedDate = em.date;
    } else if (d.dateStr != null && d.dateStr!.isNotEmpty) {
      try {
        final parts = d.dateStr!.split('/');
        if (parts.length == 3) {
          _selectedDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (_) {}
    }
    _dateCtrl = TextEditingController(text: _formatDate(_selectedDate));

    // VAT logic
    final vAmt = em?.vat ?? d.vat;
    final nAmt = em?.netAmount ?? d.netAmount;
    final vatRate = _guessVatRate(nAmt, vAmt);
    _vatSlots.add(_VatSlot(
      amountCtrl: TextEditingController(text: vAmt > 0 ? vAmt.toStringAsFixed(2) : ''),
      rate: vatRate,
    ));

    if (!widget.isReadOnly) {
      _grossCtrl.addListener(_recalcNet);
    }
  }

  double _guessVatRate(double net, double vat) {
    if (net <= 0 || vat <= 0) return 0.21;
    final r = vat / net;
    if      (r > 0.24) return 0.27;
    else if (r > 0.15) return 0.21;
    else if (r > 0.05) return 0.105;
    else               return 0.0;
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  void _recalcNet() {
    if (_selectedInvoiceType == 'Factura A') {
      final g = _parse(_grossCtrl.text);
      if (g > 0 && _vatSlots.isNotEmpty) {
        double totalVat = 0;
        for (var s in _vatSlots) {
          final slotVat = g * s.rate / (1 + s.rate);
          s.amountCtrl.text = slotVat.toStringAsFixed(2);
          totalVat += slotVat;
        }
        _netCtrl.text = (g - totalVat).toStringAsFixed(2);
      }
    } else {
      final g = _parse(_grossCtrl.text);
      _netCtrl.text = g.toStringAsFixed(2);
      for (var s in _vatSlots) { s.amountCtrl.text = '0.00'; }
    }
    setState(() {});
  }

  double _parse(String v) {
    if (v.isEmpty) return 0.0;
    return double.tryParse(v.trim().replaceAll('\$', '').replaceAll(' ', '').replaceAll(',', '.')) ?? 0.0;
  }

  @override
  void dispose() {
    _grossCtrl.removeListener(_recalcNet);
    _descCtrl.dispose();
    _grossCtrl.dispose();
    _netCtrl.dispose();
    _invoiceNumberCtrl.dispose();
    _dateCtrl.dispose();
    for (var s in _vatSlots) { s.amountCtrl.dispose(); }
    super.dispose();
  }

  // ── save ─────────────────────────────────────────────────────────────
  void _save() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final userId        = ref.read(currentUserIdProvider);
    final userRepo      = ref.read(userRepositoryProvider);
    final movementRepo  = ref.read(movementRepositoryProvider);
    final scaffoldMsg   = ScaffoldMessenger.of(context);
    final navigator     = Navigator.of(context);

    final gross   = _parse(_grossCtrl.text);
    final net     = _parse(_netCtrl.text);
    final totalVat = _vatSlots.fold(0.0, (s, slot) => s + _parse(slot.amountCtrl.text));
    final movId   = const Uuid().v4();

    final movement = MovementModel(
      id:            movId,
      userId:        userId ?? 'unknown',
      type:          _selectedType,
      netAmount:     net,
      grossAmount:   gross,
      vat:           totalVat,
      invoiceType:   _selectedInvoiceType,
      invoiceNumber: _invoiceNumberCtrl.text.isNotEmpty ? _invoiceNumberCtrl.text : null,
      description:   _descCtrl.text,
      costCenter:    _selectedCostCenter,
      paymentMethod: _selectedPayment,
      date:          _selectedDate,
      imageUrl:      null,
    );

    userRepo.saveMovementWithBalanceUpdate(movement).then((_) {
      scaffoldMsg.showSnackBar(const SnackBar(
        content: Text('Registro guardado ✓'),
        backgroundColor: AppTheme.incomeGreen,
        duration: Duration(seconds: 3),
      ));
    }).catchError((e) {
      scaffoldMsg.showSnackBar(SnackBar(
        content: Text('Error al guardar: $e'),
        backgroundColor: AppTheme.expenseRed,
      ));
    });

    if (widget.data.bytes != null) {
      _uploadInBackground(userId ?? 'unknown', movId, widget.data.bytes!, widget.data.isPdf, movementRepo, movement, scaffoldMsg);
    }

    navigator.pop();
  }

  void _uploadInBackground(String uid, String id, Uint8List bytes, bool isPdf,
      MovementRepository repo, MovementModel original, ScaffoldMessengerState msg) async {
    try {
      final ext = isPdf ? 'pdf' : 'jpg';
      final ref = FirebaseStorage.instance.ref().child('receipts/$uid/$id.$ext');
      final meta = SettableMetadata(contentType: isPdf ? 'application/pdf' : 'image/jpeg');
      final task = await ref.putData(bytes, meta);
      final url  = await task.ref.getDownloadURL();
      await repo.updateImageUrl(id, url);
    } catch (e) {
      msg.showSnackBar(const SnackBar(
        content: Text('Aviso: No se pudo subir el adjunto (CORS).'),
        backgroundColor: AppTheme.expenseRed,
      ));
    }
  }

  // ── date picker ──────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryOrange),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = _formatDate(picked);
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverHeader(),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                sliver: SliverToBoxAdapter(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Receipt preview (expenses with image)
                        if (_selectedType == MovementType.expense && widget.data.imagePath.isNotEmpty)
                          _buildReceiptPreview(),

                        _section('DATOS DEL COMPROBANTE', Icons.receipt_long_outlined),
                        _field(_invoiceNumberCtrl, 'N° de Factura / Ticket', Icons.tag, keyboardType: TextInputType.text),
                        const SizedBox(height: 16),
                        // Date row
                        _datePicker(),
                        const SizedBox(height: 16),
                        // Invoice type + gross amount in a row
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: _field(_grossCtrl, 'Monto Total (ARS)', Icons.payments_outlined,
                              keyboardType: TextInputType.number,
                              readOnly: widget.isReadOnly,
                              validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null)),
                          const SizedBox(width: 12),
                          if (_selectedType == MovementType.expense)
                            Expanded(child: _invoiceTypeDropdown(enabled: !widget.isReadOnly)),
                        ]),
                        const SizedBox(height: 16),

                        // Net amount (read-only for Factura A, editable otherwise)
                        if (_selectedType == MovementType.expense && _selectedInvoiceType == 'Factura A') ...[
                          _field(_netCtrl, 'Subtotal (sin IVA)', Icons.remove_circle_outline,
                              keyboardType: TextInputType.number, readOnly: true),
                          const SizedBox(height: 20),
                          _section('IVA / ALÍCUOTAS', Icons.percent),
                          ..._vatSlots.asMap().entries.map((e) => _vatRow(e.key, e.value, readOnly: widget.isReadOnly)),
                          if (_vatSlots.length < 2 && !widget.isReadOnly)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                              child: TextButton.icon(
                                onPressed: () => setState(() => _vatSlots.add(_VatSlot(
                                  amountCtrl: TextEditingController(text: '0.00'),
                                ))),
                                icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryOrange),
                                label: Text('Agregar 2° alícuota IVA',
                                    style: GoogleFonts.montserrat(color: AppTheme.primaryOrange, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],

                        _section('DESCRIPCIÓN', Icons.description_outlined),
                        _field(_descCtrl, 'Razón Social / Descripción', Icons.store_outlined,
                            readOnly: widget.isReadOnly,
                            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null),
                        const SizedBox(height: 20),

                        _section('ASIGNACIÓN', Icons.business_outlined),
                        _dropdown<CostCenter>(
                          value: _selectedCostCenter,
                          label: 'Establecimiento',
                          icon: Icons.location_city_outlined,
                          items: CostCenter.values.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(_costCenterNames[c] ?? c.name),
                          )).toList(),
                          onChanged: widget.isReadOnly ? null : (CostCenter? v) => setState(() => _selectedCostCenter = v ?? CostCenter.Administracion),
                        ),
                        const SizedBox(height: 16),
                        _dropdown<PaymentMethod>(
                          value: _selectedPayment,
                          label: 'Forma de Pago',
                          icon: Icons.account_balance_wallet_outlined,
                          items: const [
                            DropdownMenuItem(value: PaymentMethod.cash,  child: Text('Efectivo')),
                            DropdownMenuItem(value: PaymentMethod.debit, child: Text('Tarjeta / Débito')),
                          ],
                          onChanged: widget.isReadOnly ? null : (PaymentMethod? v) => setState(() => _selectedPayment = v ?? PaymentMethod.cash),
                        ),
                        const SizedBox(height: 40),

                        // ── Gradient Save Button ──────────────────────────────
                        _saveButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // WIDGET BUILDERS
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildSliverHeader() {
    final isExpense = _selectedType == MovementType.expense;
    final gradientColors = isExpense
        ? [const Color(0xFF8B0000), AppTheme.expenseRed, const Color(0xFFFF6B35)]
        : [const Color(0xFF1B5E20), AppTheme.incomeGreen, const Color(0xFF4CAF50)];

    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: AppTheme.pureBlack,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _selectedInvoiceType.toUpperCase(),
                        style: GoogleFonts.montserrat(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                      ),
                    ),
                    if (widget.data.imagePath.isNotEmpty && !widget.data.isPdf) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                        child: const Row(children: [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 10),
                          SizedBox(width: 4),
                          Text('OCR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  if (_parse(_grossCtrl.text) > 0)
                    Text(
                      '\$ ${_parse(_grossCtrl.text).toStringAsFixed(2)}',
                      style: GoogleFonts.montserrat(color: Colors.white.withValues(alpha: 0.85), fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
        ),
        title: Text(
          isExpense ? 'Validar Egreso' : 'Registrar Ingreso',
          style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 16),
      ),
    );
  }

  Widget _buildReceiptPreview() {
    return Container(
      height: 160,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(children: [
          widget.data.isPdf
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.picture_as_pdf, size: 48, color: AppTheme.expenseRed),
                  SizedBox(height: 8),
                  Text('DOCUMENTO PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                ]))
              : kIsWeb
                  ? Image.network(widget.data.imagePath, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                  : Image.file(io.File(widget.data.imagePath), width: double.infinity, fit: BoxFit.cover),
          Positioned(
            top: 10, right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppTheme.primaryOrange, borderRadius: BorderRadius.circular(16)),
              child: const Text('VISTA PREVIA', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _section(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 8),
      child: Row(children: [
        Container(width: 3, height: 18, decoration: BoxDecoration(color: AppTheme.primaryOrange, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Icon(icon, size: 15, color: AppTheme.primaryOrange),
        const SizedBox(width: 6),
        Text(title,
            style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textDark, letterSpacing: 1.2)),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textDark),
      decoration: _inputDeco(label, icon, readOnly: readOnly),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, {bool readOnly = false}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: readOnly ? AppTheme.textGrey : AppTheme.primaryOrange),
      filled: true,
      fillColor: readOnly ? const Color(0xFFF0F0F0) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.08))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryOrange, width: 1.5)),
      labelStyle: GoogleFonts.montserrat(color: AppTheme.textGrey, fontWeight: FontWeight.w500, fontSize: 12),
    );
  }

  Widget _datePicker() {
    return TextFormField(
      controller: _dateCtrl,
      readOnly: true,
      onTap: _pickDate,
      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14),
      decoration: _inputDeco('Fecha del Comprobante', Icons.calendar_today_outlined).copyWith(
        suffixIcon: const Icon(Icons.edit_calendar_outlined, color: AppTheme.primaryOrange, size: 18),
      ),
    );
  }

  Widget _invoiceTypeDropdown({bool enabled = true}) {
    return DropdownButtonFormField<String>(
      value: _selectedInvoiceType,
      onChanged: enabled ? (v) => setState(() {
        _selectedInvoiceType = v!;
        _recalcNet();
      }) : null,
      icon: const Icon(Icons.expand_more, color: Colors.black26, size: 18),
      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textDark),
      decoration: _inputDeco('Tipo Comprobante', Icons.receipt_outlined, readOnly: !enabled),
      items: ['Ticket', 'Factura A', 'Factura B', 'Factura C'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
    );
  }

  Widget _vatRow(int index, _VatSlot slot, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: slot.amountCtrl,
            keyboardType: TextInputType.number,
            readOnly: readOnly,
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14),
            decoration: _inputDeco('IVA ${index + 1} (\$)', Icons.percent),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<double>(
            value: slot.rate,
            onChanged: readOnly ? null : (v) => setState(() {
              slot.rate = v!;
              _recalcNet();
            }),
            icon: const Icon(Icons.expand_more, color: Colors.black26, size: 16),
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textDark),
            decoration: _inputDeco('Alícuota', Icons.percent),
            items: _vatRates.map((r) => DropdownMenuItem(value: r, child: Text('${(r * 100).toStringAsFixed(1)}%'))).toList(),
          ),
        ),
        if (_vatSlots.length > 1 && !readOnly)
          IconButton(
            onPressed: () => setState(() { slot.amountCtrl.dispose(); _vatSlots.removeAt(index); _recalcNet(); }),
            icon: const Icon(Icons.remove_circle, color: AppTheme.expenseRed, size: 20),
          ),
      ]),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    ValueChanged<T?>? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      icon: const Icon(Icons.expand_more, color: Colors.black26, size: 18),
      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textDark),
      decoration: _inputDeco(label, icon),
    );
  }

  Widget _saveButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _save,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppTheme.buttonGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text(
                  'CONFIRMAR Y GUARDAR',
                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 14),
                ),
        ),
      ),
    );
  }
}
