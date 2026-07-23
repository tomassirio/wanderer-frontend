# Phase 2a Implementation Plan — Canonical Trip-Status Color/Icon + Date-Format Dedup

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace 8 independent, mutually-contradicting trip-status color/icon implementations with one canonical source (`UiHelpers`), and extract one byte-identical duplicated date-formatting function into a shared helper — with zero change to any other visible behavior.

**Architecture:** `lib/presentation/helpers/ui_helpers.dart` already has `UiHelpers.getStatusIcon(TripStatus)`; this plan adds a sibling `UiHelpers.getStatusColor(TripStatus)` and repoints every screen/widget that currently rolls its own status color/icon switch to call these two static methods instead, deleting the local duplicates. Separately, `TripCard` and `EnhancedTripCard`'s identical `_formatDate` method moves to a new `DateFormatHelper` in the same helpers directory.

**Tech Stack:** Flutter/Dart, `flutter_test`. No new dependencies.

## Global Constraints

- `flutter analyze` zero new warnings; `flutter test` stays green throughout. Baseline on this branch: **1350 tests passing**.
- **Visible color/icon changes are intentional and already approved** — the 8 existing implementations disagree with each other, so consolidating necessarily changes at least 7 of 8 screens' appearance no matter which mapping is chosen. Canonical mapping (already decided, do not re-derive):
  - Icons — unchanged, reuse existing `UiHelpers.getStatusIcon`: `created`→`Icons.schedule`, `inProgress`→`Icons.play_arrow`, `paused`→`Icons.pause`, `finished`→`Icons.check`, `resting`→`Icons.nightlight_round`.
  - Colors — new `UiHelpers.getStatusColor`: `created`→`Color(0xFF6C757D)`, `inProgress`→`Color(0xFF4CAF50)`, `paused`→`Color(0xFFFF9800)`, `finished`→`WandererTheme.statusCompleted`, `resting`→`WandererTheme.statusResting`.
- Do **not** modify `WandererTheme.statusCreated`/`statusInProgress`/`statusCancelled` — those existing tokens color unrelated action buttons elsewhere (`trip_lifecycle_buttons.dart`, `trip_status_control.dart`, `trip_plan_info_card.dart`, `settings_screen.dart`, `trip_info_card.dart`) and must not change.
- No existing test in this repo asserts a specific status color (verified: `grep -rl "Colors\.\(green\|orange\|blue\|grey\|purple\)"` across `test/` returns nothing relevant) — no test-value updates are needed for the color change itself, only compile-correctness and existing label/text assertions must keep passing.
- Out of scope (deferred to a later Phase 2b with its own design conversation): consolidating the 4 trip-card widgets into one, and swapping any screen's inline badge rendering for the shared `StatusBadge` widget.

---

## Task 1: `UiHelpers.getStatusColor` (foundation)

**Files:**
- Modify: `lib/presentation/helpers/ui_helpers.dart`
- Test: `test/helpers/ui_helpers_test.dart` (new file — none exists yet for this helper)

**Interfaces:**
- Produces: `static Color UiHelpers.getStatusColor(TripStatus status)` — consumed by every task below.

- [ ] **Step 1: Write the failing test**

Create `test/helpers/ui_helpers_test.dart`:

```dart
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';

void main() {
  group('UiHelpers.getStatusColor', () {
    test('created is neutral grey', () {
      expect(UiHelpers.getStatusColor(TripStatus.created),
          const Color(0xFF6C757D));
    });

    test('inProgress is green', () {
      expect(UiHelpers.getStatusColor(TripStatus.inProgress),
          const Color(0xFF4CAF50));
    });

    test('paused is orange', () {
      expect(UiHelpers.getStatusColor(TripStatus.paused),
          const Color(0xFFFF9800));
    });

    test('finished reuses WandererTheme.statusCompleted', () {
      expect(UiHelpers.getStatusColor(TripStatus.finished),
          WandererTheme.statusCompleted);
    });

    test('resting reuses WandererTheme.statusResting', () {
      expect(UiHelpers.getStatusColor(TripStatus.resting),
          WandererTheme.statusResting);
    });
  });

  group('UiHelpers.getStatusIcon (unchanged, regression guard)', () {
    test('maps every status to its existing icon', () {
      expect(UiHelpers.getStatusIcon(TripStatus.created), Icons.schedule);
      expect(UiHelpers.getStatusIcon(TripStatus.inProgress), Icons.play_arrow);
      expect(UiHelpers.getStatusIcon(TripStatus.paused), Icons.pause);
      expect(UiHelpers.getStatusIcon(TripStatus.finished), Icons.check);
      expect(UiHelpers.getStatusIcon(TripStatus.resting),
          Icons.nightlight_round);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/helpers/ui_helpers_test.dart`
