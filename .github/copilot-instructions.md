# Wanderer Frontend - Copilot Coding Agent Instructions

## Repository Overview

**wanderer-frontend** is a Flutter mobile/web app for tracking trips and adventures. Clean architecture with data, presentation, and core layers.

**Key Stats:**
- Flutter 3.27.1, Dart ^3.5.0
- Version: 1.0.19-SNAPSHOT (auto-managed by CI)
- 34 models, 6 services, 26 tests
- Coverage: ~31% (targeting improvement)
- Web deployment on port 51538 via nginx/Docker
- State Management: StatefulWidget with setState (no external state management)

## Critical Build & Test Commands

### Prerequisites
Before any commands, ensure Flutter SDK 3.27.1+ is available. The CI uses Flutter 3.35.7 (stable channel).

### Standard Workflow (Always Use This Order)

**1. Install Dependencies** (Required first step):
```bash
flutter pub get
```
⚠️ **ALWAYS run this before any other command** after cloning or when pubspec.yaml changes.

**2. Format Code** (Pre-commit requirement):
```bash
dart format .
```
This modifies files in place. CI checks formatting with:
```bash
dart format --set-exit-if-changed .
```
If this fails in CI, formatting is incorrect.

**3. Static Analysis** (Pre-commit requirement):
```bash
flutter analyze
```
Must pass with zero errors/warnings before committing.

**4. Run Tests** (Pre-commit requirement):
```bash
flutter test --coverage
```
Generates coverage in `coverage/lcov.info`. Takes ~30-60 seconds.

**5. Full Verification** (Recommended before PR):
```bash
make verify
```
Runs format, analyze, and test in sequence. This is equivalent to the CI checks.

### Build Commands

```bash
flutter build web --release        # Build for production (2-3 min)
flutter run -d chrome              # Run in Chrome for testing
make run-web-dev                   # Dev server on :51538 (needs .env.dev with GOOGLE_MAPS_API_KEY)
```

### Docker Commands

```bash
docker build -f docker/Dockerfile -t wanderer-frontend:latest .  # 5-10 min
docker run -p 51538:51538 -e GOOGLE_MAPS_API_KEY=key wanderer-frontend:latest
cd docker && docker-compose up    # Needs .env file
```

### Makefile Shortcuts

- `make verify` - Format + analyze + test (use before PR)
- `make format/analyze/test/clean/build/run/docker` - Individual commands

## Project Structure & Architecture

### Directory Layout

```
wanderer-frontend/
├── lib/
│   ├── core/
│   │   ├── config/          # Configuration (API endpoint resolution)
│   │   └── constants/       # API endpoints, enums
│   ├── data/
│   │   ├── client/          # HTTP client wrapper
│   │   ├── models/          # Data models (requests/responses/domain)
│   │   ├── repositories/    # Data repositories
│   │   ├── services/        # API service classes (6 services)
│   │   └── storage/         # Local storage (token storage)
│   ├── presentation/
│   │   ├── helpers/         # UI helpers
│   │   ├── screens/         # App screens (Home, CreateTrip, TripDetail, etc.)
│   │   └── widgets/         # Reusable widgets
│   └── main.dart           # App entry point
├── test/                   # Mirror of lib/ structure with *_test.dart files
├── web/                    # Web-specific assets
│   ├── index.html          # Entry HTML (has environment variable placeholders)
│   ├── manifest.json       # Web app manifest
│   └── icons/              # App icons
├── docker/
│   ├── Dockerfile          # Multi-stage build (Flutter + nginx)
│   ├── docker-compose.yml  # Compose configuration
│   ├── nginx/
│   │   └── nginx.conf      # Nginx config (port 51538, Flutter routing)
│   └── scripts/
│       └── docker-entrypoint.sh  # Environment variable injection script
├── android/                # Android-specific files
├── ios/                    # iOS-specific files
├── pubspec.yaml           # Dart dependencies and project metadata
├── analysis_options.yaml  # Dart analyzer configuration
├── Makefile               # Build automation
```

### Key Files

