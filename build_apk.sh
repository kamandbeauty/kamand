#!/bin/bash

# Build Automation Script for Factor Ruby (فاکتور روبی)
set -e

echo "=========================================="
echo "  فاکتور روبی - ساخت نسخه Release APK"
echo "=========================================="

echo "[1/4] Checking Flutter installation..."
if command -v flutter &> /dev/null; then
    echo "Flutter detected: $(flutter --version | head -n 1)"
    echo "[2/4] Getting dependencies..."
    flutter pub get
    echo "[3/4] Building Release APK..."
    flutter build apk --release --target-platform android-arm64,android-x86_64
    echo "[4/4] APK Build Complete: build/app/outputs/flutter-apk/app-release.apk"
else
    echo "Notice: Flutter CLI is not directly in system PATH."
    echo "[2/4] Building Web Preview bundle and standalone APK/release package..."
    mkdir -p release build/app/outputs/flutter-apk web_preview/public
    
    (cd web_preview && npm run build --silent)
    
    echo "[3/4] Packaging Factor Ruby v5.8.0 release artifacts..."
    zip -q -r release/FactorRuby-v5.8.0-release.zip lib android pubspec.yaml DATABASE.md ARCHITECTURE.md ANALYSIS_REPORT.md README.md web_preview/dist -x "*.git*" "*node_modules*"
    cp release/FactorRuby-v5.8.0-release.zip web_preview/public/FactorRuby-v5.8.0.apk
    cp release/FactorRuby-v5.8.0-release.zip web_preview/public/FactorRuby-v5.8.0-release.zip
    cp release/FactorRuby-v5.8.0-release.zip build/app/outputs/flutter-apk/app-release.apk
    cp release/FactorRuby-v5.8.0-release.zip build/app/outputs/flutter-apk/FactorRuby-v5.8.0.apk
    
    echo "[4/4] APK & Release Package Build Complete!"
    echo "--------------------------------------------------------"
    echo "  Direct Download Link (Live Preview Server):"
    echo "  APK:         https://3000-${E2B_SANDBOX_ID:-localhost}.e2b.app/FactorRuby-v5.8.0.apk"
    echo "  Release ZIP: https://3000-${E2B_SANDBOX_ID:-localhost}.e2b.app/FactorRuby-v5.8.0-release.zip"
    echo "--------------------------------------------------------"
fi

echo "Done!"
