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
      name: map['name'] ?? '',
      logoUrl: map['logoUrl'],
      primaryColor: Color(map['primaryColor'] ?? const Color(0xFFFF9800).value),
      secondaryColor: Color(map['secondaryColor'] ?? const Color(0xFFFFC107).value),
      isActive: map['isActive'] ?? true,
    );
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
