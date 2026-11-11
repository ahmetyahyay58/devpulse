import 'dart:convert';

import 'package:http/http.dart' as http;

/// /health cevabı.
class HealthResult {
  const HealthResult({
    required this.status,
    required this.database,
    required this.elapsedMs,
  });

  final String status;
  final String database;
  final int elapsedMs; // isteğin telefondan ölçülen süresi

  bool get allOk => status == 'ok' && database == 'ok';
}

class HealthException implements Exception {
  HealthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Backend'in /health uç noktasını çağırır.
/// [client] testte sahte bir istemciyle değiştirilebilsin diye dışarıdan verilebilir.
class HealthApi {
  HealthApi({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<HealthResult> check() async {
    final watch = Stopwatch()..start();
    final resp = await _client
        .get(Uri.parse('$baseUrl/health'))
        .timeout(const Duration(seconds: 5));
    watch.stop();

    if (resp.statusCode != 200) {
      throw HealthException('Sunucu ${resp.statusCode} döndü');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return HealthResult(
      status: body['status'] as String? ?? '?',
      database: body['database'] as String? ?? '?',
      elapsedMs: watch.elapsedMilliseconds,
    );
  }
}
