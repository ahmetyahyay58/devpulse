import 'package:flutter/foundation.dart' show kIsWeb;

/// Backend adresi derleme sırasında değiştirilebilir, ör. gerçek telefonda:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
const _fromEnv = String.fromEnvironment('API_BASE_URL');

String get apiBaseUrl {
  if (_fromEnv.isNotEmpty) return _fromEnv;
  // Android emülatöründe 10.0.2.2, bilgisayarın localhost'una karşılık gelir.
  return kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
}
