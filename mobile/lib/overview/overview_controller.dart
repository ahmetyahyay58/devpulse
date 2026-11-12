import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import 'overview_models.dart';

/// Genel Bakış verisini (metrikler + katkı takvimi) yükler.
class OverviewController extends ChangeNotifier {
  OverviewController({required this.api, required this.onUnauthorized});

  final ApiClient api;
  final VoidCallback onUnauthorized;

  Overview? overview;
  CalendarData? calendar;
  String? error;
  bool loading = false;
  bool _disposed = false;

  Future<void> load() async {
    loading = true;
    error = null;
    _notify();
    try {
      // İki istek aynı anda gider; ikisi de bitince devam edilir.
      final results = await Future.wait([
        api.get('/metrics/overview'),
        api.get('/metrics/calendar'),
      ]);
      overview = Overview.fromJson(results[0]);
      calendar = CalendarData.fromJson(results[1]);
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
