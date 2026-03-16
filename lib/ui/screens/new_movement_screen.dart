import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:petty_cash_app/models/movement_model.dart';
import 'package:petty_cash_app/services/ocr_service.dart';
import 'package:petty_cash_app/ui/screens/validation_form_screen.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class NewMovementScreen extends ConsumerStatefulWidget {
  const NewMovementScreen({super.key});

  @override
  ConsumerState<NewMovementScreen> createState() => _NewMovementScreenState();
}

class _NewMovementScreenState extends ConsumerState<NewMovementScreen> {
  MovementType _selectedType = MovementType.expense;
  bool _isProcessingOCR = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          // Superior Toggle
          _buildTypeToggle(),
          const SizedBox(height: 48),

          if (_selectedType == MovementType.expense)
            _buildExpenseOptions()
          else
            _buildIncomeForm(),
        ],
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              label: 'EGRESO',
              isSelected: _selectedType == MovementType.expense,
              onTap: () => setState(() => _selectedType = MovementType.expense),
              color: AppTheme.expenseRed,
            ),
          ),
          Expanded(
            child: _ToggleButton(
              label: 'INGRESO',
              isSelected: _selectedType == MovementType.income,
              onTap: () => setState(() => _selectedType = MovementType.income),
              color: AppTheme.incomeGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseOptions() {
    if (_isProcessingOCR) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 100),
            const CircularProgressIndicator(color: AppTheme.primaryOrange),
            const SizedBox(height: 24),
            Text(
              'Digitalizando comprobante...',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: AppTheme.textDark),
            ),
            const SizedBox(height: 8),
            Text(
              'Esto puede tomar unos segundos',
              style: GoogleFonts.montserrat(fontSize: 12, color: AppTheme.textGrey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildActionButton(
          icon: Icons.picture_as_pdf_outlined,
          label: 'Importar Gasto (PDF)',
          description: 'Facturas digitales o recibos en PDF',
          onTap: () => _pickFile(isPdf: true),
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          icon: Icons.camera_alt_outlined,
          label: 'Tomar Foto (OCR)',
          description: 'Cámara con detección de datos',
          onTap: () => _pickImage(ImageSource.camera),
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          icon: Icons.edit_note_outlined,
          label: 'Registro Manual',
          description: 'Cargar datos sin comprobante',
          onTap: () => _goToManual(MovementType.expense),
        ),
      ],
    );
  }

  Widget _buildIncomeForm() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: AppTheme.whiteCardDecoration,
          child: Column(
            children: [
              const Icon(Icons.add_task, color: AppTheme.incomeGreen, size: 48),
              const SizedBox(height: 24),
              Text(
                'Nuevo Ingreso de Caja',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                'Solo se requiere descripción, monto y establecimiento asignado.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontSize: 13, color: AppTheme.textGrey),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _goToManual(MovementType.income),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.pureBlack,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: const Text('PROCEDER A CARGA'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.whiteCardDecoration,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryOrange, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.montserrat(color: AppTheme.textGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  void _goToManual(MovementType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ValidationFormScreen(
          data: ExtractedReceiptData(imagePath: ''),
          initialType: type,
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 80);
    if (image != null) _processOCR(image.path, false);
  }

  Future<void> _pickFile({required bool isPdf}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: isPdf ? FileType.custom : FileType.image,
      allowedExtensions: isPdf ? ['pdf'] : null,
      withData: true,
    );
    if (result != null && result.files.single.path != null) {
      _processOCR(result.files.single.path!, isPdf, bytes: result.files.single.bytes);
    }
  }

  void _processOCR(String path, bool isPdf, {dynamic bytes}) async {
    setState(() => _isProcessingOCR = true);
    
    // Simulate OCR delay as requested (Digitalizando comprobante...)
    await Future.delayed(const Duration(seconds: 2));
    
    final ocrService = ref.read(ocrServiceProvider);
    final data = await ocrService.extractData(path, isPdf: isPdf, bytes: bytes);
    
    if (mounted) {
      setState(() => _isProcessingOCR = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ValidationFormScreen(data: data, initialType: MovementType.expense),
        ),
      );
    }
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.pureWhite : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
          ] : [],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              color: isSelected ? color : AppTheme.textGrey,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
