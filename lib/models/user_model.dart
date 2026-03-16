import 'package:petty_cash_app/models/enums.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final double cashBalance;
  final double debitBalance;
  final String role;
  final CostCenter establishment;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.cashBalance,
    required this.debitBalance,
    this.role = 'user',
    this.establishment = CostCenter.Administracion,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    double? cashBalance,
    double? debitBalance,
    String? role,
    CostCenter? establishment,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      cashBalance: cashBalance ?? this.cashBalance,
      debitBalance: debitBalance ?? this.debitBalance,
      role: role ?? this.role,
      establishment: establishment ?? this.establishment,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'cashBalance': cashBalance,
      'debitBalance': debitBalance,
      'role': role,
      'establishment': establishment.name,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    double oldBalance = (map['balance'] ?? 0.0).toDouble();
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      cashBalance: map.containsKey('cashBalance') ? (map['cashBalance'] ?? 0.0).toDouble() : oldBalance,
      debitBalance: (map['debitBalance'] ?? 0.0).toDouble(),
      role: map['role'] ?? 'user',
      establishment: CostCenter.values.firstWhere(
        (e) => e.name == map['establishment'] || e.name == map['area'],
        orElse: () => CostCenter.Administracion,
      ),
    );
  }
}
