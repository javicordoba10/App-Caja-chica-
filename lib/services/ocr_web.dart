import 'dart:js_util' as js_util;

Future<String> performWebOCRMethod(String base64Data, bool isPdf) async {
  try {
    var performFn = js_util.getProperty(js_util.globalThis, 'performWebOCR');
    if (performFn == null) {
      return "ERROR FACTURA A\nNo se pudo extraer OCR porque el navegador usa una versión antigua. Refresque la página vaciando caché (Ctrl+F5). TOTAL 0.0";
    }
    final promise = js_util.callMethod(js_util.globalThis, 'performWebOCR', [base64Data, isPdf]);
    final result = await js_util.promiseToFuture(promise);
    return result.toString();
  } catch (e) {
    return "ERROR FACTURA A\nExcepción JS: $e TOTAL 0.0";
  }
}
