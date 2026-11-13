import 'dart:async';
import 'dart:convert';

import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/auth/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Hata yolları: kullanıcı ham istisna metni (SocketException, FormatException...) görmemeli.
void main() {
  ApiClient client(MockClientHandler handler, {Duration? timeout}) => ApiClient(
        baseUrl: 'http://test',
        client: MockClient(handler),
        timeout: timeout ?? const Duration(seconds: 20),
      );

  Future<ApiException> failure(Future<Object?> call) async {
    try {
      await call;
    } on ApiException catch (e) {
      return e;
    }
    fail('ApiException bekleniyordu');
  }

  test('sunucuya ulaşılamazsa Türkçe ağ mesajı (statusCode 0)', () async {
    // Telefonda gördüğümüz durum: bağlantı zaman aşımı / reddedildi.
    final api = client((_) async => throw http.ClientException(
        'SocketException: Connection timed out (OS Error: errno = 110)'));
    final e = await failure(api.get('/auth/config'));
    expect(e.isNetwork, isTrue);
    expect(e.message, ApiException.networkMessage);
    expect(e.message, isNot(contains('Socket')));
  });

  test('cevap gecikirse zaman aşımı mesajı', () async {
    final never = Completer<http.Response>().future; // hiç gelmeyen cevap
    final api = client((_) => never, timeout: const Duration(milliseconds: 10));
    final e = await failure(api.post('/auth/demo'));
    expect(e.isNetwork, isTrue);
    expect(e.message, ApiException.timeoutMessage);
  });

  test('backend detail metni olduğu gibi gösterilir', () async {
    final api = client((_) async => http.Response(
        jsonEncode({'detail': 'GitHub istek sınırı doldu; yaklaşık 5 dakika sonra tekrar dene.'}), 429,
        headers: {'content-type': 'application/json; charset=utf-8'}));
    final e = await failure(api.post('/sync'));
    expect(e.statusCode, 429);
    expect(e.message, contains('istek sınırı'));
  });

  test('422 alan hataları listesi ham gösterilmez', () async {
    final api = client((_) async => http.Response(
        jsonEncode({'detail': [{'loc': ['body', 'code'], 'msg': 'Field required'}]}), 422));
    final e = await failure(api.post('/auth/github'));
    expect(e.message, 'İstek geçersiz bulundu.');
  });

  test('JSON olmayan 502 sayfası (vekil sunucu) anlaşılır mesaja döner', () async {
    final api = client((_) async => http.Response('<html>Bad Gateway</html>', 502));
    final e = await failure(api.get('/metrics/overview'));
    expect(e.statusCode, 502);
    expect(e.message, contains('Sunucuda bir hata oluştu'));
  });

  test('userMessage: bizim hatalarımızın mesajı, diğerleri için genel metin', () {
    expect(userMessage(ApiException(0, ApiException.networkMessage)), ApiException.networkMessage);
    expect(userMessage(AuthException('Giriş penceresi kapatıldı.')), 'Giriş penceresi kapatıldı.');
    expect(userMessage(const FormatException('Unexpected character')), 'Beklenmeyen bir hata oluştu.');
    expect(userMessage(StateError('x'), fallback: 'Giriş yapılamadı.'), 'Giriş yapılamadı.');
  });
}