- **lib/core/constants/api_endpoints.dart**: API endpoints with conditional imports
- **lib/data/services/**: AuthService, UserService, TripService, CommentService, AchievementService, AdminService
- **lib/main.dart**: Entry point → InitialScreen
- **pubspec.yaml**: Version format: `x.y.z-SNAPSHOT+build` (dev), `x.y.z+build` (release)
- **analysis_options.yaml**: Uses flutter_lints
- **.gitignore**: Excludes `.env`, `build/`, `.dart_tool/`, `coverage/`, `web/index.html.template`

## Environment Variables & Configuration

### Development (Makefile)
Requires `.env.dev` file at repo root (Makefile uses `.env.$(TARGET_ENV)`):
```
GOOGLE_MAPS_API_KEY=your_key
DOMAIN=localhost
WEB_HTTP_PROTOCOL=http
WEB_WS_PROTOCOL=ws
```

`make run-web-dev` creates `web/index.html.template`, injects variables, runs on port 51538, restores on exit.
⚠️ Never commit `.env.*` or `web/index.html.template` (gitignored).

### Docker
Similar runtime injection via `docker/scripts/docker-entrypoint.sh` with same env vars and defaults.

## CI/CD & GitHub Workflows

### Feature Branch CI (.github/workflows/ci.yml)
Triggers: Push to non-master branches. Duration: ~5-7 min.

Steps: Setup Flutter 3.35.7 → pub get → format check (fails if not formatted) → analyze (fails on warnings) → test with coverage → Docker build (ci-test tag).

### Master Branch (.github/workflows/merge.yml)
Triggers: Push to master. Duration: ~8-12 min.

Steps: Version management (remove -SNAPSHOT, tag) → test → update README badges → build web → create release → increment version → push → Docker build (latest tag).

### Docker Build (.github/workflows/docker-build.yml)
Reusable workflow. Uses Flutter 3.27.1.

## Common Issues & Workarounds

1. **Format check fails in CI**: Run `dart format .` locally and commit.
2. **Test failures**: Ensure `flutter pub get` was run. Tests mirror `lib/` structure in `test/`.
3. **`make run-web-dev` fails**: Create `.env.dev` with `GOOGLE_MAPS_API_KEY` at repo root.
4. **Docker slow/fails**: Clean build takes 5-10 min, needs ~2GB space. Uses GitHub Actions cache.
5. **Port 51538 in use**: `lsof -ti:51538 | xargs kill -9`

## Testing Strategy

Tests mirror `lib/` in `test/` (client, core, models, repositories, services, storage).

```bash
flutter test --coverage                           # All tests
flutter test test/models/auth_models_test.dart   # Specific file
flutter test --verbose                           # Verbose
make test-watch                                  # Watch mode
```

Coverage: ~31%. CI uploads to Codecov. Target: Maintain/improve coverage with each PR.

## Coding Standards & Conventions

### Dart/Flutter Best Practices

1. **Linting**: Uses `flutter_lints ^5.0.0` (strict analysis rules in `analysis_options.yaml`)
2. **Formatting**: Dart standard formatting (2-space indent, 80-char line limit where practical)
3. **Naming**: 
   - Classes/Enums: PascalCase (e.g., `TripService`, `Visibility`)
   - Files: snake_case (e.g., `trip_service.dart`, `auth_models.dart`)
   - Variables/functions: camelCase (e.g., `userId`, `loadTrips()`)
   - Constants: lowerCamelCase for final, SCREAMING_SNAKE_CASE for compile-time constants
4. **Structure**: 
   - One class per file (except tightly coupled helpers)
   - Test files mirror lib/ structure with `_test.dart` suffix
   - Models in `lib/data/models/`, services in `lib/data/services/`
5. **State Management**: StatefulWidget with `setState` (no Provider/BLoC/Riverpod)
6. **Imports**: Group by SDK → package → relative, alphabetize within groups

### Code Quality Requirements

- **Zero warnings**: `flutter analyze` must pass with no warnings
- **Test coverage**: Add tests for new features (maintain or improve 31% baseline)
- **Comments**: Only when necessary (complex logic, API contracts, TODO with issue number)
- **Error handling**: Use try-catch with meaningful error messages, propagate errors up to UI layer

## Security & Best Practices

### API Keys & Secrets

1. **Never commit secrets**: `.env` files are gitignored
2. **Google Maps API Key**: 
   - Development: Store in `.env` file at repo root
   - Production: Injected at runtime via environment variables
   - Web deployment: Injected via `docker-entrypoint.sh` into `index.html`
3. **Authentication tokens**: Stored securely in `SharedPreferences` (see `lib/data/storage/`)
4. **Environment variables**: Use placeholders in `web/index.html` (e.g., `{{GOOGLE_MAPS_API_KEY}}`)

### Secure Coding Practices

1. **Input validation**: Validate all user inputs before API calls
2. **HTTPS**: All API calls use HTTPS in production
3. **Token handling**: JWT tokens stored securely, cleared on logout
4. **Error messages**: Don't expose sensitive info in error messages shown to users
5. **Dependencies**: Keep packages updated, review security advisories

## Contribution Guidelines

### Branching Strategy

- **master**: Production-ready code (protected, auto-deploys to production)
- **feature branches**: `feature/<issue-number>-<short-description>` or `copilot/<task-name>`
- **hotfix branches**: `hotfix/<description>` for urgent production fixes

### Pull Request Process

1. **Before creating PR**:
   - Run `make verify` to ensure formatting, analysis, and tests pass
   - Test locally (web: `make run-web-dev`, mobile: `flutter run`)
   - Ensure coverage doesn't decrease significantly
2. **PR naming**: Use descriptive titles with emoji prefix (e.g., "✨ Add trip sharing feature", "🐛 Fix map marker crash")
3. **PR description**: Include:
   - What changed and why
   - Testing performed
   - Screenshots for UI changes
   - Related issue number
4. **CI checks**: All workflows must pass (format check, analyze, tests, Docker build)
5. **Code review**: Wait for review approval before merging
6. **Merging**: Squash and merge to keep history clean

### Commit Message Format

- Use conventional commits style: `type(scope): description`
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
- Examples:
  - `feat(trips): add real-time location tracking`
  - `fix(auth): resolve token refresh bug`
  - `docs(readme): update installation instructions`

## IDE Setup & Debugging

### Recommended IDEs

- **VS Code** with extensions:
  - Flutter
  - Dart
  - Error Lens
  - Better Comments
- **Android Studio** with Flutter plugin

### Debugging

1. **Web debugging**: 
   - Use Chrome DevTools (F12)
   - Flutter DevTools: `flutter run -d chrome` then press 'v' for DevTools
2. **Mobile debugging**:
   - Set breakpoints in IDE
   - Use `flutter run` with connected device/emulator
   - Hot reload: Press 'r' in terminal
   - Hot restart: Press 'R' in terminal
3. **Logs**: Use `debugPrint()` for debug logging (stripped in release builds)

## Backend Integration

### API Endpoints

- **Development** (defaults in `ApiEndpoints`):
  - Command API: `http://localhost:8081/api/1`
  - Query API: `http://localhost:8082/api/1`
  - Auth API: `http://localhost:8083/api/1`
- **Production**: 
  - Set via environment variables (`COMMAND_BASE_URL`, `QUERY_BASE_URL`, `AUTH_BASE_URL`)
  - See `lib/core/constants/api_endpoints.dart` for conditional imports

### API Documentation

- Backend API docs: Contact backend team or see backend repository
- All API models defined in `lib/data/models/`
- All API services in `lib/data/services/`

## Common Development Tasks

### Adding a New Screen

1. Create screen file in `lib/presentation/screens/my_screen.dart`
2. Extend `StatefulWidget` (or `StatelessWidget` if no state needed)
3. Add navigation from existing screen using `Navigator.push()` with custom page transition
4. Import in parent screen and add routing logic
5. Add tests in `test/presentation/screens/my_screen_test.dart`

### Adding a New API Service

1. Define request/response models in `lib/data/models/`
2. Create service class in `lib/data/services/my_service.dart`
3. Use `BaseClient` for HTTP calls (handles auth tokens automatically)
4. Add error handling for all endpoints
5. Add unit tests in `test/services/my_service_test.dart`
6. Use `mockito` for mocking HTTP calls in tests

### Adding a New Model

1. Create model class in appropriate subdirectory of `lib/data/models/`
2. Implement `toJson()` and `fromJson()` methods for serialization
3. Add required fields with types (avoid nullable unless API allows null)
4. Add tests in `test/models/my_model_test.dart` to verify serialization

## Dependencies

**Prod:** http ^1.2.0, shared_preferences ^2.2.2, google_maps_flutter ^2.5.0, geolocator ^14.0.2
**Dev:** flutter_test, flutter_lints ^6.0.0, mockito ^5.4.4, build_runner ^2.4.8

## Best Practices

1. **Always `flutter pub get` first** after pubspec.yaml changes or clone
2. **Format before commit**: `dart format .` to avoid CI failures
3. **Use `make verify`** before PR (runs CI checks)
4. **Never commit `.env`** - create locally as needed
5. **Don't manually update version** in pubspec.yaml (merge workflow handles it)
6. **Test Docker locally**: `make docker` before pushing
7. **Preserve placeholders** in `web/index.html`: `{{GOOGLE_MAPS_API_KEY}}`, etc.
8. **Zero warnings required**: `flutter analyze` must be clean
9. **Add tests**: Maintain/improve 31% coverage baseline
10. **Follow structure**: Models in `lib/data/models/`, services in `lib/data/services/`, etc.

## When to Use These Instructions

**ALWAYS follow these instructions for:**
- Building, testing, and deploying the application
- Understanding project structure and architecture
- Setting up development environment
- Following coding standards and security practices
- Creating pull requests and contributing code

**Search for additional information only if:**
- These instructions are incomplete for your specific task
- You encounter an error not documented here
- You need to understand implementation details beyond structure
- You need to integrate with new external services or APIs

For standard build, test, and deployment tasks, trust and follow these instructions exactly.
