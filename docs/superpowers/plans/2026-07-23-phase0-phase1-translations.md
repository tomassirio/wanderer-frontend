# Phase 0 & Phase 1 Implementation Plan — Baseline + File-Based Translations

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lock in the current test baseline, fix the `en`/`es`-only locale bug, then migrate the app's translations from hardcoded Dart `const Map` literals + inline `switch(_lang)` methods into JSON asset files loaded at startup — with zero change to the public `AppLocalizations` / `context.l10n` API so the ~472 existing call sites keep compiling and behaving identically.

**Architecture:** A new `TranslationLoader` singleton (repository-style) loads `assets/translations/{en,es,fr,nl}.json` once at app startup via `rootBundle` and caches the decoded maps in memory. `AppLocalizations` becomes a thin facade: every existing getter/method keeps its exact signature but now reads through `TranslationLoader` instead of the old const maps/switch statements. A `TranslationTemplate` helper does `{placeholder}` substitution for the ~30 parameterized strings (time-ago, achievement progress, etc.), including a simple singular/`_one` vs plural/`_other` convention for the handful of count-sensitive strings — no ICU/CLDR machinery needed since none of the 4 supported languages need anything beyond a singular/plural split at these call sites.

The old hardcoded data is never hand-retyped: a one-off migration test (`test/tool/generate_translation_assets_test.dart`) calls the *existing* `AppLocalizations` methods with sentinel inputs and captures their real output into the JSON files, then is deleted once the migration is verified. This eliminates transcription risk for ~1,850 flat strings + ~30 parameterized methods across 4 languages.

**Tech Stack:** Flutter 3.x / Dart `^3.5.0`, `flutter_test`, `dart:convert` (`json.decode`/`JsonEncoder`), `rootBundle` (`package:flutter/services.dart`). No new dependencies.

## Global Constraints

