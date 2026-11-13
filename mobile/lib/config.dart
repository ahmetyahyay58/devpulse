import 'package:flutter/foundation.dart' show kIsWeb;

/// Backend adresi derleme sırasında değiştirilebilir. Gerçek telefonda (USB ya da
/// kablosuz adb) en kolayı telefonun 127.0.0.1:8000'ini bilgisayara yönlendirmek:
///   flutter build apk --debug --target-platform android-arm64 --dart-define=API_BASE_URL=http://127.0.0.1:8000
///   adb reverse tcp:8000 tcp:8000   (adb bağlantısı her koptuğunda yeniden)
const _fromEnv = String.fromEnvironment('API_BASE_URL');

String get apiBaseUrl {
  if (_fromEnv.isNotEmpty) return _fromEnv;
  // Android emülatöründe 10.0.2.2, bilgisayarın localhost'una karşılık gelir.
  return kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
}
