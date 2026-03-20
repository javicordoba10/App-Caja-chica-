import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petty_cash_app/models/user_model.dart';
import 'package:petty_cash_app/models/movement_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository(this._firestore);

  CollectionReference get _users => _firestore.collection('users');

  Future<UserModel?> getUser(String id) async {
    final doc = await _users.doc(id).get()
        .timeout(const Duration(seconds: 10), onTimeout: () {
      throw Exception(
        'No se pudo conectar con Firestore (timeout). '
        'Verificá tu conexión o las reglas de seguridad.'
      );
    });
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

  Stream<List<UserModel>> streamAllUsers() {
    return _users.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    await _users.doc(userId).update({'role': newRole});
  }

  Future<void> updateUserStatus(String userId, bool isActive) async {
    await _users.doc(userId).update({'isActive': isActive});
  }

  Future<void> deleteUser(String userId) async {
    // Note: This only deletes the Firestore document. 
    // Authentication deletion usually requires admin SDK or re-authentication.
    await _users.doc(userId).delete();
  }

  Future<void> updateBalance(String userId, double amount, bool isIncome, PaymentMethod method) async {
    final docRef = _users.doc(userId);
    final fieldName = method == PaymentMethod.cash ? 'cashBalance' : 'debitBalance';
    final otherField = method == PaymentMethod.cash ? 'debitBalance' : 'cashBalance';
    final value = isIncome ? amount : -amount;

    try {
      await docRef.set({
        fieldName: FieldValue.increment(value),
        otherField: FieldValue.increment(0.0),
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveMovementWithBalanceUpdate(MovementModel movement) async {
    final userDocRef = _users.doc(movement.userId);
    final movementDocRef = _firestore.collection('movements').doc(movement.id);
    
    final fieldName = movement.paymentMethod == PaymentMethod.cash ? 'cashBalance' : 'debitBalance';
    final otherField = movement.paymentMethod == PaymentMethod.cash ? 'debitBalance' : 'cashBalance';
    final amountDelta = movement.type == MovementType.income ? movement.grossAmount : -movement.grossAmount;
    
    try {
      final p1 = movementDocRef.set(movement.toMap());
      final p2 = userDocRef.set({
        fieldName: FieldValue.increment(amountDelta),
        otherField: FieldValue.increment(0.0),
      }, SetOptions(merge: true));
      
      await Future.wait([p1, p2]);
    } catch (e) {
      throw e;
    }
  }

  Future<void> deleteMovementWithBalanceUpdate(MovementModel movement) async {
    final userDocRef = _users.doc(movement.userId);
    final movementDocRef = _firestore.collection('movements').doc(movement.id);
    
    final fieldName = movement.paymentMethod == PaymentMethod.cash ? 'cashBalance' : 'debitBalance';
    final otherField = movement.paymentMethod == PaymentMethod.cash ? 'debitBalance' : 'cashBalance';
    final amountDelta = movement.type == MovementType.income ? -movement.grossAmount : movement.grossAmount;
    
    try {
      final p1 = movementDocRef.delete();
      final p2 = userDocRef.set({
        fieldName: FieldValue.increment(amountDelta),
        otherField: FieldValue.increment(0.0),
      }, SetOptions(merge: true));
      
      await Future.wait([p1, p2]);
    } catch (e) {
      throw e;
    }
  }

  Future<void> recalculateBalances(String userId) async {
    final movementsSnapshot = await _firestore.collection('movements')
        .where('userId', isEqualTo: userId)
        .get();
        
    double cash = 0.0;
    double debit = 0.0;
    
    for (var doc in movementsSnapshot.docs) {
      final data = doc.data();
      final amount = (data['grossAmount'] as num?)?.toDouble() ?? 0.0;
      final type = data['type']; 
      final method = data['paymentMethod']; 
      
      final delta = type == 'income' ? amount : -amount;
      if (method == 'cash') {
        cash += delta;
      } else {
        debit += delta;
      }
    }
    
    await _users.doc(userId).update({
      'cashBalance': cash,
      'debitBalance': debit,
    });
  }

  Future<void> updateUserProfile(String userId, {String? name, String? phone, List<CostCenter>? establishments}) async {
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (establishments != null) {
      updates['establishments'] = establishments.map((e) => e.name).toList();
    }
    
    if (updates.isNotEmpty) {
      await _users.doc(userId).update(updates);
    }
  }
}
