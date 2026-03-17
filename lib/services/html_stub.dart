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

class Window {
  void open(String url, String target) {}
}

final Window window = Window();
