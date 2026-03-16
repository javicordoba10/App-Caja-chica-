import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:petty_cash_app/models/user_model.dart';
import 'package:petty_cash_app/models/movement_model.dart';
import 'package:petty_cash_app/repositories/user_repository.dart';
import 'package:petty_cash_app/repositories/movement_repository.dart';

import 'package:petty_cash_app/services/ocr_service.dart';

// Provider to check the low-level socket connectivity to Firestore
final connectivityStatusProvider = StreamProvider<bool>((ref) async* {
  if (kIsWeb) {
    yield true; // Simple assumption for web, or could use connectivity_plus
    return;
  }
  
  // Mobile only connectivity check
  while (true) {
    bool isOk = false;
    // We would need to use dynamic imports or a package if we really want this on mobile 
    // but for now let's simplify to avoid dart:io issues on web.
    isOk = true; 
    yield isOk;
    await Future.delayed(const Duration(seconds: 15));
  }
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository(ref.watch(firestoreProvider)));
final movementRepositoryProvider = Provider<MovementRepository>((ref) => MovementRepository(ref.watch(firestoreProvider)));
final ocrServiceProvider = Provider<OCRService>((ref) => OCRService());


// Current logged in user ID (Set during LoginScreen)
final currentUserIdProvider = StateProvider<String?>((ref) => null);

// Streams the current user's profile and live balance
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  
  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.streamUser(userId);
});

// Streams the current user's movements (or ALL movements if admin)
final movementsProvider = StreamProvider<List<MovementModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();

  final role = ref.watch(currentUserProvider).value?.role ?? 'user';
  final movementRepository = ref.watch(movementRepositoryProvider);
  
  return movementRepository.getMovements(userId, role);
});

// Selector for Dashboard Chart (Daily, Weekly, Monthly, Yearly)
final dashboardChartRangeProvider = StateProvider<String>((ref) => 'Mensual');
