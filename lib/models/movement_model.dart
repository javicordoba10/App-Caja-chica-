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
  final String establishment;
  final String paymentMethod;
  final DateTime date;
  final DateTime? invoiceDate; // v17: Fecha del comprobante (del OCR o manual)
  final String? imageUrl;
  final String? userName; // v24: Attribution for admin view
  final String? userEmail; // v24: Attribution for admin view
  final MovementCategory? category; // v28: Classification
  final String companyId; // v29: SaaS multi-tenancy support
  final double otherTaxes; // Monto acumulado de otros impuestos / percepciones
  final List<Map<String, dynamic>>? otherTaxesDetails; // Desglose individual (nombre y monto)

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
    required this.establishment,
    required this.paymentMethod,
    required this.date,
    this.invoiceDate,
    this.imageUrl,
    this.userName,
    this.userEmail,
    this.category,
    this.companyId = 'alm_agro',
    this.otherTaxes = 0.0,
    this.otherTaxesDetails,
  });

  static double _safeDouble(double val) => (val.isNaN || val.isInfinite) ? 0.0 : val;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.name,
      'netAmount': _safeDouble(netAmount),
      'grossAmount': _safeDouble(grossAmount),
      'vat': _safeDouble(vat),
      'invoiceType': invoiceType,
      'invoiceNumber': invoiceNumber,
      'description': description,
      'establishment': establishment,
      'paymentMethod': paymentMethod,
      'date': Timestamp.fromDate(date),
      'invoiceDate': invoiceDate != null ? Timestamp.fromDate(invoiceDate!) : null,
      'imageUrl': imageUrl,
      'userName': userName,
      'userEmail': userEmail,
      'category': category?.name,
      'companyId': companyId,
      'otherTaxes': _safeDouble(otherTaxes),
      'otherTaxesDetails': otherTaxesDetails,
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
      establishment: (map['establishment'] ?? map['costCenter'] ?? 'ADMINISTRACIÓN').toString().toUpperCase(),
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
      otherTaxes: (map['otherTaxes'] ?? 0.0).toDouble(),
      otherTaxesDetails: map['otherTaxesDetails'] != null
          ? (map['otherTaxesDetails'] as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : null,
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
    String? establishment,
    String? paymentMethod,
    DateTime? date,
    String? imageUrl,
    String? userName,
    String? userEmail,
    MovementCategory? category,
    String? companyId,
    double? otherTaxes,
    List<Map<String, dynamic>>? otherTaxesDetails,
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
      establishment: establishment ?? this.establishment,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
      invoiceDate: invoiceDate ?? invoiceDate,
      imageUrl: imageUrl ?? this.imageUrl,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      category: category ?? this.category,
      companyId: companyId ?? this.companyId,
      otherTaxes: otherTaxes ?? this.otherTaxes,
      otherTaxesDetails: otherTaxesDetails ?? this.otherTaxesDetails,
    );
  }
}
