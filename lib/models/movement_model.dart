import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petty_cash_app/models/enums.dart';

export 'package:petty_cash_app/models/enums.dart';

class MovementModel {
  final String id;
  final String userId;
  final MovementType type;
  final double netAmount;
  final double grossAmount;
  final double vat;
  final String invoiceType;
  final String? invoiceNumber;
  final String description;
  final CostCenter costCenter;
  final PaymentMethod paymentMethod;
  final DateTime date;
  final String? imageUrl;

  MovementModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.netAmount,
    required this.grossAmount,
    required this.vat,
    required this.invoiceType,
    this.invoiceNumber,
    required this.description,
    required this.costCenter,
    required this.paymentMethod,
    required this.date,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.name,
      'netAmount': netAmount,
      'grossAmount': grossAmount,
      'vat': vat,
      'invoiceType': invoiceType,
      'invoiceNumber': invoiceNumber,
      'description': description,
      'costCenter': costCenter.name,
      'paymentMethod': paymentMethod.name,
      'date': Timestamp.fromDate(date),
      'imageUrl': imageUrl,
    };
  }

  factory MovementModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MovementModel(
      id: documentId,
      userId: map['userId'] ?? '',
      type: MovementType.values.firstWhere((e) => e.name == map['type'], orElse: () => MovementType.expense),
      netAmount: (map['netAmount'] ?? 0.0).toDouble(),
      grossAmount: (map['grossAmount'] ?? 0.0).toDouble(),
      vat: (map['vat'] ?? 0.0).toDouble(),
      invoiceType: map['invoiceType'] ?? '',
      invoiceNumber: map['invoiceNumber'],
      description: map['description'] ?? '',
      costCenter: CostCenter.values.firstWhere((e) => e.name == map['costCenter'], orElse: () => CostCenter.Administracion),
      paymentMethod: PaymentMethod.values.firstWhere((e) => e.name == map['paymentMethod'], orElse: () => PaymentMethod.cash),
      date: (map['date'] as Timestamp).toDate(),
      imageUrl: map['imageUrl'],
    );
  }

  MovementModel copyWith({
    String? id,
    String? userId,
    MovementType? type,
    double? netAmount,
    double? grossAmount,
    double? vat,
    String? invoiceType,
    String? invoiceNumber,
    String? description,
    CostCenter? costCenter,
    PaymentMethod? paymentMethod,
    DateTime? date,
    String? imageUrl,
  }) {
    return MovementModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      netAmount: netAmount ?? this.netAmount,
      grossAmount: grossAmount ?? this.grossAmount,
      vat: vat ?? this.vat,
      invoiceType: invoiceType ?? this.invoiceType,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      description: description ?? this.description,
      costCenter: costCenter ?? this.costCenter,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
