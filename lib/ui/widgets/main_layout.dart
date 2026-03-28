import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petty_cash_app/ui/widgets/app_drawer.dart';
import 'package:petty_cash_app/ui/screens/dashboard_screen.dart';
import 'package:petty_cash_app/ui/screens/history_screen.dart';
import 'package:petty_cash_app/ui/screens/new_movement_screen.dart';
import 'package:petty_cash_app/ui/screens/profile_screen.dart';
import 'package:petty_cash_app/ui/screens/validation_form_screen.dart';
import 'package:petty_cash_app/models/movement_model.dart';
import 'package:petty_cash_app/services/ocr_service.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:petty_cash_app/ui/screens/users_screen.dart';
import 'package:petty_cash_app/ui/screens/superadmin_screen.dart';
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
            if (currentRoute == 'history')
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
      case 'superadmin':
        return const SuperadminScreen();
      default:
        return DashboardScreen();
    }
  }
}
