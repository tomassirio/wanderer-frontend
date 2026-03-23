#!/bin/bash
set -e

# Load environment variables from .env.local if it exists
if [ ! -f .env ]; then
    echo "Error: .env file not found!"
    echo ""
    echo "Please create .env with your API key:"
    echo "  GOOGLE_MAPS_API_KEY=your_actual_api_key_here"
    echo ""
    echo "You can copy .env.example:"
    echo "  cp .env.example .env"
    exit 1
fi

# Source the env file
source .env

# Backup original index.html if not already backed up
if [ ! -f web/index.html.template ]; then
    cp web/index.html web/index.html.template
fi

# Restore from template
cp web/index.html.template web/index.html

# Replace placeholders with actual values
echo "Injecting environment variables into web/index.html..."

# Replace Google Maps API key
sed -i.bak "s|{{GOOGLE_MAPS_API_KEY}}|${GOOGLE_MAPS_API_KEY}|g" web/index.html

# Replace backend URLs (or use defaults if not set)
COMMAND_URL="${COMMAND_BASE_URL:-http://localhost:8081/api/1}"
QUERY_URL="${QUERY_BASE_URL:-http://localhost:8082/api/1}"
AUTH_URL="${AUTH_BASE_URL:-http://localhost:8083/api/1/auth}"
WS_URL="${WS_BASE_URL:-ws://localhost:8080}"

sed -i.bak "s|{{COMMAND_BASE_URL}}|${COMMAND_URL}|g" web/index.html
sed -i.bak "s|{{QUERY_BASE_URL}}|${QUERY_URL}|g" web/index.html
sed -i.bak "s|{{AUTH_BASE_URL}}|${AUTH_URL}|g" web/index.html
sed -i.bak "s|{{WS_BASE_URL}}|${WS_URL}|g" web/index.html

# Remove backup file
rm -f web/index.html.bak

echo "Environment variables injected successfully!"
echo "  Google Maps API Key: ${GOOGLE_MAPS_API_KEY:0:20}..."
echo "  Command URL: ${COMMAND_URL}"
echo "  Query URL: ${QUERY_URL}"
echo "  Auth URL: ${AUTH_URL}"
echo "  WebSocket URL: ${WS_URL}"
echo ""

# Function to restore template on exit
cleanup() {
    if [ -f web/index.html.template ]; then
        echo ""
        echo "Restoring original web/index.html..."
        cp web/index.html.template web/index.html
    fi
}

# Set trap to restore on script exit
trap cleanup EXIT INT TERM

# Run Flutter on port 51538
echo "Starting Flutter application on http://localhost:51538..."
flutter run -d web-server --web-port=51538 --web-hostname=0.0.0.0 "$@"
