import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  Future<void> saveMovement(MovementModel movement) => addMovement(movement);

  Future<void> updateImageUrl(String id, String url) async {
    await _movements.doc(id).update({'imageUrl': url});
  }

  Stream<List<MovementModel>> getMovements(String userId, String role, String companyId) {
    // STRICT SaaS Isolation Level 1: Absolute Company Isolation for ALL roles
    Query query = _movements.where('companyId', isEqualTo: companyId);
    
    // SaaS Isolation Level 2: User Role Isolation (only for non-admins)
    if (role == 'user') {
      query = query.where('userId', isEqualTo: userId);
    }
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => 
        MovementModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)
      ).toList();
    });
  }

  Future<void> deleteMovement(String id) async {
    print('>>> MovementRepository: Deleting movement: $id');
    await _movements.doc(id).delete();
  }

  /// Removes attachments older than 60 days
  Future<int> cleanupOldAttachments() async {
    final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60));
    final snapshot = await _movements
        .where('date', isLessThan: Timestamp.fromDate(sixtyDaysAgo))
        .get();

    int deletedCount = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final url = data['imageUrl'] as String?;
      if (url != null && url.isNotEmpty) {
        try {
          // Permanently delete from Storage
          await FirebaseStorage.instance.refFromURL(url).delete();
          // Clear reference in Firestore
          await doc.reference.update({'imageUrl': FieldValue.delete()});
          deletedCount++;
        } catch (e) {
          print('Error deleting attachment for doc ${doc.id}: $e');
        }
      }
    }
    return deletedCount;
  }
}