Expected: FAIL — `getStatusColor` is not defined on `UiHelpers`.

- [ ] **Step 3: Implement `getStatusColor`**

In `lib/presentation/helpers/ui_helpers.dart`, add the import and method (insert right after the existing `getStatusIcon`, before `getVisibilityIcon`):

```dart
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
```

```dart
  /// Gets the canonical color for a trip status.
  static Color getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return const Color(0xFF6C757D);
      case TripStatus.inProgress:
        return const Color(0xFF4CAF50);
      case TripStatus.paused:
        return const Color(0xFFFF9800);
      case TripStatus.finished:
        return WandererTheme.statusCompleted;
      case TripStatus.resting:
        return WandererTheme.statusResting;
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/helpers/ui_helpers_test.dart`
Expected: PASS, all 6 cases green.

- [ ] **Step 5: Full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: 1356 tests passing (1350 + 6 new), analyze clean.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/helpers/ui_helpers.dart test/helpers/ui_helpers_test.dart
git commit -m "feat: add UiHelpers.getStatusColor as the canonical trip-status color

Sibling to the existing getStatusIcon. Consolidates 8 independent,
mutually-contradicting per-screen color mappings into one source,
reusing WandererTheme.statusCompleted/statusResting where they
already match the chosen canonical scheme."
```

---

## Task 2: Replace `profile_screen.dart` + `home_screen.dart`

**Files:**
- Modify: `lib/presentation/screens/profile_screen.dart` (3 methods: outer `_getStatusIcon`, outer `_getStatusChipColor`, inner `_ProfileTripCardState._getStatusColor`)
- Modify: `lib/presentation/screens/home_screen.dart` (2 methods, both nullable)

Both files already `import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';` — no new imports needed.

**Interfaces:**
- Consumes: `UiHelpers.getStatusColor`/`getStatusIcon` (Task 1).

- [ ] **Step 1: `profile_screen.dart` — outer class**

Delete the outer class's `_getStatusIcon` (currently `lib/presentation/screens/profile_screen.dart:1966-1979`) and `_getStatusChipColor` (currently `:1981-1994`):

```dart
  /// Returns an icon for each trip status.
  IconData _getStatusIcon(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return Icons.edit_note_rounded;
      case TripStatus.inProgress:
        return Icons.directions_walk_rounded;
      case TripStatus.paused:
        return Icons.pause_circle_outline_rounded;
      case TripStatus.finished:
        return Icons.check_circle_outline_rounded;
      case TripStatus.resting:
        return Icons.hotel_rounded;
    }
  }

  Color _getStatusChipColor(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return Colors.grey;
      case TripStatus.inProgress:
        return Colors.blue;
      case TripStatus.paused:
        return Colors.orange;
      case TripStatus.finished:
        return Colors.green;
      case TripStatus.resting:
        return WandererTheme.statusResting;
    }
  }
```

Update the two call sites to use `UiHelpers` directly instead of the deleted local methods:
- Line `1882`: `final statusColor = _getStatusChipColor(status);` → `final statusColor = UiHelpers.getStatusColor(status);`
- Line `1921`: `_getStatusIcon(status),` → `UiHelpers.getStatusIcon(status),`

- [ ] **Step 2: `profile_screen.dart` — `_ProfileTripCardState`**

Delete the inner class's own duplicate (currently `:2016-2029`):

```dart
  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return Colors.grey;
      case TripStatus.inProgress:
        return Colors.blue;
      case TripStatus.paused:
        return Colors.orange;
      case TripStatus.finished:
        return Colors.green;
      case TripStatus.resting:
        return WandererTheme.statusResting;
    }
  }
```

