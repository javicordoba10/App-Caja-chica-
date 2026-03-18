import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:petty_cash_app/models/movement_model.dart';
import 'package:petty_cash_app/services/pdf_converter_stub.dart' if (dart.library.io) 'package:petty_cash_app/services/pdf_converter_mobile.dart';
import 'dart:convert';
import 'package:petty_cash_app/services/ocr_stub.dart' if (dart.library.html) 'package:petty_cash_app/services/ocr_web.dart';

class ExtractedReceiptData {
  final double netAmount;
  final double grossAmount;
  final double vat;
  final String invoiceType;
  final String rawText;
  final String imagePath;
  final String? dateStr; // e.g. "12/10/2023"
  final String? invoiceNumber;
  final bool isPdf;
  final Uint8List? bytes;
  final String description;

  ExtractedReceiptData({
    this.netAmount = 0.0,
    this.grossAmount = 0.0,
    this.vat = 0.0,
    this.invoiceType = 'Ticket',
    this.rawText = '',
    required this.imagePath,
    this.dateStr,
    this.invoiceNumber,
    this.isPdf = false,
    this.bytes,
    this.description = '',
  });
}

class OCRService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<ExtractedReceiptData> extractData(String filePath, {Uint8List? bytes, bool isPdf = false}) async {
    if (kIsWeb) {
      final effectivelyPdf = isPdf || filePath.toLowerCase().contains('.pdf');
      String text = '';
      if (bytes != null) {
        try {
          final base64Image = base64Encode(bytes);
          text = await performWebOCRMethod(base64Image, effectivelyPdf);
        } catch (e) {
          if (kDebugMode) print('Web OCR error: $e');
          text = 'ERROR: $e';
        }
      } else {
        if (kDebugMode) print('Web OCR error: No bytes provided for $filePath');
      }
      return _parseText(text, filePath, isPdf: effectivelyPdf, bytes: bytes);
    }

    String processingPath = filePath;
    bool isPdfFile = isPdf || filePath.toLowerCase().endsWith('.pdf');

    if (isPdfFile) {
      processingPath = await _convertPdfToImage(filePath);
    }

    final inputImage = InputImage.fromFilePath(processingPath);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    
    final text = recognizedText.text;
    
