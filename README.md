<p align="center">
  <img src="assets/images/wanderer-logo.png" alt="Wanderer Logo" width="180" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.4.6-blue" alt="Version" />
  <img src="https://img.shields.io/badge/coverage-27%25-red
  <img src="https://img.shields.io/badge/Flutter-3.27.1-02569B?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License" />
</p>

A cross-platform Flutter application for tracking trips and adventures in real time. Runs on the web, Android, and iOS.

![Wanderer Feature Overview](assets/images/wanderer-feature.png)

## Features

- **Real-Time Trip Tracking** — Start a trip, send location updates with messages and photos, and watch the route appear on an interactive Google Maps view
- **Multi-Day Trips** — Mark the end and start of each day while on longer adventures
- **Trip Planning** — Plan future trips with waypoints before you hit the road
- **Social** — Follow other travelers, comment on trips, and react to updates
- **Achievements** — Unlock milestones based on your travel history
- **Visibility Control** — Set trips to private, protected (followers / link only), or public
- **Weather** — See current weather conditions alongside trip updates
- **QR Code Sharing** — Generate and scan QR codes for quick trip or profile sharing
- **Deep Links** — Share direct links to trips or user profiles
- **Push Notifications** — Receive notifications for follows, comments, and reactions (Android)
- **Background Updates** — Continue sending location updates while the app is in the background (Android)
- **Admin Panel** — User management and trip data maintenance tools for administrators

### Screenshots

| Home | Trip Detail | Trip Map |
|:----:|:-----------:|:--------:|
| ![Home](assets/images/inApp/home.jpeg) | ![Trip Detail](assets/images/inApp/trip_details.jpeg) | ![Trip Map](assets/images/inApp/in_map.jpeg) |

| Create Trip | Profile | Trip Planning |
|:-----------:|:-------:|:-------------:|
| ![Create Trip](assets/images/inApp/trip_create.jpeg) | ![Profile](assets/images/inApp/profile.jpeg) | ![Trip Planning](assets/images/inApp/trip_plan_create.jpeg) |

## Architecture

The project follows a clean layered architecture:

```
lib/
├── core/
│   ├── config/             # Platform-aware API endpoint resolution
│   ├── constants/          # API endpoints, enums
│   ├── routing/            # Deep-link router and route strategies
│   ├── services/           # Background updates, notifications, navigation
│   └── theme/              # Wanderer theme constants
├── data/
│   ├── client/             # HTTP & WebSocket clients (auth, command, query)
│   ├── models/             # Domain models, request/response DTOs
│   ├── repositories/       # Data repositories
│   ├── services/           # Business-logic services
│   └── storage/            # Local token storage (SharedPreferences)
├── presentation/
│   ├── helpers/            # UI utilities (dialogs, map helpers, transitions)
│   ├── screens/            # Full-page screens
│   ├── strategies/         # Responsive layout strategies (mobile / desktop)
│   └── widgets/            # Reusable widget components
└── main.dart               # App entry point
```

### Services

| Service | Purpose |
|---------|---------|
| `AuthService` | Registration, login, password reset, email verification |
| `UserService` | Profiles, follow / unfollow, friend requests |
| `TripService` | Trip CRUD, visibility, multi-day management |
| `TripUpdateService` | Location updates, day markers |
| `TripPlanService` | Planned trips and waypoints |
| `CommentService` | Comments, replies, and reactions |
| `AchievementService` | Achievement queries |
| `AdminService` | User admin, trip data maintenance, polyline / geocoding recomputation |
| `WebSocketService` | Real-time events (trip updates, reactions, polyline updates) |

## Getting Started

### Prerequisites

- **Flutter SDK** 3.38.5+ (stable channel)
- **Dart SDK** ^3.5.0
- A **Google Maps API key** (for map features)
- Optionally, an Android device / emulator or iOS simulator

### Install & Run

```bash
# 1. Clone the repository
git clone https://github.com/tomassirio/wanderer-frontend.git
cd wanderer-frontend

# 2. Install dependencies
flutter pub get

# 3. Run on Chrome (no API key needed for non-map screens)
flutter run -d chrome
```

### Local Development (with Maps)

#### Quick Start with Environment Files

1. **Create your environment file** from the template:

```bash
# For development
cp .env.template .env.dev
# Edit .env.dev with your values

# For production (optional)
cp .env.template .env.prod
# Edit .env.prod with your values
```

2. **Run the application**:

```bash
# Android emulator (development)
make run-android-dev

# Android emulator (production)
make run-android-prod

# Web app (development) - runs on port 51538
make run-web-dev

# Web app (production)
make run-web-prod
```

The `.env.dev` and `.env.prod` files follow this structure:

