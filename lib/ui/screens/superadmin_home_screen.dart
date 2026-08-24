import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:petty_cash_app/ui/screens/superadmin_screen.dart';
import 'package:petty_cash_app/ui/screens/superadmin_users_tab.dart';
import 'package:petty_cash_app/ui/screens/profile_screen.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:petty_cash_app/ui/widgets/tenant_dialog.dart';
import 'package:petty_cash_app/ui/widgets/main_layout.dart';

class SuperAdminHomeScreen extends ConsumerStatefulWidget {
  const SuperAdminHomeScreen({super.key});

  @override
  ConsumerState<SuperAdminHomeScreen> createState() => _SuperAdminHomeScreenState();
}

class _SuperAdminHomeScreenState extends ConsumerState<SuperAdminHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = ref.watch(firestoreProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      drawer: _SuperAdminDrawer(tabController: _tabController),
      appBar: AppBar(
        backgroundColor: AppTheme.pureBlack,
        surfaceTintColor: AppTheme.pureBlack,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('SUPER', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
            ),
            const SizedBox(width: 8),
            Text('Panel SaaS', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryOrange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.business), text: 'Empresas'),
            Tab(icon: Icon(Icons.people), text: 'Usuarios'),
          ],
        ),
      ),
      body: Column(
        children: [
          _GlobalMetricsHeader(firestore: firestore),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                SuperadminScreen(),
                SuperAdminUsersTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryOrange,
        icon: const Icon(Icons.domain_add, color: Colors.white),
        label: Text('Nueva Empresa', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          showDialog(context: context, builder: (_) => const TenantDialog());
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drawer del SuperAdmin
// ─────────────────────────────────────────────────────────────────────────────

class _SuperAdminDrawer extends ConsumerWidget {
  final TabController tabController;
  const _SuperAdminDrawer({required this.tabController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    final name = currentUser?.name ?? 'Super Admin';
    final email = currentUser?.email ?? '';

    return Drawer(
      child: Column(
        children: [
          // Header negro
          Container(
            color: AppTheme.pureBlack,
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20, right: 20, bottom: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryOrange,
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                      style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                ),
                const SizedBox(height: 10),
                Text(name, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(email, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.primaryOrange, borderRadius: BorderRadius.circular(6)),
                  child: Text('SUPER ADMIN', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.dashboard_customize_outlined, color: AppTheme.primaryOrange),
                  title: const Text('Panel SaaS'),
                  subtitle: const Text('Empresas y métricas'),
                  onTap: () {
                    Navigator.pop(context);
                    tabController.animateTo(0);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people_outline, color: Colors.blue),
                  title: const Text('Gestión de Usuarios'),
                  subtitle: const Text('Control de roles por empresa'),
                  onTap: () {
                    Navigator.pop(context);
                    tabController.animateTo(1);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Mi Perfil'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Mi Perfil'), backgroundColor: AppTheme.pureBlack, foregroundColor: Colors.white),
                      body: const ProfileScreen(),
                    )));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(context);
                    await FirebaseAuth.instance.signOut();
                    ref.read(currentUserIdProvider.notifier).state = null;
                  },
                ),
              ],
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Sistema de Gestión SaaS', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header de métricas globales
// ─────────────────────────────────────────────────────────────────────────────

class _GlobalMetricsHeader extends StatelessWidget {
  final FirebaseFirestore firestore;
  const _GlobalMetricsHeader({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.pureBlack,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: StreamBuilder<QuerySnapshot>(
        stream: firestore.collection('companies_config').snapshots(),
        builder: (context, companiesSnap) {
          final totalCompanies = companiesSnap.data?.docs.length ?? 0;
          final activeCompanies = companiesSnap.data?.docs
              .where((d) => (d.data() as Map<String, dynamic>)['isActive'] == true)
              .length ?? 0;

          return StreamBuilder<QuerySnapshot>(
            stream: firestore.collection('users').snapshots(),
            builder: (context, usersSnap) {
              final totalUsers = usersSnap.data?.docs.length ?? 0;

              return StreamBuilder<QuerySnapshot>(
                stream: firestore.collection('movements').snapshots(),
                builder: (context, movSnap) {
                  final totalMovements = movSnap.data?.docs.length ?? 0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _HeaderMetric(label: 'Empresas', value: '', sub: ' activas', color: AppTheme.primaryOrange),
                      _HeaderMetric(label: 'Usuarios', value: '', sub: 'en total', color: Colors.blueAccent),
                      _HeaderMetric(label: 'Movimientos', value: '', sub: 'globales', color: Colors.greenAccent),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  const _HeaderMetric({required this.label, required this.value, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: GoogleFonts.montserrat(color: color, fontWeight: FontWeight.w900, fontSize: 22)),
        Text(label, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
        Text(sub, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}
