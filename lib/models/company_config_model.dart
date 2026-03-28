import 'package:flutter/material.dart';

class CompanyConfigModel {
  final String id;
  final String name;
  final String? logoUrl;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isActive;

  CompanyConfigModel({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.primaryColor,
    required this.secondaryColor,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'logoUrl': logoUrl,
      'primaryColor': primaryColor.value,
      'secondaryColor': secondaryColor.value,
      'isActive': isActive,
    };
  }

  factory CompanyConfigModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CompanyConfigModel(
      id: documentId,
      name: map['name'] ?? map['displayName'] ?? '',
      logoUrl: map['logoUrl'],
      primaryColor: _parseColor(map['primaryColor'], const Color(0xFFFF9800)),
      secondaryColor: _parseColor(map['secondaryColor'], const Color(0xFFFFC107)),
      isActive: map['isActive'] ?? true,
    );
  }

  static Color _parseColor(dynamic value, Color defaultColor) {
    if (value == null) return defaultColor;
    if (value is int) return Color(value);
    if (value is String) {
      try {
        String hex = value.trim().replaceAll('#', '');
        if (hex.length == 6) hex = 'FF$hex';
        if (hex.length == 8) {
          return Color(int.parse(hex, radix: 16));
        }
      } catch (e) {
        debugPrint('Color Filter Error: $e for value $value');
      }
    }
    // Diagnosis: Fallback to RED if something is wrong
    return Colors.red; 
  }

  CompanyConfigModel copyWith({
    String? id,
    String? name,
    String? logoUrl,
    Color? primaryColor,
    Color? secondaryColor,
    bool? isActive,
  }) {
    return CompanyConfigModel(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      isActive: isActive ?? this.isActive,
    );
  }
}
