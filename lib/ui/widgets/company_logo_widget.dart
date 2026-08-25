import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class CompanyLogoWidget extends StatelessWidget {
  final String? logoUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Color? fallbackColor;
  final double fallbackIconSize;

  const CompanyLogoWidget({
    super.key,
    required this.logoUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius = 8.0,
    this.fallbackColor,
    this.fallbackIconSize = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    if (logoUrl == null || logoUrl!.trim().isEmpty) {
      return _buildFallback();
    }

    final raw = logoUrl!.trim();

    // Check if it is a Base64 data URI or raw base64 string
    if (raw.startsWith('data:image') || !raw.startsWith('http')) {
      try {
        final base64String = raw.contains(',') ? raw.split(',').last : raw;
        final Uint8List bytes = base64Decode(base64String);
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _buildFallback(),
          ),
        );
      } catch (_) {
        // If decoding fails, continue to fallback or network
      }
    }

    // Network image
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        raw,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallback() {
    return Icon(
      Icons.business,
      size: fallbackIconSize,
      color: fallbackColor ?? Colors.grey[500],
    );
  }
}
