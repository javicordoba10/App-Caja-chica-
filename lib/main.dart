import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants/conci_logo.dart';
import 'models/user_model.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/unverified_email_screen.dart';
import 'ui/screens/superadmin_home_screen.dart';
import 'ui/widgets/main_layout.dart';
import 'ui/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'services/platform_service.dart';

Future<void> _ensureConciCompaniesSeeded() async {
  if (DefaultFirebaseOptions.web.projectId != 'cajachica-conci') return;
  try {
    final fs = FirebaseFirestore.instance;
    final companiesToSeed = [
      {'id': 'conci_sa', 'name': 'CONCI S.A.'},
      {'id': 'conci_srl', 'name': 'CONCI S.R.L.'},
      {'id': 'las_marias', 'name': 'LAS MARÍAS'},
    ];
    for (final c in companiesToSeed) {
      final docRef = fs.collection('companies_config').doc(c['id']);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'name': c['name'],
          'primaryColor': 0xFF212121,
          'secondaryColor': 0xFFBA4817,
          'logoUrl': kDefaultConciLogoBase64,
          'isActive': true,
          'maxUsers': 50,
          'allowedEstablishments': ['ADMINISTRACIÓN', 'CAMPO', 'OBRA'],
        });
      }
    }
  } catch (e) {
    debugPrint('Error auto-seeding CONCI companies: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  debugPrint('v30.5-ULTRA: MARCA BLANCA ACTIVA');

  _ensureConciCompaniesSeeded();

  var initialCompId = PlatformService.getUriParameter('comp');
  if ((initialCompId == null || initialCompId.isEmpty) &&
      DefaultFirebaseOptions.web.projectId == 'cajachica-conci') {
    initialCompId = 'conci_sa';
  }
  if (initialCompId != null) {
    debugPrint('TENANT ID CAPTURADO: $initialCompId');
  }

  runApp(
    ProviderScope(
      overrides: [
        if (initialCompId != null)
          targetCompanyIdProvider.overrideWith((ref) => initialCompId),
      ],
      child: const InitializerWidget(),
    ),
  );
}

class InitializerWidget extends ConsumerWidget {
  const InitializerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyConfigAsync = ref.watch(companyConfigProvider);
    final config = companyConfigAsync.valueOrNull;

    return MaterialApp(
      title: config?.name ?? 'Sistema de Gestión',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildDynamicTheme(config),
      home: _HomeRouter(isLoading: companyConfigAsync.isLoading && config == null),
    );
  }
}

class _HomeRouter extends ConsumerWidget {
  final bool isLoading;
  const _HomeRouter({required this.isLoading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading) {
      return const SplashScreen();
    }
    
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          final currentUser = FirebaseAuth.instance.currentUser ?? snapshot.data!;
          if (!currentUser.emailVerified) {
            return UnverifiedEmailScreen(user: currentUser);
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ref.read(currentUserIdProvider) != currentUser.uid) {
              ref.read(currentUserIdProvider.notifier).state = currentUser.uid;
            }
          });

          // Detectar rol y empresa para decidir pantalla principal
          final userAsync = ref.watch(currentUserProvider);
          final targetCompId = ref.watch(targetCompanyIdProvider);
          final companyConfig = ref.watch(companyConfigProvider).value;

          return userAsync.when(
            data: (user) {
              if (user == null) {
                FirebaseAuth.instance.signOut();
                return const LoginScreen();
              }

              // 1. SuperAdmin: Acceso global a su consola SaaS
              if (user.role == 'superadmin') {
                return const SuperAdminHomeScreen();
              }

              // 2. En WEB: Validar aislamiento estricto por parámetro de URL solo en SaaS maestro
              final isSaasMaster = DefaultFirebaseOptions.web.projectId == 'pettycashapp-80f5e';
              if (kIsWeb && isSaasMaster) {
                if (targetCompId == null || targetCompId.isEmpty) {
                  return _AccessDeniedScreen(
                    user: user,
                    message: 'Esta dirección es la URL base exclusiva para la consola de administración SaaS.\nPara ingresar al sistema de tu empresa debés acceder mediante tu enlace oficial.',
                  );
                }

                if (user.companyId != targetCompId) {
                  return _AccessDeniedScreen(
                    user: user,
                    message: 'Tu cuenta pertenece a la empresa "${user.companyId}".\nNo tenés permisos para acceder al espacio de "$targetCompId".',
                  );
                }
              }

              // 3. Empresa suspendida en tiempo real
              if (companyConfig != null && !companyConfig.isActive) {
                return _SuspendedCompanyScreen(
                  companyName: companyConfig.name.isNotEmpty ? companyConfig.name : user.companyId,
                );
              }

              return const MainLayout();
            },
            loading: () => const SplashScreen(),
            error: (_, __) => const LoginScreen(),
          );
        }
        
        return const LoginScreen();
      },
    );
  }
}

class _AccessDeniedScreen extends ConsumerWidget {
  final UserModel user;
  final String message;
  const _AccessDeniedScreen({super.key, required this.user, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final domain = kIsWeb ? Uri.base.origin : 'https://${DefaultFirebaseOptions.web.projectId}.web.app';
    final companyUrl = '$domain/?comp=${user.companyId}';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.link_off_rounded, size: 65, color: Colors.amber.shade800),
              ),
              const SizedBox(height: 24),
              Text(
                'ACCESO NO AUTORIZADO A ESTA URL',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
              ),
              const SizedBox(height: 24),
              if (user.companyId.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Text('Tu enlace correcto es:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 6),
                      SelectableText(
                        companyUrl,
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: AppTheme.primaryOrange, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
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
}

class _SuspendedCompanyScreen extends ConsumerWidget {
  final String companyName;
  const _SuspendedCompanyScreen({super.key, required this.companyName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.block_outlined, size: 70, color: Colors.red.shade700),
              ),
              const SizedBox(height: 24),
              Text(
                'EMPRESA SUSPENDIDA',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.red.shade800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'El acceso para la empresa "$companyName" ha sido temporalmente suspendido por el administrador de la plataforma.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.pureBlack,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.grey),
              const SizedBox(height: 20),
              Text('Cargando Identidad...', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

