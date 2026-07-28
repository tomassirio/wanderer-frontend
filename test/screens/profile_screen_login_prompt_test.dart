import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/screens/profile_screen.dart';

// Regression test for the guard in `ProfileScreen._buildBody()` that decides
// whether to show the "please log in" / fetch-error prompt instead of
// profile content. Extracted as a pure predicate
// (`profileScreenShowsLoginOrErrorPrompt`) so this matrix is testable
// without pumping the full widget tree (ProfileScreen has no existing
// widget-test infrastructure).
void main() {
  group('profileScreenShowsLoginOrErrorPrompt', () {
    test('own profile, logged in, no error -> false (show content)', () {
      expect(
        profileScreenShowsLoginOrErrorPrompt(
          hasError: false,
          isLoggedIn: true,
          isOwnProfile: true,
        ),
        isFalse,
      );
    });

    test('own profile, logged in, error -> true (show error, no button)', () {
      expect(
        profileScreenShowsLoginOrErrorPrompt(
          hasError: true,
          isLoggedIn: true,
          isOwnProfile: true,
        ),
        isTrue,
      );
    });

    test(
      'own profile, logged out, no error -> true (show login prompt) '
      '- the intended fix this guard preserves',
      () {
        expect(
          profileScreenShowsLoginOrErrorPrompt(
            hasError: false,
            isLoggedIn: false,
            isOwnProfile: true,
          ),
          isTrue,
        );
      },
    );

    test('own profile, logged out, error -> true (login prompt wins)', () {
      expect(
        profileScreenShowsLoginOrErrorPrompt(
          hasError: true,
          isLoggedIn: false,
          isOwnProfile: true,
        ),
        isTrue,
      );
    });

    test("someone else's profile, logged in, no error -> false", () {
      expect(
        profileScreenShowsLoginOrErrorPrompt(
          hasError: false,
          isLoggedIn: true,
          isOwnProfile: false,
        ),
        isFalse,
      );
    });

    test("someone else's profile, logged in, error -> true (show error)", () {
      expect(
        profileScreenShowsLoginOrErrorPrompt(
          hasError: true,
          isLoggedIn: true,
          isOwnProfile: false,
        ),
        isTrue,
      );
    });

    test(
      "someone else's profile, logged out, no error -> false "
      '(the bug this fix targets: fade-transition window / '
      'deep-link UserChromeState race must NOT show a login prompt)',
      () {
        expect(
          profileScreenShowsLoginOrErrorPrompt(
            hasError: false,
            isLoggedIn: false,
            isOwnProfile: false,
          ),
          isFalse,
        );
      },
    );

    test(
      "someone else's profile, logged out, error -> true "
      '(a genuine fetch error still surfaces the prompt)',
      () {
        expect(
          profileScreenShowsLoginOrErrorPrompt(
            hasError: true,
            isLoggedIn: false,
            isOwnProfile: false,
          ),
          isTrue,
        );
      },
    );
  });
}
