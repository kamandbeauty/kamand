#!/usr/bin/env bash
set -e

echo "=============================================="
echo "    LUMI PRODUCTION CI/CD ANDROID ENGINE      "
echo "=============================================="

# 1. Install prerequisites (apktool, zipalign, apksigner, aapt)
echo "=== Installing packaging toolchain ==="
sudo apt-get update -qq && sudo apt-get install -y -qq apktool zipalign apksigner aapt || true

# 2. Setup SDK path
SDK_PATH="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
export ANDROID_HOME="$SDK_PATH"
export ANDROID_SDK_ROOT="$SDK_PATH"

# 3. Setup Godot 4.3 Linux binary
if ! command -v godot &> /dev/null; then
    echo "Downloading Godot 4.3 binary..."
    wget -q https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip -O /tmp/godot.zip
    unzip -q /tmp/godot.zip -d /tmp/godot_bin
    sudo mv /tmp/godot_bin/Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot || mv /tmp/godot_bin/Godot_v4.3-stable_linux.x86_64 /usr/bin/godot
    chmod +x /usr/local/bin/godot 2>/dev/null || chmod +x /usr/bin/godot
fi
godot --version

# 4. Setup Export Templates
echo "Setting up Godot 4.3 export templates..."
mkdir -p "$HOME/.local/share/godot/export_templates/4.3.stable"
mkdir -p "$HOME/.local/share/godot/templates/4.3.stable"

if [ ! -f "$HOME/.local/share/godot/export_templates/4.3.stable/android_debug.apk" ]; then
    wget -q https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz -O /tmp/templates.tpz
    unzip -q /tmp/templates.tpz -d /tmp/tpz_out
    cp -r /tmp/tpz_out/templates/* "$HOME/.local/share/godot/export_templates/4.3.stable/"
    cp -r /tmp/tpz_out/templates/* "$HOME/.local/share/godot/templates/4.3.stable/"
fi

# 5. Generate Debug Keystore
echo "Generating debug keystore..."
mkdir -p "$HOME/.android"
KEYSTORE_PATH="$HOME/.android/debug.keystore"
rm -f "$KEYSTORE_PATH"
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore "$KEYSTORE_PATH" -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12

# 6. Configure Editor Settings
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

# 7. Execute Production Packaging
python3 scripts/ci/build_apk.py

# 8. Final check
if [ -f "builds/android/lumi-bubblewood.apk" ]; then
    echo "=========================================================="
    echo "🎉 VERIFIED PRODUCTION APK: builds/android/lumi-bubblewood.apk"
    ls -lh builds/android/lumi-bubblewood.apk
    echo "=========================================================="
    exit 0
else
    echo "❌ ERROR: Export failed."
    exit 1
fi
