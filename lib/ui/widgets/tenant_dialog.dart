import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/models/company_config_model.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';

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

  Future<void> _save() async {
    if (_idCtrl.text.isEmpty || _nameCtrl.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final docId = _idCtrl.text.trim().toLowerCase().replaceAll(' ', '_');
      final docRef = FirebaseFirestore.instance.collection('companies_config').doc(docId);
      
      final Map<String, dynamic> data = {
        'name': _nameCtrl.text.trim(),
        'displayName': _nameCtrl.text.trim(),
        'logoUrl': _logoUrlCtrl.text.trim().isNotEmpty ? _logoUrlCtrl.text.trim() : null,
        'primaryColor': '#${_primaryHexCtrl.text.trim()}',
        'secondaryColor': '#${_secondaryHexCtrl.text.trim()}',
        'isActive': _isActive,
      };

      await docRef.set(data, SetOptions(merge: true));
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.company != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(isEditing ? Icons.edit_note : Icons.domain_add, color: AppTheme.primaryOrange),
          const SizedBox(width: 10),
          Text(isEditing ? 'Editar Empresa' : 'Nueva Empresa Marca Blanca', 
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
                hintText: 'Minúsculas sin espacios',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl, 
              decoration: const InputDecoration(
                labelText: 'Nombre Comercial Oficial',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _logoUrlCtrl, 
              decoration: const InputDecoration(
                labelText: 'URL del Logo de la Empresa (HTTPS)',
                hintText: 'https://ejemplo.com/logo.png',
                prefixIcon: Icon(Icons.image_outlined),
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
              subtitle: Text(_isActive ? 'Activo (Acceso Permitido)' : 'Inactivo (Acceso Bloqueado)',
                             style: TextStyle(color: _isActive ? AppTheme.incomeGreen : AppTheme.expenseRed, fontSize: 12)),
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
          onPressed: _isLoading ? null : _save,
          child: _isLoading 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : Text(isEditing ? 'Guardar Cambios' : 'Crear Inquilino'),
        )
      ],
    );
  }
}