Update its one call site (`:2068`): `color: _getStatusColor(widget.trip.status),` → `color: UiHelpers.getStatusColor(widget.trip.status),`

- [ ] **Step 3: `home_screen.dart`**

Delete `_getStatusIcon`/`_getStatusColor` (currently `:1132-1162`), preserving the nullable "all statuses" fallback behavior:

```dart
  IconData _getStatusIcon(TripStatus? status) {
    if (status == null) return Icons.all_inclusive;
    switch (status) {
      case TripStatus.inProgress:
        return Icons.circle;
      case TripStatus.paused:
        return Icons.pause;
      case TripStatus.finished:
        return Icons.check_circle_outline;
      case TripStatus.created:
        return Icons.edit_outlined;
      case TripStatus.resting:
        return Icons.nightlight_round;
    }
  }

  Color _getStatusColor(TripStatus? status) {
    if (status == null) return Colors.grey;
    switch (status) {
      case TripStatus.inProgress:
        return Colors.green;
      case TripStatus.paused:
        return Colors.orange;
      case TripStatus.finished:
        return Colors.blue;
      case TripStatus.created:
        return Colors.grey;
      case TripStatus.resting:
        return WandererTheme.statusResting;
    }
  }
```

Replace their two call sites (`:994-995`):

```dart
            icon: _getStatusIcon(_statusFilter),
            iconColor: _getStatusColor(_statusFilter),
```

becomes:

```dart
            icon: _statusFilter == null
                ? Icons.all_inclusive
                : UiHelpers.getStatusIcon(_statusFilter!),
            iconColor: _statusFilter == null
                ? Colors.grey
                : UiHelpers.getStatusColor(_statusFilter!),
```

- [ ] **Step 4: Run full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: 1356 tests passing (no new tests this task — existing widget/screen tests, if any exercise these screens, must still pass since only colors/icons changed, not structure or text), analyze clean. If `profile_screen.dart` or `home_screen.dart` have any existing tests, run them specifically first: `flutter test test/ -name "profile\|home"` is not valid Dart test syntax — instead run `flutter test` (full suite) since these screens' test files (if present) are already included in the baseline count.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/profile_screen.dart lib/presentation/screens/home_screen.dart
git commit -m "refactor: use UiHelpers for status color/icon in profile_screen and home_screen

Deletes 3 duplicated switch(TripStatus) blocks (profile_screen's outer
class + its inner _ProfileTripCardState, plus home_screen's nullable
variant for the \"all statuses\" filter). Visible colors/icons on these
two screens now match the canonical UiHelpers mapping."
```

---

## Task 3: Replace `trip_promotion_screen.dart` + `trip_card.dart`

**Files:**
- Modify: `lib/presentation/screens/trip_promotion_screen.dart`
- Modify: `lib/presentation/widgets/home/trip_card.dart`

Both already import `ui_helpers.dart` — `trip_promotion_screen.dart` does; `trip_card.dart` does **not** yet — add it.

**Interfaces:**
- Consumes: `UiHelpers.getStatusColor`/`getStatusIcon` (Task 1).

- [ ] **Step 1: `trip_promotion_screen.dart`**

Delete `_getStatusIcon`/`_getStatusColor` (currently `:922-950`):

```dart
  IconData _getStatusIcon(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return Icons.fiber_new;
      case TripStatus.inProgress:
        return Icons.directions_run;
      case TripStatus.paused:
        return Icons.pause_circle;
      case TripStatus.finished:
        return Icons.check_circle;
      case TripStatus.resting:
        return Icons.nightlight_round;
    }
  }

  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return Colors.blue;
      case TripStatus.inProgress:
        return Colors.green;
      case TripStatus.paused:
        return Colors.orange;
      case TripStatus.finished:
        return Colors.grey;
      case TripStatus.resting:
        return WandererTheme.statusResting;
    }
  }
```

Replace the two call-site pairs (`:802-803` and `:863-864`), each shaped like:

```dart
              _getStatusIcon(trip.status),
              color: _getStatusColor(trip.status),
