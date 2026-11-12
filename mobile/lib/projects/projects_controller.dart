import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import 'projects_models.dart';

/// Projeler sekmesinin verisini yükler.
class ProjectsController extends ChangeNotifier {
  ProjectsController({required this.api, required this.onUnauthorized});

  final ApiClient api;
  final VoidCallback onUnauthorized;

  ProjectsData? data;
  String? error;
  bool _disposed = false;

  Future<void> load() async {
    error = null;
    _notify();
    try {
      data = ProjectsData.fromJson(await api.get('/projects'));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        onUnauthorized();
      } else {
        error = e.message;
      }
    } catch (_) {
      error = 'Projeler yüklenemedi.';
    }
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
