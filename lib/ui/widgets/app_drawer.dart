import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:petty_cash_app/ui/widgets/company_logo_widget.dart';

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
    final companyConfig = ref.watch(companyConfigProvider).value;
    
    return Drawer(
      backgroundColor: AppTheme.pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        children: [
          // Header: User Profile with Company Logo (Circulo 2)
          userAsync.when(
            data: (user) => Container(
              padding: const EdgeInsets.only(top: 50, left: 24, right: 24, bottom: 24),
              width: double.infinity,
              color: AppTheme.pureBlack,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.primaryOrange,
                        child: Text(
                          _getInitials(user?.name ?? 'U'),
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      if (companyConfig?.logoUrl != null && companyConfig!.logoUrl!.trim().isNotEmpty)
                        Container(
                          height: 46,
                          width: 46,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                          ),
                          child: CompanyLogoWidget(
                            logoUrl: companyConfig!.logoUrl,
                            height: 38,
                            width: 38,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user?.name ?? 'Usuario',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${(user?.jobRole ?? 'Sin Rol').toUpperCase()} (${companyConfig?.name ?? 'ALM'})',
                    style: GoogleFonts.montserrat(
                      color: Colors.white60,
                      fontSize: 11,
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
          
          // Solo para Administradores de Inquilino
          userAsync.when(
            data: (user) => (user?.role == 'admin' || user?.role == 'superadmin')
              ? Column(
                  children: [
                    _DrawerItem(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Gestión Usuarios',
                      isSelected: currentRoute == 'users',
                      onTap: () => onItemSelected('users'),
                    ),
                    _DrawerItem(
                      icon: Icons.request_quote_outlined,
                      label: 'Gestión Reintegros',
                      isSelected: currentRoute == 'recharges',
                      onTap: () => onItemSelected('recharges'),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          
          // Solo para SuperAdmin Global (SaaS)
          userAsync.when(
            data: (user) => user?.role == 'superadmin' 
              ? _DrawerItem(
                  icon: Icons.business_center_outlined,
                  label: 'Gestión SaaS',
                  isSelected: currentRoute == 'superadmin',
                  onTap: () => onItemSelected('superadmin'),
                )
              : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          
          const Spacer(),
          
          // Footer with Company Logo (Circulo 3)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              children: [
                if (companyConfig?.logoUrl != null && companyConfig!.logoUrl!.trim().isNotEmpty) ...[
                  CompanyLogoWidget(
                    logoUrl: companyConfig!.logoUrl,
                    height: 44,
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  (companyConfig?.name ?? 'CONTROL DE CAJA').toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
