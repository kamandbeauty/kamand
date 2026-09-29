#!/usr/bin/env bash
set -e

echo "=============================================="
echo "    LUMI ANDROID EXPORT (GRADLE BUILD METHOD) "
echo "=============================================="

# 1. Setup SDK path and environment
SDK_PATH="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
echo "Android SDK path: $SDK_PATH"
export ANDROID_HOME="$SDK_PATH"
export ANDROID_SDK_ROOT="$SDK_PATH"

# 2. Setup Godot 4.3 Linux binary
if ! command -v godot &> /dev/null; then
    echo "Downloading Godot 4.3 headless binary..."
    wget -q https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip -O /tmp/godot.zip
    unzip -q /tmp/godot.zip -d /tmp/godot_bin
    sudo mv /tmp/godot_bin/Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot || mv /tmp/godot_bin/Godot_v4.3-stable_linux.x86_64 /usr/bin/godot
    chmod +x /usr/local/bin/godot 2>/dev/null || chmod +x /usr/bin/godot
fi
godot --version

# 3. Setup Export Templates
echo "Setting up Godot 4.3 export templates..."
mkdir -p "$HOME/.local/share/godot/export_templates/4.3.stable"
mkdir -p "$HOME/.local/share/godot/templates/4.3.stable"

if [ ! -f "$HOME/.local/share/godot/export_templates/4.3.stable/android_source.zip" ]; then
    wget -q https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz -O /tmp/templates.tpz
    unzip -q /tmp/templates.tpz -d /tmp/tpz_out
    cp -r /tmp/tpz_out/templates/* "$HOME/.local/share/godot/export_templates/4.3.stable/"
    cp -r /tmp/tpz_out/templates/* "$HOME/.local/share/godot/templates/4.3.stable/"
fi
ls -la "$HOME/.local/share/godot/export_templates/4.3.stable/"

# 4. Generate Debug Keystore
echo "Generating debug keystore..."
mkdir -p "$HOME/.android"
KEYSTORE_PATH="$HOME/.android/debug.keystore"
rm -f "$KEYSTORE_PATH"
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore "$KEYSTORE_PATH" -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
ls -la "$KEYSTORE_PATH"

# 5. Configure Editor Settings
echo "Configuring Editor Settings..."
mkdir -p "$HOME/.config/godot"
cat > "$HOME/.config/godot/editor_settings-4.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "${SDK_PATH}"
export/android/debug_keystore = "${KEYSTORE_PATH}"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
export/android/force_system_user = false
EOF

# 6. Install Android Build Template
echo "Installing Android build templates into project..."
godot --headless -v --install-android-build-template || true

# 7. Run Godot Export
echo "Exporting Android APK..."
mkdir -p builds/android
godot -v --headless --export-debug "Android" builds/android/lumi-bubblewood.apk

# 8. Validate Output
if [ -f "builds/android/lumi-bubblewood.apk" ]; then
    echo "=========================================================="
    echo "🎉 SUCCESS: builds/android/lumi-bubblewood.apk generated!"
    ls -lh builds/android/lumi-bubblewood.apk
    echo "=========================================================="
else
    # Check if Gradle output is in android/build/build/outputs/apk/debug/
    GRADLE_APK=$(find android/ -name "*.apk" 2>/dev/null | head -n 1 || true)
    if [ -n "$GRADLE_APK" ] && [ -f "$GRADLE_APK" ]; then
        echo "Found APK at $GRADLE_APK, copying to builds/android/lumi-bubblewood.apk..."
        cp "$GRADLE_APK" builds/android/lumi-bubblewood.apk
        ls -lh builds/android/lumi-bubblewood.apk
    else
        echo "❌ ERROR: Export failed to generate APK."
        exit 1
    fi
fi
