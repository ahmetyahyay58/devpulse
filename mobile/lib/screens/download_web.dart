import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Tarayıcıda dosyayı doğrudan indirir: bellekte bir Blob oluşturup görünmez bir
/// <a download> bağlantısına tıklar. Yalnız web derlemesinde kullanılır.
Future<bool> downloadInBrowser(Uint8List bytes, String filename) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'application/json'));
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..click();
  web.URL.revokeObjectURL(url);
  return true;
}
