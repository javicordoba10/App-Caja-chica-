class UserModel {
  final String id;
  final String name;
  final double cashBalance;
  final double debitBalance;

  UserModel({
    required this.id,
    required this.name,
    required this.cashBalance,
    required this.debitBalance,
  });

  UserModel copyWith({
    String? id,
    String? name,
    double? cashBalance,
    double? debitBalance,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      cashBalance: cashBalance ?? this.cashBalance,
      debitBalance: debitBalance ?? this.debitBalance,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cashBalance': cashBalance,
      'debitBalance': debitBalance,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    // Migración temporal si existe clave antigua 'balance' en DB lo pasamos a efectivo por defecto
    double oldBalance = (map['balance'] ?? 0.0).toDouble();
    
    return UserModel(
      id: documentId,
      name: map['name'] ?? '',
      cashBalance: map.containsKey('cashBalance') ? (map['cashBalance'] ?? 0.0).toDouble() : oldBalance,
      debitBalance: (map['debitBalance'] ?? 0.0).toDouble(),
    );
  }
}
