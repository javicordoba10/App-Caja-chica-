import 'dart:io' as io;

class PdfConverter {
  static Future<String> convertPdfToImage(String pdfPath) async {
    // Mobile PDF conversion is completely stripped for Web Preview
    return pdfPath;
  }
}
