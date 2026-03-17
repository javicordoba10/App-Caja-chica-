import 'dart:io' as io;
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
    
    // 1. Detección de Tipo de Comprobante (Más robusta)
    if (upperText.contains('FACTURAA') || upperText.contains('ORIGINALA') || (upperText.contains('FACTURA') && text.contains(RegExp(r'\bA\b')))) {
      type = 'Factura A';
    } else if (upperText.contains('FACTURAB') || (upperText.contains('FACTURA') && text.contains(RegExp(r'\bB\b')))) {
      type = 'Factura B';
    } else if (upperText.contains('FACTURAC') || (upperText.contains('FACTURA') && text.contains(RegExp(r'\bC\b')))) {
      type = 'Factura C';
    } else if (upperText.contains('TIQUE') || upperText.contains('TICKET')) {
       type = 'Ticket';
    }

    // 2. Regex para Montos (Permitir espacios opcionales ej: 857 . 502 , 80)
    final amountRegex = RegExp(r'(\d{1,3}(?:\s*[.,\s]\s*\d{3})*(?:\s*[.,\s]\s*\d{1,2})?)');
    final allMatches = amountRegex.allMatches(text);
    List<double> foundAmounts = [];
    for (var m in allMatches) {
      double val = _parseAmount(m.group(1)!);
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
      
      // Si la fecha está cerca de la palabra "inicio" o "actividad", la saltamos
      final startIndex = m.start;
      final contextBefore = text.substring((startIndex - 80).clamp(0, text.length), startIndex).toUpperCase();
      final contextAfter = text.substring(startIndex, (startIndex + 40).clamp(0, text.length)).toUpperCase();
      
      if (contextBefore.contains('INICIO') || contextBefore.contains('ACTIV') || contextAfter.contains('INICIO') || contextAfter.contains('ACTIV')) {
        continue;
      }
      
      foundDate = possibleDate;
      break;
    }
    // Fallback si no encontramos una que no sea de inicio
    if (foundDate == null && matches.isNotEmpty) {
      final m = matches.first;
      String year = m.group(3)!;
      if (year.length == 2) year = "20$year";
      foundDate = "${m.group(1)!.padLeft(2,'0')}/${m.group(2)!.padLeft(2,'0')}/$year";
    }

    // 4. Búsqueda del Número de Factura
    String? foundNumber;
    final numRegexLong = RegExp(r'(\d{3,5})\s*[-]\s*(\d{5,8})');
    final numMatchLong = numRegexLong.firstMatch(text);
    if (numMatchLong != null) {
      final g1 = numMatchLong.group(1) ?? '';
      final g2 = numMatchLong.group(2) ?? '';
      foundNumber = "${g1.padLeft(4,'0')}-${g2.padLeft(8,'0')}";
    } else {
      final numRegex = RegExp(r'(?:Nro|Num|Factura|Comp|Tique)[:\s]*([0-9-]+)', caseSensitive: false);
      final numMatch = numRegex.firstMatch(text);
      if (numMatch != null) foundNumber = numMatch.group(1);
    }

    // 5. Búsqueda de Montos Totales e IVA
    final lines = text.split('\n');
    double detectedTotal = 0.0;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toUpperCase();
      if (line.contains('TOTAL') || line.contains('FINAL') || line.contains('PAGAR') || line.contains('IMPORTE') || line.contains('VENCIMIENTO') || line.contains('NETOGRAVADO')) {
        final matches = amountRegex.allMatches(lines[i]);
        if (matches.isNotEmpty) {
           double val = _parseAmount(matches.last.group(1)!);
           if (val > detectedTotal && val < 500000000) detectedTotal = val;
        } else if (i + 1 < lines.length) {
           final nextMatches = amountRegex.allMatches(lines[i + 1]);
           if (nextMatches.isNotEmpty) {
              double val = _parseAmount(nextMatches.last.group(1)!);
              if (val > detectedTotal && val < 500000000) detectedTotal = val;
           }
        }
      }
    }

    maxAmount = detectedTotal > 0 ? detectedTotal : (foundAmounts.isNotEmpty ? foundAmounts.reduce((a, b) => a > b ? a : b) : 0.0);

    // 6. Lógica específica para FACTURA A
    if (type == 'Factura A' && maxAmount > 0) {
      for (var line in lines) {
        final upperLine = line.toUpperCase();
        if (upperLine.contains('SUB') || upperLine.contains('NETO') || upperLine.contains('GRAVADO') || upperLine.contains('BI')) {
           final matches = amountRegex.allMatches(line);
           if (matches.isNotEmpty) {
             double val = _parseAmount(matches.last.group(1)!);
             if (val < maxAmount) netAmt = val;
           }
        }
        if (upperLine.contains('IVA') || upperLine.contains('21%') || upperLine.contains('10.5%')) {
           final matches = amountRegex.allMatches(line);
           if (matches.isNotEmpty) {
             double possibleIva = _parseAmount(matches.last.group(1)!);
             if (possibleIva < maxAmount) ivaAmt = possibleIva;
           }
        }
      }
      // Fallback matemático estricto si el neto es incongruente
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
    // 1. Limpieza inicial
    String clean = raw.replaceAll(' ', '').replaceAll('\$', '');
    
    // 2. Lógica Argentina: Punto miles, Coma decimal
    if (clean.contains(',') && clean.contains('.')) {
      if (clean.lastIndexOf(',') > clean.lastIndexOf('.')) {
        // Formato Estándar AR: 1.234,56 -> 1234.56
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Formato Inverso: 1,234.56 -> 1234.56
        clean = clean.replaceAll(',', '');
      }
    } else if (clean.contains(',')) {
      // Solo coma: asumimos decimal ej 1234,56
      clean = clean.replaceAll(',', '.');
    } else if (clean.contains('.')) {
      // Solo punto: ¿Miles o Decimal? 
      final parts = clean.split('.');
      if (parts.length > 2) {
        // Varios puntos (1.200.000) -> Miles
        clean = clean.replaceAll('.', '');
      } else if (parts.length == 2) {
        // Un punto: Si hay 3 dígitos después (1.200) -> Miles
        if (parts.last.length == 3) {
          clean = clean.replaceAll('.', '');
        }
      }
      // De lo contrario se asume decimal ej 12.34
    }
    
    return double.tryParse(clean) ?? 0.0;
  }

  void dispose() {
    if (!kIsWeb) {
      _textRecognizer.close();
    }
  }
}
