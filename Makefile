SHELL := /bin/bash
.DEFAULT_GOAL := help

# Configuration
TARGET_ENV ?= dev
ENV_FILE = .env.$(TARGET_ENV)

# Helper to check for .env file
define check_env
	@if [ ! -f $(1) ]; then \
		echo "❌ Error: $(1) not found!"; \
		exit 1; \
	fi
endef

.PHONY: help verify format analyze test clean build run docker clean-verify test-watch run-android run-web run-android-dev run-android-prod run-web-dev run-web-prod

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

verify: format analyze test ## Run format, analyze, and test

format: ## Format Dart code
	@echo "🎨 Formatting Dart code..."
	@dart format .

analyze: ## Run static analysis
	@echo "🔍 Running static analysis..."
	@flutter analyze

test: ## Run all tests with coverage
	@echo "🧪 Running tests..."
	@set -o pipefail; flutter test --coverage 2>&1 | tee /tmp/flutter_test_output.log || ( \
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
		exit 1 \
	)

clean: ## Clean build artifacts
	@echo "🧹 Cleaning build artifacts..."
	@flutter clean

build: ## Build the web application
	@echo "🏗️  Building web application..."
	@flutter build web --release

run: ## Run the application in Chrome
	@echo "🚀 Running application..."
	@flutter run -d chrome

docker: ## Build Docker image
	@echo "🐳 Building Docker image..."
	@docker build -f docker/Dockerfile -t wanderer-frontend:latest .

clean-verify: clean verify ## Clean and verify

test-watch: ## Run tests continuously (re-run on file changes)
	@echo "Watching for changes... (Press Ctrl+C to stop)"
	@while true; do \
		clear; \
		echo "🧪 Running tests... ($$(date '+%H:%M:%S'))"; \
		flutter test --coverage || true; \
		echo -e "\n⏸️  Waiting for changes (press Ctrl+C to stop)..."; \
		sleep 3; \
	done

run-android: ## Run on Android (usage: make run-android TARGET_ENV=dev)
	$(call check_env,$(ENV_FILE))
	@echo "🤖 Running on Android ($(TARGET_ENV))..."
	@source $(ENV_FILE) && \
	DEVICE_ID=$${ANDROID_DEVICE_ID:-emulator-5554} && \
	API_PATH=$${API_PATH:-/api/1} && \
	flutter run -d $$DEVICE_ID \
		--dart-define=COMMAND_BASE_URL=$${ANDROID_HTTP_PROTOCOL}://$${DOMAIN}$${API_PATH}/command \
		--dart-define=QUERY_BASE_URL=$${ANDROID_HTTP_PROTOCOL}://$${DOMAIN}$${API_PATH}/query \
		--dart-define=AUTH_BASE_URL=$${ANDROID_HTTP_PROTOCOL}://$${DOMAIN}$${API_PATH}/auth \
		--dart-define=WS_BASE_URL=$${ANDROID_WS_PROTOCOL}://$${DOMAIN} \
		--dart-define=APP_BASE_URL=$${ANDROID_HTTP_PROTOCOL}://$${DOMAIN} \
		--dart-define=GOOGLE_MAPS_API_KEY=$${GOOGLE_MAPS_API_KEY}

run-web: ## Run on Web (usage: make run-web TARGET_ENV=dev)
	$(call check_env,$(ENV_FILE))
	@echo "🌐 Running web application ($(TARGET_ENV))..."
	@source $(ENV_FILE) && \
	if [ ! -f web/index.html.template ]; then \
		cp web/index.html web/index.html.template; \
	fi && \
	cp web/index.html.template web/index.html && \
	API_PATH=$${API_PATH:-/api/1} && \
	COMMAND_URL="$${WEB_HTTP_PROTOCOL}://$${DOMAIN}$${API_PATH}/command" && \
	QUERY_URL="$${WEB_HTTP_PROTOCOL}://$${DOMAIN}$${API_PATH}/query" && \
	AUTH_URL="$${WEB_HTTP_PROTOCOL}://$${DOMAIN}$${API_PATH}/auth" && \
	APP_BASE_URL="$${WEB_HTTP_PROTOCOL}://$${DOMAIN}" && \
	WS_URL="$${WEB_WS_PROTOCOL}://$${DOMAIN}" && \
	sed -i.bak "s|{{GOOGLE_MAPS_API_KEY}}|$${GOOGLE_MAPS_API_KEY}|g" web/index.html && \
	sed -i.bak "s|{{COMMAND_BASE_URL}}|$${COMMAND_URL}|g" web/index.html && \
	sed -i.bak "s|{{QUERY_BASE_URL}}|$${QUERY_URL}|g" web/index.html && \
	sed -i.bak "s|{{AUTH_BASE_URL}}|$${AUTH_URL}|g" web/index.html && \
	sed -i.bak "s|{{WS_BASE_URL}}|$${WS_URL}|g" web/index.html && \
	rm -f web/index.html.bak && \
	trap 'cp web/index.html.template web/index.html' EXIT INT TERM && \
	flutter run -d web-server --web-port=51538 --web-hostname=0.0.0.0

# Shortcuts
run-android-dev: ## Run android dev environment
	@$(MAKE) run-android TARGET_ENV=dev

run-android-prod: ## Run android prod environment
	@$(MAKE) run-android TARGET_ENV=prod

run-web-dev: ## Run web dev environment
	@$(MAKE) run-web TARGET_ENV=dev

run-web-prod: ## Run web prod environment
	@$(MAKE) run-web TARGET_ENV=prod