    return _parseText(text, filePath, isPdf: isPdfFile);
  }

  Future<String> _convertPdfToImage(String pdfPath) async {
    return PdfConverter.convertPdfToImage(pdfPath);
  }

  ExtractedReceiptData _parseText(String text, String filePath, {bool isPdf = false, Uint8List? bytes}) {
    double maxAmount = 0.0;
    double netAmt = 0.0;
    double ivaAmt = 0.0;
    String type = 'Ticket';
    final upperText = text.toUpperCase().replaceAll(' ', '');
    // 1. Detección de Tipo de Comprobante (Especificaciones v19)
    if (RegExp(r"(?:FACTURA|TIQUE\s*FACTURA)\s*['""]?A['""]?", caseSensitive: false).hasMatch(text) || 
        upperText.contains('COD.01') || upperText.contains('COD01')) {
      type = 'Factura A';
    } else if (RegExp(r"(?:FACTURA|TIQUE\s*FACTURA)\s*['""]?B['""]?", caseSensitive: false).hasMatch(text)) {
      type = 'Factura B';
    } else if (RegExp(r"(?:FACTURA|TIQUE\s*FACTURA)\s*['""]?C['""]?", caseSensitive: false).hasMatch(text)) {
      type = 'Factura C';
    } else if (upperText.contains('TIQUE') || upperText.contains('TICKET')) {
       type = 'Ticket';
    }
    // Fallback por letra aislada si no se detectó arriba
    if (type == 'Ticket') {
      if (text.contains(RegExp(r'[\[|]\s*A\s*[\]|]')) || text.contains(RegExp(r'\bA\b'))) type = 'Factura A';
      else if (text.contains(RegExp(r'[\[|]\s*B\s*[\]|]')) || text.contains(RegExp(r'\bB\b'))) type = 'Factura B';
      else if (text.contains(RegExp(r'[\[|]\s*C\s*[\]|]')) || text.contains(RegExp(r'\bC\b'))) type = 'Factura C';
    }

    // 2. Regex para Montos (v20 - Robusta: captura $, espacios y múltiples miles)
    final amountRegex = RegExp(r'[$]?\s*\d{1,3}(?:[.,\s]\d{3})*(?:[.,]\d{1,2})?');
    final allMatches = amountRegex.allMatches(text);
    List<double> foundAmounts = [];
    for (var m in allMatches) {
      double val = _parseAmount(m.group(0)!);
      // Evitar CUITs o fechas (números muy largos o con muchos puntos)
      if (val > 0 && val < 50000000000) foundAmounts.add(val);
    }

    // 3. Búsqueda de la Fecha (Mejorada para priorizar Emisión sobre Inicio Actividad)
    String? foundDate;
    final dateRegex = RegExp(r'(\d{1,2})[\s/.-]+(\d{1,2})[\s/.-]+(\d{2,4})');
    final matches = dateRegex.allMatches(text);
    
    // Buscar la fecha más probable de emisión
    for (var m in matches) {
      final day = m.group(1)!.padLeft(2, '0');
      final month = m.group(2)!.padLeft(2, '0');
      String year = m.group(3)!;
      if (year.length == 2) year = "20$year";
      final possibleDate = "$day/$month/$year";
      
      final startIndex = m.start;
      final contextBefore = text.substring((startIndex - 80).clamp(0, text.length), startIndex).toUpperCase();
      final contextAfter = text.substring(startIndex, (startIndex + 40).clamp(0, text.length)).toUpperCase();
      
      // PRIORIDAD (v19): Si dice "FECHA", "FECHA DE EMISIÓN" o "FECHA DE EMISION" justo antes
      int marginIndex = contextBefore.length > 30 ? contextBefore.length - 30 : 0;
      String recentContext = contextBefore.substring(marginIndex);
      if (recentContext.contains('FECHA') || recentContext.contains('EMISION') || recentContext.contains('EMISIÓN')) {
        foundDate = possibleDate;
        break;
      }

      // Si la fecha está cerca de la palabra "inicio" o "actividad", la saltamos
      if (contextBefore.contains('INICIO') || contextBefore.contains('ACTIV') || contextAfter.contains('INICIO') || contextAfter.contains('ACTIV')) {
        continue;
      }
      
      foundDate = possibleDate;
    }
    // Fallback si no encontramos una que no sea de inicio
    if (foundDate == null && matches.isNotEmpty) {
      final m = matches.first;
      String year = m.group(3)!;
      if (year.length == 2) year = "20$year";
      foundDate = "${m.group(1)!.padLeft(2,'0')}/${m.group(2)!.padLeft(2,'0')}/$year";
    }

    // 4. Búsqueda del Número de Factura (v19)
    String? foundNumber;
    // Patrón Punto de Venta + Comp Nro
    final pvMatch = RegExp(r'(?:Punto de Venta|PV)[:\s]*(\d{1,5})', caseSensitive: false).firstMatch(text);
    final cnMatch = RegExp(r'(?:Comp\.?\s*Nro|Numero|Nro)[:\s]*(\d{1,8})', caseSensitive: false).firstMatch(text);
    
    if (pvMatch != null && cnMatch != null) {
      foundNumber = "${pvMatch.group(1)!.padLeft(4,'0')}-${cnMatch.group(1)!.padLeft(8,'0')}";
    } else {
      // Patrón Estándar \d{4,5}-\d{8}
      final numRegexLong = RegExp(r'(\d{4,5})\s*[-]\s*(\d{5,8})');
      final numMatchLong = numRegexLong.firstMatch(text);
      if (numMatchLong != null) {
        foundNumber = "${numMatchLong.group(1)!.padLeft(4,'0')}-${numMatchLong.group(2)!.padLeft(8,'0')}";
      } else {
        final numRegex = RegExp(r'(?:Factura Numero|Factura Nro|Factura N°|Numero|Nro)[:\s]*([0-9-]+)', caseSensitive: false);
        final numMatch = numRegex.firstMatch(text);
        if (numMatch != null) foundNumber = numMatch.group(1);
      }
    }

    // 5. Búsqueda de Montos Totales e IVA
    final lines = text.split('\n');
    double detectedTotal = 0.0;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toUpperCase();
      if (line.contains('TOTAL') || line.contains('FINAL') || line.contains('PAGAR') || line.contains('IMPORTE') || line.contains('VENCIMIENTO') || line.contains('NETOGRAVADO')) {
        final matches = amountRegex.allMatches(lines[i]);
        if (matches.isNotEmpty) {
           String rawMatch = matches.last.group(0)!;
           double val = _parseAmount(rawMatch);
           if (val > detectedTotal && val < 500000000) detectedTotal = val;
        } else if (i + 1 < lines.length) {
           final nextMatches = amountRegex.allMatches(lines[i + 1]);
           if (nextMatches.isNotEmpty) {
              String rawMatch = nextMatches.last.group(0)!;
              double val = _parseAmount(rawMatch);
              if (val > detectedTotal && val < 500000000) detectedTotal = val;
           }
        }
      }
    }

    maxAmount = detectedTotal > 0 ? detectedTotal : (foundAmounts.isNotEmpty ? foundAmounts.reduce((a, b) => a > b ? a : b) : 0.0);

    // 6. Lógica específica para FACTURA A (v19)
    if (type == 'Factura A' && maxAmount > 0) {
      for (var line in lines) {
        final upperLine = line.toUpperCase().replaceFirst(r'$', '').trim();
        // Keywords para Subtotal
        if (upperLine.contains('SUBTOT') || upperLine.contains('IMP.NETOGRAVADO') || upperLine.contains('IMPORTENETOGRAVADO') || upperLine.contains('SUBTOTAL') || upperLine.contains('SUB-TOTAL')) {
           final matches = amountRegex.allMatches(line);
           if (matches.isNotEmpty) {
             double val = _parseAmount(matches.last.group(0)!);
             if (val < maxAmount) netAmt = val;
           }
        }
        // Keywords para IVA
        if (upperLine.contains('ALICUOTA') || upperLine.contains('IVA') || upperLine.contains('IMPORTEIVA') || upperLine.contains('21%') || upperLine.contains('10.5%')) {
           final matches = amountRegex.allMatches(line);
           if (matches.isNotEmpty) {
             double possibleIva = _parseAmount(matches.last.group(0)!);
             if (possibleIva < maxAmount) ivaAmt = possibleIva;
           }
        }
      }
      
      // Lógica de Respaldo (v19): Cálculo por diferencia
      if (netAmt > 0 && ivaAmt == 0) ivaAmt = (maxAmount - netAmt).abs() > 0.1 ? (maxAmount - netAmt) : 0;
      if (ivaAmt > 0 && netAmt == 0) netAmt = (maxAmount - ivaAmt).abs() > 0.1 ? (maxAmount - ivaAmt) : 0;

      // Fallback matemático estricto si sigue habiendo incongruencia
      if (netAmt == 0 || (netAmt + ivaAmt - maxAmount).abs() > 10.0) {
         netAmt = maxAmount / 1.21;
         ivaAmt = maxAmount - netAmt;
      }
    } else {
      netAmt = maxAmount;
    }

    return ExtractedReceiptData(
      grossAmount: maxAmount,
      netAmount: netAmt,
      vat: ivaAmt,
      invoiceType: type,
      rawText: text,
      imagePath: filePath,
      dateStr: foundDate,
      invoiceNumber: foundNumber,
      isPdf: isPdf,
      bytes: bytes,
      description: '', // REGLA DE ORO: SIEMPRE VACÍO
    );
  }

  double _parseAmount(String raw) {
    // 1. Limpieza inicial (v20): Quitar $, espacios y otros ruidos
    String clean = raw.replaceAll(' ', '').replaceAll(r'$', '').replaceAll(r'$', '').replaceAll('ARS', '');
    
    // 2. Lógica Argentina Mejorada (v20): Soporta cifras millonarias (1.200.000,50)
    // Buscamos cuál es el separador decimal (el último)
    int lastComma = clean.lastIndexOf(',');
    int lastDot = clean.lastIndexOf('.');
    
    if (lastComma > lastDot) {
      // Formato típico AR: 1.200.000,50
      // Quitamos todos los puntos y cambiamos coma por punto
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    } else if (lastDot > lastComma) {
      // Formato alternativo o miles con punto al final: 1,200,000.50 o 1.200
      if (clean.split('.').last.length == 3) {
         // Si hay exactamente 3 dígitos tras el punto, probablemente es miles: 1.200 -> 1200
         clean = clean.replaceAll('.', '').replaceAll(',', '');
      } else {
         // Si hay 1 o 2 dígitos, es decimal: 1,200,000.50 -> 1200000.50
         clean = clean.replaceAll(',', '');
      }
    } else {
      // No hay comas ni puntos: 1200000
      // Nada que hacer
    }
    
    return double.tryParse(clean) ?? 0.0;
  }

  void dispose() {
    if (!kIsWeb) {
      _textRecognizer.close();
    }
  }
}
