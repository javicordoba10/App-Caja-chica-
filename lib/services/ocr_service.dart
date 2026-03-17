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
      final isPdf = filePath.toLowerCase().endsWith('.pdf') ||
          (filePath.toLowerCase().contains('.pdf'));
      String text = '';
      if (bytes != null) {
        try {
          final base64Image = base64Encode(bytes);
          text = await performWebOCRMethod(base64Image, isPdf);
        } catch (e) {
          print('Web OCR error: $e');
        }
      }
      return _parseText(text, filePath, isPdf: isPdf, bytes: bytes);
    }

    String processingPath = filePath;
    bool isPdf = filePath.toLowerCase().endsWith('.pdf');

    if (isPdf) {
      processingPath = await _convertPdfToImage(filePath);
    }

    final inputImage = InputImage.fromFilePath(processingPath);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    
    final text = recognizedText.text;
    
    return _parseText(text, filePath, isPdf: isPdf);
  }

  Future<String> _convertPdfToImage(String pdfPath) async {
    return PdfConverter.convertPdfToImage(pdfPath);
  }

  ExtractedReceiptData _parseText(String text, String filePath, {bool isPdf = false, Uint8List? bytes}) {
    // Basic heuristics to find totals and VAT in Argentine receipts
    double maxAmount = 0.0;
    double netAmt = 0.0;
    double ivaAmt = 0.0;
    // Extraer tipo de comprobante (mejorado para tolerar espacios extra o guiones)
    String type = 'Ticket';
    final upperText = text.toUpperCase();
    if (RegExp(r'(?:FACTURA|TIQUE\s+FACTURA)\s*[-:"·]*\s*A\b').hasMatch(upperText) || RegExp(r'C[OÓ]D(?:IGO)?\.?\s*01').hasMatch(upperText) || RegExp(r'\bFACTURA\s+A\b').hasMatch(upperText)) {
      type = 'Factura A';
    } else if (RegExp(r'(?:FACTURA|TIQUE\s+FACTURA)\s*[-:"·]*\s*B\b').hasMatch(upperText) || RegExp(r'C[OÓ]D(?:IGO)?\.?\s*06').hasMatch(upperText)) {
      type = 'Factura B';
    } else if (RegExp(r'(?:FACTURA|TIQUE\s+FACTURA)\s*[-:"·]*\s*C\b').hasMatch(upperText) || RegExp(r'C[OÓ]D(?:IGO)?\.?\s*11').hasMatch(upperText)) {
      type = 'Factura C';
    }

    // Regex to find currency amounts: numbers optionally separated by dot/comma/space, ending with 2 decimals
    final amountRegex = RegExp(r'\$?\s*(\d{1,3}(?:[\s.,]\d{3})*(?:[.,]\d{2}))');
    final matches = amountRegex.allMatches(text);
    
    List<double> amounts = [];
    for (var match in matches) {
      String? matchedStr = match.group(1);
      if (matchedStr != null) {
        String cleanNum = matchedStr.replaceAll(' ', '').replaceAll('.', '').replaceAll(',', '.');
        if (matchedStr.contains(',') && matchedStr.contains('.')) {
          if (matchedStr.lastIndexOf(',') < matchedStr.lastIndexOf('.')) {
            cleanNum = matchedStr.replaceAll(' ', '').replaceAll(',', '');
          } else {
            cleanNum = matchedStr.replaceAll(' ', '').replaceAll('.', '').replaceAll(',', '.');
          }
        }
        double? val = double.tryParse(cleanNum);
        if (val != null) amounts.add(val);
      }
    }

    // Búsqueda de la Fecha
    String? foundDate;
    final dateRegex = RegExp(r'(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})');
    final dateMatch = dateRegex.firstMatch(text);
    if (dateMatch != null) {
      String day = dateMatch.group(1)!.padLeft(2, '0');
      String month = dateMatch.group(2)!.padLeft(2, '0');
      foundDate = "$day/$month/${dateMatch.group(3)}";
    }

    // Búsqueda del Número de Factura
    String? foundNumber;
    // Format: 0000-00000000 or similar
    final numRegexLong = RegExp(r'\b(\d{4,5}[-\s]\d{7,8})\b');
    final numMatchLong = numRegexLong.firstMatch(text);
    if (numMatchLong != null) {
      foundNumber = numMatchLong.group(1);
    } else {
      final numRegex = RegExp(r'(?:N[uú]mero|Nro\.?|Factura|Comprobante)\s*(?:Nro\.?|N\s*[º°]|#)?\s*(\d+)', caseSensitive: false);
      final numMatch = numRegex.firstMatch(text);
      if (numMatch != null) {
        foundNumber = numMatch.group(1);
      }
    }

    // Mejora OCR: Buscar palabras clave como TOTAL o IMPORTE que estén cerca de un número
    final lines = text.split('\n');
    double possibleTotal = 0.0;
    
    // Extracción Razón Social (asumimos la 1ra línea válida)
    String foundDescription = '';
    final validLines = lines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (validLines.isNotEmpty) {
      final firstLine = validLines.first;
      if (!firstLine.contains('[OCR') && !firstLine.contains('ERROR')) {
        foundDescription = firstLine;
      }
      if (foundDescription.length > 50) {
         foundDescription = foundDescription.substring(0, 50);
      }
    }
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final upperLine = line.toUpperCase();
      if (upperLine.contains('TOTAL') || upperLine.contains('IMPORTE') || upperLine.contains('TOTAL FINAL')) {
        // Buscar un número en esta línea o en las 3 siguientes
        for (int j = i; j <= i + 3 && j < lines.length; j++) {
           final searchLine = lines[j];
           final matches = amountRegex.allMatches(searchLine);
           if (matches.isNotEmpty) {
              String rawMatch = matches.last.group(1)!;
              String cleanNum = rawMatch.replaceAll(' ', '').replaceAll('.', '').replaceAll(',', '.');
              if (rawMatch.contains(',') && rawMatch.contains('.')) {
                 if (rawMatch.lastIndexOf(',') < rawMatch.lastIndexOf('.')) {
                   cleanNum = rawMatch.replaceAll(' ', '').replaceAll(',', '');
                 } else {
                   cleanNum = rawMatch.replaceAll(' ', '').replaceAll('.', '').replaceAll(',', '.');
                 }
              }
              double? val = double.tryParse(cleanNum);
              if (val != null && val > possibleTotal) {
                 possibleTotal = val;
                 if (j == i) break; 
              }
           }
        }
      }
    }

    if (possibleTotal > 0.0) {
      maxAmount = possibleTotal;
    } else if (amounts.isNotEmpty) {
      maxAmount = amounts.reduce((curr, next) => curr > next ? curr : next);
    }
    
    // Attempt to perfectly extract Net and VAT using an algebraic heuristic: 
    // In any receipt, the 3 highest amounts are usually [Total, Net, VAT]. 
    // If Net + VAT == Total, we have found them exactly.
    if (amounts.length >= 3 && maxAmount > 0) {
      amounts.sort((a, b) => b.compareTo(a)); // sort descending
      // maxAmount is amounts[0]
      if ((amounts[1] + amounts[2] - maxAmount).abs() < 2.0) {
        netAmt = amounts[1];
        ivaAmt = amounts[2];
      }
    }
    
    // Fallback guess if algebraic extraction failed
    if (netAmt == 0.0 && type == 'Factura A' && maxAmount > 0) {
      double detectedRate = 0.21;
      for(var amt in amounts) {
        double ratio = amt / maxAmount;
        if(ratio > 0.17 && ratio < 0.22) { // rough 21%
          ivaAmt = amt;
          detectedRate = 0.21;
          break;
        } else if (ratio > 0.08 && ratio < 0.12) { // rough 10.5%
          ivaAmt = amt;
          detectedRate = 0.105;
          break;
        } else if (ratio > 0.24 && ratio < 0.29) { // rough 27%
          ivaAmt = amt;
          detectedRate = 0.27;
          break;
        }
      }
      
      if(ivaAmt == 0.0) {
        // Assume standard 21% if no exact mathematical match was found in amounts
        detectedRate = 0.21;
        netAmt = maxAmount / (1 + detectedRate);
        ivaAmt = maxAmount - netAmt;
      } else {
        netAmt = maxAmount - ivaAmt;
      }
    } else if (netAmt == 0.0) {
      netAmt = maxAmount; // No discriminatory VAT in B/C
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
      description: foundDescription,
    );
  }

  void dispose() {
    if (!kIsWeb) {
      _textRecognizer.close();
    }
  }
}
