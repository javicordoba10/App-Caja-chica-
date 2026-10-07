import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petty_cash_app/ui/widgets/app_drawer.dart';
import 'package:petty_cash_app/ui/screens/dashboard_screen.dart';
import 'package:petty_cash_app/ui/screens/history_screen.dart';
import 'package:petty_cash_app/ui/screens/new_movement_screen.dart';
import 'package:petty_cash_app/ui/screens/profile_screen.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:petty_cash_app/ui/screens/users_screen.dart';
import 'package:petty_cash_app/ui/screens/superadmin_screen.dart';
import 'package:petty_cash_app/ui/screens/admin_recharges_screen.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/ui/screens/superadmin_home_screen.dart';
import 'package:petty_cash_app/ui/widgets/company_logo_widget.dart';

// State for navigation
final navigationProvider = StateProvider<String>((ref) => 'dashboard');

class MainLayout extends ConsumerWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = ref.watch(navigationProvider);
    final companyConfig = ref.watch(companyConfigProvider).value;
    final scaffoldKey = GlobalKey<ScaffoldState>();

    final currentUser = ref.watch(currentUserProvider).value;

    // Pantalla neutra si el usuario normal no tiene empresa asignada
    final hasNoCompany = companyConfig == null && currentUser != null
        && currentUser.role != 'superadmin'
        && (currentUser.companyId == null || currentUser.companyId!.isEmpty);

    if (hasNoCompany) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.business_outlined, size: 72, color: Colors.grey),
                const SizedBox(height: 24),
                Text('Bienvenido',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                const SizedBox(height: 12),
                Text(
                  'Tu cuenta aún no está asociada a ninguna empresa.\nPor favor accedé desde el link que te proporcionó tu empresa o contactá al administrador.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar Sesión'),
                  onPressed: () async {
                    await performLogout(ref, context);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Theme(
      data: AppTheme.buildDynamicTheme(companyConfig),
      child: Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          title: Text(_getTitle(currentRoute), style: const TextStyle(color: AppTheme.textDark, fontSize: 18)),
          backgroundColor: AppTheme.pureWhite,
          surfaceTintColor: AppTheme.pureWhite,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.pureBlack),
                  tooltip: 'Volver al Panel General',
                  onPressed: () => Navigator.pop(context),
                )
              : IconButton(
                  icon: const Icon(Icons.menu, color: AppTheme.pureBlack),
                  onPressed: () => scaffoldKey.currentState?.openDrawer(),
                ),
          actions: [
            if (currentUser?.role == 'superadmin')
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Center(
                  child: PopupMenuButton<String>(
                    tooltip: 'Auditoría: Cambiar Empresa',
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.pureBlack,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryOrange, width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_user_outlined, size: 14, color: AppTheme.primaryOrange),
                          const SizedBox(width: 5),
                          Text(
                            companyConfig?.name ?? 'CONCI',
                            style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                    onSelected: (selectedId) {
                      if (selectedId == 'saas_console') {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const SuperAdminHomeScreen()),
                          (route) => false,
                        );
                      } else {
                        ref.read(targetCompanyIdProvider.notifier).state = selectedId;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        enabled: false,
                        child: Text(
                          'AUDITAR SUB-EMPRESA',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ),
                      const PopupMenuItem(value: 'conci_sa', child: Text('🏢 CONCI S.A.')),
                      const PopupMenuItem(value: 'conci_srl', child: Text('🏢 CONCI S.R.L.')),
                      const PopupMenuItem(value: 'las_marias', child: Text('🏢 LAS MARÍAS')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'saas_console',
                        child: Row(
                          children: [
                            Icon(Icons.dashboard_customize_rounded, size: 16, color: AppTheme.primaryOrange),
                            SizedBox(width: 8),
                            Text('⚡ Panel Global SaaS', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (Navigator.canPop(context))
              IconButton(
                icon: const Icon(Icons.menu, color: AppTheme.pureBlack),
                tooltip: 'Menú lateral',
                onPressed: () => scaffoldKey.currentState?.openDrawer(),
              ),
            // Circulo 1: Logo de la empresa al lado del signo "+"
            if (companyConfig?.logoUrl != null && companyConfig!.logoUrl!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Center(
                  child: Container(
                    height: 34,
                    width: 34,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: CompanyLogoWidget(
                      logoUrl: companyConfig!.logoUrl,
                      height: 28,
                      width: 28,
                    ),
                  ),
                ),
              ),
            if (currentRoute == 'history' || currentRoute == 'dashboard')
              IconButton(
                icon: const Icon(Icons.add, color: AppTheme.primaryOrange),
                onPressed: () => ref.read(navigationProvider.notifier).state = 'new',
              ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.black54),
              tooltip: 'Cerrar Sesión',
              onPressed: () async {
                await performLogout(ref, context);
              },
            ),
          ],
        ),
        drawer: AppDrawer(
          currentRoute: currentRoute,
          onItemSelected: (route) {
            scaffoldKey.currentState?.closeDrawer();
            ref.read(navigationProvider.notifier).state = route;
          },
        ),
        body: _buildBody(currentRoute),
      ),
    );
  }

  String _getTitle(String route) {
    switch (route) {
      case 'dashboard':
        return 'Panel de Control';
      case 'history':
        return 'Historial';
      case 'new':
        return 'Nuevo Registro';
      case 'profile':
        return 'Mi Perfil';
      case 'users':
        return 'Gestión de Usuarios';
      case 'recharges':
        return 'Solicitudes de Recarga';
      case 'superadmin':
        return 'Consola SaaS';
      default:
        return 'Petty Cash';
    }
  }

  Widget _buildBody(String route) {
    switch (route) {
      case 'dashboard':
        return DashboardScreen();
      case 'history':
        return HistoryScreen();
      case 'new':
        return NewMovementScreen();
      case 'profile':
        return ProfileScreen();
      case 'users':
        return const UsersScreen();
      case 'recharges':
        return const AdminRechargesScreen();
      case 'superadmin':
        return const SuperadminScreen();
      default:
        return DashboardScreen();
    }
  }
}