- No change to any public method/getter signature on `AppLocalizations` — all ~472 call sites (`context.l10n.xxx`) must keep compiling unchanged.
- No visible translation text may change for any of the 4 languages (en/es/fr/nl) except the two acknowledged bug fixes: `fr`/`nl` becoming selectable via `MaterialApp.supportedLocales`.
- `flutter analyze` must show zero new warnings and `flutter test` must stay green after every task.
- Run `dart format .` before each commit (per this repo's `Makefile` `verify` target: `format analyze test`).
- Every task's commit is scoped to files listed in that task — do not fold unrelated changes in.

---

## Phase 0 — Baseline & locale bug fix

### Task 0.1: Record the test/analyze baseline

**Files:** none (verification only, no commit).

- [ ] **Step 1: Run static analysis**

Run: `flutter analyze`
Expected: `No issues found!` (or note any pre-existing issues verbatim — do not fix them in this task, just record them so later phases can tell new issues from old ones).

- [ ] **Step 2: Run the full test suite with coverage**

Run: `flutter test --coverage`
Expected: All tests pass. Note the total test count and the `coverage/lcov.info` summary (e.g. via `lcov --summary coverage/lcov.info` if `lcov` is installed, otherwise just note pass count) as the floor for later phases.

- [ ] **Step 3: Note the baseline in the PR description**

No file changes in this task — carry the baseline numbers (pass count, any pre-existing analyzer issues) forward into the Phase 0 PR description so reviewers can diff later phases against it.

---

### Task 0.2: Fix `supportedLocales` drift bug (fr/nl not selectable)

**Context:** `lib/main.dart:67` hardcodes `supportedLocales: const [Locale('en'), Locale('es')]`, while `LocaleController.supportedLocales` (`lib/core/l10n/locale_controller.dart:18-23`) — the single source of truth used everywhere else (language picker, sidebar, settings) — lists all four `en/es/fr/nl`. Result: users can switch the app's UI strings to French/Dutch (the `AppLocalizations` layer supports it), but `MaterialApp`'s own `Localizations` widget never advertises `fr`/`nl` as supported, which can cause Material/Cupertino framework strings (date pickers, "OK"/"Cancel" on system dialogs, etc.) to silently fall back to the nearest supported locale instead of matching the user's actual selection.

**Fix:** point `main.dart` at `LocaleController.supportedLocales` directly instead of a second hardcoded list — this removes the possibility of the two ever drifting apart again, rather than just patching the current mismatch.

**Files:**
- Modify: `lib/main.dart:67`
- Test: `test/widget_test.dart`

**Interfaces:**
- Consumes: `LocaleController.supportedLocales` (existing `static const List<Locale>`, `lib/core/l10n/locale_controller.dart:18`) — no change to this file.

- [ ] **Step 1: Write the failing test**

Add to `test/widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MaterialApp), findsOneWidget);

    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('MaterialApp supports every locale LocaleController supports',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 500));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.supportedLocales, LocaleController.supportedLocales);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: FAIL — `app.supportedLocales` is `[Locale('en'), Locale('es')]` but `LocaleController.supportedLocales` has 4 entries.

- [ ] **Step 3: Fix `main.dart`**

In `lib/main.dart`, change:

```dart
              supportedLocales: const [Locale('en'), Locale('es')],
```

to:

```dart
              supportedLocales: LocaleController.supportedLocales,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart`
Expected: PASS — both tests green.

- [ ] **Step 5: Full suite + manual check**

Run: `flutter test` (expect same pass count as Task 0.1 + 1 new test) and `flutter analyze` (expect no new issues).
Manually: run the app, open Settings → Language, switch to Français/Nederlands, confirm the UI updates (this already worked before the fix — this task only affects the Material framework's own locale registration, not `AppLocalizations` text).

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart test/widget_test.dart
git commit -m "fix: register all 4 supported locales with MaterialApp

supportedLocales hardcoded only en/es while LocaleController (the
actual source of truth used by the language picker) supports
en/es/fr/nl. Point MaterialApp at LocaleController.supportedLocales
directly so the two can never drift apart again."
```

---

## Phase 1 — File-based translations (JSON assets, same API)

### Task 1.1: Generate JSON translation assets from the current hardcoded data

**Context:** Before touching `AppLocalizations`, mechanically export everything it currently returns into JSON — the ~463 flat keys per language (already in `const Map` literals) plus ~30 parameterized methods (currently inline `switch(_lang)` code) plus the `achievementNameFor`/`achievementDescriptionFor` lookups (keyed by `AchievementType.toJson()`, defined in `lib/data/models/domain/achievement_category.dart`).

This is done by a throwaway migration test that calls the *current* `AppLocalizations` with sentinel inputs, captures the real rendered output, substitutes the sentinel back out for a `{placeholder}` token, and writes the result to `assets/translations/*.json`. This guarantees byte-for-byte fidelity to current behavior with no hand-transcription.

Placeholder naming matches each method's actual Dart parameter name (`n`, `days`, `day`, `v`, `remaining`, `hours`, `minutes`, `count`, `unlocked`, `total`, `email`, `username`, `date`, `error`, `value`) so the JSON is self-documenting.

**Files:**
- Create: `test/tool/generate_translation_assets_test.dart` (deleted in Task 1.5)
- Create (generated, then committed): `assets/translations/en.json`, `assets/translations/es.json`, `assets/translations/fr.json`, `assets/translations/nl.json`

**Interfaces:**
- Consumes: `AppLocalizations` (unchanged, current implementation), `translationsEn/Es/Fr/Nl` (`lib/core/l10n/translations/translations_*.dart`), `AchievementType.values` + `.toJson()` (`lib/data/models/domain/achievement_category.dart:2-93`).
- Produces: `assets/translations/{en,es,fr,nl}.json`, each a flat JSON object containing: (a) every original flat key verbatim, (b) one entry per parameterized method named after that method (e.g. `"minutesAgo": "{n} minutes ago"`), (c) `_one`/`_other` pairs for `tripCountLabel`, `achievementUpdatesCount`, `achievementFollowers`, `achievementFriends`, (d) two nested objects `achievementNames` and `achievementDescriptions` keyed by the backend type string (`FIRST_TRIP`, `DISTANCE_100KM`, …).

- [ ] **Step 1: Write the generator/migration test**

Create `test/tool/generate_translation_assets_test.dart`:

```dart
// One-off migration tool for Phase 1 of the standards refactor.
//
// Run with: flutter test test/tool/generate_translation_assets_test.dart
// It writes assets/translations/{en,es,fr,nl}.json from the CURRENT
// hardcoded AppLocalizations implementation. Inspect the output, commit it,
// then delete this file and lib/core/l10n/translations/translations_*.dart
// together in Task 1.5 — this script has no purpose once its inputs are gone.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/translations/translations_en.dart';
import 'package:wanderer_frontend/core/l10n/translations/translations_es.dart';
import 'package:wanderer_frontend/core/l10n/translations/translations_fr.dart';
import 'package:wanderer_frontend/core/l10n/translations/translations_nl.dart';
import 'package:wanderer_frontend/data/models/domain/achievement_category.dart';

const _flatMaps = {
  'en': translationsEn,
  'es': translationsEs,
  'fr': translationsFr,
  'nl': translationsNl,
};

// Sentinel values substituted into method calls, then replaced with named
// placeholders in the captured output. Chosen to be extremely unlikely to
// collide with real translated text.
const _intA = 947;
const _intB = 813;
const _emailToken = 'PLACEHOLDER_EMAIL_TOKEN';
const _usernameToken = 'PLACEHOLDER_USERNAME_TOKEN';
const _dateToken = 'PLACEHOLDER_DATE_TOKEN';
const _errorToken = 'PLACEHOLDER_ERROR_TOKEN';

String _sub(String rendered, Map<String, String> literalToPlaceholder) {
  var out = rendered;
  literalToPlaceholder.forEach((literal, placeholder) {
    out = out.replaceAll(literal, placeholder);
  });
  return out;
}

Map<String, dynamic> _buildLocaleJson(String code) {
  final l10n = AppLocalizations(code);
  final out = <String, dynamic>{..._flatMaps[code]!};

  out['minutesAgo'] = _sub(l10n.minutesAgo(_intA), {'947': '{n}'});
  out['hoursAgo'] = _sub(l10n.hoursAgo(_intA), {'947': '{n}'});
  out['daysAgo'] = _sub(l10n.daysAgo(_intA), {'947': '{n}'});
  out['weeksAgo'] = _sub(l10n.weeksAgo(_intA), {'947': '{n}'});
  out['monthsAgo'] = _sub(l10n.monthsAgo(_intA), {'947': '{n}'});
  out['startsInDays'] = _sub(l10n.startsInDays(_intA), {'947': '{days}'});
  out['dayNumber'] = _sub(l10n.dayNumber(_intA), {'947': '{day}'});
  out['dayNStarted'] = _sub(l10n.dayNStarted(_intA), {'947': '{day}'});
  out['dayNEnded'] = _sub(l10n.dayNEnded(_intA), {'947': '{day}'});
  out['achievementDays'] = _sub(l10n.achievementDays(_intA), {'947': '{v}'});
  out['easterEggTapsRemaining'] =
      _sub(l10n.easterEggTapsRemaining(_intA), {'947': '{remaining}'});
  out['daysAgoShort'] = _sub(l10n.daysAgoShort(_intA), {'947': '{days}'});
  out['hoursAgoShort'] = _sub(l10n.hoursAgoShort(_intA), {'947': '{hours}'});
  out['minutesAgoShort'] =
      _sub(l10n.minutesAgoShort(_intA), {'947': '{minutes}'});

  out['passwordResetEmailSent'] = _sub(
      l10n.passwordResetEmailSent(_emailToken), {_emailToken: '{email}'});
  out['unfollowedUser'] = _sub(
      l10n.unfollowedUser(_usernameToken), {_usernameToken: '{username}'});
  out['nowFollowingUser'] = _sub(
      l10n.nowFollowingUser(_usernameToken), {_usernameToken: '{username}'});
  out['noLongerFriendsWith'] = _sub(l10n.noLongerFriendsWith(_usernameToken),
      {_usernameToken: '{username}'});
  out['friendRequestSentTo'] = _sub(
      l10n.friendRequestSentTo(_usernameToken), {_usernameToken: '{username}'});
  out['failedToFollowUser'] =
      _sub(l10n.failedToFollowUser(_errorToken), {_errorToken: '{error}'});
  out['failedToUnfollowUser'] =
      _sub(l10n.failedToUnfollowUser(_errorToken), {_errorToken: '{error}'});
  out['failedToAcceptFriendRequest'] = _sub(
      l10n.failedToAcceptFriendRequest(_errorToken), {_errorToken: '{error}'});
  out['failedToDeclineFriendRequest'] = _sub(
      l10n.failedToDeclineFriendRequest(_errorToken), {_errorToken: '{error}'});
  out['sentDateLabel'] = _sub(l10n.sentDateLabel(_dateToken), {_dateToken: '{date}'});

  out['achievementsProgress'] = _sub(
    l10n.achievementsProgress(_intA, _intB),
    {'947': '{unlocked}', '813': '{total}'},
  );
  out['achievedValue'] = _sub(l10n.achievedValue(_dateToken), {_dateToken: '{value}'});
  out['unlockedOn'] = _sub(l10n.unlockedOn(_dateToken), {_dateToken: '{date}'});
  out['goalValue'] = _sub(l10n.goalValue(_dateToken), {_dateToken: '{value}'});

  out['tripCountLabel_one'] = l10n.tripCountLabel(1);
  out['tripCountLabel_other'] =
      _sub(l10n.tripCountLabel(_intA), {'947': '{count}'});
  out['achievementUpdatesCount_one'] = l10n.achievementUpdatesCount(1);
  out['achievementUpdatesCount_other'] =
      _sub(l10n.achievementUpdatesCount(_intA), {'947': '{v}'});
  out['achievementFollowers_one'] = l10n.achievementFollowers(1);
  out['achievementFollowers_other'] =
      _sub(l10n.achievementFollowers(_intA), {'947': '{v}'});
  out['achievementFriends_one'] = l10n.achievementFriends(1);
  out['achievementFriends_other'] =
      _sub(l10n.achievementFriends(_intA), {'947': '{v}'});

  final names = <String, String>{};
  final descriptions = <String, String>{};
  for (final type in AchievementType.values) {
    final key = type.toJson();
    names[key] = l10n.achievementNameFor(key);
    descriptions[key] = l10n.achievementDescriptionFor(key);
  }
  out['achievementNames'] = names;
  out['achievementDescriptions'] = descriptions;

  return out;
}

void main() {
  test('generate assets/translations/*.json from current hardcoded strings',
      () {
    const encoder = JsonEncoder.withIndent('  ');
    for (final code in _flatMaps.keys) {
      final data = _buildLocaleJson(code);

      final file = File('assets/translations/$code.json');
      file.createSync(recursive: true);
      file.writeAsStringSync('${encoder.convert(data)}\n');

      for (final key in _flatMaps[code]!.keys) {
        expect(data.containsKey(key), isTrue, reason: '$code missing $key');
      }
      for (final t in AchievementType.values) {
        expect(
            (data['achievementNames'] as Map).containsKey(t.toJson()), isTrue);
        expect((data['achievementDescriptions'] as Map)
            .containsKey(t.toJson()), isTrue);
      }
    }
  });
}
```

- [ ] **Step 2: Run it to generate the assets**

Run: `flutter test test/tool/generate_translation_assets_test.dart`
Expected: PASS, and `assets/translations/en.json`, `es.json`, `fr.json`, `nl.json` now exist on disk.

- [ ] **Step 3: Spot-check the generated output**

Open `assets/translations/en.json` and confirm entries look like:
```json
"minutesAgo": "{n} minutes ago",
"tripCountLabel_one": "1 trip",
"tripCountLabel_other": "{count} trips",
"achievementNames": {
  "FIRST_TRIP": "First Trip",
  ...
}
```
Open `assets/translations/fr.json` and confirm e.g. `"minutesAgo": "il y a {n} minutes"`, `"achievementFriends_one": "1 ami"`. If any entry looks wrong (sentinel leaked through, e.g. contains `947` or `PLACEHOLDER_`), the corresponding method in the generator has a substitution bug — fix the `_sub` call and re-run Step 2.

- [ ] **Step 4: Commit**

```bash
git add test/tool/generate_translation_assets_test.dart assets/translations/
git commit -m "chore: generate JSON translation assets from current hardcoded strings

One-off migration tool that captures the exact current output of
AppLocalizations (flat keys + all parameterized methods + achievement
name/description tables) into assets/translations/*.json, with zero
hand-transcription. Script is removed once AppLocalizations is
rewired to read from these files (Task 1.5)."
```

---

### Task 1.2: `TranslationLoader` + `TranslationTemplate`

**Files:**
- Create: `lib/core/l10n/translation_loader.dart`
- Test: `test/core/l10n/translation_loader_test.dart`
- Modify: `pubspec.yaml` (register `assets/translations/`)

**Interfaces:**
- Produces: `TranslationLoader.instance` (singleton) with `Future<void> load()`, `bool get isLoaded`, `String string(String code, String key)`, `String nested(String code, String mapKey, String entryKey)`. `TranslationTemplate.format(String template, Map<String, Object> params)` and `TranslationTemplate.plural(TranslationLoader loader, String code, String key, int count, Map<String, Object> params)`.

- [ ] **Step 1: Register the asset directory**

In `pubspec.yaml`, under `flutter: assets:`, add the new line (keep existing entries):

```yaml
  assets:
    - assets/images/
    - assets/images/egg/
    - assets/images/inApp/
    - assets/legal/
    - assets/third_app_logos/
    - assets/translations/
```

- [ ] **Step 2: Write the failing test**

Create `test/core/l10n/translation_loader_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/l10n/translation_loader.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await TranslationLoader.instance.load();
  });

  group('TranslationLoader', () {
    test('loads all four supported locales', () {
      expect(TranslationLoader.instance.isLoaded, isTrue);
    });

    test('returns a flat string for a known key', () {
      expect(TranslationLoader.instance.string('en', 'trips'), 'Trips');
      expect(TranslationLoader.instance.string('es', 'trips'), 'Viajes');
      expect(TranslationLoader.instance.string('fr', 'trips'), 'Voyages');
      expect(TranslationLoader.instance.string('nl', 'trips'), 'Reizen');
    });

    test('falls back to English for an unknown locale', () {
      expect(TranslationLoader.instance.string('xx', 'trips'), 'Trips');
    });

    test('falls back to the key itself for an unknown key', () {
      expect(TranslationLoader.instance.string('en', 'doesNotExist'),
          'doesNotExist');
    });

    test('reads a nested achievement name', () {
      expect(
        TranslationLoader.instance.nested(
            'en', 'achievementNames', 'FIRST_TRIP'),
        'First Trip',
      );
      expect(
        TranslationLoader.instance.nested(
            'fr', 'achievementNames', 'FIRST_TRIP'),
        'Premier Voyage',
      );
    });

    test('load() is idempotent', () async {
      await TranslationLoader.instance.load();
      expect(TranslationLoader.instance.isLoaded, isTrue);
    });
  });

  group('TranslationTemplate', () {
    test('substitutes a single placeholder', () {
      expect(
        TranslationTemplate.format('{n} minutes ago', {'n': 5}),
        '5 minutes ago',
      );
    });

    test('substitutes multiple placeholders', () {
      expect(
        TranslationTemplate.format(
            'Achievements ({unlocked}/{total})', {'unlocked': 3, 'total': 10}),
        'Achievements (3/10)',
      );
    });

    test('plural() picks the singular form for count == 1', () {
      final result = TranslationTemplate.plural(
          TranslationLoader.instance, 'en', 'tripCountLabel', 1, {'count': 1});
      expect(result, '1 trip');
    });

    test('plural() picks the other form for count != 1', () {
      final result = TranslationTemplate.plural(
          TranslationLoader.instance, 'en', 'tripCountLabel', 3, {'count': 3});
      expect(result, '3 trips');
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/l10n/translation_loader_test.dart`
Expected: FAIL — `translation_loader.dart` doesn't exist yet (compile error).

- [ ] **Step 4: Implement `TranslationLoader` and `TranslationTemplate`**

Create `lib/core/l10n/translation_loader.dart`:

```dart
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Loads and caches the app's translation JSON assets
/// (`assets/translations/{code}.json`).
///
/// Call [load] once during app startup (see `main.dart`), before any
/// [AppLocalizations] is constructed. This is the single source of truth
/// for translated strings — widgets never touch it directly, they go
/// through `context.l10n` as before.
class TranslationLoader {
  TranslationLoader._internal();
  static final TranslationLoader instance = TranslationLoader._internal();

  static const List<String> supportedCodes = ['en', 'es', 'fr', 'nl'];
  static const String fallbackCode = 'en';

  final Map<String, Map<String, dynamic>> _cache = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Loads every supported locale's JSON asset into memory.
  /// Safe to call more than once — subsequent calls are no-ops.
  Future<void> load() async {
    if (_loaded) return;
    for (final code in supportedCodes) {
      final raw =
          await rootBundle.loadString('assets/translations/$code.json');
      _cache[code] = json.decode(raw) as Map<String, dynamic>;
    }
    _loaded = true;
  }

  Map<String, dynamic> _localeMap(String code) =>
      _cache[code] ?? _cache[fallbackCode] ?? const {};

  /// Flat string lookup: [code] -> falls back to [fallbackCode] -> falls
  /// back to [key] itself if nothing is found.
  String string(String code, String key) {
    final value = _localeMap(code)[key] ?? _cache[fallbackCode]?[key];
    return value is String ? value : key;
  }

  /// Nested map lookup (used for achievement names/descriptions), keyed by
  /// [mapKey] (e.g. `achievementNames`) then [entryKey] (e.g. `FIRST_TRIP`).
  String nested(String code, String mapKey, String entryKey) {
    final map = _localeMap(code)[mapKey];
    if (map is Map && map[entryKey] is String) return map[entryKey] as String;
    final fallbackMap = _cache[fallbackCode]?[mapKey];
    if (fallbackMap is Map && fallbackMap[entryKey] is String) {
      return fallbackMap[entryKey] as String;
    }
    return entryKey;
  }
}

/// Simple `{placeholder}` substitution for translation templates, plus a
/// singular/plural convention (`<key>_one` / `<key>_other`) for the handful
/// of count-sensitive strings the app uses.
class TranslationTemplate {
  const TranslationTemplate._();

  static String format(String template, Map<String, Object> params) {
    var result = template;
    params.forEach((key, value) {
      result = result.replaceAll('{$key}', value.toString());
    });
    return result;
  }

  /// Picks `<key>_one` when [count] == 1, else `<key>_other`, then applies
  /// [params] to the chosen template.
  static String plural(
    TranslationLoader loader,
    String code,
    String key,
    int count,
    Map<String, Object> params,
  ) {
    final suffix = count == 1 ? '_one' : '_other';
    final template = loader.string(code, '$key$suffix');
    return format(template, params);
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/l10n/translation_loader_test.dart`
Expected: PASS, all cases green.

- [ ] **Step 6: Commit**

```bash
git add lib/core/l10n/translation_loader.dart test/core/l10n/translation_loader_test.dart pubspec.yaml
git commit -m "feat: add TranslationLoader + TranslationTemplate

Loads assets/translations/*.json at startup and caches them in memory.
TranslationTemplate does {placeholder} substitution and a simple
_one/_other plural convention. AppLocalizations is rewired to use
these in the next task; call sites are unaffected."
```

---

### Task 1.3: Rewire `AppLocalizations` to read from `TranslationLoader`

**Files:**
- Modify: `lib/core/l10n/app_localizations.dart` (full rewrite of the data-sourcing internals; every public getter/method signature stays identical)
- Modify: `test/core/l10n/app_localizations_test.dart` (add loader bootstrap only — no assertions change)

**Interfaces:**
- Consumes: `TranslationLoader.instance` / `TranslationTemplate` (Task 1.2).
- Produces: `AppLocalizations` — same public surface as before (all getters/methods listed in `lib/core/l10n/app_localizations.dart:69-1307` keep their exact names, parameter names, and return types).

- [ ] **Step 1: Add the loader bootstrap to the existing test (still red against the old impl until Step 3, since the file doesn't need code changes to pass structurally — this step just adds setup)**

At the top of `test/core/l10n/app_localizations_test.dart`, add:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/translation_loader.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await TranslationLoader.instance.load();
  });

  group('AppLocalizations - English', () {
    // ... existing groups/tests below are unchanged ...
```

(Only the two new lines — the `setUpAll` block and the `translation_loader.dart` import — are added; every existing `group`/`test` body stays exactly as-is since the expected literal values do not change.)

- [ ] **Step 2: Run test to verify current behavior (still passing — this confirms Step 1 added no regressions before the rewire)**

Run: `flutter test test/core/l10n/app_localizations_test.dart`
Expected: PASS (old implementation still in place, loader now loaded but unused).

- [ ] **Step 3: Rewrite `AppLocalizations`**

Replace the top of `lib/core/l10n/app_localizations.dart` (imports + class header + constructor + `_tr`) — delete the `translations/translations_*.dart` imports and `_allTranslations`/`_t` field:

```dart
import 'package:flutter/widgets.dart';
import 'locale_controller.dart';
import 'translation_loader.dart';
```

```dart
class AppLocalizations {
  final String _lang;
  final TranslationLoader _loader;

  AppLocalizations(this._lang, {TranslationLoader? loader})
      : _loader = loader ?? TranslationLoader.instance;

  /// Creates an instance reflecting the current locale from [LocaleController].
  /// Prefer [BuildContext.l10n] in widget build methods for auto-rebuild.
  factory AppLocalizations.fromController() =>
      AppLocalizations(LocaleController().locale.value.languageCode);

  /// Look up a key, falling back to English if missing.
  String _tr(String key) => _loader.string(_lang, key);
```

All ~360 plain getters below (e.g. `String get trips => _tr('trips');`) are **unchanged** — `_tr` still exists with the same signature, it just delegates to `_loader` now instead of the local `_t` map.

Replace each parameterized method (currently a `switch (_lang) { ... }` block) with a call into `TranslationTemplate`. Full replacement set:

```dart
  String minutesAgo(int n) =>
      TranslationTemplate.format(_tr('minutesAgo'), {'n': n});

  String hoursAgo(int n) =>
      TranslationTemplate.format(_tr('hoursAgo'), {'n': n});

  String daysAgo(int n) =>
      TranslationTemplate.format(_tr('daysAgo'), {'n': n});

  String weeksAgo(int n) =>
      TranslationTemplate.format(_tr('weeksAgo'), {'n': n});

  String monthsAgo(int n) =>
      TranslationTemplate.format(_tr('monthsAgo'), {'n': n});

  String minutesAgoCompact(int n) => '${n}m';
  String hoursAgoCompact(int n) => '${n}h';
  String daysAgoCompact(int n) => '${n}d';

  String startsInDays(int days) =>
      TranslationTemplate.format(_tr('startsInDays'), {'days': days});

  String dayNumber(int day) =>
      TranslationTemplate.format(_tr('dayNumber'), {'day': day});

  String dayNStarted(int day) =>
      TranslationTemplate.format(_tr('dayNStarted'), {'day': day});

  String dayNEnded(int day) =>
      TranslationTemplate.format(_tr('dayNEnded'), {'day': day});

  String achievementsProgress(int unlocked, int total) =>
      TranslationTemplate.format(
          _tr('achievementsProgress'), {'unlocked': unlocked, 'total': total});

  String achievedValue(String value) =>
      TranslationTemplate.format(_tr('achievedValue'), {'value': value});

  String unlockedOn(String date) =>
      TranslationTemplate.format(_tr('unlockedOn'), {'date': date});

  String goalValue(String value) =>
      TranslationTemplate.format(_tr('goalValue'), {'value': value});

  String achievementKm(double v) => '${v.toStringAsFixed(1)} km';

  String achievementDays(int v) =>
      TranslationTemplate.format(_tr('achievementDays'), {'v': v});

  String achievementUpdatesCount(int v) => TranslationTemplate.plural(
      _loader, _lang, 'achievementUpdatesCount', v, {'v': v});

  String achievementFollowers(int v) => TranslationTemplate.plural(
      _loader, _lang, 'achievementFollowers', v, {'v': v});

  String achievementFriends(int v) => TranslationTemplate.plural(
      _loader, _lang, 'achievementFriends', v, {'v': v});

  String achievementNameFor(String typeKey) =>
      _loader.nested(_lang, 'achievementNames', typeKey);

  String achievementDescriptionFor(String typeKey) =>
      _loader.nested(_lang, 'achievementDescriptions', typeKey);

  String myTripsLabel(bool isViewingOwnProfile) =>
      isViewingOwnProfile ? myTrips : trips;

  String tripCountLabel(int count) => TranslationTemplate.plural(
      _loader, _lang, 'tripCountLabel', count, {'count': count});

  String unfollowedUser(String username) => TranslationTemplate.format(
      _tr('unfollowedUser'), {'username': username});

  String nowFollowingUser(String username) => TranslationTemplate.format(
      _tr('nowFollowingUser'), {'username': username});

  String noLongerFriendsWith(String username) => TranslationTemplate.format(
      _tr('noLongerFriendsWith'), {'username': username});

  String friendRequestSentTo(String username) => TranslationTemplate.format(
      _tr('friendRequestSentTo'), {'username': username});

  String failedToFollowUser(String e) =>
      TranslationTemplate.format(_tr('failedToFollowUser'), {'error': e});

  String failedToUnfollowUser(String e) =>
      TranslationTemplate.format(_tr('failedToUnfollowUser'), {'error': e});

  String failedToAcceptFriendRequest(String e) => TranslationTemplate.format(
      _tr('failedToAcceptFriendRequest'), {'error': e});

  String failedToDeclineFriendRequest(String e) => TranslationTemplate.format(
      _tr('failedToDeclineFriendRequest'), {'error': e});

  String sentDateLabel(String date) =>
      TranslationTemplate.format(_tr('sentDateLabel'), {'date': date});

  String daysAgoShort(int days) =>
      TranslationTemplate.format(_tr('daysAgoShort'), {'days': days});

  String hoursAgoShort(int hours) =>
      TranslationTemplate.format(_tr('hoursAgoShort'), {'hours': hours});

  String minutesAgoShort(int minutes) =>
      TranslationTemplate.format(_tr('minutesAgoShort'), {'minutes': minutes});

  String easterEggTapsRemaining(int remaining) => TranslationTemplate.format(
      _tr('easterEggTapsRemaining'), {'remaining': remaining});

  String passwordResetEmailSent(String email) => TranslationTemplate.format(
      _tr('passwordResetEmailSent'), {'email': email});
```

Every other plain getter (`trips`, `cancel`, `languageNameFor(code)`, etc. — lines 69-1307 in the original file, minus the methods replaced above) is copy-pasted unchanged from the current file; only the class header, constructor, `_tr`, and the ~30 parameterized methods above change. Delete the old inline `switch (_lang)` bodies for every one of those 30 methods and the giant inline `descs` map inside the old `achievementDescriptionFor` — both are now data, not code.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/l10n/app_localizations_test.dart`
Expected: PASS — every existing assertion (literal English/Spanish/French/Dutch strings) still holds, because the JSON was generated from this exact class's prior output in Task 1.1.

- [ ] **Step 5: Run the full suite**

Run: `flutter test`
Expected: All tests pass (same count as Task 0.2's baseline + the new `translation_loader_test.dart` cases). If any widget test that renders real (non-mocked) `l10n` strings fails because `TranslationLoader` was never loaded in that test file, add the same `setUpAll` bootstrap (`TestWidgetsFlutterBinding.ensureInitialized(); await TranslationLoader.instance.load();`) to that file — grep for it: `grep -rl "AppLocalizations\|context.l10n" test/` should currently only surface `test/core/l10n/app_localizations_test.dart` and `test/widget_test.dart` (handled in Task 1.4); if the grep turns up more files at this point, apply the same fix to each.

- [ ] **Step 6: Commit**

```bash
git add lib/core/l10n/app_localizations.dart test/core/l10n/app_localizations_test.dart
git commit -m "refactor: source AppLocalizations from TranslationLoader

AppLocalizations is now a thin facade over TranslationLoader — every
getter/method keeps its exact signature and behavior, but the data
comes from assets/translations/*.json instead of hardcoded Dart maps
and inline switch(_lang) blocks. No call site changes required."
```

---

### Task 1.4: Wire loading into app startup + smoke test

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `TranslationLoader.instance.load()` (Task 1.2).

- [ ] **Step 1: Write the failing/updated test**

In `test/widget_test.dart`, add the bootstrap so the real translated strings render during the smoke test (previously this worked for free since the const maps needed no loading step):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/core/l10n/translation_loader.dart';
import 'package:wanderer_frontend/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await TranslationLoader.instance.load();
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('MaterialApp supports every locale LocaleController supports',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 500));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.supportedLocales, LocaleController.supportedLocales);
  });
}
```

- [ ] **Step 2: Run test to verify it still passes (this step is additive — main.dart doesn't load translations itself yet, only `main()` will, so this test's `MyApp` pump doesn't strictly need it, but keeps parity going forward)**

Run: `flutter test test/widget_test.dart`
Expected: PASS.

- [ ] **Step 3: Wire the loader into app startup**

In `lib/main.dart`, add the import and the `load()` call:

```dart
import 'package:wanderer_frontend/core/l10n/translation_loader.dart';
```

```dart
  // Load the persisted locale preference before showing the app
  await LocaleController().initialize();

  // Load translation JSON assets before showing the app
  await TranslationLoader.instance.load();
