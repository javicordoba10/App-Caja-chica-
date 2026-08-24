import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/unverified_email_screen.dart';
import 'ui/screens/superadmin_home_screen.dart';
import 'ui/widgets/main_layout.dart';
import 'ui/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'services/platform_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  debugPrint('v30.5-ULTRA: MARCA BLANCA ACTIVA');

  final initialCompId = PlatformService.getUriParameter('comp');
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

          // Detectar rol para decidir pantalla principal
          final userAsync = ref.watch(currentUserProvider);
          return userAsync.when(
            data: (user) {
              if (user?.role == 'superadmin') {
                return const SuperAdminHomeScreen();
              }
              return const MainLayout();
            },
            loading: () => const SplashScreen(),
            error: (_, __) => const MainLayout(),
          );
        }
        
        return const LoginScreen();
      },
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
