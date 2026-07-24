# Phase 4b (Batch H) Implementation Plan — Convert Common Widgets to Riverpod DI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the eighth batch — three widgets, not screens (`notifications_dropdown.dart`, `wanderer_app_bar.dart`, `trip_share_dialog.dart`) — to read their services from the Phase 4a Riverpod provider graph.

**Architecture:** Same conversion pattern as every prior batch. `notifications_dropdown.dart`'s convertible class (`_NotificationsDropdownContent`) is a private `StatefulWidget` — the conversion is identical regardless of the leading underscore in the class name. `wanderer_app_bar.dart`'s `_webSocketService` is used immediately in `initState()` (event-stream subscriptions), so both its fields must be assigned before that usage, same as the `HomeScreen`/`FriendsFollowersScreen` pattern from earlier batches. `trip_share_dialog.dart` already has `UrlShortenerService` as an eager field (introduced by Phase 3's HTTP-extraction work) — Phase 4a subsequently built `urlShortenerServiceProvider` for exactly this, so this task completes that connection.

**Tech Stack:** `flutter_riverpod` (provider graph from Phase 4a, `lib/core/providers/app_providers.dart`).

## Global Constraints

- `flutter analyze` zero new warnings; `flutter test` stays green throughout. Baseline on this branch: **1383 tests passing**.
- No change to any widget's public constructor signature.
- No behavior change — pure DI-wiring refactor.
- Check every task for indirect test construction, not just direct `grep "WidgetName("`.

---

## Task 1: `notifications_dropdown.dart`

**Files:**
- Modify: `lib/presentation/widgets/common/notifications_dropdown.dart`
- Test: check `find test -iname "*notifications_dropdown*"` and `grep -rln "showNotificationsDropdown\|_NotificationsDropdownContent" test/` first

**Interfaces:**
- Consumes: `notificationApiServiceProvider` (Phase 4a).

- [ ] **Step 1: Check for existing test coverage**

Run: `find test -iname "*notifications_dropdown*"` and `grep -rln "showNotificationsDropdown\|NotificationsDropdown" test/`.

- [ ] **Step 2: Convert the widget class**

Add the imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
```

Change (currently `lib/presentation/widgets/common/notifications_dropdown.dart:59-71`):

```dart
class _NotificationsDropdownContent extends StatefulWidget {
  const _NotificationsDropdownContent({
    required this.position,
    required this.animation,
  });

  final RelativeRect position;
  final Animation<double> animation;

  @override
  State<_NotificationsDropdownContent> createState() =>
      _NotificationsDropdownContentState();
}
```

to:

```dart
class _NotificationsDropdownContent extends ConsumerStatefulWidget {
  const _NotificationsDropdownContent({
    required this.position,
    required this.animation,
  });

  final RelativeRect position;
  final Animation<double> animation;

  @override
  ConsumerState<_NotificationsDropdownContent> createState() =>
      _NotificationsDropdownContentState();
}
```

- [ ] **Step 3: Convert the State class and the `NotificationApiService` field**

Change (currently `:73-90`):

```dart
class _NotificationsDropdownContentState
    extends State<_NotificationsDropdownContent> {
  final NotificationApiService _notificationService = NotificationApiService();
  final List<NotificationDto> _notifications = [];
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 0;
  bool _hasMore = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }
```

to:

```dart
class _NotificationsDropdownContentState
    extends ConsumerState<_NotificationsDropdownContent> {
  late final NotificationApiService _notificationService;
  final List<NotificationDto> _notifications = [];
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 0;
  bool _hasMore = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _notificationService = ref.read(notificationApiServiceProvider);
    _loadNotifications();
  }
```

- [ ] **Step 4: If a test exists and doesn't already use `ProviderScope`, add it**

Same approach as previous batches.

- [ ] **Step 5: Run analyze + relevant test(s) + full suite**

Run: `flutter analyze` — expect clean.
If a test exists: run it, expect PASS.
Run: `flutter test` — expect 1383 passing (unchanged).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/common/notifications_dropdown.dart
git commit -m "refactor: convert _NotificationsDropdownContent to ConsumerStatefulWidget, read NotificationApiService via provider"
```

(Include the test file too if Step 4 changed one.)

---

## Task 2: `wanderer_app_bar.dart`

**Context:** Both `_notificationService` and `_webSocketService` need conversion. `_webSocketService` is used immediately in `initState()` (event-stream subscriptions before any async work), so both provider reads must happen at the very top of `initState()`, before the existing subscription/fetch logic.

**Files:**
- Modify: `lib/presentation/widgets/common/wanderer_app_bar.dart`
- Test: check `find test -iname "*wanderer_app_bar*"` and `grep -rln "WandererAppBar(" test/` first

**Interfaces:**
- Consumes: `notificationApiServiceProvider`, `websocketServiceProvider` (Phase 4a).

- [ ] **Step 1: Check for existing test coverage**

Run: `find test -iname "*wanderer_app_bar*"` and `grep -rln "WandererAppBar(" test/`. This file already has `test/widgets/wanderer_app_bar_test.dart` referenced elsewhere in this overall effort (Batch B found it navigates to `SearchScreen`) — confirm its current state and whether it already wraps in `ProviderScope` from that earlier change, or needs it for this widget's own construction too.

- [ ] **Step 2: Convert the widget class**

Add the same two imports as Task 1. Change (currently `lib/presentation/widgets/common/wanderer_app_bar.dart:17-54`, showing the relevant declaration lines — the full class has many more constructor parameters, keep every one of them exactly as-is):

```dart
class WandererAppBar extends StatefulWidget implements PreferredSizeWidget {
```

to:

```dart
class WandererAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
```

And change (currently `:49-50`):

```dart
  @override
  State<WandererAppBar> createState() => _WandererAppBarState();
```

to:

```dart
  @override
  ConsumerState<WandererAppBar> createState() => _WandererAppBarState();
```

(All constructor parameters — `isLoggedIn`, `onLoginPressed`, `username`, `userId`, `displayName`, `avatarUrl`, `onProfile`, `onSettings`, `onLogout`, `leading`, `menuButtonKey`, `searchButtonKey`, `notificationButtonKey` — and the `preferredSize` getter stay completely unchanged.)

- [ ] **Step 3: Convert the State class and the 2 field constructions**

Change (currently `:56-60`, preserving the `SingleTickerProviderStateMixin` mixin):

```dart
class _WandererAppBarState extends State<WandererAppBar>
    with SingleTickerProviderStateMixin {
  int _unreadCount = 0;
  final NotificationApiService _notificationService = NotificationApiService();
  final WebSocketService _webSocketService = WebSocketService();
```

to:

```dart
class _WandererAppBarState extends ConsumerState<WandererAppBar>
    with SingleTickerProviderStateMixin {
  int _unreadCount = 0;
  late final NotificationApiService _notificationService;
  late final WebSocketService _webSocketService;
```

- [ ] **Step 4: Assign both fields at the top of `initState()`**

Change (currently `:87-93`):

```dart
  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _fetchUnreadCount();
    }

```

to:

```dart
  @override
  void initState() {
    super.initState();
    _notificationService = ref.read(notificationApiServiceProvider);
    _webSocketService = ref.read(websocketServiceProvider);

    if (widget.isLoggedIn) {
      _fetchUnreadCount();
    }

```

(Everything after this point in `initState()` — the WebSocket event/connection-state subscriptions, the conditional user-topic subscription — is unchanged.)

- [ ] **Step 5: If a test exists and doesn't already use `ProviderScope`, add it**

Same approach as before — this widget is likely constructed by multiple screen tests (it's the app's shared app bar), so check broadly: `grep -rln "WandererAppBar(" test/` and wrap every construction site found.

- [ ] **Step 6: Run analyze + relevant test(s) + full suite**

Run: `flutter analyze` — expect clean.
If tests exist: run them, expect PASS.
Run: `flutter test` — expect 1383 passing (unchanged).

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/widgets/common/wanderer_app_bar.dart
git commit -m "refactor: convert WandererAppBar to ConsumerStatefulWidget, read NotificationApiService/WebSocketService via provider"
```

(Include any test files too if Step 5 changed them.)

---

## Task 3: `trip_share_dialog.dart`

**Context:** This widget's `UrlShortenerService` field was introduced in Phase 3 (extracting the raw `tinyurl.com` HTTP call out of the UI layer). Phase 4a subsequently built `urlShortenerServiceProvider` for it. This task is the final connection.

**Files:**
- Modify: `lib/presentation/widgets/trip_detail/trip_share_dialog.dart`
- Test: check `find test -iname "*trip_share_dialog*"` and `grep -rln "TripShareDialog" test/` first

**Interfaces:**
- Consumes: `urlShortenerServiceProvider` (Phase 4a).

- [ ] **Step 1: Check for existing test coverage**

Run: `find test -iname "*trip_share_dialog*"` and `grep -rln "TripShareDialog" test/`.

- [ ] **Step 2: Convert the widget class**

Add the imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
```

Change (currently `lib/presentation/widgets/trip_detail/trip_share_dialog.dart:11-39`, only the class declaration and `createState()` line — the `show()` static helper method in the middle is unchanged):

```dart
class TripShareDialog extends StatefulWidget {
```

to:

```dart
class TripShareDialog extends ConsumerStatefulWidget {
```

And:

```dart
  @override
  State<TripShareDialog> createState() => _TripShareDialogState();
```

to:

```dart
  @override
  ConsumerState<TripShareDialog> createState() => _TripShareDialogState();
```

(The `tripId`/`tripName` fields, constructor, and the static `show()` method are all unchanged.)

- [ ] **Step 3: Convert the State class and the `UrlShortenerService` field**

Change (currently `:41-46`):

```dart
class _TripShareDialogState extends State<TripShareDialog> {
  late final String _tripUrl;
  final UrlShortenerService _urlShortenerService = UrlShortenerService();
  String? _shortUrl;
  bool _isLoadingShortUrl = true;
  String? _shortUrlError;
```

to:

```dart
class _TripShareDialogState extends ConsumerState<TripShareDialog> {
  late final String _tripUrl;
  late final UrlShortenerService _urlShortenerService;
  String? _shortUrl;
  bool _isLoadingShortUrl = true;
  String? _shortUrlError;
```

- [ ] **Step 4: Assign the field in `initState()`**

Change (currently `:48-53`):

```dart
  @override
  void initState() {
    super.initState();
    _tripUrl = ApiEndpoints.tripDeepLink(widget.tripId);
    _fetchShortUrl();
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    _tripUrl = ApiEndpoints.tripDeepLink(widget.tripId);
    _urlShortenerService = ref.read(urlShortenerServiceProvider);
    _fetchShortUrl();
  }
```

- [ ] **Step 5: If a test exists and doesn't already use `ProviderScope`, add it**

Same approach as before.

- [ ] **Step 6: Run analyze + relevant test(s) + full suite**

Run: `flutter analyze` — expect clean.
If a test exists: run it, expect PASS.
Run: `flutter test` — expect 1383 passing (unchanged).

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/widgets/trip_detail/trip_share_dialog.dart
git commit -m "refactor: convert TripShareDialog to ConsumerStatefulWidget, read UrlShortenerService via provider

Completes the connection between Phase 3's UrlShortenerService
extraction and Phase 4a's urlShortenerServiceProvider."
```

(Include the test file too if Step 5 changed one.)

---

## Overall verification

- [ ] `flutter analyze` — clean throughout, zero new warnings vs the 1383-test/clean-analyze baseline.
- [ ] `flutter test` — 1383 passing at the end (no new tests — pure DI rewiring of 3 files).
- [ ] Manual smoke test: `flutter run` — open the notifications dropdown (list loads, mark-as-read works), confirm the app bar's unread badge and WebSocket-driven live updates still work, open a trip's share dialog (short link still loads). Behavior identical to before this batch.
- [ ] `git log --oneline` shows one commit per task, each independently revertable.
- [ ] Confirm scope discipline: only the 3 named files (plus any test files touched) changed.