```

- [ ] **Step 4: Run the full suite**

Run: `flutter test`
Expected: All green, same count as Task 1.3.

- [ ] **Step 5: Manual verification**

Run the app (`flutter run`), confirm it launches normally and all 4 languages still render correct text in Settings → Language picker, sidebar, home screen.

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart test/widget_test.dart
git commit -m "feat: load translation assets at app startup

TranslationLoader.instance.load() runs once during main(), alongside
the existing theme/locale preference loading, before runApp."
```

---

### Task 1.5: Delete the dead hardcoded translation sources

**Files:**
- Delete: `lib/core/l10n/translations/translations_en.dart`
- Delete: `lib/core/l10n/translations/translations_es.dart`
- Delete: `lib/core/l10n/translations/translations_fr.dart`
- Delete: `lib/core/l10n/translations/translations_nl.dart`
- Delete: `test/tool/generate_translation_assets_test.dart`

**Interfaces:** none — nothing outside these 5 files imports them anymore (`AppLocalizations` stopped importing `translations_*.dart` in Task 1.3; the generator test was already a one-off).

- [ ] **Step 1: Confirm nothing else references the old files**

Run: `grep -rn "translations_en\|translations_es\|translations_fr\|translations_nl" lib/ test/`
Expected: no output (only the 4 files themselves, which are being deleted, and possibly the now-obsolete generator test, also being deleted).

