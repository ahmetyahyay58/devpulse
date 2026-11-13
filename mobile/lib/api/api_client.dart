import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Backend'den gelen hata: durum kodu ve kullanıcıya gösterilecek Türkçe mesaj.
/// statusCode 0: sunucuya hiç ulaşılamadı (ağ hatası ya da zaman aşımı).
class ApiException implements Exception, UserFacingError {
  ApiException(this.statusCode, this.message, [this.detail]);
  final int statusCode;
  final String message;
  final Object? detail; // FastAPI "detail" alanının ham hali (ör. 409'da {"job_id": ...})

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == 0;

  static const networkMessage =
      'Sunucuya ulaşılamadı. İnternet bağlantını kontrol edip tekrar dene.';
  static const timeoutMessage = 'Sunucu zamanında yanıt vermedi. Biraz sonra tekrar dene.';

  @override
  String toString() => message;
}

/// Ekranda gösterilecek hata metni. Bizim hatalarımız (ApiException, AuthException)
/// zaten Türkçe mesaj taşır; beklenmeyen hataların ham metni (ör. Dart istisna adı)
/// kullanıcıya gösterilmez.
String userMessage(Object error, {String fallback = 'Beklenmeyen bir hata oluştu.'}) =>
    error is UserFacingError ? error.toString() : fallback;

/// Mesajı kullanıcıya doğrudan gösterilebilen hatalar.
abstract interface class UserFacingError {}

/// Backend'e JSON istekleri atar; oturum belirteci varsa Authorization başlığına ekler.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _http = client ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// İsteğin en fazla bekleneceği süre. Olmazsa telefon işletim sisteminin
  /// zaman aşımını (dakikalar) bekler, kullanıcı boş ekrana bakar.
  final Duration timeout;

  /// Giriş yapınca AuthService tarafından ayarlanır.
  String? sessionToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (sessionToken != null) 'Authorization': 'Bearer $sessionToken',
      };

  Future<Map<String, dynamic>> get(String path) async =>
      _decode(await _send(() => _http.get(_uri(path), headers: _headers)));

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async =>
      _decode(await _send(
          () => _http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))));

  Future<Map<String, dynamic>> delete(String path, [Map<String, dynamic>? body]) async =>
      _decode(await _send(
          () => _http.delete(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))));

  /// JSON olmayan (düz metin) cevaplar için, ör. /privacy.
  Future<String> getText(String path) async {
    final resp = await _send(() => _http.get(_uri(path), headers: _headers));
    if (resp.statusCode >= 400) throw ApiException(resp.statusCode, _fallbackMessage(resp.statusCode));
    return utf8.decode(resp.bodyBytes);
  }

  /// Dosya indirme için ham bayt, ör. /me/export. Hata yolu JSON isteklerle aynı.
  Future<Uint8List> getBytes(String path) async {
    final resp = await _send(() => _http.get(_uri(path), headers: _headers));
    if (resp.statusCode >= 400) _decode(resp); // hata mesajını aynı kurallarla çıkarır (fırlatır)
    return resp.bodyBytes;
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// Tüm istekler buradan geçer: ağ hatası ve zaman aşımı tek yerde Türkçe mesaja çevrilir.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw ApiException(0, ApiException.timeoutMessage);
    } on http.ClientException {
      // http paketi soket hatalarını (bağlantı reddedildi, ağ yok...) ClientException'a sarar.
      throw ApiException(0, ApiException.networkMessage);
    }
  }

  Map<String, dynamic> _decode(http.Response resp) {
    Object? body;
    try {
      body = resp.body.isEmpty ? <String, dynamic>{} : jsonDecode(utf8.decode(resp.bodyBytes));
    } on FormatException {
      body = null; // JSON değil (ör. bir vekil sunucunun HTML hata sayfası)
    }
    if (resp.statusCode >= 400) {
      final detail = body is Map ? body['detail'] : null;
      // FastAPI: detail ya metin, ya {"message": ...} ya da (422'de) alan hataları listesi.
      final message = detail is String
          ? detail
          : detail is Map && detail['message'] is String
              ? detail['message'] as String
              : _fallbackMessage(resp.statusCode);
      throw ApiException(resp.statusCode, message, detail);
    }
    if (body is! Map<String, dynamic>) {
      throw ApiException(resp.statusCode, 'Sunucudan beklenmeyen bir cevap geldi.');
    }
    return body;
  }

  static String _fallbackMessage(int status) => switch (status) {
        401 => 'Oturumun sona erdi. Lütfen yeniden giriş yap.',
        422 => 'İstek geçersiz bulundu.',
        >= 500 => 'Sunucuda bir hata oluştu. Biraz sonra tekrar dene.',
        _ => 'Sunucu $status döndü.',
      };
}
