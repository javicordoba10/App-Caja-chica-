import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:petty_cash_app/models/user_model.dart';
import 'package:petty_cash_app/models/movement_model.dart';
import 'package:petty_cash_app/models/company_config_model.dart';
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

// Tenant ID captured from URL (for onboarding/pre-login branding)
final targetCompanyIdProvider = StateProvider<String?>((ref) => null);

// Tenant ID selected by SuperAdmin for "God-Mode" inspection
final superAdminInspectTenantProvider = StateProvider<String?>((ref) => null);

// Streams the current user's profile and live balance
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  
  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.streamUser(userId);
});

// Selector for Dashboard Chart (Daily, Weekly, Monthly, Yearly)
final dashboardChartRangeProvider = StateProvider<String>((ref) => 'Mensual');

// Toggle for Admins to switch between "Supervision Mode" (all users) and "Personal Mode" (self)
final adminViewAllProvider = StateProvider<bool>((ref) => true);

// Streams the current user's movements (or ALL movements if admin and toggle is true)
final movementsProvider = StreamProvider<List<MovementModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();

  final currentUser = ref.watch(currentUserProvider).value;
  final role = currentUser?.role ?? 'user';
  final companyId = currentUser?.companyId ?? 'alm_agro';
  final viewAll = ref.watch(adminViewAllProvider);
  final inspectTenant = ref.watch(superAdminInspectTenantProvider);
  
  final movementRepository = ref.watch(movementRepositoryProvider);
  
  final effectiveRole = (role == 'superadmin' && inspectTenant != null) 
      ? 'admin' // Impersonate admin
      : (role == 'admin' && viewAll) ? 'admin' : (role == 'superadmin' ? 'superadmin' : 'user');
      
  final effectiveCompanyId = (role == 'superadmin' && inspectTenant != null)
      ? inspectTenant
      : companyId;
  
  return movementRepository.getMovements(userId, effectiveRole, effectiveCompanyId);
});

// Provider to store which user is being supervised by the admin
final adminSelectedUserIdProvider = StateProvider<String?>((ref) => null);

// Streams movements for a SPECIFIC user selected by an admin
final selectedUserMovementsProvider = StreamProvider.family<List<MovementModel>, String>((ref, userId) {
  final movementRepository = ref.watch(movementRepositoryProvider);
  final currentUser = ref.watch(currentUserProvider).value;
  final companyId = currentUser?.companyId ?? 'alm_agro';
  final role = currentUser?.role ?? 'user';
  final inspectTenant = ref.watch(superAdminInspectTenantProvider);
  
  final effectiveCompanyId = (role == 'superadmin' && inspectTenant != null)
      ? inspectTenant
      : companyId;

  return movementRepository.getMovements(userId, 'user', effectiveCompanyId); 
});

// Streams all users for admin management
final allUsersProvider = StreamProvider<List<UserModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null || (user.role != 'admin' && user.role != 'superadmin')) {
    return const Stream.empty();
  }
  
  final inspectTenant = ref.watch(superAdminInspectTenantProvider);
  final effectiveCompanyId = (user.role == 'superadmin' && inspectTenant != null)
      ? inspectTenant
      : user.companyId;
      
  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.streamAllUsers(user.role, effectiveCompanyId);
});

// Provides the sum of balances of ALL users (Consolidated Corporate Balance)
final globalBalancesProvider = Provider<AsyncValue<Map<String, double>>>((ref) {
  final allUsersAsync = ref.watch(allUsersProvider);
  return allUsersAsync.whenData((users) {
    final totals = <String, double>{};
    for (var u in users) {
      u.balances.forEach((method, balance) {
        totals[method] = (totals[method] ?? 0.0) + balance;
      });
    }
    return totals;
  });
});

// Streams the branding configuration for the current company (Support pre-login)
final companyConfigProvider = StreamProvider<CompanyConfigModel?>((ref) {
  final user = ref.watch(currentUserProvider).value;
  final targetId = ref.watch(targetCompanyIdProvider);
  final inspectTenant = ref.watch(superAdminInspectTenantProvider);
  
  // Priority: SuperAdmin Inspect > Logged In User > URL Param > Default ALM
  final companyId = inspectTenant ?? user?.companyId ?? targetId ?? 'alm_agro';
  
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('companies_config').doc(companyId).snapshots().map((doc) {
    debugPrint('Provider: Intentando leer doc "$companyId". ¿Existe? ${doc.exists}');
    if (doc.exists) {
      final config = CompanyConfigModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      debugPrint('Provider: Marca cargada: ${config.name}');
      return config;
    }
    debugPrint('Provider: Marca "$companyId" no encontrada en Firestore.');
    return null;
  });
});
