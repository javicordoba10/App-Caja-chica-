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
  final String paymentMethod;
  final DateTime date;
  final DateTime? invoiceDate; // v17: Fecha del comprobante (del OCR o manual)
  final String? imageUrl;
  final String? userName; // v24: Attribution for admin view
  final String? userEmail; // v24: Attribution for admin view
  final MovementCategory? category; // v28: Classification
  final String companyId; // v29: SaaS multi-tenancy support

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
    this.invoiceDate,
    this.imageUrl,
    this.userName,
    this.userEmail,
    this.category,
    this.companyId = 'alm_agro',
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
      'paymentMethod': paymentMethod,
      'date': Timestamp.fromDate(date),
      'invoiceDate': invoiceDate != null ? Timestamp.fromDate(invoiceDate!) : null,
      'imageUrl': imageUrl,
      'userName': userName,
      'userEmail': userEmail,
      'category': category?.name,
      'companyId': companyId,
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
      paymentMethod: map['paymentMethod'] ?? 'Efectivo',
      date: (map['date'] as Timestamp).toDate(),
      invoiceDate: map['invoiceDate'] != null ? (map['invoiceDate'] as Timestamp).toDate() : null,
      imageUrl: map['imageUrl'],
      userName: map['userName'],
      userEmail: map['userEmail'],
      category: map['category'] != null 
          ? MovementCategory.values.firstWhere((e) => e.name == map['category'], orElse: () => MovementCategory.otros)
          : null,
      companyId: map['companyId'] ?? 'alm_agro',
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
    String? paymentMethod,
    DateTime? date,
    String? imageUrl,
    String? userName,
    String? userEmail,
    MovementCategory? category,
    String? companyId,
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
      invoiceDate: invoiceDate ?? this.invoiceDate,
      imageUrl: imageUrl ?? this.imageUrl,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      category: category ?? this.category,
      companyId: companyId ?? this.companyId,
    );
  }
}
