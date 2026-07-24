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
import 'package:petty_cash_app/services/ocr_service.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:petty_cash_app/ui/widgets/responsive_layout.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

const Map<MovementCategory, String> _categoryNames = {
  MovementCategory.combustible: 'Combustible',
  MovementCategory.comida: 'Comida',
  MovementCategory.alojamiento: 'Alojamiento',
  MovementCategory.ferreteria: 'Ferretería',
  MovementCategory.personalChanga: 'Personal - Changas',
  MovementCategory.viajePeaje: 'Viaje - Peaje',
  MovementCategory.otros: 'Otros',
};

// ─── VAT & Tax slots ───────────────────────────────────────────────────
class _VatSlot {
  final TextEditingController amountCtrl;
  double rate;
  _VatSlot({required this.amountCtrl, this.rate = 0.21});
}

class _TaxSlot {
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  _TaxSlot({required this.nameCtrl, required this.amountCtrl});
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

  // Otros / Impuestos (opcional, múltiples)
  final List<_TaxSlot> _taxSlots = [];

  // Attachment state (Image/PDF)
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  bool _selectedIsPdf = false;

  late MovementType _selectedType;
  String _selectedEstablishment = 'ADMINISTRACIÓN';
  String _selectedPayment = 'Efectivo';
  String _selectedInvoiceType = 'Ticket';
  bool _isLoading = false;
  String _loadingMessage = 'Cargando...';
  DateTime _selectedDate = DateTime.now();
  MovementCategory _selectedCategory = MovementCategory.otros;

  static const List<double> _vatRates = [0.0, 0.105, 0.21, 0.27];

  bool _isInitializing = false;

  // ── init ────────────────────────────────────────────────────────────
  @override
  void initState() {
    _isInitializing = true;
    super.initState();
    final d = widget.data;
    final em = widget.existingMovement;
    
    // Debug OCR data
    if (kDebugMode) {
      print('OCR DATA RECEIVED: Gross=${d.grossAmount}, Net=${d.netAmount}, VAT=${d.vat}, Type=${d.invoiceType}, Num=${d.invoiceNumber}, Date=${d.dateStr}');
    }

    _selectedType = em?.type ?? widget.initialType;
    _selectedInvoiceType = em?.invoiceType ?? d.invoiceType;
    _selectedEstablishment = em?.establishment ?? (ref.read(currentUserProvider).value?.establishments.isNotEmpty == true ? ref.read(currentUserProvider).value!.establishments.first : 'ADMINISTRACIÓN');
    _selectedPayment = em?.paymentMethod ?? 'Efectivo';
    _selectedCategory = em?.category ?? MovementCategory.otros;

    // Controllers
    _descCtrl          = TextEditingController(text: em?.description ?? '');
    _grossCtrl         = TextEditingController(text: (em != null) 
        ? em.grossAmount.toStringAsFixed(2) 
        : (d.grossAmount > 0 ? d.grossAmount.toStringAsFixed(2) : ''));
    _netCtrl           = TextEditingController(text: (em != null) 
        ? em.netAmount.toStringAsFixed(2) 
        : (d.netAmount > 0 ? d.netAmount.toStringAsFixed(2) : ''));
    _invoiceNumberCtrl = TextEditingController(text: em?.invoiceNumber ?? d.invoiceNumber ?? '');

    // Date logic
    if (em != null) {
      _selectedDate = em.invoiceDate ?? em.date;
    } else if (d.dateStr != null && d.dateStr!.isNotEmpty) {
      try {
        final parts = d.dateStr!.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          if (year < 100) year += 2000;
          _selectedDate = DateTime(year, month, day);
        }
      } catch (e) {
        if (kDebugMode) print('Error parsing OCR date: $e');
      }
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

    // Other taxes logic
    if (em != null && em.otherTaxesDetails != null && em.otherTaxesDetails!.isNotEmpty) {
      for (var t in em.otherTaxesDetails!) {
        _taxSlots.add(_TaxSlot(
          nameCtrl: TextEditingController(text: t['name']?.toString() ?? 'Otros Impuestos'),
          amountCtrl: TextEditingController(text: (t['amount'] as num).toDouble().toStringAsFixed(2)),
        ));
      }
    } else if (em != null && em.otherTaxes > 0) {
      _taxSlots.add(_TaxSlot(
        nameCtrl: TextEditingController(text: 'Otros Impuestos'),
        amountCtrl: TextEditingController(text: em.otherTaxes.toStringAsFixed(2)),
      ));
    }

    if (d.bytes != null) {
      _selectedFileBytes = d.bytes;
      _selectedIsPdf = d.isPdf;
    }

    // Listener después de inicializar todo
    if (!widget.isReadOnly) {
      _grossCtrl.addListener(_recalcNet);
    }
    
    _isInitializing = false;
  }

