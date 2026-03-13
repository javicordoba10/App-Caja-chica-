import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sidebar.dart';
import '../screens/dashboard_screen.dart';
import '../screens/history_screen.dart';
import '../screens/validation_form_screen.dart';
import '../../models/movement_model.dart';
import '../../services/ocr_service.dart';

// State for navigation
final navigationProvider = StateProvider<String>((ref) => 'dashboard');

class MainLayout extends ConsumerWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = ref.watch(navigationProvider);

    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            currentRoute: currentRoute,
            onItemSelected: (route) {
              if (route == 'new') {
                _showNewEntryOptions(context);
              } else {
                ref.read(navigationProvider.notifier).state = route;
              }
            },
          ),
          Expanded(
            child: _buildBody(currentRoute),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(String route) {
    switch (route) {
      case 'dashboard':
        return const DashboardScreen();
      case 'history':
        return const HistoryScreen();
      default:
        return const DashboardScreen();
    }
  }

  void _showNewEntryOptions(BuildContext context) {
    // We reuse the existing logic from Dashboard but trigger it from sidebar
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Nuevo Registro', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.orange),
                  title: const Text('Carga Manual'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ValidationFormScreen(
                        data: ExtractedReceiptData(imagePath: ''),
                        initialType: MovementType.expense,
                      ),
                    ));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.orange),
                  title: const Text('Escanear / Foto'),
                  onTap: () {
                    // Similar to dashboard logic...
                    Navigator.pop(ctx);
                    // This is handled in DashboardScreen normally, 
                    // but for a true Sidebar experience we might want to consolidate state.
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
