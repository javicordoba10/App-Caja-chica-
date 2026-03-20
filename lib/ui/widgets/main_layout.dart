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

// State for navigation
final navigationProvider = StateProvider<String>((ref) => 'dashboard');

class MainLayout extends ConsumerWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = ref.watch(navigationProvider);
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: Text(_getTitle(currentRoute)),
        backgroundColor: AppTheme.pureWhite,
        surfaceTintColor: AppTheme.pureWhite,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppTheme.pureBlack),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
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
      default:
        return DashboardScreen();
    }
  }
}
