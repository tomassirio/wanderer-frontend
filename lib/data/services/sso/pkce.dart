import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A PKCE (RFC 7636) verifier/challenge pair used for the SSO login flow.
class PkcePair {
  final String verifier;
  final String challenge;

  const PkcePair({required this.verifier, required this.challenge});

  /// Generates a fresh verifier from 32 secure-random bytes (base64url,
  /// no padding — 43 chars) and its matching S256 challenge.
  factory PkcePair.generate({Random? random}) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final verifier = base64Url.encode(bytes).replaceAll('=', '');
    return PkcePair(verifier: verifier, challenge: challengeFor(verifier));
  }

  /// Computes the S256 code challenge for a given verifier:
  /// BASE64URL(SHA256(ASCII(verifier))), no padding.
  static String challengeFor(String verifier) {
    final digest = sha256.convert(ascii.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}
