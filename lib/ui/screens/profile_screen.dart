import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:petty_cash_app/models/user_model.dart';
import 'package:petty_cash_app/models/movement_model.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  List<CostCenter> _selectedEstablishments = [];
  List<String> _selectedPaymentMethods = [];
  final _newMethodCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _newMethodCtrl.dispose();
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
                    _buildPaymentMethodsList(user, enabled: _isEditing),
                  ],
                ),
                const SizedBox(height: 16),
                
                _buildInfoCard(
                  title: 'CONFIGURACIÓN DE TRABAJO',
                  children: [
                    _buildMultiSelectTile(
                      Icons.business_outlined, 
                      'Establecimientos a Cargo', 
                      _selectedEstablishments,
                      enabled: _isEditing,
                      onToggle: (val) {
                        setState(() {
                          if (_selectedEstablishments.contains(val)) {
                            if (_selectedEstablishments.length > 1) {
                              _selectedEstablishments.remove(val);
                            }
                          } else {
                            _selectedEstablishments.add(val!);
                          }
                        });
                      },
                    ),
                    _buildInfoTile(Icons.badge_outlined, 'Rol de Usuario', user?.role ?? 'Usuario'),
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
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          icon: const Icon(Icons.logout, size: 18, color: AppTheme.expenseRed),
                          label: const Text('CERRAR SESIÓN', style: TextStyle(color: AppTheme.expenseRed, fontWeight: FontWeight.bold)),
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
          user?.establishments.map((e) => _getEstablishmentName(e)).join(' • ') ?? 'General',
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

  Widget _buildMultiSelectTile(IconData icon, String label, List<CostCenter> current, {required bool enabled, required ValueChanged<CostCenter?> onToggle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: enabled ? AppTheme.primaryOrange : AppTheme.textGrey.withOpacity(0.5)),
              const SizedBox(width: 16),
              Text(label, style: GoogleFonts.montserrat(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CostCenter.values.map((c) {
              final isSelected = current.contains(c);
              if (!enabled && !isSelected) return const SizedBox.shrink();
              
              return FilterChip(
                label: Text(_getEstablishmentName(c), style: GoogleFonts.montserrat(
                  fontSize: 12, 
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.textDark,
                )),
                selected: isSelected,
                onSelected: enabled ? (selected) => onToggle(c) : null,
                selectedColor: AppTheme.pureBlack,
                checkmarkColor: Colors.white,
                backgroundColor: Colors.black12,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsList(UserModel? user, {required bool enabled}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _selectedPaymentMethods.map((m) {
            return Chip(
              label: Text(m, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
              onDeleted: enabled ? () {
                setState(() {
                  if (_selectedPaymentMethods.length > 1) {
                    _selectedPaymentMethods.remove(m);
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
                  controller: _newMethodCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ej: Mercado Pago',
                    hintStyle: GoogleFonts.montserrat(fontSize: 12, color: AppTheme.textGrey),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  final text = _newMethodCtrl.text.trim();
                  if (text.isNotEmpty && !_selectedPaymentMethods.contains(text)) {
                    setState(() {
                      _selectedPaymentMethods.add(text);
                      _newMethodCtrl.clear();
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

  String _getEstablishmentName(CostCenter c) {
    switch (c) {
      case CostCenter.Administracion: return 'Administración';
      case CostCenter.PuestoDeLuna: return 'Puesto de Luna';
      case CostCenter.FeedLot: return 'FeedLot';
      case CostCenter.SanIsidro: return 'San Isidro';
      case CostCenter.LaCarlota: return 'La Carlota';
      case CostCenter.LaHuella: return 'La Huella';
      case CostCenter.ElSiete: return 'El Siete';
      case CostCenter.ElMoro: return 'El Moro';
      default: return 'Otro';
    }
  }

  void _saveProfile(String userId) async {
    try {
      await ref.read(userRepositoryProvider).updateUserProfile(
        userId,
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
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
}
