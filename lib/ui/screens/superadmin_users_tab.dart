import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';

class SuperAdminUsersTab extends ConsumerWidget {
  const SuperAdminUsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);

    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('users').orderBy('name').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay usuarios registrados.'));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final uid = docs[index].id;
            final name = data['name'] ?? 'Sin nombre';
            final email = data['email'] ?? '';
            final role = data['role'] ?? 'user';
            final companyId = data['companyId'] ?? '';

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: _roleColor(role).withOpacity(0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(color: _roleColor(role), fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(name, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _roleColor(role).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _roleColor(role)),
                          ),
                        ),
                        if (companyId.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text('📍 ', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) async {
                    if (value == 'superadmin' || value == 'admin' || value == 'user') {
                      await firestore.collection('users').doc(uid).update({'role': value});
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Rol de  cambiado a '), backgroundColor: AppTheme.incomeGreen),
                        );
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'user', child: Text('🙋 Cambiar a User')),
                    const PopupMenuItem(value: 'admin', child: Text('🛡️ Cambiar a Admin')),
                    const PopupMenuItem(value: 'superadmin', child: Text('⚡ Cambiar a SuperAdmin')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'superadmin': return AppTheme.primaryOrange;
      case 'admin': return Colors.blue;
      default: return Colors.grey;
    }
  }
}
