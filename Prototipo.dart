import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petty_cash_app/models/movement_model.dart';


class MovementRepository {
  final FirebaseFirestore _firestore;

  MovementRepository(this._firestore);

  CollectionReference get _movements => _firestore.collection('movements');

  Future<void> addMovement(MovementModel movement) async {
    print('>>> MovementRepository: Attempting to set doc: ${movement.id}');
    try {
      await _movements.doc(movement.id).set(movement.toMap());
      print('>>> MovementRepository: Set doc successful.');
    } catch (e) {
      print('>>> MovementRepository ERROR: $e');
      rethrow;
    }
  }

  Stream<List<MovementModel>> getMovements(String userId) {
    return _movements
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => 
        MovementModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)
      ).toList();
    });
  }

  Future<void> deleteMovement(String id) async {
    print('>>> MovementRepository: Deleting movement: $id');
    await _movements.doc(id).delete();
  }
}
