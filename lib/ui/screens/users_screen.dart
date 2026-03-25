import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/models/user_model.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';

import 'package:petty_cash_app/ui/screens/user_history_screen.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      backgroundColor: AppTheme.pureWhite,
      appBar: AppBar(
        title: Text(
          'GESTIÓN DE USUARIOS',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        centerTitle: true,
      ),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = users[index];
              return _UserCard(user: user);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  final UserModel user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBlocked = !user.isActive;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.whiteCardDecoration.copyWith(
        border: isBlocked ? Border.all(color: Colors.red.withOpacity(0.3), width: 1) : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isBlocked 
                    ? Colors.grey.withOpacity(0.1) 
                    : AppTheme.primaryOrange.withOpacity(0.1),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: isBlocked ? Colors.grey : AppTheme.primaryOrange, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.name,
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700, 
                            fontSize: 16,
                            decoration: isBlocked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (isBlocked) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.block, size: 14, color: Colors.red),
                        ],
                      ],
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.textGrey),
                onSelected: (val) {
                  if (val == 'role') _showRoleDialog(context, ref);
                  if (val == 'status') _toggleBlock(context, ref);
                  if (val == 'delete') _showDeleteDialog(context, ref);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'role',
                    child: Row(children: [
                      const Icon(Icons.badge_outlined, size: 18),
                      const SizedBox(width: 10),
                      Text('Cambiar a ${user.role == "admin" ? "Usuario" : "Admin"}'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'status',
                    child: Row(children: [
                      Icon(isBlocked ? Icons.check_circle_outline : Icons.block, size: 18, color: isBlocked ? Colors.green : Colors.orange),
                      const SizedBox(width: 10),
                      Text(isBlocked ? 'Desbloquear' : 'Bloquear Usuario'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_forever_outlined, size: 18, color: Colors.red),
                      const SizedBox(width: 10),
                      Text('Eliminar Definitivo', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SALDO TOTAL', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(
                    'ARS ${user.balances.values.fold(0.0, (sum, val) => sum + val).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => UserHistoryScreen(user: user)),
                  );
                },
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Supervisar Historial', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRoleDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar Rol'),
        content: Text('¿Deseas cambiar el rol de ${user.name} a ${user.role == "admin" ? "Usuario" : "Administrador"}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              final newRole = user.role == "admin" ? "user" : "admin";
              await ref.read(userRepositoryProvider).updateUserRole(user.id, newRole);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('CAMBIAR'),
          ),
        ],
      ),
    );
  }

  void _toggleBlock(BuildContext context, WidgetRef ref) async {
    final status = !user.isActive;
    await ref.read(userRepositoryProvider).updateUserStatus(user.id, status);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status ? 'Usuario desbloqueado' : 'Usuario bloqueado')),
      );
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar definitivamente', style: TextStyle(color: Colors.red)),
        content: Text('¿Estás seguro de que deseas eliminar permanentemente a ${user.name}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(userRepositoryProvider).deleteUser(user.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
