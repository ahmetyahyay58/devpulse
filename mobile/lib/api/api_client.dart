import 'dart:convert';

import 'package:http/http.dart' as http;

/// Backend'den gelen hata: durum kodu ve FastAPI'nin "detail" mesajı.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, [this.detail]);
  final int statusCode;
  final String message;
  final Object? detail; // FastAPI "detail" alanının ham hali (ör. 409'da {"job_id": ...})

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Backend'e JSON istekleri atar; oturum belirteci varsa Authorization başlığına ekler.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client}) : _http = client ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Giriş yapınca AuthService tarafından ayarlanır.
  String? sessionToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (sessionToken != null) 'Authorization': 'Bearer $sessionToken',
      };

  Future<Map<String, dynamic>> get(String path) async =>
      _decode(await _http.get(Uri.parse('$baseUrl$path'), headers: _headers));

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async =>
      _decode(await _http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body ?? {}),
      ));

  Map<String, dynamic> _decode(http.Response resp) {
    final body = resp.body.isEmpty ? <String, dynamic>{} : jsonDecode(utf8.decode(resp.bodyBytes));
    if (resp.statusCode >= 400) {
      final detail = body is Map ? body['detail'] : null;
      final message = detail is Map ? detail['message'] : detail;
      throw ApiException(resp.statusCode, '${message ?? 'Sunucu ${resp.statusCode} döndü'}', detail);
    }
    return body as Map<String, dynamic>;
  }
}
