import 'package:cloud_firestore/cloud_firestore.dart';

class MigrationUtils {
  static Future<void> migrateToSaaS(FirebaseFirestore firestore, String defaultCompanyId) async {
    print('>>> Iniciando migración SaaS...');
    
    // 1. Migrar Usuarios
    final usersSnapshot = await firestore.collection('users').get();
    for (var doc in usersSnapshot.docs) {
      if (!doc.data().containsKey('companyId')) {
        await doc.reference.update({'companyId': defaultCompanyId});
        print('Usuario migrado: ${doc.id}');
      }
    }

    // 2. Migrar Movimientos
    final movementsSnapshot = await firestore.collection('movements').get();
    for (var doc in movementsSnapshot.docs) {
      if (!doc.data().containsKey('companyId')) {
        await doc.reference.update({'companyId': defaultCompanyId});
        print('Movimiento migrado: ${doc.id}');
      }
    }
    
    print('>>> Migración SaaS completada.');
  }
}
