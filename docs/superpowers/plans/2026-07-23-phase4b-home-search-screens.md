# Phase 4b (Batch B) Implementation Plan — Convert Home/Search Screens to Riverpod DI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the second batch of screens (`home_screen.dart`, `search_screen.dart`, `search_bar_widget.dart`) from manually constructing their own services/repository to reading them from the Riverpod providers built in Phase 4a.

**Architecture:** Same conversion pattern as Batch A: `StatefulWidget`/`State<X>` → `ConsumerStatefulWidget`/`ConsumerState<X>`, each `final XService _x = XService();` field becomes `late final XService _x;` assigned via `ref.read(xProvider)` in `initState()`. `home_screen.dart`'s `_webSocketService` field is read from immediately inside `initState()` (an event-stream subscription) — the `ref.read` assignment must happen before that first use, so all three field assignments go at the very top of `initState()`, right after `super.initState()`.

**Tech Stack:** `flutter_riverpod` (provider graph from Phase 4a, `lib/core/providers/app_providers.dart`).

## Global Constraints

- `flutter analyze` zero new warnings; `flutter test` stays green throughout. Baseline on this branch: **1383 tests passing**.
- No change to any widget's public constructor signature.
- No behavior change — pure DI-wiring refactor.
- `home_screen.dart`'s `PushNotificationManager` field is **out of scope** — `PushNotificationManager` has no provider in the Phase 4a graph (it lives in `lib/core/services/`, a different layer than the `lib/data/` services/repositories Phase 4a covers) and is not part of this conversion. Leave `final PushNotificationManager _pushNotificationManager = PushNotificationManager();` untouched.
- `_HomeScreenState` currently has two mixins (`SingleTickerProviderStateMixin, RouteAware`) — these must be preserved on the converted `ConsumerState` class exactly as-is.

---

## Task 1: `search_bar_widget.dart`

**Files:**
- Modify: `lib/presentation/widgets/common/search_bar_widget.dart`
- Test: check `find test -iname "*search_bar*"` first

**Interfaces:**
- Consumes: `tripServiceProvider` (`lib/core/providers/app_providers.dart`, Phase 4a).

- [ ] **Step 1: Check for an existing widget test**

Run: `find test -iname "*search_bar*"` and `grep -rln "SearchBarWidget(" test/`. If a test exists and only wraps in `MaterialApp` (not `ProviderScope`), note it for Step 4.

- [ ] **Step 2: Convert the widget class**

Add the imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
```

Change (currently `lib/presentation/widgets/common/search_bar_widget.dart:15-24`):

```dart
class SearchBarWidget extends StatefulWidget {
  /// Called when the search bar wants to close itself (e.g. the user tapped
  /// outside the results overlay, or navigated to a trip).
  final VoidCallback? onClose;

  const SearchBarWidget({super.key, this.onClose});

  @override
  State<SearchBarWidget> createState() => SearchBarWidgetState();
}
```

to:

```dart
class SearchBarWidget extends ConsumerStatefulWidget {
  /// Called when the search bar wants to close itself (e.g. the user tapped
  /// outside the results overlay, or navigated to a trip).
  final VoidCallback? onClose;

  const SearchBarWidget({super.key, this.onClose});

