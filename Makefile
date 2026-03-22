SHELL := /bin/bash
.PHONY: help format analyze test verify clean build run docker clean-verify test-watch

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
