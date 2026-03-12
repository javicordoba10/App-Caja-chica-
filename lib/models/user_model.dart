class UserModel {
  final String id;
  final String name;
  final double cashBalance;
  final double debitBalance;
  final String role; // 'admin' or 'user'
  final String area;

  UserModel({
    required this.id,
    required this.name,
    required this.cashBalance,
    required this.debitBalance,
    this.role = 'user',
    this.area = 'Administracion',
  });

  UserModel copyWith({
    String? id,
    String? name,
    double? cashBalance,
    double? debitBalance,
    String? role,
    String? area,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      cashBalance: cashBalance ?? this.cashBalance,
      debitBalance: debitBalance ?? this.debitBalance,
      role: role ?? this.role,
      area: area ?? this.area,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cashBalance': cashBalance,
      'debitBalance': debitBalance,
      'role': role,
      'area': area,
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
      role: map['role'] ?? 'user',
      area: map['area'] ?? 'Administracion',
    );
  }
}
