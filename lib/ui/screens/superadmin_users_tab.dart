import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';

class SuperAdminUsersTab extends ConsumerStatefulWidget {
  const SuperAdminUsersTab({super.key});

  @override
  ConsumerState<SuperAdminUsersTab> createState() => _SuperAdminUsersTabState();
}

class _SuperAdminUsersTabState extends ConsumerState<SuperAdminUsersTab> {
  String _selectedCompanyFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = ref.watch(firestoreProvider);

    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('companies_config').snapshots(),
      builder: (context, companiesSnap) {
        final Map<String, String> companyNames = {};
        final List<Map<String, String>> companiesList = [];

        if (companiesSnap.hasData) {
          for (var doc in companiesSnap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name']?.toString() ?? doc.id;
            companyNames[doc.id] = name;
            companiesList.add({'id': doc.id, 'name': name});
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: firestore.collection('users').snapshots(),
          builder: (context, usersSnap) {
            if (usersSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allDocs = usersSnap.data?.docs ?? [];
            var filteredDocs = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final role = data['role']?.toString() ?? 'user';
              final compId = data['companyId']?.toString() ?? '';
              final name = data['name']?.toString().toLowerCase() ?? '';
              final email = data['email']?.toString().toLowerCase() ?? '';

              // Filter by company
              if (_selectedCompanyFilter != 'all') {
                if (_selectedCompanyFilter == 'superadmin_only') {
                  if (role != 'superadmin') return false;
                } else {
                  if (compId != _selectedCompanyFilter) return false;
                }
              }

              // Filter by search text
              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                if (!name.contains(q) && !email.contains(q)) return false;
              }

              return true;
            }).toList();

            return Column(
              children: [
                // Filter Header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      // Search field
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Buscar usuario por nombre o correo...',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      ),
                      const SizedBox(height: 10),
                      // Company Dropdown filter
                      Row(
                        children: [
                          const Icon(Icons.filter_list, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text('Filtrar Empresa:', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCompanyFilter,
                              isExpanded: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                              items: [
                                const DropdownMenuItem(value: 'all', child: Text('🌐 Todas las Empresas')),
                                ...companiesList.map((c) => DropdownMenuItem(
                                      value: c['id']!,
                                      child: Text('🏢 ${c['name']} (${c['id']})'),
                                    )),
                                const DropdownMenuItem(value: 'superadmin_only', child: Text('⚡ Solo SuperAdmins')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCompanyFilter = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Users list
                Expanded(
                  child: filteredDocs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people_outline, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text('No se encontraron usuarios.', style: GoogleFonts.montserrat(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final data = filteredDocs[index].data() as Map<String, dynamic>;
                            final uid = filteredDocs[index].id;
                            final name = data['name']?.toString() ?? 'Sin nombre';
                            final email = data['email']?.toString() ?? '';
                            final role = data['role']?.toString() ?? 'user';
                            final compId = data['companyId']?.toString() ?? '';
                            final compName = companyNames[compId] ?? (compId.isNotEmpty ? compId : 'Sin Empresa');

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: Colors.grey[200]!),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: _roleColor(role).withOpacity(0.15),
                                          child: Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                                            style: TextStyle(color: _roleColor(role), fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(name, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15)),
                                              Text(email, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                            ],
                                          ),
                                        ),
                                        // Role badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _roleColor(role).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: _roleColor(role).withOpacity(0.4)),
                                          ),
                                          child: Text(
                                            role.toUpperCase(),
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _roleColor(role)),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, size: 20),
                                          tooltip: 'Cambiar Rol',
                                          onSelected: (value) async {
                                            if (value == 'superadmin' || value == 'admin' || value == 'user') {
                                              await firestore.collection('users').doc(uid).update({'role': value});
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Rol de $name actualizado a $value'),
                                                    backgroundColor: AppTheme.incomeGreen,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(value: 'user', child: Text('🙋 Asignar Rol Usuario (User)')),
                                            const PopupMenuItem(value: 'admin', child: Text('🛡️ Asignar Rol Administrador (Admin)')),
                                            const PopupMenuItem(value: 'superadmin', child: Text('⚡ Asignar Rol SuperAdmin')),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(role == 'superadmin' ? Icons.shield_outlined : Icons.business, size: 14, color: Colors.grey[700]),
                                          const SizedBox(width: 6),
                                          Text(
                                            role == 'superadmin' ? 'SuperAdmin Global (Todas las empresas)' : 'Empresa: $compName ($compId)',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
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

