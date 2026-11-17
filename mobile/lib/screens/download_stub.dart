import 'dart:typed_data';

/// Web dışı platformlar (Android): tarayıcı indirmesi yok; çağıran paylaşım menüsünü kullanır.
Future<bool> downloadInBrowser(Uint8List bytes, String filename, String mimeType) async => false;
