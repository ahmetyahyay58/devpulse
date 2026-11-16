import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import 'overview_models.dart';

/// Genel Bakış ve Analiz → Metrikler verisini (metrikler + katkı takvimi) tek seferde yükler.
class OverviewController extends ChangeNotifier {
  OverviewController({required this.api, required this.onUnauthorized});

  final ApiClient api;
  final VoidCallback onUnauthorized;

  Overview? overview;
  CalendarData? calendar;
  MetricSection? anomalies; // olağan dışı yoğun günler
  MetricSection? commitTypes; // commit türleri dağılımı
  MetricSection? changePoints; // haftalık commit'te değişim noktaları
  MetricSection? technology; // diller, çeşitlilik, araçlar
  MetricSection? collaboration; // PR sonuçları ve kod incelemeleri
  Map<String, dynamic>? achievements; // rozetler + yıl kıyası
  String? error;
  bool loading = false;
  bool _disposed = false;

  Future<void> load() async {
    loading = true;
    error = null;
    _notify();
    try {
      // İstekler aynı anda gider; hepsi bitince devam edilir.
      final results = await Future.wait([
        api.get('/metrics/overview'),
        api.get('/metrics/calendar?days=210'), // son 30 hafta
        api.get('/metrics/anomalies'),
        api.get('/metrics/commit-types'),
        api.get('/metrics/change-points'),
        api.get('/metrics/technology'),
        api.get('/metrics/achievements'),
        api.get('/metrics/collaboration'),
      ]);
      overview = Overview.fromJson(results[0]);
      calendar = CalendarData.fromJson(results[1]);
      anomalies = MetricSection.fromJson(results[2]);
      commitTypes = MetricSection.fromJson(results[3]);
      changePoints = MetricSection.fromJson(results[4]);
      technology = MetricSection.fromJson(results[5]);
      achievements = results[6];
      collaboration = MetricSection.fromJson(results[7]);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        onUnauthorized();
      } else {
        error = e.message;
      }
    } catch (_) {
      error = 'Genel Bakış yüklenemedi.';
    }
    loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
