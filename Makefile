SHELL := /bin/bash
.PHONY: help format analyze test verify clean build run docker clean-verify test-watch
.PHONY: help format analyze test verify clean build run docker clean-verify test-watch run-android-dev run-android-prod run-web-dev run-web-prod

# Load environment variables from .env.dev by default
-include .env.dev
export

# Default target
help:
	@echo "Available commands:"
	@echo "  make verify       - Run format, analyze, and test (like mvn verify)"
	@echo "  make format       - Format all Dart code"
	@echo "  make analyze      - Run static analysis"
	@echo "  make test         - Run all tests"
	@echo "  make test-watch   - Run tests continuously (re-run on file changes)"
	@echo "  make clean        - Clean build artifacts"
	@echo "  make build        - Build the web application"
	@echo "  make run          - Run the application in Chrome"
	@echo "  make docker       - Build Docker image"
	@echo "  make clean-verify - Clean and verify"
	@echo "  make verify          - Run format, analyze, and test (like mvn verify)"
	@echo "  make format          - Format all Dart code"
	@echo "  make analyze         - Run static analysis"
	@echo "  make test            - Run all tests"
	@echo "  make test-watch      - Run tests continuously (re-run on file changes)"
	@echo "  make clean           - Clean build artifacts"
	@echo "  make build           - Build the web application"
	@echo "  make run             - Run the application in Chrome"
	@echo "  make run-android-dev - Run on Android emulator with dev environment"
	@echo "  make run-android-prod- Run on Android emulator with prod environment"
	@echo "  make docker          - Build Docker image"
	@echo "  make clean-verify    - Clean and verify"
# Main verification command (equivalent to mvn spotless:apply clean verify)
verify: format analyze test
	@echo "✅ All checks passed!"

# Format all Dart code
format:
	@echo "🎨 Formatting Dart code..."
	@dart format .

# Run static analysis
analyze:
	@echo "🔍 Running static analysis..."
	@flutter analyze

# Run all tests with coverage
test:
	@echo "🧪 Running tests..."
	@flutter test --coverage 2>&1 | tee /tmp/flutter_test_output.log; \
	TEST_EXIT=$${PIPESTATUS[0]}; \
	if [ $$TEST_EXIT -ne 0 ]; then \
		echo ""; \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		echo "❌ FAILED TESTS SUMMARY"; \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		FAILED=$$(grep -c '\[E\]' /tmp/flutter_test_output.log 2>/dev/null || echo 0); \
		echo ""; \
		echo "$$FAILED test(s) failed:"; \
		echo ""; \
		grep '\[E\]' /tmp/flutter_test_output.log | sed 's/^[0-9:.]*[[:space:]]*+[0-9]* -[0-9]*: //' | sed 's/ \[E\]$$//' | awk '{print "  " NR ") " $$0}' || true; \
		echo ""; \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		echo "🔁 Re-run commands:"; \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		grep -E '^\s*(flutter test|.*dart-sdk.*dart test)' /tmp/flutter_test_output.log | sed 's/^[[:space:]]*//' || true; \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		exit 1; \
	fi

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@flutter clean
	@rm -rf build/
	@rm -rf .dart_tool/

# Build web application
build:
	@echo "🏗️  Building web application..."
	@flutter build web --release

# Run application in Chrome
run:
	@echo "🚀 Running application..."
	@flutter run -d chrome

# Build Docker image
docker:
	@echo "🐳 Building Docker image..."
	@docker build -f docker/Dockerfile -t wanderer-frontend:latest .

# Full clean + verify
clean-verify: clean verify

# Run tests continuously (re-run on file changes)
test-watch:
	@while true; do \
		clear; \
		echo "🧪 Running tests... ($$(date '+%H:%M:%S'))"; \
		flutter test --coverage || true; \
		echo "\n⏸️  Waiting for changes (press Ctrl+C to stop)..."; \
		sleep 3; \
	done

