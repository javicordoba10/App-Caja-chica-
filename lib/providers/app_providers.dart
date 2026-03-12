import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/movement_model.dart';
import '../repositories/user_repository.dart';
import '../repositories/movement_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository(ref.watch(firestoreProvider)));
final movementRepositoryProvider = Provider<MovementRepository>((ref) => MovementRepository(ref.watch(firestoreProvider)));


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
