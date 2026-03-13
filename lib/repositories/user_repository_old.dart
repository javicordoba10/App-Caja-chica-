import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/movement_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository(this._firestore);

  CollectionReference get _users => _firestore.collection('users');

  Future<UserModel?> getUser(String id) async {
    final doc = await _users.doc(id).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Stream<UserModel?> streamUser(String id) {
    return _users.doc(id).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  Future<void> createUser(UserModel user) async {
    await _users.doc(user.id).set(user.toMap());
  }

  Future<void> updateBalance(String userId, double amount, bool isIncome, PaymentMethod method) async {
    final docRef = _users.doc(userId);
    final fieldName = method == PaymentMethod.cash ? 'cashBalance' : 'debitBalance';
    final otherField = method == PaymentMethod.cash ? 'debitBalance' : 'cashBalance';
    final value = isIncome ? amount : -amount;

    print('>>> UserRepository: Updating $fieldName by $value for user $userId');
    
    try {
      await docRef.set({
        fieldName: FieldValue.increment(value),
        otherField: FieldValue.increment(0.0),
        'name': 'Javier',
      }, SetOptions(merge: true));

      print('>>> UserRepository: Balance updated successfully.');
    } catch (e) {
      print('>>> UserRepository ERROR: $e');
      rethrow;
    }
  }

  Future<void> saveMovementWithBalanceUpdate(MovementModel movement) async {
    final userDocRef = _users.doc(movement.userId);
    final movementDocRef = _firestore.collection('movements').doc(movement.id);
    
    final fieldName = movement.paymentMethod == PaymentMethod.cash ? 'cashBalance' : 'debitBalance';
    final otherField = movement.paymentMethod == PaymentMethod.cash ? 'debitBalance' : 'cashBalance';
    final amountDelta = movement.type == MovementType.income ? movement.grossAmount : -movement.grossAmount;

    print('>>> UserRepository: Running concurrent saves for movement ${movement.id} with delta $amountDelta');
    
    try {
      // 1. Set movement doc
      final p1 = movementDocRef.set(movement.toMap());
      
      // 2. Increment balance doc
      final p2 = userDocRef.set({
        fieldName: FieldValue.increment(amountDelta),
        otherField: FieldValue.increment(0.0),
        'name': 'Javier',
      }, SetOptions(merge: true));
      
      await Future.wait([p1, p2]);
      print('>>> UserRepository: Concurrent saves successful.');
    } catch (e) {
      print('>>> UserRepository SAVE ERROR: $e');
      throw e;
    }
  }

  Future<void> deleteMovementWithBalanceUpdate(MovementModel movement) async {
    final userDocRef = _users.doc(movement.userId);
    final movementDocRef = _firestore.collection('movements').doc(movement.id);
    
    final fieldName = movement.paymentMethod == PaymentMethod.cash ? 'cashBalance' : 'debitBalance';
    final otherField = movement.paymentMethod == PaymentMethod.cash ? 'debitBalance' : 'cashBalance';
    // To delete, we REVERSE the impact
    final amountDelta = movement.type == MovementType.income ? -movement.grossAmount : movement.grossAmount;

    print('>>> UserRepository: Running concurrent DELETE for movement ${movement.id} with delta $amountDelta');
    
    try {
      // 1. Delete movement doc
      final p1 = movementDocRef.delete();
      
      // 2. Adjust balance doc
      final p2 = userDocRef.set({
        fieldName: FieldValue.increment(amountDelta),
        otherField: FieldValue.increment(0.0),
        'name': 'Javier',
      }, SetOptions(merge: true));
      
      await Future.wait([p1, p2]);
      print('>>> UserRepository: Delete concurrent valid.');
    } catch (e) {
      print('>>> UserRepository DELETE ERROR: $e');
      throw e;
    }
  }
}