```

becomes:

```dart
              UiHelpers.getStatusIcon(trip.status),
              color: UiHelpers.getStatusColor(trip.status),
```

(apply this same substitution at both call sites).

- [ ] **Step 2: `trip_card.dart` — add the import**

At the top of `lib/presentation/widgets/home/trip_card.dart`, add:

```dart
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
```

- [ ] **Step 3: `trip_card.dart` — delete the duplicated methods**

Delete `_getStatusColor`/`_getStatusIcon` (currently `:559-588`):

```dart
  /// Get status color based on trip status
  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return const Color(0xFF6C757D); // Gray
      case TripStatus.inProgress:
        return const Color(0xFF28A745); // Green
      case TripStatus.paused:
        return const Color(0xFFFFC107); // Yellow/Amber
      case TripStatus.finished:
        return const Color(0xFF007BFF); // Blue
      case TripStatus.resting:
        return WandererTheme.statusResting; // Indigo
    }
  }

  /// Get status icon
  IconData _getStatusIcon(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return Icons.pending_outlined;
      case TripStatus.inProgress:
        return Icons.play_arrow;
      case TripStatus.paused:
        return Icons.pause;
      case TripStatus.finished:
        return Icons.check_circle_outline;
      case TripStatus.resting:
        return Icons.nightlight_round;
    }
  }
```

Replace the two call sites:
- `:398`: `final statusColor = _getStatusColor(widget.trip.status);` → `final statusColor = UiHelpers.getStatusColor(widget.trip.status);`
- `:417`: `_getStatusIcon(widget.trip.status),` → `UiHelpers.getStatusIcon(widget.trip.status),`

- [ ] **Step 4: Run full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: 1356 tests passing, analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/trip_promotion_screen.dart lib/presentation/widgets/home/trip_card.dart
git commit -m "refactor: use UiHelpers for status color/icon in trip_promotion_screen and trip_card"
```

---

## Task 4: Replace `trip_status_menu.dart` + `search_bar_widget.dart` + `status_badge.dart`

**Files:**
- Modify: `lib/presentation/widgets/trip_detail/trip_status_menu.dart` (color only — icon already delegates to `UiHelpers`)
- Modify: `lib/presentation/widgets/common/search_bar_widget.dart` (color only — no icon shown here)
- Modify: `lib/presentation/widgets/home/status_badge.dart` (icon, icon-color, and border-color)

`trip_status_menu.dart` already imports `ui_helpers.dart`. `search_bar_widget.dart` and `status_badge.dart` do **not** — add the import to both.

**Interfaces:**
- Consumes: `UiHelpers.getStatusColor`/`getStatusIcon` (Task 1).

- [ ] **Step 1: `trip_status_menu.dart`**

Delete `_getStatusColor` (currently `:76-89`):

```dart
  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.inProgress:
        return Colors.green;
      case TripStatus.paused:
        return Colors.orange;
      case TripStatus.resting:
        return WandererTheme.statusResting;
      case TripStatus.finished:
        return Colors.grey;
      case TripStatus.created:
        return Colors.blue;
    }
  }
```

Replace its one call site (`:65`): `color: _getStatusColor(status),` → `color: UiHelpers.getStatusColor(status),`

(Leave `UiHelpers.getStatusIcon(status)` at line 64 untouched — already correct.)

- [ ] **Step 2: `search_bar_widget.dart` — add import and delete `_statusColor`**

Add at the top:

```dart
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
```

Delete `_statusColor` (currently `:328-341`):

```dart
  Color _statusColor(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return Colors.grey;
      case TripStatus.inProgress:
        return Colors.blue;
      case TripStatus.paused:
        return Colors.orange;
      case TripStatus.finished:
        return Colors.green;
      case TripStatus.resting:
        return WandererTheme.statusResting;
    }
  }
```

Replace all three call sites (`:267`, `:301`, `:309`) — every `_statusColor(trip.status)` becomes `UiHelpers.getStatusColor(trip.status)`.

- [ ] **Step 3: `status_badge.dart` — add import and delete the 3 duplicated methods**

Add at the top:

```dart
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
```

Delete `_getIcon` (currently `:121-134`), `_getBorderColor` (`:151-164`), and `_getIconColor` (`:166-179`):

