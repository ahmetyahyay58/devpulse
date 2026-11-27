import 'dart:async';

import 'package:devpulse/ui/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Flutter her test dosyasından önce bunu çalıştırır. Cihaz deposu (shared_preferences) test
/// ortamında yoktur; boş bir sahte depo kurulur, yoksa ona erişen kod (çıkışta CV bilgilerinin
/// silinmesi gibi) cevap beklerken takılırdı.
///
/// Arayüz animasyonları da kapatılır (sayılar ve kartlar hemen son halinde). Hareketin kendisi
/// test/motion_test.dart'ta animasyon açıkken ayrıca denenir.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SharedPreferences.setMockInitialValues({});
  Motion.testMode = true;
  await testMain();
}
