import 'package:cloud_firestore/cloud_firestore.dart';

enum RechargeStatus { solicitado, pedido, acreditado, denegado }

class RechargeRequestModel {
  final String id;
  final String userId;
  final String companyId;
  final String userName;
  final double amount;
  final String paymentMethod;
  final RechargeStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  RechargeRequestModel({
    required this.id,
    required this.userId,
    required this.companyId,
    required this.userName,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'companyId': companyId,
      'userName': userName,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory RechargeRequestModel.fromMap(Map<String, dynamic> map, String documentId) {
    return RechargeRequestModel(
      id: documentId,
      userId: map['userId'] ?? '',
      companyId: map['companyId'] ?? '',
      userName: map['userName'] ?? 'Desconocido',
      amount: (map['amount'] ?? 0.0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? 'Efectivo',
      status: RechargeStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => RechargeStatus.solicitado),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  RechargeRequestModel copyWith({
    String? id,
    String? userId,
    String? companyId,
    String? userName,
    double? amount,
    String? paymentMethod,
    RechargeStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RechargeRequestModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      userName: userName ?? this.userName,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
