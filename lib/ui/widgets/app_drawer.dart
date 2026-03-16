import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:petty_cash_app/models/movement_model.dart';

class AppDrawer extends ConsumerWidget {
  final String currentRoute;
  final Function(String) onItemSelected;

  const AppDrawer({
    super.key,
    required this.currentRoute,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    
    return Drawer(
      backgroundColor: AppTheme.pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        children: [
          // Header: User Profile
          userAsync.when(
            data: (user) => Container(
              padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 30),
              width: double.infinity,
              color: AppTheme.pureBlack,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.primaryOrange,
                    child: Text(
                      _getInitials(user?.name ?? 'U'),
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? 'Usuario',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    user?.establishment.name ?? 'General',
                    style: GoogleFonts.montserrat(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const DrawerHeader(child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const DrawerHeader(child: Center(child: Text('Error'))),
          ),
          
          const SizedBox(height: 10),
          
          // Navigation Items
          _DrawerItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            isSelected: currentRoute == 'dashboard',
            onTap: () => onItemSelected('dashboard'),
          ),
          _DrawerItem(
            icon: Icons.add_circle_outline,
            label: 'Nuevo Registro',
            isSelected: currentRoute == 'new',
            onTap: () => onItemSelected('new'),
          ),
          _DrawerItem(
            icon: Icons.history,
            label: 'Historial',
            isSelected: currentRoute == 'history',
            onTap: () => onItemSelected('history'),
          ),
          _DrawerItem(
            icon: Icons.person_outline,
            label: 'Perfil',
            isSelected: currentRoute == 'profile',
            onTap: () => onItemSelected('profile'),
          ),
          
          const Spacer(),
          
          // Footer
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  'AGROPECUARIA',
                  style: GoogleFonts.montserrat(
                    color: Colors.black26,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'LAS MARÍAS',
                  style: GoogleFonts.montserrat(
                    color: Colors.black45,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryOrange : AppTheme.textGrey,
      ),
      title: Text(
        label,
        style: GoogleFonts.montserrat(
          color: isSelected ? AppTheme.primaryOrange : AppTheme.textDark,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 15,
        ),
      ),
      selected: isSelected,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
