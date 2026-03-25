import 'package:petty_cash_app/models/enums.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final Map<String, double> balances; // v27: Dynamic balances map
  final List<String> paymentMethods; // v27: Custom payment methods
  final List<CostCenter> establishments; // v25: Multiple establishments support
  final String role;
  final bool isActive;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.balances,
    required this.paymentMethods,
    this.role = 'user',
    this.establishments = const [CostCenter.Administracion],
    this.isActive = true,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    Map<String, double>? balances,
    List<String>? paymentMethods,
    String? role,
    List<CostCenter>? establishments,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      balances: balances ?? this.balances,
      paymentMethods: paymentMethods ?? this.paymentMethods,
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
      'balances': balances,
      'paymentMethods': paymentMethods,
      'role': role,
      'establishments': establishments.map((e) => e.name).toList(),
      'isActive': isActive,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    // Balances migration logic
    // Improved Balances Migration
    Map<String, double> balancesMap = {};
    if (map.containsKey('balances') && map['balances'] is Map) {
      // Tomamos el mapa existente y saneamos claves antiguas
      final rawBalances = Map<String, dynamic>.from(map['balances']);
      double legacyCash = (rawBalances.remove('cash') ?? 0.0).toDouble();
      double legacyDebit = (rawBalances.remove('debit') ?? 0.0).toDouble();
      
      rawBalances.forEach((key, value) {
        balancesMap[key] = (value as num).toDouble();
      });

      // Consolidamos en las claves oficiales
      balancesMap['Efectivo'] = (balancesMap['Efectivo'] ?? 0.0) + legacyCash;
      balancesMap['Tarjeta / Débito'] = (balancesMap['Tarjeta / Débito'] ?? 0.0) + legacyDebit;
    } else {
      // Legacy compatibility total
      final cash = (map['cashBalance'] ?? map['balance'] ?? 0.0).toDouble();
      final debit = (map['debitBalance'] ?? 0.0).toDouble();
      balancesMap = {
        'Efectivo': cash,
        'Tarjeta / Débito': debit,
      };
    }

    // Payment methods migration logic
    List<String> methods = [];
    if (map.containsKey('paymentMethods')) {
      methods = List<String>.from(map['paymentMethods']);
    } else {
      methods = ['Efectivo', 'Tarjeta / Débito'];
    }
    // Asegurar que las claves oficiales estén en los métodos si tienen saldo
    if (!methods.contains('Efectivo')) methods.add('Efectivo');
    if (!methods.contains('Tarjeta / Débito')) methods.add('Tarjeta / Débito');

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
      balances: balancesMap,
      paymentMethods: methods,
      role: map['role'] ?? 'user',
      isActive: map['isActive'] ?? true,
      establishments: establishmentsList,
    );
  }
}