```dart
  IconData _getIcon() {
    switch (widget.status) {
      case TripStatus.created:
        return Icons.edit_outlined;
      case TripStatus.inProgress:
        return Icons.circle;
      case TripStatus.paused:
        return Icons.pause;
      case TripStatus.finished:
        return Icons.check_circle_outline;
      case TripStatus.resting:
        return Icons.nightlight_round;
    }
  }
```
```dart
  Color _getBorderColor() {
    switch (widget.status) {
      case TripStatus.created:
        return Colors.grey.withOpacity(0.3);
      case TripStatus.inProgress:
        return Colors.green.withOpacity(0.3);
      case TripStatus.paused:
        return Colors.orange.withOpacity(0.3);
      case TripStatus.finished:
        return Colors.blue.withOpacity(0.3);
      case TripStatus.resting:
        return WandererTheme.statusResting.withOpacity(0.3);
    }
  }
```
```dart
  Color _getIconColor() {
    switch (widget.status) {
      case TripStatus.created:
        return Colors.grey.shade700;
      case TripStatus.inProgress:
        return Colors.green.shade700;
      case TripStatus.paused:
        return Colors.orange.shade700;
      case TripStatus.finished:
        return Colors.blue.shade700;
      case TripStatus.resting:
        return WandererTheme.statusResting;
    }
  }
```

