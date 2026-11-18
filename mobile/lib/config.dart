import 'package:flutter/foundation.dart' show kIsWeb;

/// Backend adresi (docs/dagitim.md).
/// - Android: varsayılan olarak buluttaki sunucu (Render). Düz `flutter build apk --release`
///   ile derlenen APK, bilgisayara bağlı olmadan internetle çalışır.
/// - Web: geliştirmede bilgisayardaki sunucu.
/// İstenirse derlemede değiştirilir, ör. telefondan bilgisayardaki sunucuya bağlanmak için:
///   flutter build apk --dart-define=API_BASE_URL=http://127.0.0.1:8000 --target-platform android-arm64
///   adb reverse tcp:8000 tcp:8000
const cloudApiUrl = 'https://devpulse-api-mvwt.onrender.com';
const _fromEnv = String.fromEnvironment('API_BASE_URL');

String get apiBaseUrl {
  if (_fromEnv.isNotEmpty) return _fromEnv;
  return kIsWeb ? 'http://localhost:8000' : cloudApiUrl;
}
