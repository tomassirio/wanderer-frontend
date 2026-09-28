import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/data/services/sso/pkce.dart';

void main() {
  group('PkcePair', () {
    test('challengeFor matches RFC 7636 Appendix B vector', () {
      const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';

      expect(
        PkcePair.challengeFor(verifier),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('generate creates a verifier and matching challenge', () {
      final pair = PkcePair.generate();

      expect(pair.verifier.length, 43);
      expect(pair.verifier, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(pair.challenge.length, 43);
      expect(pair.challenge, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(pair.challenge, PkcePair.challengeFor(pair.verifier));
    });

    test('generate produces a different verifier on each call', () {
      final first = PkcePair.generate();
      final second = PkcePair.generate();

      expect(first.verifier, isNot(equals(second.verifier)));
    });
  });
}
