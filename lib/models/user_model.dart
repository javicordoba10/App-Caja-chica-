import 'package:petty_cash_app/models/enums.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final double cashBalance;
  final double debitBalance;
  final String role;
  final List<CostCenter> establishments; // v25: Multiple establishments support
  final bool isActive;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.cashBalance,
    required this.debitBalance,
    this.role = 'user',
    this.establishments = const [CostCenter.Administracion],
    this.isActive = true,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    double? cashBalance,
    double? debitBalance,
    String? role,
    List<CostCenter>? establishments,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      cashBalance: cashBalance ?? this.cashBalance,
      debitBalance: debitBalance ?? this.debitBalance,
      role: role ?? this.role,
      establishments: establishments ?? this.establishments,
      isActive: isActive ?? this.isActive,
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
      'establishments': establishments.map((e) => e.name).toList(),
      'isActive': isActive,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    double oldBalance = (map['balance'] ?? 0.0).toDouble();
    
    // Compatibility logic for single vs multiple establishments
    List<CostCenter> establishmentsList = [];
    if (map.containsKey('establishments') && map['establishments'] is List) {
      establishmentsList = (map['establishments'] as List)
          .map((e) => CostCenter.values.firstWhere((v) => v.name == e, orElse: () => CostCenter.Administracion))
          .toList();
    } else {
      final oldEst = map['establishment'] ?? map['area'];
      if (oldEst != null) {
        establishmentsList = [
          CostCenter.values.firstWhere((e) => e.name == oldEst, orElse: () => CostCenter.Administracion)
        ];
      } else {
        establishmentsList = [CostCenter.Administracion];
      }
    }

    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      cashBalance: map.containsKey('cashBalance') ? (map['cashBalance'] ?? 0.0).toDouble() : oldBalance,
      debitBalance: (map['debitBalance'] ?? 0.0).toDouble(),
      role: map['role'] ?? 'user',
      isActive: map['isActive'] ?? true,
      establishments: establishmentsList,
    );
  }
}
