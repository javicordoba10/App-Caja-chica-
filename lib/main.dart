import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/login_screen.dart';
import 'providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const ProviderScope(child: PettyCashApp()));
}

class PettyCashApp extends ConsumerWidget {
  const PettyCashApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyConfig = ref.watch(companyConfigProvider).value;

    return MaterialApp(
      title: 'Petty Cash',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(companyConfig),
      home: const LoginScreen(),
    );
  }
}
