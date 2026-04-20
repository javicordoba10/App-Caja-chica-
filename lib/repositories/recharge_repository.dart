import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petty_cash_app/models/recharge_request_model.dart';

class RechargeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<RechargeRequestModel>> getUserRechargeRequests(String userId) {
    return _firestore
        .collection('recharge_requests')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RechargeRequestModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<RechargeRequestModel>> getCompanyRechargeRequests(String companyId) {
    return _firestore
        .collection('recharge_requests')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RechargeRequestModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> createRequest(RechargeRequestModel request) async {
    await _firestore
        .collection('recharge_requests')
        .doc(request.id)
        .set(request.toMap());
  }

  Future<void> updateRequestStatus(String requestId, RechargeStatus status) async {
    await _firestore.collection('recharge_requests').doc(requestId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRequest(String requestId) async {
    await _firestore.collection('recharge_requests').doc(requestId).delete();
  }
}
