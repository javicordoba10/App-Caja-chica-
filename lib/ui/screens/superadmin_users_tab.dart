import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:petty_cash_app/ui/widgets/company_logo_widget.dart';

class SuperAdminUsersTab extends ConsumerWidget {
  const SuperAdminUsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);

    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('companies_config').snapshots(),
      builder: (context, companiesSnap) {
        if (companiesSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final companiesDocs = companiesSnap.data?.docs ?? [];
        final Map<String, Map<String, dynamic>> companiesMap = {};
        for (var doc in companiesDocs) {
          companiesMap[doc.id] = doc.data() as Map<String, dynamic>;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: firestore.collection('users').snapshots(),
          builder: (context, usersSnap) {
            if (usersSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final userDocs = usersSnap.data?.docs ?? [];

            // Group users by companyId (and isolate superadmins)
            final List<DocumentSnapshot> superAdmins = [];
            final Map<String, List<DocumentSnapshot>> usersByCompany = {};

            // Initialize all registered companies
            for (var compId in companiesMap.keys) {
              usersByCompany[compId] = [];
            }
            usersByCompany['unassigned'] = [];

            for (var uDoc in userDocs) {
              final uData = uDoc.data() as Map<String, dynamic>;
              final role = uData['role']?.toString() ?? 'user';
              final compId = uData['companyId']?.toString() ?? '';

              if (role == 'superadmin') {
                superAdmins.add(uDoc);
              } else if (usersByCompany.containsKey(compId)) {
                usersByCompany[compId]!.add(uDoc);
              } else {
                usersByCompany['unassigned']!.add(uDoc);
              }
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.apartment, color: AppTheme.primaryOrange, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Usuarios agrupados por empresa. Tocá cualquier empresa para ver sus usuarios.',
                          style: GoogleFonts.montserrat(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // SuperAdmins Global Group
                _buildCompanyAccordion(
                  context: context,
                  firestore: firestore,
                  title: '⚡ SuperAdmins Globales',
                  subtitle: 'Control total de la plataforma SaaS',
                  users: superAdmins,
                  isSuperAdminGroup: true,
                  color: AppTheme.primaryOrange,
                  allCompanies: companiesDocs,
                  initiallyExpanded: false,
                ),

                // Companies Accordions
                ...companiesDocs.map((cDoc) {
                  final cData = cDoc.data() as Map<String, dynamic>;
                  final compId = cDoc.id;
                  final compName = cData['name']?.toString() ?? compId;
                  final logoUrl = cData['logoUrl']?.toString();
                  final isActive = cData['isActive'] == true;
                  final compUsers = usersByCompany[compId] ?? [];

                  return _buildCompanyAccordion(
                    context: context,
                    firestore: firestore,
                    title: compName,
                    subtitle: 'ID: $compId • ${isActive ? "Licencia Activa" : "Suspendida"}',
                    logoUrl: logoUrl,
                    users: compUsers,
                    allCompanies: companiesDocs,
                    isSuperAdminGroup: false,
                    color: isActive ? Colors.blue : Colors.grey,
                    initiallyExpanded: true,
                  );
                }),

                // Unassigned users group (if any)
                if ((usersByCompany['unassigned'] ?? []).isNotEmpty)
                  _buildCompanyAccordion(
                    context: context,
                    firestore: firestore,
                    title: '⚠️ Sin Empresa Asignada',
                    subtitle: 'Usuarios huérfanos o sin configurar',
                    users: usersByCompany['unassigned']!,
                    allCompanies: companiesDocs,
                    isSuperAdminGroup: false,
                    color: Colors.red,
                    initiallyExpanded: false,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCompanyAccordion({
    required BuildContext context,
    required FirebaseFirestore firestore,
    required String title,
    required String subtitle,
    required List<DocumentSnapshot> users,
    required bool isSuperAdminGroup,
    required Color color,
    required bool initiallyExpanded,
    List<DocumentSnapshot> allCompanies = const [],
    String? logoUrl,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: logoUrl != null && logoUrl.trim().isNotEmpty
              ? CompanyLogoWidget(
                  logoUrl: logoUrl,
                  width: 38,
                  height: 38,
                  borderRadius: 8,
                )
              : CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(isSuperAdminGroup ? Icons.shield : Icons.business, color: color, size: 20),
                ),
          title: Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${users.length} ${users.length == 1 ? "usuario" : "usuarios"}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
            ),
          ),
          children: [
            if (users.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No hay usuarios registrados en esta empresa.', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: users.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[100]),
                itemBuilder: (context, index) {
                  final uDoc = users[index];
                  final data = uDoc.data() as Map<String, dynamic>;
                  final uid = uDoc.id;
                  final name = data['name']?.toString() ?? 'Sin nombre';
                  final email = data['email']?.toString() ?? '';
                  final role = data['role']?.toString() ?? 'user';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: _roleColor(role).withOpacity(0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(color: _roleColor(role), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    title: Text(name, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(email, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _roleColor(role).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _roleColor(role).withOpacity(0.3)),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _roleColor(role)),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          tooltip: 'Gestionar Usuario',
                          onSelected: (action) async {
                            if (action == 'user' || action == 'admin' || action == 'superadmin') {
                              await firestore.collection('users').doc(uid).update({'role': action});
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Rol de $name cambiado a $action'),
                                    backgroundColor: AppTheme.incomeGreen,
                                  ),
                                );
                              }
                            } else if (action == 'change_company') {
                              _showChangeCompanyDialog(context, firestore, uid, name, allCompanies);
                            } else if (action == 'delete') {
                              _showDeleteUserDialog(context, firestore, uid, name);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'user', child: Text('🙋 Cambiar Rol: Usuario')),
                            const PopupMenuItem(value: 'admin', child: Text('🛡️ Cambiar Rol: Administrador')),
                            const PopupMenuItem(value: 'superadmin', child: Text('⚡ Cambiar Rol: SuperAdmin')),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'change_company', child: Text('🏢 Cambiar de Empresa')),
                            const PopupMenuItem(value: 'delete', child: Text('🗑️ Eliminar Usuario', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showChangeCompanyDialog(
    BuildContext context,
    FirebaseFirestore firestore,
    String uid,
    String userName,
    List<DocumentSnapshot> companies,
  ) {
    String? selectedCompId;
    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Reasignar Empresa', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Seleccioná la nueva empresa para $userName:', style: const TextStyle(fontSize: 13, color: Colors.black87)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCompId,
                hint: const Text('Elegir empresa destino'),
                items: companies.map((c) {
                  final data = c.data() as Map<String, dynamic>;
                  final name = data['name'] ?? c.id;
                  return DropdownMenuItem<String>(value: c.id, child: Text(name));
                }).toList(),
                onChanged: (val) => setDlgState(() => selectedCompId = val),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('CANCELAR')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: selectedCompId == null
                  ? null
                  : () async {
                      Navigator.pop(dlgCtx);
                      await firestore.collection('users').doc(uid).update({'companyId': selectedCompId});
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$userName fue reasignado exitosamente.'),
                            backgroundColor: AppTheme.incomeGreen,
                          ),
                        );
                      }
                    },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteUserDialog(
    BuildContext context,
    FirebaseFirestore firestore,
    String uid,
    String userName,
  ) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar usuario?'),
        content: Text('¿Estás seguro de que querés eliminar a $userName? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('CANCELAR')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dlgCtx);
              await firestore.collection('users').doc(uid).delete();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Usuario $userName eliminado.'), backgroundColor: AppTheme.incomeGreen),
                );
              }
            },
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'superadmin':
        return AppTheme.primaryOrange;
      case 'admin':
        return Colors.blue;
      default:
        return Colors.grey[700]!;
    }
  }
}


