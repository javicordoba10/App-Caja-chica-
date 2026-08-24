import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
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


// State for navigation
final navigationProvider = StateProvider<String>((ref) => 'dashboard');

class MainLayout extends ConsumerWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = ref.watch(navigationProvider);
    final companyConfig = ref.watch(companyConfigProvider).value;
    final scaffoldKey = GlobalKey<ScaffoldState>();

    final inspectId = ref.watch(superAdminInspectTenantProvider);
    final isInspecting = inspectId != null;
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
                    await FirebaseAuth.instance.signOut();
                    ref.read(currentUserIdProvider.notifier).state = null;
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
          title: Text(isInspecting ? '👁️ AUDITANDO: ${companyConfig?.name ?? inspectId}' : _getTitle(currentRoute), style: TextStyle(color: isInspecting ? AppTheme.expenseRed : AppTheme.textDark, fontWeight: isInspecting ? FontWeight.bold : FontWeight.normal, fontSize: isInspecting ? 14 : 18)),
          backgroundColor: isInspecting ? AppTheme.expenseRed.withOpacity(0.1) : AppTheme.pureWhite,
          surfaceTintColor: isInspecting ? AppTheme.expenseRed.withOpacity(0.1) : AppTheme.pureWhite,
          leading: IconButton(
            icon: Icon(Icons.menu, color: isInspecting ? AppTheme.expenseRed : AppTheme.pureBlack),
            onPressed: () => scaffoldKey.currentState?.openDrawer(),
          ),
          actions: [
            if (isInspecting)
               Padding(
                 padding: const EdgeInsets.only(right: 8.0),
                 child: OutlinedButton.icon(
                   icon: const Icon(Icons.close, size: 16, color: AppTheme.expenseRed),
                   label: const Text('SALIR', style: TextStyle(color: AppTheme.expenseRed, fontWeight: FontWeight.bold)),
                   style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.expenseRed)),
                   onPressed: () => ref.read(superAdminInspectTenantProvider.notifier).state = null,
                 ),
               ),
            // Circulo 1: Logo de la empresa al lado del signo "+"
            if (companyConfig?.logoUrl != null && companyConfig!.logoUrl!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Center(
                  child: Container(
                    height: 32,
                    width: 32,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        companyConfig!.logoUrl!.trim(),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            if (currentRoute == 'history' || currentRoute == 'dashboard')
              IconButton(
                icon: const Icon(Icons.add, color: AppTheme.primaryOrange),
                onPressed: () => ref.read(navigationProvider.notifier).state = 'new',
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