- [ ] **Step 2: Delete the files**

```bash
git rm lib/core/l10n/translations/translations_en.dart
git rm lib/core/l10n/translations/translations_es.dart
git rm lib/core/l10n/translations/translations_fr.dart
git rm lib/core/l10n/translations/translations_nl.dart
git rm test/tool/generate_translation_assets_test.dart
```

- [ ] **Step 3: Run analyze + full suite**

Run: `flutter analyze && flutter test`
Expected: no unused-import warnings, all tests still green (same count as Task 1.4, minus the deleted generator test's single `test()` case).

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: remove hardcoded translation sources and migration script

assets/translations/*.json (Task 1.1) is now the only source of
translation data; AppLocalizations reads it via TranslationLoader
(Task 1.3). The Dart const-map files and the one-off generator that
produced the JSON from them are no longer referenced by anything."
```

---

### Task 1.6: Drift-guard test — all locales must share the same keys

**Context:** The old hand-maintained Dart maps could (and did, per the audit) silently drift out of sync across languages with no automated check. Now that all 4 languages are files with the same shape, add a cheap structural test so a future edit to one locale's JSON without updating the others fails CI immediately, instead of silently falling back to English at runtime.

**Files:**
- Test: `test/core/l10n/translation_assets_test.dart`

**Interfaces:**
- Consumes: `assets/translations/*.json` directly (reads files from disk via `dart:io`, not through `TranslationLoader`, so it also catches malformed JSON that `TranslationLoader`'s runtime fallback would otherwise mask).

- [ ] **Step 1: Write the failing test**

Create `test/core/l10n/translation_assets_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _codes = ['en', 'es', 'fr', 'nl'];

Map<String, dynamic> _load(String code) => json.decode(
    File('assets/translations/$code.json').readAsStringSync())
    as Map<String, dynamic>;

void main() {
  test('every locale JSON file has the same top-level flat keys', () {
    final maps = {for (final c in _codes) c: _load(c)};
    final flatKeySets = maps.map((code, m) => MapEntry(
        code,
        m.keys
            .where((k) => m[k] is! Map)
            .toSet()));

    final reference = flatKeySets['en']!;
    for (final code in _codes.skip(1)) {
      final missing = reference.difference(flatKeySets[code]!);
      final extra = flatKeySets[code]!.difference(reference);
      expect(missing, isEmpty,
          reason: '$code is missing keys present in en: $missing');
      expect(extra, isEmpty,
          reason: '$code has extra keys not present in en: $extra');
    }
  });

  test('every locale has the same achievementNames keys', () {
    final maps = {for (final c in _codes) c: _load(c)};
    final reference =
        (maps['en']!['achievementNames'] as Map).keys.toSet();
    for (final code in _codes.skip(1)) {
      final keys = (maps[code]!['achievementNames'] as Map).keys.toSet();
      expect(keys, reference, reason: '$code achievementNames key mismatch');
    }
  });

  test('every locale has the same achievementDescriptions keys', () {
    final maps = {for (final c in _codes) c: _load(c)};
    final reference =
        (maps['en']!['achievementDescriptions'] as Map).keys.toSet();
    for (final code in _codes.skip(1)) {
      final keys =
          (maps[code]!['achievementDescriptions'] as Map).keys.toSet();
      expect(keys, reference,
          reason: '$code achievementDescriptions key mismatch');
    }
  });
}
```

- [ ] **Step 2: Run test to verify it currently passes**

Run: `flutter test test/core/l10n/translation_assets_test.dart`
Expected: PASS — the generator in Task 1.1 produced identical key sets for all 4 locales by construction (it iterated the same `_flatMaps.keys`/`AchievementType.values` for every locale).

(If this fails, it means the Task 1.1 generation had a locale-specific gap — go back and check `_buildLocaleJson` ran cleanly for all 4 codes before proceeding.)

- [ ] **Step 3: Commit**

```bash
git add test/core/l10n/translation_assets_test.dart
git commit -m "test: guard against translation key drift across locales

Cheap structural check that all 4 assets/translations/*.json files
expose the same flat keys and the same achievementNames/
achievementDescriptions keys, so a future edit to one locale without
updating the others fails fast instead of silently falling back to
English at runtime."
```

---

## Phase 0 & 1 overall verification

- [ ] `flutter analyze` — zero new warnings vs the Task 0.1 baseline.
- [ ] `flutter test` — all tests green; count = Task 0.1 baseline + 1 (Task 0.2) + 6 (Task 1.2) + 2 (Task 1.4) + 3 (Task 1.6) − 1 (Task 1.5 removes the one-off generator test).
- [ ] Manual smoke test: `flutter run`, switch through all 4 languages in Settings, confirm every screen (home, sidebar, achievements list with a couple of unlocked achievements, a comment's relative timestamp like "5 minutes ago") renders identically to how it looked before this plan, in every language including the newly-selectable fr/nl Material framework strings (date pickers etc.).
- [ ] `git log --oneline` on the branch shows one commit per task above, each independently revertable.
