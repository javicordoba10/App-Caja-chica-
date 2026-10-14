import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:petty_cash_app/models/user_model.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'legal_terms_screen.dart';
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _jobRoleCtrl;
  List<String> _selectedEstablishments = [];
  List<String> _selectedPaymentMethods = [];
  final _newMethodCtrl = TextEditingController();
  final _newEstablishmentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _jobRoleCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _jobRoleCtrl.dispose();
    _newMethodCtrl.dispose();
    _newEstablishmentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
        data: (user) {
          if (!_isEditing) {
            _nameCtrl.text = user?.name ?? '';
            _phoneCtrl.text = user?.phone ?? '';
            _jobRoleCtrl.text = user?.jobRole ?? 'Sin Rol';
            _selectedEstablishments = List.from(user?.establishments ?? []);
            _selectedPaymentMethods = List.from(user?.paymentMethods ?? []);
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                // Avatar Section
                _buildAvatarSection(user),
                const SizedBox(height: 32),

                // Info Cards
                _buildInfoCard(
                  title: 'DATOS PERSONALES',
                  children: [
                    _buildEditableTile(Icons.person_outline, 'Nombre completo', _nameCtrl, enabled: _isEditing),
                    _buildInfoTile(Icons.email_outlined, 'Email', user?.email ?? 'No disponible'),
                    _buildEditableTile(Icons.phone_outlined, 'Teléfono', _phoneCtrl, enabled: _isEditing),
                  ],
                ),
                const SizedBox(height: 16),
                
                _buildInfoCard(
                  title: 'GESTIÓN DE FORMAS DE PAGO',
                  children: [
                    _buildDynamicList(
                      items: _selectedPaymentMethods,
                      controller: _newMethodCtrl,
                      hint: 'Ej: Mercado Pago',
                      enabled: _isEditing,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                _buildInfoCard(
                  title: 'CONFIGURACIÓN DE TRABAJO',
                  children: [
                    _buildEditableTile(Icons.work_outline, 'Rol', _jobRoleCtrl, enabled: _isEditing),
                    const SizedBox(height: 12),
                    Text('Establecimientos a Cargo', style: GoogleFonts.montserrat(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildDynamicList(
                      items: _selectedEstablishments,
                      controller: _newEstablishmentCtrl,
                      hint: 'Ej: Sede Principal',
                      enabled: _isEditing,
                      isEstablishment: true,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoTile(Icons.security_outlined, 'Permisos (Sistema)', user?.role ?? 'Usuario'),
                  ],
                ),
                const SizedBox(height: 32),

                // Actions
                if (_isEditing)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _isEditing = false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('CANCELAR'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _saveProfile(user!.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.pureBlack,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('GUARDAR'),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _isEditing = true),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('EDITAR PERFIL'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            foregroundColor: AppTheme.primaryOrange,
                            side: const BorderSide(color: AppTheme.primaryOrange),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => LegalTermsScreen.showLegalDialog(context),
                          icon: const Icon(Icons.shield_outlined, size: 18, color: AppTheme.textGrey),
                          label: Text(
                            'Términos del Servicio y Privacidad',
                            style: GoogleFonts.montserrat(color: AppTheme.textGrey, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () async {
                            await performLogout(ref, context);
                          },
                          icon: const Icon(Icons.logout, size: 18, color: AppTheme.expenseRed),
                          label: const Text('CERRAR SESIÓN', style: TextStyle(color: AppTheme.expenseRed, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => _confirmDeleteAccount(user!),
                          icon: const Icon(Icons.delete_forever_outlined, size: 16, color: Colors.grey),
                          label: Text(
                            'Eliminar mi cuenta / Solicitar baja',
                            style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 11.5, decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e')),
      );
  }

  Widget _buildAvatarSection(UserModel? user) {
    final initials = (user?.name ?? 'U').split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase();
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primaryOrange, width: 2),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: AppTheme.pureBlack,
            child: Text(
              initials,
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user?.name ?? 'Usuario',
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textDark,
          ),
        ),
        Text(
          user?.jobRole ?? 'Sin Rol',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: AppTheme.textGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.textGrey,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textGrey.withOpacity(0.5)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.montserrat(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
              Text(value, style: GoogleFonts.montserrat(color: AppTheme.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableTile(IconData icon, String label, TextEditingController ctrl, {required bool enabled}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: enabled ? AppTheme.primaryOrange : AppTheme.textGrey.withOpacity(0.5)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.montserrat(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                if (enabled)
                  TextField(
                    controller: ctrl,
                    style: GoogleFonts.montserrat(color: AppTheme.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      border: UnderlineInputBorder(),
                    ),
                  )
                else
                  Text(ctrl.text.isEmpty ? 'No establecido' : ctrl.text, style: GoogleFonts.montserrat(color: AppTheme.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicList({
    required List<String> items,
    required TextEditingController controller,
    required String hint,
    required bool enabled,
    bool isEstablishment = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((m) {
            return Chip(
              label: Text(m, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
              onDeleted: enabled ? () {
                setState(() {
                  if (items.length > 1) {
                    items.remove(m);
                  }
                });
              } : null,
              deleteIconColor: AppTheme.expenseRed,
              backgroundColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            );
          }).toList(),
        ),
        if (enabled) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.montserrat(fontSize: 12, color: AppTheme.textGrey),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty && !items.contains(isEstablishment ? text.toUpperCase() : text)) {
                    setState(() {
                      items.add(isEstablishment ? text.toUpperCase() : text);
                      controller.clear();
                    });
                  }
                },
                icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryOrange),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _saveProfile(String userId) async {
    try {
      await ref.read(userRepositoryProvider).updateUserProfile(
        userId,
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        jobRole: _jobRoleCtrl.text,
        establishments: _selectedEstablishments,
        paymentMethods: _selectedPaymentMethods,
      );
      
      setState(() => _isEditing = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado ✓'), backgroundColor: AppTheme.incomeGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: AppTheme.expenseRed),
        );
      }
    }
  }

  void _confirmDeleteAccount(UserModel user) {
    if (user.role == 'superadmin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por seguridad, la cuenta SuperAdmin no puede ser eliminada desde la aplicación.'),
          backgroundColor: AppTheme.expenseRed,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '¿Solicitar baja de cuenta?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'En cumplimiento de las políticas de privacidad y protección de datos (Ley 25.326 y normativas de tiendas de aplicaciones), tu cuenta será desactivada y desvinculada de la organización.\n\n¿Estás seguro de que deseas proceder?',
          style: GoogleFonts.montserrat(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(userRepositoryProvider).updateUserStatus(user.id, false);
                try {
                  await FirebaseAuth.instance.currentUser?.delete();
                } catch (_) {
                  // Fallback si requiere reautenticación
                }
                if (mounted) {
                  await performLogout(ref, context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al procesar la baja: $e'), backgroundColor: AppTheme.expenseRed),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.expenseRed),
            child: const Text('CONFIRMAR BAJA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
