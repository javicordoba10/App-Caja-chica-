import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petty_cash_app/models/company_config_model.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'company_logo_widget.dart';

class TenantDialog extends StatefulWidget {
  final CompanyConfigModel? company;
  const TenantDialog({super.key, this.company});

  @override
  State<TenantDialog> createState() => _TenantDialogState();
}

class _TenantDialogState extends State<TenantDialog> {
  late TextEditingController _idCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _logoUrlCtrl;
  late TextEditingController _primaryHexCtrl;
  late TextEditingController _secondaryHexCtrl;
  late bool _isActive;
  bool _isLoading = false;
  bool _isUploadingLogo = false;
  double _uploadProgress = 0;
  Uint8List? _previewBytes;

  @override
  void initState() {
    super.initState();
    final c = widget.company;
    _idCtrl = TextEditingController(text: c?.id ?? '');
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _logoUrlCtrl = TextEditingController(text: c?.logoUrl ?? '');
    _primaryHexCtrl = TextEditingController(text: c != null ? _colorToHex(c.primaryColor) : 'BA4817');
    _secondaryHexCtrl = TextEditingController(text: c != null ? _colorToHex(c.secondaryColor) : 'E5A102');
    _isActive = c?.isActive ?? true;
  }

  String _colorToHex(Color color) {
    return color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
  }

  Future<void> _pickAndUploadLogo() async {
    final companyId = _idCtrl.text.trim().toLowerCase().replaceAll(' ', '_');
    if (companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa primero el Identificador URL de la empresa.')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final ext = picked.name.split('.').last.toLowerCase();
    final dataUri = 'data:image/$ext;base64,${base64Encode(bytes)}';

    setState(() {
      _previewBytes = bytes;
      _logoUrlCtrl.text = dataUri;
    });

    // Subir también a Firebase Storage en segundo plano
    try {
      final ref = FirebaseStorage.instance.ref('logos/$companyId.$ext');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Logo seleccionado y cargado correctamente'), backgroundColor: AppTheme.incomeGreen),
      );
    }
  }

  Future<void> _save() async {
    if (_idCtrl.text.isEmpty || _nameCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final docId = _idCtrl.text.trim().toLowerCase().replaceAll(' ', '_');
      final docRef = FirebaseFirestore.instance.collection('companies_config').doc(docId);
      final primaryHex = _primaryHexCtrl.text.trim().replaceAll('#', '');
      final secondaryHex = _secondaryHexCtrl.text.trim().replaceAll('#', '');

      final Map<String, dynamic> data = {
        'name': _nameCtrl.text.trim(),
        'displayName': _nameCtrl.text.trim(),
        'logoUrl': _logoUrlCtrl.text.trim().isNotEmpty ? _logoUrlCtrl.text.trim() : null,
        'primaryColor': '#$primaryHex',
        'secondaryColor': '#$secondaryHex',
        'isActive': _isActive,
      };
      await docRef.set(data, SetOptions(merge: true));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.company != null;
    final existingLogoUrl = _logoUrlCtrl.text.trim();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(isEditing ? Icons.edit_note : Icons.domain_add, color: AppTheme.primaryOrange),
          const SizedBox(width: 10),
          Text(isEditing ? 'Editar Empresa' : 'Nueva Empresa',
               style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _idCtrl,
              enabled: !isEditing,
              decoration: const InputDecoration(
                labelText: 'Identificador URL (Ej: conci)',
                hintText: 'Minusculas sin espacios',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre Comercial',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Logo de la Empresa', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 10),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: _previewBytes != null
                          ? Image.memory(_previewBytes!, fit: BoxFit.contain)
                          : (existingLogoUrl.isNotEmpty
                              ? CompanyLogoWidget(
                                  logoUrl: existingLogoUrl,
                                  width: 100,
                                  height: 100,
                                  fallbackIconSize: 40,
                                )
                              : const Icon(Icons.image_outlined, size: 40, color: Colors.grey)),
                    ),
                  ),
                  if (_isUploadingLogo)
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(value: _uploadProgress, color: Colors.white, strokeWidth: 3),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_rounded),
              label: Text(_isUploadingLogo
                  ? 'Subiendo... %'
                  : 'Elegir imagen del dispositivo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryOrange,
                side: const BorderSide(color: AppTheme.primaryOrange),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _logoUrlCtrl,
              onChanged: (_) => setState(() => _previewBytes = null),
              decoration: const InputDecoration(
                labelText: 'O pegar URL del logo (HTTPS)',
                hintText: 'https://ejemplo.com/logo.png',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _primaryHexCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Color Primario (Hex)',
                      hintText: 'BA4817',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _secondaryHexCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Color Secundario (Hex)',
                      hintText: 'E5A102',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: Text('Estado de la Licencia', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(
                _isActive ? 'Activo (Acceso Permitido)' : 'Inactivo (Acceso Bloqueado)',
                style: TextStyle(color: _isActive ? AppTheme.incomeGreen : AppTheme.expenseRed, fontSize: 12),
              ),
              value: _isActive,
              activeColor: AppTheme.incomeGreen,
              onChanged: (val) => setState(() => _isActive = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: (_isLoading || _isUploadingLogo) ? null : _save,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(isEditing ? 'Guardar Cambios' : 'Crear Empresa'),
        ),
      ],
    );
  }
}
