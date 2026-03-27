# AGENTS.md

## Overview

Flutter trip-tracking app (web/Android/iOS). Clean layered architecture: `core/` (config, routing, theme, l10n), `data/` (clients, models, services, storage), `presentation/` (screens, widgets, helpers).

## Build & Verify

```bash
flutter pub get                # ALWAYS first — required before any other command
make verify                    # Format + analyze + test (mirrors CI exactly)
dart format .                  # Auto-fix formatting
flutter test test/services/trip_service_test.dart  # Run single test file
```

CI runs Flutter 3.35.7. Zero warnings required from `flutter analyze`. Formatting is checked with `--set-exit-if-changed`.

## Architecture — CQRS Client Layer

The backend uses CQRS — reads and writes go to **different servers**. This is the most important structural pattern:

- **Query clients** (`lib/data/client/query/`) → read from `queryBaseUrl` (port 8082)
- **Command clients** (`lib/data/client/command/`) → write to `commandBaseUrl` (port 8081)
- **Auth client** (`lib/data/client/auth/`) → `authBaseUrl` (port 8083)
- **Services** (`lib/data/services/`) compose multiple clients — e.g. `TripService` injects both `TripQueryClient` and `TripCommandClient`

All clients extend/use `ApiClient` (`lib/data/client/api_client.dart`) which handles JWT auth, token refresh, and `AuthenticationRedirectException` for 401 redirects.

## Key Patterns

- **State management**: `StatefulWidget` + `setState` only — no Provider/BLoC/Riverpod
- **Routing**: Strategy pattern in `lib/core/routing/` — `AppRouter` iterates `RouteStrategy` instances; add new deep links by creating a strategy in `strategies/`
- **Localization**: Custom `context.l10n` extension via `L10nScope` InheritedNotifier (not flutter_gen) — translations are plain `Map<String, String>` in `lib/core/l10n/translations/`
- **Theme**: `WandererTheme` in `lib/core/theme/wanderer_theme.dart` — use `WandererTheme.primaryOrange`, status colors, etc. instead of hardcoded values
- **Barrel files**: Models use barrel exports (`trip_models.dart`, `models.dart`); clients use `clients.dart`. Import the barrel, not individual files
- **Web config**: `ApiEndpoints` uses conditional imports (`dart.library.js_interop`) to read config from `window.appConfig` on web vs. defaults on mobile

## Testing

Tests mirror `lib/` under `test/`. Services use **hand-written mocks** (not mockito `@GenerateMocks`) — see `test/services/trip_service_test.dart` for the pattern: mock clients are defined at the bottom of test files with tracking booleans (e.g. `getCurrentUserTripsCalled`). Constructor injection makes all clients mockable via optional named parameters.

## Adding New Features

- **New screen**: Create in `lib/presentation/screens/`, use `StatefulWidget`, add navigation via `Navigator.push()`, add route strategy if deep-linkable
- **New API endpoint**: Add constant to `ApiEndpoints`, create query/command client, create or update service, add tests
- **New model**: Add to `lib/data/models/domain/`, implement `fromJson`/`toJson`, export via barrel file, add serialization tests
- **New widget**: Place in appropriate `lib/presentation/widgets/<feature>/` subdirectory

## Pitfalls

- **Never commit** `.env` or `web/index.html.template` (gitignored)
- **Version in `pubspec.yaml`** is auto-managed by CI merge workflow — don't manually change it
- `analysis_options.yaml` ignores `deprecated_member_use` and `use_build_context_synchronously` — these are intentional
- Command client write operations return **just a trip ID** (HTTP 202); full data arrives via `WebSocketService`
- Google Maps API key is injected at runtime via env vars — `{{GOOGLE_MAPS_API_KEY}}` placeholder in `web/index.html`

