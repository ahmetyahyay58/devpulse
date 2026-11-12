import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// PKCE (RFC 7636): kodu yolda ele geçiren biri verifier'ı bilmediği için
/// onu token'a çeviremez. GitHub'a yalnızca verifier'ın özeti (challenge) gider.
class Pkce {
  Pkce._(this.verifier, this.challenge);

  final String verifier;
  final String challenge;

  /// Yeni, rastgele bir verifier/challenge çifti.
  factory Pkce.generate() => Pkce.fromVerifier(randomUrlSafe(64));

  factory Pkce.fromVerifier(String verifier) => Pkce._(verifier, challengeFor(verifier));

  /// challenge = BASE64URL(SHA256(verifier)), sondaki '=' dolguları olmadan.
  static String challengeFor(String verifier) {
    final digest = sha256.convert(ascii.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}

const _unreserved = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

/// RFC 7636'nın izin verdiği karakterlerden, güvenli rastgele kaynakla üretilmiş metin.
/// Random.secure(): işletim sisteminin kriptografik kaynağı (Random() tahmin edilebilir).
String randomUrlSafe(int length) {
  final rng = Random.secure();
  return List.generate(length, (_) => _unreserved[rng.nextInt(_unreserved.length)]).join();
}
