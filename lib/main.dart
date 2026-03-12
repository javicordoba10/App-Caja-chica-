import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Offline persistence is enabled by default on Android and iOS.
  // Enabling it manually on native platforms can trigger a [cloud_firestore/unavailable] race condition.
  // For web, it must be explicitly enabled if desired.
  runApp(const ProviderScope(child: PettyCashApp()));
}

class PettyCashApp extends StatelessWidget {
  const PettyCashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Petty Cash',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
