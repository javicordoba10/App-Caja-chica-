import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:petty_cash_app/services/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'package:petty_cash_app/services/html_stub.dart' if (dart.library.io) 'dart:io' as io;
import 'package:path_provider/path_provider.dart' if (dart.library.html) 'package:petty_cash_app/services/html_stub.dart';

class PlatformService {
  static Future<void> saveExcel(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Usamos dynamic para evitar que el compilador web falle al ver tipos de dart:io o path_provider
      try {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = io.File(filePath);
        await file.writeAsBytes(bytes);
      } catch (e) {
        debugPrint('Error saving file on mobile: $e');
      }
    }
  }

  static void openUrl(String url) {
    if (kIsWeb) {
      html.window.open(url, '_blank');
    } else {
      // url_launcher se encarga de esto en DashboardScreen
    }
  }

  static String? getUriParameter(String key) {
    if (kIsWeb) {
      try {
        final uri = Uri.base;
        debugPrint('PlatformService: Analizando URI: $uri');
        if (uri.queryParameters.containsKey(key)) {
          final val = uri.queryParameters[key];
          debugPrint('PlatformService: Encontrado en query: $val');
          return val;
        }
        if (uri.hasFragment && uri.fragment.contains('?')) {
          final queryPart = uri.fragment.split('?').last;
          final params = Uri.splitQueryString(queryPart);
          if (params.containsKey(key)) {
            final val = params[key];
            debugPrint('PlatformService: Encontrado en fragment: $val');
            return val;
          }
        }
        debugPrint('PlatformService: No se encontro el parametro $key');
      } catch (_) {}
    }
    return null;
  }
}
