import 'package:devpulse/auth/pkce.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RFC 7636 Ek B örneği: bilinen verifier bilinen challenge verir', () {
    final pkce = Pkce.fromVerifier('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk');
    expect(pkce.challenge, 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
  });

  test('üretilen verifier kurallara uyar ve her seferinde farklıdır', () {
    final a = Pkce.generate();
    final b = Pkce.generate();
    expect(a.verifier.length, inInclusiveRange(43, 128));
    expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(a.verifier), isTrue);
    expect(a.challenge.contains('='), isFalse); // dolgu yok
    expect(a.verifier, isNot(b.verifier));
  });
}
