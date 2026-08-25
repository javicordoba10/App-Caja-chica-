import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Memory cache to avoid re-fetching the same logo bytes multiple times
final Map<String, Uint8List> _logoBytesCache = {};

class CompanyLogoWidget extends StatefulWidget {
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
  State<CompanyLogoWidget> createState() => _CompanyLogoWidgetState();
}

class _CompanyLogoWidgetState extends State<CompanyLogoWidget> {
  Uint8List? _bytes;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _processLogo();
  }

  @override
  void didUpdateWidget(covariant CompanyLogoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logoUrl != widget.logoUrl) {
      _processLogo();
    }
  }

  Future<void> _processLogo() async {
    final url = widget.logoUrl?.trim();
    if (url == null || url.isEmpty) {
      if (mounted) setState(() { _bytes = null; _isLoading = false; _hasError = false; });
      return;
    }

    // 1. Check in-memory cache
    if (_logoBytesCache.containsKey(url)) {
      if (mounted) {
        setState(() {
          _bytes = _logoBytesCache[url];
          _isLoading = false;
          _hasError = false;
        });
      }
      return;
    }

    // 2. Base64 Data URI or raw base64
    if (url.startsWith('data:image') || !url.startsWith('http')) {
      try {
        final base64String = url.contains(',') ? url.split(',').last : url;
        final decoded = base64Decode(base64String.replaceAll('\n', '').replaceAll('\r', '').trim());
        _logoBytesCache[url] = decoded;
        if (mounted) {
          setState(() {
            _bytes = decoded;
            _isLoading = false;
            _hasError = false;
          });
        }
        return;
      } catch (e) {
        debugPrint('Error decoding base64 logo: $e');
      }
    }

    // 3. Firebase Storage URL -> Download bytes directly via Firebase Storage SDK (bypasses browser CORS)
    if (url.contains('firebasestorage.googleapis.com') || url.contains('firebasestorage.app')) {
      if (mounted) setState(() => _isLoading = true);
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        final data = await ref.getData(5 * 1024 * 1024); // max 5 MB
        if (data != null && data.isNotEmpty) {
          _logoBytesCache[url] = data;
          if (mounted) {
            setState(() {
              _bytes = data;
              _isLoading = false;
              _hasError = false;
            });
          }
          return;
        }
      } catch (e) {
        debugPrint('Firebase Storage getData error (falling back): $e');
      }
    }

    // 4. Regular HTTP image (or fallback)
    if (mounted) {
      setState(() {
        _bytes = null;
        _isLoading = false;
        _hasError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.logoUrl?.trim();
    if (url == null || url.isEmpty || _hasError) {
      return _buildFallback();
    }

    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // If we have byte data (Base64 or fetched from Firebase Storage)
    if (_bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Image.memory(
          _bytes!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => _buildFallback(),
        ),
      );
    }

    // Otherwise standard Image.network
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image.network(
        url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    return Icon(
      Icons.business,
      size: widget.fallbackIconSize,
      color: widget.fallbackColor ?? Colors.grey[500],
    );
  }
}
