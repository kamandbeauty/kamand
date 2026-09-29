#!/usr/bin/env bash

echo "=============================================="
echo "    LUMI ANDROID EXPORT DIAGNOSTIC & BUILD    "
echo "=============================================="

# 1. Install prerequisites in Debian/Ubuntu container
echo "=== Installing toolchain ==="
apt-get update -qq && apt-get install -y -qq zipalign apksigner aapt openjdk-17-jdk wget unzip || true

# 2. Check and setup export templates
echo "=== Setting up Export Templates ==="
mkdir -p "$HOME/.local/share/godot/export_templates/4.3.stable"
mkdir -p "/root/.local/share/godot/export_templates/4.3.stable"

if [ -f "/root/.local/share/godot/export_templates/4.3.stable/android_debug.apk" ]; then
    echo "Found existing templates in /root"
    cp -r /root/.local/share/godot/export_templates/4.3.stable/* "$HOME/.local/share/godot/export_templates/4.3.stable/" || true
else
    echo "Downloading Godot 4.3 export templates..."
    wget -q https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz -O /tmp/templates.tpz
    unzip -q /tmp/templates.tpz -d /tmp/tpz_out
    cp -r /tmp/tpz_out/templates/* "$HOME/.local/share/godot/export_templates/4.3.stable/"
    cp -r /tmp/tpz_out/templates/* "/root/.local/share/godot/export_templates/4.3.stable/"
fi

ls -la "$HOME/.local/share/godot/export_templates/4.3.stable/"

# 3. Setup Android SDK structure
echo "=== Setting up Android SDK ==="
SDK_DIR="/opt/android-sdk"
mkdir -p "$SDK_DIR/platform-tools"
mkdir -p "$SDK_DIR/build-tools/34.0.0"

# Link tools
ln -sf "$(command -v adb || echo /usr/bin/adb)" "$SDK_DIR/platform-tools/adb"
ln -sf "$(command -v aapt || echo /usr/bin/aapt)" "$SDK_DIR/build-tools/34.0.0/aapt"
ln -sf "$(command -v zipalign || echo /usr/bin/zipalign)" "$SDK_DIR/build-tools/34.0.0/zipalign"
ln -sf "$(command -v apksigner || echo /usr/bin/apksigner)" "$SDK_DIR/build-tools/34.0.0/apksigner"

echo "SDK Directory contents:"
ls -la "$SDK_DIR"
ls -la "$SDK_DIR/build-tools/34.0.0"

# 4. Generate Debug Keystore
echo "=== Generating Debug Keystore ==="
KEYSTORE_PATH="/opt/debug.keystore"
rm -f "$KEYSTORE_PATH"
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore "$KEYSTORE_PATH" -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
ls -la "$KEYSTORE_PATH"

# 5. Write Editor Settings
echo "=== Writing Editor Settings ==="
for cfg in "$HOME/.config/godot" "/root/.config/godot"; do
    mkdir -p "$cfg"
    cat > "$cfg/editor_settings-4.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "${SDK_DIR}"
export/android/debug_keystore = "${KEYSTORE_PATH}"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
export/android/force_system_user = false
EOF
    cat "$cfg/editor_settings-4.tres"
done

# 6. Execute Godot Export
echo "=== Exporting Android APK ==="
mkdir -p builds/android
godot -v --headless --export-debug "Android" builds/android/lumi-bubblewood.apk

if [ -f "builds/android/lumi-bubblewood.apk" ]; then
    echo "=========================================================="
    echo "🎉 SUCCESS: builds/android/lumi-bubblewood.apk generated!"
    ls -lh builds/android/lumi-bubblewood.apk
    echo "=========================================================="
    exit 0
else
    echo "❌ ERROR: Export failed to generate APK."
    exit 1
fi
