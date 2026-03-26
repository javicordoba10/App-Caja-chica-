enum CostCenter {
  Administracion, PuestoDeLuna, SanIsidro, FeedLot, LaCarlota, ElSiete, ElMoro, LaHuella
}

enum MovementType { income, expense }
enum MovementCategory {
  combustible,
  comida,
  alojamiento,
  ferreteria,
  personalChanga,
  viajePeaje,
  otros
}

extension MovementCategoryExtension on MovementCategory {
  String get displayName {
    switch (this) {
      case MovementCategory.combustible: return 'Combustible';
      case MovementCategory.comida: return 'Comida';
      case MovementCategory.alojamiento: return 'Alojamiento';
      case MovementCategory.ferreteria: return 'Ferretería';
      case MovementCategory.personalChanga: return 'Personal - Changas';
      case MovementCategory.viajePeaje: return 'Viaje - Peaje';
      case MovementCategory.otros: return 'Otros';
    }
  }
}
