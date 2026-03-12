import 'package:cloud_firestore/cloud_firestore.dart';

enum CostCenter {
  Administracion,
  PuestoDeLuna,
  SanIsidro,
  FeedLot,
  LaCarlota,
  ElSiete,
  ElMoro,
  LaHuella
}

enum MovementType { income, expense }
enum PaymentMethod { cash, debit }

class MovementModel {
  final String id;
  final String userId;
  final MovementType type; // Ingreso/Egreso
  final double netAmount; // Monto_Neto
  final double grossAmount; // Monto_Bruto
  final double vat; // IVA
  final String invoiceType; // Tipo_Factura
  final String? invoiceNumber; // Número de factura
  final String description; // Descripción
  final CostCenter costCenter; // Centro_Costo
  final PaymentMethod paymentMethod; // Método_Pago
  final DateTime date; // Fecha_Carga
  final String? imageUrl; // URL_Imagen

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
      type: MovementType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MovementType.expense,
      ),
      netAmount: (map['netAmount'] ?? 0.0).toDouble(),
      grossAmount: (map['grossAmount'] ?? 0.0).toDouble(),
      vat: (map['vat'] ?? 0.0).toDouble(),
      invoiceType: map['invoiceType'] ?? '',
      invoiceNumber: map['invoiceNumber'],
      description: map['description'] ?? '',
      costCenter: CostCenter.values.firstWhere(
        (e) => e.name == map['costCenter'],
        orElse: () => CostCenter.Administracion,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == map['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
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