# Run on Android emulator with development environment
run-android-dev:
	@echo "🤖 Running on Android emulator (development)..."
	@if [ ! -f .env.dev ]; then \
		echo "❌ Error: .env.dev file not found!"; \
		echo "Please create .env.dev from .env.template"; \
		exit 1; \
	fi
	@source .env.dev && \
	DEVICE_ID=$${ANDROID_DEVICE_ID:-emulator-5554} && \
	API_PATH=$${API_PATH:-/api/1} && \
	flutter run -d $$DEVICE_ID \
		--dart-define=COMMAND_BASE_URL=$${ANDROID_HTTP_PROTOCOL}://$${DOMAIN}$${API_PATH}/command \
		--dart-define=QUERY_BASE_URL=$${ANDROID_HTTP_PROTOCOL}://$${DOMAIN}$${API_PATH}/query \
		--dart-define=AUTH_BASE_URL=$${ANDROID_HTTP_PROTOCOL}://$${DOMAIN}$${API_PATH}/auth \
		--dart-define=WS_BASE_URL=$${ANDROID_WS_PROTOCOL}://$${DOMAIN} \
		--dart-define=APP_BASE_URL=$${ANDROID_HTTP_PROTOCOL}://$${DOMAIN} \
		--dart-define=GOOGLE_MAPS_API_KEY=$${GOOGLE_MAPS_API_KEY}

# Run web application with development environment
run-web-dev:
	@echo "🌐 Running web application (development)..."
	@if [ ! -f .env.dev ]; then \
		echo "❌ Error: .env.dev file not found!"; \
		echo "Please create .env.dev from .env.template"; \
		exit 1; \
	fi
	@source .env.dev && \
	if [ ! -f web/index.html.template ]; then \
		cp web/index.html web/index.html.template; \
	fi && \
	cp web/index.html.template web/index.html && \
	API_PATH=$${API_PATH:-/api/1} && \
	COMMAND_URL="$${WEB_HTTP_PROTOCOL}://$${DOMAIN}$${API_PATH}/command" && \
	QUERY_URL="$${WEB_HTTP_PROTOCOL}://$${DOMAIN}$${API_PATH}/query" && \
	AUTH_URL="$${WEB_HTTP_PROTOCOL}://$${DOMAIN}$${API_PATH}/auth" && \
	WS_URL="$${WEB_WS_PROTOCOL}://$${DOMAIN}" && \
	echo "Injecting environment variables into web/index.html..." && \
	sed -i.bak "s|{{GOOGLE_MAPS_API_KEY}}|$${GOOGLE_MAPS_API_KEY}|g" web/index.html && \
	sed -i.bak "s|{{COMMAND_BASE_URL}}|$${COMMAND_URL}|g" web/index.html && \
	sed -i.bak "s|{{QUERY_BASE_URL}}|$${QUERY_URL}|g" web/index.html && \
	sed -i.bak "s|{{AUTH_BASE_URL}}|$${AUTH_URL}|g" web/index.html && \
	sed -i.bak "s|{{WS_BASE_URL}}|$${WS_URL}|g" web/index.html && \
	rm -f web/index.html.bak && \
	echo "Environment variables injected successfully!" && \
	echo "  Google Maps API Key: $${GOOGLE_MAPS_API_KEY:0:20}..." && \
	echo "  Command URL: $${COMMAND_URL}" && \
	echo "  Query URL: $${QUERY_URL}" && \
	echo "  Auth URL: $${AUTH_URL}" && \
	echo "  WebSocket URL: $${WS_URL}" && \
	echo "" && \
	echo "Starting Flutter application on http://localhost:51538..." && \
	trap 'if [ -f web/index.html.template ]; then echo ""; echo "Restoring original web/index.html..."; cp web/index.html.template web/index.html; fi' EXIT INT TERM && \
	flutter run -d web-server --web-port=51538 --web-hostname=0.0.0.0
