import 'dart:io' as io;
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';

class PdfConverter {
  static Future<String> convertPdfToImage(String pdfPath) async {
    try {
      final document = await PdfDocument.openFile(pdfPath);
      final page = await document.getPage(1);
      final pageImage = await page.render(
        width: page.width * 2, // Mejoramos la calidad para el OCR
        height: page.height * 2,
        format: PdfPageImageFormat.jpeg,
        quality: 100,
      );
      
      final tempDir = await getTemporaryDirectory();
      final imagePath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = io.File(imagePath);
      await file.writeAsBytes(pageImage!.bytes);
      
      await page.close();
      await document.close();
      
      return imagePath;
    } catch (e) {
      // Si falla, devolvemos el path original aunque ML Kit falle luego
      return pdfPath;
    }
  }
}
