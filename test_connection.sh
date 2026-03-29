#!/bin/bash
# Frontend-Backend Connection Test Script
# This script helps verify that frontend and backend are properly connected

echo "=========================================="
echo "Money Mentor - Connection Test"
echo "=========================================="
echo ""

# Check if backend is running
echo "[1/4] Checking backend connectivity..."
BACKEND_URL="http://localhost:8000/api/ping"

if command -v curl &> /dev/null; then
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $BACKEND_URL)
    if [ "$RESPONSE" = "200" ]; then
        echo "✅ Backend is running and responding (Status: $RESPONSE)"
    else
        echo "❌ Backend returned status: $RESPONSE"
        echo "   Make sure backend is running: python backend/main.py"
    fi
else
    echo "⚠️  curl not found, skipping backend check"
fi

echo ""

# Check Flutter
echo "[2/4] Checking Flutter installation..."
if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -n1)
    echo "✅ Flutter found: $FLUTTER_VERSION"
else
    echo "❌ Flutter not found in PATH"
    exit 1
fi

echo ""

# Check pubspec.yaml dependencies
echo "[3/4] Checking required dependencies in pubspec.yaml..."
if grep -q "http:" pubspec.yaml; then
    echo "✅ http package found"
else
    echo "❌ http package not found - run: flutter pub get"
fi

if grep -q "intl:" pubspec.yaml; then
    echo "✅ intl package found"
else
    echo "❌ intl package not found - run: flutter pub get"
fi

echo ""

# Check API configuration file
echo "[4/4] Checking API configuration..."
if [ -f "lib/config/api_config.dart" ]; then
    echo "✅ API config file found"
    
    if grep -q "static const String baseUrl" lib/config/api_config.dart; then
        CONFIGURED_URL=$(grep "static const String baseUrl" lib/config/api_config.dart | grep -oP "http[s]?://[^'\"]*")
        echo "   Configured URL: $CONFIGURED_URL"
    fi
else
    echo "❌ API config file not found"
fi

echo ""
echo "=========================================="
echo "Connection Test Summary"
echo "=========================================="
echo ""
echo "✅ All checks completed!"
echo ""
echo "Next steps:"
echo "1. Run backend: cd backend && python main.py"
echo "2. Run frontend: flutter run"
echo "3. Check the green/red connection indicator in app"
echo ""
echo "For physical device:"
echo "1. Get your IP: ipconfig (Windows) or ifconfig (Mac/Linux)"
echo "2. Update baseUrl in lib/config/api_config.dart"
echo "3. Ensure device is on same network"
echo ""