```dotenv
# Domain without protocol
DOMAIN=wanderer.localwanderer-dev.com

# Protocols for Web (use https/wss - ingress handles HTTPS)
WEB_HTTP_PROTOCOL=https
WEB_WS_PROTOCOL=wss

# Protocols for Android Emulator (use http/ws - can't handle self-signed certs)
ANDROID_HTTP_PROTOCOL=http
ANDROID_WS_PROTOCOL=ws

# Google Maps API Key
GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here

# Android Emulator Device ID (optional, defaults to emulator-5554)
ANDROID_DEVICE_ID=emulator-5554
```

**Note:** Web uses HTTPS (ingress redirects), but Android emulator uses HTTP since it can't easily handle self-signed certificates.

The Makefile automatically constructs URLs using the pattern: `{{PROTOCOL}}://{{DOMAIN}}/api/{{service}}`

> **Note:** The `dev.sh` script is now deprecated. Use `make run-web-dev` or `make run-web-prod` instead.

### Running Tests

```bash
flutter test                                      # All tests with coverage
flutter test test/models/auth_models_test.dart    # Single file
flutter test --verbose                            # Verbose output
```

### Verify Before Committing

```bash
make verify       # Runs: format → analyze → test
```

The full list of Makefile targets:

| Target | Description |
|--------|-------------|
| `make format` | Format all Dart code |
| `make analyze` | Run static analysis |
| `make test` | Run tests with coverage |
| `make verify` | Format + analyze + test |
| `make build` | Build web release |
| `make run` | Run in Chrome |
| `make run-android-dev` | Run on Android emulator (dev environment) |
| `make run-android-prod` | Run on Android emulator (prod environment) |
| `make run-web-dev` | Run web app (dev environment) |
| `make run-web-prod` | Run web app (prod environment) |
| `make clean` | Remove build artifacts |

## Building for Android

API URLs must be provided via `--dart-define` flags for mobile builds (the app defaults to relative paths, which only work behind a web reverse proxy).

```bash
flutter build apk --release \
  --dart-define=COMMAND_BASE_URL=https://your-domain/api/command \
  --dart-define=QUERY_BASE_URL=https://your-domain/api/query \
  --dart-define=AUTH_BASE_URL=https://your-domain/api/auth \
  --dart-define=WS_BASE_URL=wss://your-domain \
  --dart-define=GOOGLE_MAPS_API_KEY=your_key
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

For Google Play, use `flutter build appbundle` instead. Add `--split-per-abi` to the APK command for smaller per-architecture binaries.

## Docker

The web build is served with nginx on **port 51538**. Environment variables are injected into `index.html` at container startup.

```bash
# Build
docker build -f docker/Dockerfile -t wanderer-frontend:latest .

# Run
docker run -p 51538:51538 \
  -e GOOGLE_MAPS_API_KEY=your_key \
  wanderer-frontend:latest
```

Or with Docker Compose:

```bash
# Create a .env file with GOOGLE_MAPS_API_KEY (and optionally backend URLs)
cd docker
docker-compose up
```

See [`docker/DOCKER.md`](docker/DOCKER.md) for more details.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GOOGLE_MAPS_API_KEY` | *(required)* | Google Maps JavaScript API key |
| `COMMAND_BASE_URL` | `/api/command` | Backend command service URL |
| `QUERY_BASE_URL` | `/api/query` | Backend query service URL |
| `AUTH_BASE_URL` | `/api/auth` | Backend auth service URL |
| `WS_BASE_URL` | `/ws` | WebSocket endpoint |

## Kubernetes

A Helm chart lives in [`chart/`](chart/). See [`chart/README.md`](chart/README.md) for configuration values.

```bash
helm install wanderer-frontend ./chart \
  --namespace wanderer --create-namespace \
  --set image.tag="v1.2.12" \
  --set application.googleMapsApiKey="YOUR_KEY"
```

## CI / CD

All workflows live in `.github/workflows/`:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| **Feature Branch** (`feature-branch.yml`) | Push to non-master branch | Format, analyze, test, build Docker image, deploy to dev |
| **Merge to Master** (`merge.yml`) | Push to master | Tag release, test, build web + APK, publish Docker to GHCR, deploy to production, bump to next SNAPSHOT |
| **Docker Build** (`docker-build.yml`) | Reusable workflow | Builds and optionally pushes the Docker image |
| **Helm Deploy** (`helm-deploy.yml`) | Reusable workflow | Deploys to a Kubernetes cluster via Twingate |
| **Manual Deploy** (`manual-deploy.yml`) | Workflow dispatch / release publish | Deploy a specific image tag to dev or prod |
| **Release Notes** (`release-notes.yml`) | Reusable workflow | Generates GitHub release with artifacts |

### Deployment Flow

```
Feature branch → CI (test + dev deploy) → Merge to master → Release + prod deploy
```

## Contributing

1. Create a feature branch from `master`
2. Make your changes
3. Run `make verify` to ensure format, analysis, and tests pass
4. Open a pull request — all CI checks must be green before merge

## License

This project is part of the Wanderer application suite.
