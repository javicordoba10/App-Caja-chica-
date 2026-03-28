import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class TenantDialog extends StatefulWidget {
  const TenantDialog({super.key});

  @override
  State<TenantDialog> createState() => _TenantDialogState();
}

class _TenantDialogState extends State<TenantDialog> {
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _primaryHexCtrl = TextEditingController(text: 'BA4817');
  final _secondaryHexCtrl = TextEditingController(text: 'E5A102');
  bool _isLoading = false;

  Future<void> _save() async {
    if (_idCtrl.text.isEmpty || _nameCtrl.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final docId = _idCtrl.text.trim().toLowerCase().replaceAll(' ', '_');
      final docRef = FirebaseFirestore.instance.collection('companies_config').doc(docId);
      
      await docRef.set({
        'name': _nameCtrl.text.trim(),
        'displayName': _nameCtrl.text.trim(),
        'primaryColor': '#${_primaryHexCtrl.text.trim()}',
        'secondaryColor': '#${_secondaryHexCtrl.text.trim()}',
        'isActive': true,
      }, SetOptions(merge: true));
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nueva Marca Blanca', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _idCtrl, decoration: const InputDecoration(labelText: 'Identificador URL (Ej: conci)', hintText: 'Minúsculas sin espacios')),
            const SizedBox(height: 12),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nombre Comercial Oficial')),
            const SizedBox(height: 12),
            TextField(controller: _primaryHexCtrl, decoration: const InputDecoration(labelText: 'Color Primario (Hex sin #)')),
            const SizedBox(height: 12),
            TextField(controller: _secondaryHexCtrl, decoration: const InputDecoration(labelText: 'Color Secundario (Hex sin #)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Crear Inquilino'),
        )
      ],
    );
  }
}
