import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/l10n/translation_loader.dart';

/// Runs once per test file before its `main()`, for every test under this
/// directory (see the Flutter test framework's `flutter_test_config.dart`
/// convention). Ensures `TranslationLoader` is loaded so any widget that
/// renders real (non-mocked) `context.l10n` text sees actual translations
/// instead of raw JSON keys — without every test file needing its own
/// bootstrap. `TranslationLoader.load()` is idempotent, so this is cheap
/// even for files that don't touch l10n at all.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await TranslationLoader.instance.load();
  await testMain();
}