  @override
  ConsumerState<SearchBarWidget> createState() => SearchBarWidgetState();
}
```

Note: the state class name `SearchBarWidgetState` (no leading underscore — it's public, referenced elsewhere) stays exactly as named; only its base class changes.

- [ ] **Step 3: Convert the State class and TripService construction**

Change (currently `:26-30`):

```dart
class SearchBarWidgetState extends State<SearchBarWidget> {
  final TripService _tripService = TripService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
```

to:

```dart
class SearchBarWidgetState extends ConsumerState<SearchBarWidget> {
  late final TripService _tripService;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
```

Find this file's existing `initState()` (search for `void initState` in the file) and add the assignment as its first line after `super.initState();`:

```dart
  @override
  void initState() {
    super.initState();
    _tripService = ref.read(tripServiceProvider);
    // ... existing initState body continues unchanged below this line
```

- [ ] **Step 4: If a widget test exists and doesn't already use `ProviderScope`, add it**

Same approach as Batch A Task 1 Step 4 — wrap `pumpWidget` calls in `ProviderScope`.

- [ ] **Step 5: Run analyze + relevant test(s) + full suite**

Run: `flutter analyze` — expect clean.
If a test exists: run it, expect PASS.
Run: `flutter test` — expect 1383 passing (unchanged).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/common/search_bar_widget.dart
git commit -m "refactor: convert SearchBarWidget to ConsumerStatefulWidget, read TripService via provider"
```

(Include the test file too if Step 4 changed one.)

---

## Task 2: `search_screen.dart`

**Files:**
- Modify: `lib/presentation/screens/search_screen.dart`
- Test: check `find test -iname "*search_screen*"` first

**Interfaces:**
- Consumes: `searchServiceProvider` (Phase 4a).

- [ ] **Step 1: Check for an existing widget test**

Run: `find test -iname "*search_screen*"` and `grep -rln "SearchScreen(" test/`.

- [ ] **Step 2: Convert the widget class**

Add the same two imports as Task 1. Change (currently `lib/presentation/screens/search_screen.dart:11-16`):

```dart
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}
```

to:

```dart
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}
```

- [ ] **Step 3: Convert the State class and SearchService construction**

Change (currently `:18-19`):

```dart
class _SearchScreenState extends State<SearchScreen> {
  final SearchService _searchService = SearchService();
```

to:

```dart
class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final SearchService _searchService;
```

Find this file's existing `initState()` and add the assignment as its first line after `super.initState();` (if this screen has no `initState()` override yet, add one):

```dart
  @override
  void initState() {
    super.initState();
    _searchService = ref.read(searchServiceProvider);
    // ... existing initState body (if any) continues unchanged below this line
  }
```

- [ ] **Step 4: If a widget test exists and doesn't already use `ProviderScope`, add it**

Same approach as before.

- [ ] **Step 5: Run analyze + relevant test(s) + full suite**

Run: `flutter analyze` — expect clean.
If a test exists: run it, expect PASS.
Run: `flutter test` — expect 1383 passing (unchanged).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/search_screen.dart
git commit -m "refactor: convert SearchScreen to ConsumerStatefulWidget, read SearchService via provider"
```

(Include the test file too if Step 4 changed one.)

---

## Task 3: `home_screen.dart`

**Context:** This is the largest and highest-traffic screen in this batch. It has 3 fields to convert (`HomeRepository`, `TripService`, `WebSocketService`) and one field to explicitly leave alone (`PushNotificationManager` — out of scope, no provider exists for it). `_webSocketService` is used immediately in `initState()` (subscribing to its event stream before any async work completes), so all three provider reads must happen at the very top of `initState()`, before any of the existing logic that follows.

**Files:**
- Modify: `lib/presentation/screens/home_screen.dart`
- Test: check `find test -iname "*home_screen*"` first

**Interfaces:**
- Consumes: `homeRepositoryProvider`, `tripServiceProvider`, `websocketServiceProvider` (Phase 4a).

- [ ] **Step 1: Check for an existing widget test**

Run: `find test -iname "*home_screen*"` and `grep -rln "HomeScreen(" test/` (it may also be constructed indirectly, e.g. by `InitialScreen` or a route strategy test, similar to what Batch A found for `AuthScreen`).

- [ ] **Step 2: Convert the widget class**

Add the same two imports as Task 1. Change (currently `lib/presentation/screens/home_screen.dart:35-40`):

```dart
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
```

to:

```dart
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}
```

- [ ] **Step 3: Convert the State class and the 3 in-scope field constructions**

Change (currently `:42-48`):

```dart
class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  final HomeRepository _repository = HomeRepository();
  final TripService _tripService = TripService();
  final WebSocketService _webSocketService = WebSocketService();
  final PushNotificationManager _pushNotificationManager =
      PushNotificationManager();
```

to:

```dart
class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late final HomeRepository _repository;
  late final TripService _tripService;
  late final WebSocketService _webSocketService;
  final PushNotificationManager _pushNotificationManager =
      PushNotificationManager();
```

(`PushNotificationManager` stays exactly as-is — no provider exists for it, out of scope per Global Constraints.)

- [ ] **Step 4: Assign the 3 fields at the top of `initState()`**

Change (currently `:89-107`):

```dart
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _initializeData();

    // Listen to the global WebSocket events stream immediately so events
    // are caught even before the async connect / userId resolution finishes.
    _wsSubscription = _webSocketService.events.listen(_handleWebSocketEvent);

    // Fire-and-forget: connect to WebSocket server. Once connected the
    // pending trip / user subscriptions will be activated automatically.
    _webSocketService.connect();

    // Start periodic polling as a reliable fallback — ensures the trip
    // list stays fresh even when WebSocket events are missed or delayed.
    _startPolling();
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    _repository = ref.read(homeRepositoryProvider);
    _tripService = ref.read(tripServiceProvider);
    _webSocketService = ref.read(websocketServiceProvider);

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _initializeData();

    // Listen to the global WebSocket events stream immediately so events
    // are caught even before the async connect / userId resolution finishes.
    _wsSubscription = _webSocketService.events.listen(_handleWebSocketEvent);

    // Fire-and-forget: connect to WebSocket server. Once connected the
    // pending trip / user subscriptions will be activated automatically.
    _webSocketService.connect();

    // Start periodic polling as a reliable fallback — ensures the trip
    // list stays fresh even when WebSocket events are missed or delayed.
    _startPolling();
  }
```

Every other reference to `_repository`, `_tripService`, `_webSocketService` throughout the rest of the file (there are ~20+ call sites — `_repository.getMyProfile()`, `_tripService.getTripById(...)`, `_webSocketService.unsubscribeFromAllTrips()`, etc.) needs **no changes** — they already reference these fields by name, which now hold the same type of object, just sourced differently.

- [ ] **Step 5: If a widget test exists and doesn't already use `ProviderScope`, add it**

Same approach as before — check every construction site found in Step 1.

- [ ] **Step 6: Run analyze + relevant test(s) + full suite**

Run: `flutter analyze` — expect clean.
If a test exists: run it, expect PASS.
Run: `flutter test` — expect 1383 passing (unchanged).

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/screens/home_screen.dart
git commit -m "refactor: convert HomeScreen to ConsumerStatefulWidget, read HomeRepository/TripService/WebSocketService via provider

PushNotificationManager is left untouched - no provider exists for it
in the Phase 4a graph (different layer, core/services not data/*)."
```

(Include the test file too if Step 5 changed one.)

---

## Overall verification

- [ ] `flutter analyze` — clean throughout, zero new warnings vs the 1383-test/clean-analyze baseline.
- [ ] `flutter test` — 1383 passing at the end (no new tests — pure DI rewiring of 3 files).
- [ ] Manual smoke test: `flutter run` — visit Home (feed loads, WebSocket connects, tabs switch), use Search (results load), open the search bar from wherever it's embedded. Behavior identical to before this batch.
- [ ] `git log --oneline` shows one commit per task, each independently revertable.
- [ ] Confirm scope discipline: only the 3 named files (plus any test files touched) changed — no other screens converted in this batch, `PushNotificationManager` untouched in `home_screen.dart`.
