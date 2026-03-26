import 'dart:typed_data';

class Blob {
  Blob(List<dynamic> blobParts, [String? type]);
}

class Url {
  static String createObjectUrlFromBlob(dynamic blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  String? href;
  AnchorElement({this.href});
  void setAttribute(String name, String value) {}
  void click() {}
}

class Location {
  String href = '';
}

class Window {
  final Location location = Location();
  void open(String url, String target) {}
}

final Window window = Window();

// Stubs para evitar errores de compilación Web (dart2js)
class File {
  final String path;
  File(this.path);
  Future<void> writeAsBytes(List<int> bytes) async {}
  Future<Uint8List> readAsBytes() async => Uint8List(0);
}

Future<dynamic> getApplicationDocumentsDirectory() async {
  return null;
}