Replace them with three one-line methods in the same spot (keep the same private-method names and 0-arg signatures so the rest of the widget's `build`/`_getLabel` call sites — lines 65, 68, 78, 86, 90, 96, 100, 102, 112 — need no changes at all):

```dart
  IconData _getIcon() => UiHelpers.getStatusIcon(widget.status);

  Color _getBorderColor() =>
      UiHelpers.getStatusColor(widget.status).withOpacity(0.3);

  Color _getIconColor() => UiHelpers.getStatusColor(widget.status);
```

- [ ] **Step 4: Run full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: 1356 tests passing (including `test/widgets/home/status_badge_test.dart`, which asserts labels/text only — no color assertions to update), analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/trip_detail/trip_status_menu.dart lib/presentation/widgets/common/search_bar_widget.dart lib/presentation/widgets/home/status_badge.dart
git commit -m "refactor: use UiHelpers for status color/icon in trip_status_menu, search_bar_widget, status_badge

status_badge.dart's three private methods keep their existing 0-arg
signatures so none of its own call sites need to change - only the
method bodies now delegate to the canonical UiHelpers mapping."
```

---

## Task 5: Replace `search_screen.dart` (String-keyed, isolated)

**Files:**
- Modify: `lib/presentation/screens/search_screen.dart`

This is the one site with a different signature: `_getStatusColor(String status, ThemeData theme)` takes a raw backend string (`TripSummary.status` is `String`, e.g. `'IN_PROGRESS'`) plus a `ThemeData` fallback for unparseable values. `TripStatus.fromJson(String)` (`lib/core/constants/enums.dart:307-320`) parses the same strings but **throws** `ArgumentError` on an unrecognized value, so the existing theme-fallback behavior must be preserved with a try/catch, not a blind parse.

**Interfaces:**
- Consumes: `UiHelpers.getStatusColor` (Task 1), `TripStatus.fromJson` (existing, `lib/core/constants/enums.dart`).

- [ ] **Step 1: Add the two missing imports**

At the top of `lib/presentation/screens/search_screen.dart`, add:

```dart
import '../../core/constants/enums.dart';
import '../helpers/ui_helpers.dart';
```

- [ ] **Step 2: Replace `_getStatusColor`**

Delete the current body (`:659-674`):

```dart
  Color _getStatusColor(String status, ThemeData theme) {
    switch (status) {
      case 'IN_PROGRESS':
        return Colors.green;
      case 'PAUSED':
        return Colors.orange;
      case 'RESTING':
        return Colors.blue;
      case 'FINISHED':
        return Colors.grey;
      case 'CREATED':
        return Colors.purple;
      default:
        return theme.colorScheme.primary;
    }
  }
```

Replace with:

```dart
  Color _getStatusColor(String status, ThemeData theme) {
    try {
      return UiHelpers.getStatusColor(TripStatus.fromJson(status));
    } on ArgumentError {
      return theme.colorScheme.primary;
    }
  }
```

The call site (`:494`, `final statusColor = _getStatusColor(trip.status, theme);`) needs no change — same signature, same call.

- [ ] **Step 3: Run full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: 1356 tests passing, analyze clean.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/search_screen.dart
git commit -m "refactor: use UiHelpers for status color in search_screen

Parses the raw backend status string via TripStatus.fromJson before
delegating to the canonical UiHelpers.getStatusColor, preserving the
existing theme.colorScheme.primary fallback for any unparseable value."
```

---

## Task 6: Extract `DateFormatHelper` (dedup `trip_card.dart` / `enhanced_trip_card.dart`)

**Context:** `_formatDate(DateTime date)` in `lib/presentation/widgets/home/trip_card.dart:31-61` and `lib/presentation/widgets/home/enhanced_trip_card.dart:44-74` are byte-identical (verified by direct comparison) — same day/hour/week/month thresholds, same `l10n` calls, same `DateFormat('MMM d, yyyy')` fallback for dates over a year old. `_formatCountdown` in `enhanced_trip_card.dart` (lines 86-102) is a different, non-duplicated function and is **not** touched by this task.

**Files:**
- Create: `lib/presentation/helpers/date_format_helper.dart`
- Test: `test/helpers/date_format_helper_test.dart`
- Modify: `lib/presentation/widgets/home/trip_card.dart`
- Modify: `lib/presentation/widgets/home/enhanced_trip_card.dart`

**Interfaces:**
- Produces: `static String DateFormatHelper.formatRelativeDate(AppLocalizations l10n, DateTime date)`.

- [ ] **Step 1: Write the failing test**

Create `test/helpers/date_format_helper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/translation_loader.dart';
import 'package:wanderer_frontend/presentation/helpers/date_format_helper.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await TranslationLoader.instance.load();
  });

  group('DateFormatHelper.formatRelativeDate', () {
    final l10n = AppLocalizations('en');

    test('just now for a date seconds ago', () {
      final date = DateTime.now();
      expect(DateFormatHelper.formatRelativeDate(l10n, date), l10n.justNow);
    });

    test('minutes ago for a date under an hour old', () {
      final date = DateTime.now().subtract(const Duration(minutes: 5));
      expect(DateFormatHelper.formatRelativeDate(l10n, date),
          l10n.minutesAgo(5));
    });

    test('hours ago for a date under a day old', () {
      final date = DateTime.now().subtract(const Duration(hours: 3));
      expect(DateFormatHelper.formatRelativeDate(l10n, date),
          l10n.hoursAgo(3));
    });

    test('days ago for a date under a week old', () {
      final date = DateTime.now().subtract(const Duration(days: 3));
      expect(DateFormatHelper.formatRelativeDate(l10n, date),
          l10n.daysAgo(3));
    });

    test('weeks ago for a date under a month old', () {
      final date = DateTime.now().subtract(const Duration(days: 14));
      expect(DateFormatHelper.formatRelativeDate(l10n, date),
          l10n.weeksAgo(2));
    });

    test('months ago for a date under a year old', () {
      final date = DateTime.now().subtract(const Duration(days: 60));
      expect(DateFormatHelper.formatRelativeDate(l10n, date),
          l10n.monthsAgo(2));
    });

    test('absolute date for anything over a year old', () {
      final date = DateTime(2020, 3, 15);
      expect(
          DateFormatHelper.formatRelativeDate(l10n, date), 'Mar 15, 2020');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/helpers/date_format_helper_test.dart`
Expected: FAIL — `date_format_helper.dart` doesn't exist yet.

- [ ] **Step 3: Implement `DateFormatHelper`**

Create `lib/presentation/helpers/date_format_helper.dart`:

```dart
import 'package:intl/intl.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Helper for formatting dates as human-relative strings across trip cards.
class DateFormatHelper {
  /// Formats [date] relative to now: "just now", "5 minutes ago", "3 days
  /// ago", etc., falling back to an absolute "MMM d, yyyy" date once
  /// [date] is over a year old.
  static String formatRelativeDate(AppLocalizations l10n, DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return l10n.justNow;
        }
        return difference.inMinutes == 1
            ? l10n.minuteAgo
            : l10n.minutesAgo(difference.inMinutes);
      }
      return difference.inHours == 1
          ? l10n.hourAgo
          : l10n.hoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return difference.inDays == 1
          ? l10n.dayAgo
          : l10n.daysAgo(difference.inDays);
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? l10n.weekAgo : l10n.weeksAgo(weeks);
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? l10n.monthAgo : l10n.monthsAgo(months);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/helpers/date_format_helper_test.dart`
Expected: PASS, all 7 cases green.

- [ ] **Step 5: Rewire `trip_card.dart`**

In `lib/presentation/widgets/home/trip_card.dart`, add the import:

```dart
import 'package:wanderer_frontend/presentation/helpers/date_format_helper.dart';
```

Delete the local `_formatDate` (currently `:31-61`):

```dart
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    final l10n = context.l10n;

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return l10n.justNow;
        }
        return difference.inMinutes == 1
            ? l10n.minuteAgo
            : l10n.minutesAgo(difference.inMinutes);
      }
      return difference.inHours == 1
          ? l10n.hourAgo
          : l10n.hoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return difference.inDays == 1
          ? l10n.dayAgo
          : l10n.daysAgo(difference.inDays);
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? l10n.weekAgo : l10n.weeksAgo(weeks);
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? l10n.monthAgo : l10n.monthsAgo(months);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
```

Replace with a one-line delegation, keeping the same name/signature so every call site (`_formatDate(...)`) in this file needs no other changes:

```dart
  String _formatDate(DateTime date) =>
      DateFormatHelper.formatRelativeDate(context.l10n, date);
```

Note: `package:intl/intl.dart` may now be unused in this file if `_formatDate` was its only consumer — check with `grep -n "DateFormat\|Intl\." lib/presentation/widgets/home/trip_card.dart` after this edit; if there are no other uses, remove the now-unused `import 'package:intl/intl.dart';` line.

- [ ] **Step 6: Rewire `enhanced_trip_card.dart`**

In `lib/presentation/widgets/home/enhanced_trip_card.dart`, add the import:

```dart
import 'package:wanderer_frontend/presentation/helpers/date_format_helper.dart';
```

Delete the local `_formatDate` (currently `:44-74`, identical body to the one just removed from `trip_card.dart`) and replace with:

```dart
  String _formatDate(DateTime date) =>
      DateFormatHelper.formatRelativeDate(context.l10n, date);
```

Do **not** touch `_formatCountdown` (`:86-102`) — out of scope for this task, it still uses `DateFormat` directly for its own absolute-date fallback, so keep the `package:intl/intl.dart` import in this file regardless.

- [ ] **Step 7: Run full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: 1363 tests passing (1356 + 7 new), analyze clean.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/helpers/date_format_helper.dart test/helpers/date_format_helper_test.dart lib/presentation/widgets/home/trip_card.dart lib/presentation/widgets/home/enhanced_trip_card.dart
git commit -m "refactor: extract DateFormatHelper, dedup TripCard/EnhancedTripCard _formatDate

The two _formatDate methods were byte-identical. Both now delegate to
DateFormatHelper.formatRelativeDate; enhanced_trip_card's unrelated
_formatCountdown is untouched."
```

---

## Overall verification

- [ ] `flutter analyze` — clean throughout, zero new warnings vs the 1350-test/clean-analyze baseline.
- [ ] `flutter test` — 1363 passing at the end (1350 baseline + 6 + 7 new tests across Tasks 1 and 6; Tasks 2-5 add no new tests, only compile/behavior-preserving swaps).
- [ ] Manual smoke test: `flutter run` — visit Home (status filter chips + trip cards), Profile (status filter chips + mini trip cards), Trip Promotion (promotable/promoted trip rows), Search (search results with status badges), a trip's detail screen (status change menu), and confirm every status badge/icon across all these screens now shows the **same** color and icon for the same `TripStatus` value — this is the actual fix, so eyeball it once across screens side by side.
- [ ] `git log --oneline` on `refactor/phase-2-dedup-ui` shows one commit per task, each independently revertable.