  double _guessVatRate(double net, double vat) {
    if (net <= 0 || vat <= 0) return 0.21;
    final r = vat / net;
    if      (r > 0.24) {
      return 0.27;
    } else if (r > 0.15) return 0.21;
    else if (r > 0.05) return 0.105;
    else               return 0.0;
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  void _recalcNet() {
    if (_isInitializing) return;
    final g = _parse(_grossCtrl.text);
    double totalOtherTaxes = 0.0;
    for (var t in _taxSlots) {
      totalOtherTaxes += _parse(t.amountCtrl.text);
    }

    if (_selectedType == MovementType.expense && _selectedInvoiceType == 'Factura A') {
      if (g > 0) {
        final baseForVat = (g - totalOtherTaxes).clamp(0.0, double.infinity);
        double totalVat = 0;
        for (var s in _vatSlots) {
          final slotVat = baseForVat * s.rate / (1 + s.rate);
          s.amountCtrl.text = slotVat.toStringAsFixed(2);
          totalVat += slotVat;
        }
        _netCtrl.text = (g - totalVat - totalOtherTaxes).clamp(0.0, double.infinity).toStringAsFixed(2);
      }
    } else {
      _netCtrl.text = (g - totalOtherTaxes).clamp(0.0, double.infinity).toStringAsFixed(2);
      for (var s in _vatSlots) { s.amountCtrl.text = '0.00'; }
    }
    setState(() {});
  }

  double _parse(String v) {
    if (v.isEmpty) return 0.0;
    String clean = v.trim().replaceAll('\$', '').replaceAll(' ', '');
    
    if (clean.contains('.') && clean.contains(',')) {
      if (clean.lastIndexOf('.') < clean.lastIndexOf(',')) {
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        clean = clean.replaceAll(',', '');
      }
    } else if (clean.contains(',')) {
      clean = clean.replaceAll(',', '.');
    } else if (clean.contains('.')) {
      final parts = clean.split('.');
      if (parts.length > 1 && parts.last.length == 3) {
        clean = clean.replaceAll('.', '');
      }
    }
    
    return double.tryParse(clean) ?? 0.0;
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
    for (var t in _taxSlots) { t.nameCtrl.dispose(); t.amountCtrl.dispose(); }
    super.dispose();
  }

  // ── pick attachment ──────────────────────────────────────────────────
  Future<void> _pickAttachment({required bool isPdf, bool fromCamera = false}) async {
    try {
      if (isPdf) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true,
        );
        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          setState(() {
            _selectedFileBytes = file.bytes;
            _selectedIsPdf = true;
            _selectedFileName = file.name;
          });
        }
      } else {
        final picker = ImagePicker();
        final source = fromCamera ? ImageSource.camera : ImageSource.gallery;
        final picked = await picker.pickImage(source: source, imageQuality: 85);
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          setState(() {
            _selectedFileBytes = bytes;
            _selectedIsPdf = false;
            _selectedFileName = picked.name;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar archivo: $e'), backgroundColor: AppTheme.expenseRed),
        );
      }
    }
  }

  // ── save ─────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Guardando...';
    });

    final userId        = ref.read(currentUserIdProvider);
    final userRepo      = ref.read(userRepositoryProvider);

    final gross   = _parse(_grossCtrl.text);
    final net     = _parse(_netCtrl.text);
    final totalVat = _vatSlots.fold(0.0, (s, slot) => s + _parse(slot.amountCtrl.text));
    
    // Other taxes calculation
    double totalOtherTaxes = 0.0;
    final List<Map<String, dynamic>> taxDetails = [];
    for (var t in _taxSlots) {
      final amt = _parse(t.amountCtrl.text);
      if (amt > 0) {
        totalOtherTaxes += amt;
        taxDetails.add({
          'name': t.nameCtrl.text.trim().isEmpty ? 'Otros Impuestos' : t.nameCtrl.text.trim(),
          'amount': amt,
        });
      }
    }

    final movId = widget.existingMovement?.id ?? const Uuid().v4();
    final currentUser = ref.read(currentUserProvider).value;

    // Check attachment bytes to upload
    Uint8List? uploadBytes = _selectedFileBytes ?? widget.data.bytes;
    bool isPdf = _selectedIsPdf || widget.data.isPdf;

    if (uploadBytes == null && widget.data.imagePath.isNotEmpty && !widget.data.imagePath.startsWith('http') && !kIsWeb) {
      try {
        uploadBytes = await io.File(widget.data.imagePath).readAsBytes();
      } catch (e) {
        debugPrint('Error leyendo bytes de archivo local: $e');
      }
    }

    String? uploadedUrl = widget.existingMovement?.imageUrl;

    // Subida a Firebase Storage con timeout corto de 5 segundos y fallback sin bloqueo
    final localPath = widget.data.imagePath;
    final bool hasLocalFile = !kIsWeb && localPath.isNotEmpty && !localPath.startsWith('http') && io.File(localPath).existsSync();

    if (uploadBytes != null || hasLocalFile) {
      setState(() => _loadingMessage = 'Subiendo comprobante...');
      try {
        final ext = isPdf ? 'pdf' : 'jpg';
        final refStorage = FirebaseStorage.instance.ref().child('receipts/${userId ?? "unknown"}/$movId.$ext');
        final meta = SettableMetadata(contentType: isPdf ? 'application/pdf' : 'image/jpeg');
        
        UploadTask task;
        if (hasLocalFile) {
          task = refStorage.putFile(io.File(localPath), meta);
        } else {
          task = refStorage.putData(uploadBytes!, meta);
        }

        final snapshot = await task.timeout(const Duration(seconds: 5));
        uploadedUrl = await snapshot.ref.getDownloadURL().timeout(const Duration(seconds: 3));
        debugPrint('>>> Subida de comprobante exitosa: $uploadedUrl');
      } catch (e) {
        debugPrint('>>> Error o timeout en subida de comprobante ($e). Se procesará en segundo plano.');
        final movementRepo = ref.read(movementRepositoryProvider);
        _startBackgroundUpload(userId ?? 'unknown', movId, uploadBytes, localPath, isPdf, movementRepo);
      }
    }

    setState(() => _loadingMessage = 'Guardando registro...');

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
      establishment: _selectedEstablishment,
      paymentMethod: _selectedPayment,
      date:          widget.existingMovement?.date ?? DateTime.now(),
      invoiceDate:   _selectedDate,
      imageUrl:      uploadedUrl,
      userName:      currentUser?.name,
      userEmail:     currentUser?.email,
      category:      _selectedCategory,
      companyId:     currentUser?.companyId ?? 'alm_agro',
      otherTaxes:    totalOtherTaxes,
      otherTaxesDetails: taxDetails.isNotEmpty ? taxDetails : null,
    );

    try {
      await userRepo.saveMovementWithBalanceUpdate(movement).timeout(const Duration(seconds: 10));
      if (mounted) {
        final message = ((uploadBytes != null || hasLocalFile) && uploadedUrl == null)
            ? 'Guardado ✓ (Procesando imagen...)'
            : 'Guardado exitosamente ✓';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.incomeGreen,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: AppTheme.expenseRed,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: MovementCategory.values.map((cat) {
        final isSelected = _selectedCategory == cat;
        return FilterChip(
          label: Text(_categoryNames[cat] ?? cat.name, style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textDark,
          )),
          selected: isSelected,
          onSelected: widget.isReadOnly ? null : (selected) {
            if (selected) setState(() => _selectedCategory = cat);
          },
          selectedColor: AppTheme.pureBlack,
          checkmarkColor: Colors.white,
          backgroundColor: Colors.black12,
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        );
      }).toList(),
    );
  }

  void _startBackgroundUpload(String uid, String mid, Uint8List? bytes, String imagePath, bool isPdf, MovementRepository repo) async {
    try {
      final ext = isPdf ? 'pdf' : 'jpg';
      final refStorage = FirebaseStorage.instance.ref().child('receipts/$uid/$mid.$ext');
      final meta = SettableMetadata(contentType: isPdf ? 'application/pdf' : 'image/jpeg');
      
      TaskSnapshot snapshot;
      if (!kIsWeb && imagePath.isNotEmpty && !imagePath.startsWith('http') && io.File(imagePath).existsSync()) {
        snapshot = await refStorage.putFile(io.File(imagePath), meta);
      } else if (bytes != null && bytes.isNotEmpty) {
        snapshot = await refStorage.putData(bytes, meta);
      } else {
        return;
      }

      final url = await snapshot.ref.getDownloadURL();
      await repo.updateImageUrl(mid, url);
      debugPrint('>>> Subida en segundo plano exitosa: $mid -> $url');
    } catch (e) {
      debugPrint('>>> ERROR en subida silenciosa ($mid): $e');
    }
  }

  // Eliminamos _uploadInBackground ya que ahora es síncrono

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
    final userMethods = ref.watch(currentUserProvider).value?.paymentMethods ?? ['Efectivo', 'Tarjeta / Débito'];
    final userEstablishments = ref.watch(currentUserProvider).value?.establishments ?? ['ADMINISTRACIÓN'];
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
                        // Receipt preview & Attachment section (Both Expense and Income)
                        _buildReceiptPreview(),

                        _section('DATOS DEL COMPROBANTE', Icons.receipt_long_outlined),
                        _field(_invoiceNumberCtrl, 'N° de Factura / Ticket', Icons.tag, keyboardType: TextInputType.text),
                        const SizedBox(height: 16),
                        // Date row
                        _datePicker(),
                        const SizedBox(height: 16),
                        // Invoice type + gross amount (Responsive)
                        if (ResponsiveLayout.isMobile(context))
                          Column(children: [
                            _field(_grossCtrl, 'Monto Total (ARS)', Icons.payments_outlined,
                                keyboardType: TextInputType.number,
                                readOnly: widget.isReadOnly,
                                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null),
                            const SizedBox(height: 16),
                            if (_selectedType == MovementType.expense)
                              _invoiceTypeDropdown(enabled: !widget.isReadOnly),
                          ])
                        else
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

                        // Otros Impuestos (Opcional - Múltiples)
                        if (_selectedType == MovementType.expense) ...[
                          const SizedBox(height: 8),
                          _section('OTROS / IMPUESTOS (OPCIONAL)', Icons.account_balance_outlined),
                          ..._taxSlots.asMap().entries.map((e) => _taxRow(e.key, e.value, readOnly: widget.isReadOnly)),
                          if (!widget.isReadOnly)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => setState(() {
                                    _taxSlots.add(_TaxSlot(
                                      nameCtrl: TextEditingController(text: 'Percepción / Impuesto'),
                                      amountCtrl: TextEditingController(text: '0.00'),
                                    ));
                                    _recalcNet();
                                  }),
                                  icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryOrange),
                                  label: Text('+ Agregar otro impuesto / percepción',
                                      style: GoogleFonts.montserrat(color: AppTheme.primaryOrange, fontWeight: FontWeight.w600, fontSize: 12)),
                                ),
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
                        _dropdown<String>(
                          value: userEstablishments.contains(_selectedEstablishment) ? _selectedEstablishment : userEstablishments.first,
                          label: 'Establecimiento',
                          icon: Icons.location_city_outlined,
                          items: userEstablishments.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          )).toList(),
                          onChanged: widget.isReadOnly ? null : (String? v) => setState(() => _selectedEstablishment = v ?? userEstablishments.first),
                        ),
                        const SizedBox(height: 16),
                        _dropdown<String>(
                          value: userMethods.contains(_selectedPayment) ? _selectedPayment : userMethods.first,
                          label: 'Forma de Pago',
                          icon: Icons.account_balance_wallet_outlined,
                          items: userMethods.map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(m),
                          )).toList(),
                          onChanged: widget.isReadOnly ? null : (String? v) => setState(() => _selectedPayment = v ?? 'Efectivo'),
                        ),
                        const SizedBox(height: 24),
                        _section('RUBRO / CATEGORÍA', Icons.category_outlined),
                        const SizedBox(height: 12),
                        _buildCategoryChips(),
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
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppTheme.primaryOrange),
                    const SizedBox(height: 20),
                    Text(
                      _loadingMessage,
                      style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
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
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
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
                      style: GoogleFonts.montserrat(color: Colors.white.withOpacity(0.85), fontSize: 15, fontWeight: FontWeight.w600),
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
    final bool hasBytes = _selectedFileBytes != null;
    final String path = widget.data.imagePath;
    final String? existingUrl = widget.existingMovement?.imageUrl;
    final bool hasFile = hasBytes || path.isNotEmpty || (existingUrl != null && existingUrl.isNotEmpty);

    final bool isPdf = _selectedIsPdf || widget.data.isPdf || path.toLowerCase().contains('.pdf') || (existingUrl?.toLowerCase().contains('.pdf') ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('COMPROBANTE ADJUNTO', Icons.attach_file),
        if (hasFile)
          GestureDetector(
            onTap: () async {
              final url = existingUrl ?? (path.startsWith('http') ? path : '');
              if (url.isNotEmpty) {
                try {
                  final uri = Uri.parse(url);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al abrir enlace: $e')),
                    );
                  }
                }
              }
            },
            child: Container(
              width: double.infinity,
              height: 180,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.pureWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    isPdf
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.picture_as_pdf, size: 52, color: AppTheme.expenseRed),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedFileName ?? 'DOCUMENTO PDF',
                                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.textDark),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryOrange,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'DOCUMENTO LISTO',
                                    style: GoogleFonts.montserrat(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : hasBytes
                            ? Image.memory(_selectedFileBytes!, width: double.infinity, fit: BoxFit.cover)
                            : (existingUrl != null && existingUrl.startsWith('http'))
                                ? Image.network(existingUrl, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                                : (path.startsWith('http') || kIsWeb)
                                    ? Image.network(path, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                                    : Image.file(io.File(path), width: double.infinity, fit: BoxFit.cover),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: AppTheme.primaryOrange, borderRadius: BorderRadius.circular(16)),
                        child: const Text('VISTA PREVIA', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                const Icon(Icons.no_photography_outlined, color: AppTheme.textGrey),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sin archivo o comprobante adjunto',
                    style: GoogleFonts.montserrat(fontSize: 13, color: AppTheme.textGrey, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

        if (!widget.isReadOnly)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickAttachment(isPdf: false, fromCamera: false),
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: Text(hasFile ? 'Cambiar' : 'Foto', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryOrange,
                    side: const BorderSide(color: AppTheme.primaryOrange),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickAttachment(isPdf: false, fromCamera: true),
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: Text('Cámara', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryOrange,
                    side: const BorderSide(color: AppTheme.primaryOrange),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickAttachment(isPdf: true),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: Text(hasFile ? 'PDF' : 'PDF', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.expenseRed,
                    side: const BorderSide(color: AppTheme.expenseRed),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _taxRow(int index, _TaxSlot slot, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: slot.nameCtrl,
              readOnly: readOnly,
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 13),
              decoration: _inputDeco('Concepto (ej: ITC, IIBB)', Icons.label_outlined),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: slot.amountCtrl,
              keyboardType: TextInputType.number,
              readOnly: readOnly,
              onChanged: (_) => _recalcNet(),
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 13),
              decoration: _inputDeco('Monto (\$)', Icons.attach_money),
            ),
          ),
          if (!readOnly)
            IconButton(
              onPressed: () => setState(() {
                slot.nameCtrl.dispose();
                slot.amountCtrl.dispose();
                _taxSlots.removeAt(index);
                _recalcNet();
              }),
              icon: const Icon(Icons.remove_circle, color: AppTheme.expenseRed, size: 20),
            ),
        ],
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
      items: ['Ticket', 'Factura A', 'Factura B', 'Factura C', 'Recibo'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
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
