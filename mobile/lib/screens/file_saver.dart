import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

// Koşullu import: web derlemesinde tarayıcı kodu, Android'de boş taslak gelir.
import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';

/// Bir dosyayı kullanıcıya verir. Testlerde sahtesi verilir.
typedef FileSaver = Future<void> Function(Uint8List bytes, String filename);

/// Dosya türü uzantıdan: verilerim .json, CV .pdf.
String mimeTypeOf(String filename) =>
    filename.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'application/json';

/// Web'de dosyayı doğrudan indirir. Android'de paylaşım menüsünü açar
/// (Dosyalar'a kaydet, Drive'a yükle, gönder...).
Future<void> shareFile(Uint8List bytes, String filename) async {
  final mime = mimeTypeOf(filename);
  if (await downloadInBrowser(bytes, filename, mime)) return;
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(bytes, mimeType: mime, name: filename)],
    fileNameOverrides: [filename],
  ));
}

/// İndirilen dosyanın adı, ör. devpulse-verilerim-2026-11-13.json
String exportFileName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'devpulse-verilerim-${now.year}-${two(now.month)}-${two(now.day)}.json';
}
