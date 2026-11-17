import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Flutter her test dosyasından önce bunu çalıştırır. Cihaz deposu (shared_preferences) test
/// ortamında yoktur; boş bir sahte depo kurulur, yoksa ona erişen kod (çıkışta CV bilgilerinin
/// silinmesi gibi) cevap beklerken takılırdı.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SharedPreferences.setMockInitialValues({});
  await testMain();
}
