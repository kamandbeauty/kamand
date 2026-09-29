#!/usr/bin/env bash
set -e

echo "=============================================="
echo "    LUMI ANDROID EXPORT ENVIRONMENT SETUP     "
echo "=============================================="

echo "Current user: $(whoami), HOME=$HOME"

echo "=== 1. Discovering Export Templates ==="
TEMPLATE_APKS=$(find / -name "android_debug.apk" 2>/dev/null || true)
echo "Found android_debug.apk at: $TEMPLATE_APKS"

TEMPLATE_DIR=""
for apk in $TEMPLATE_APKS; do
    DIR=$(dirname "$apk")
    if [ -f "$DIR/android_debug.apk" ]; then
        TEMPLATE_DIR="$DIR"
        break
    fi
done

if [ -n "$TEMPLATE_DIR" ]; then
    echo "Source template directory: $TEMPLATE_DIR"
    for target in "$HOME/.local/share/godot/export_templates/4.3.stable" \
                  "$HOME/.local/share/godot/templates/4.3.stable" \
                  "/root/.local/share/godot/export_templates/4.3.stable" \
                  "/root/.local/share/godot/templates/4.3.stable"; do
        mkdir -p "$target"
        cp -r "$TEMPLATE_DIR"/* "$target/" || true
        echo "Populated template directory: $target"
    done
else
    echo "Warning: android_debug.apk not found in image, downloading official Godot 4.3 templates..."
    wget -q https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz -O /tmp/templates.tpz
    unzip -q /tmp/templates.tpz -d /tmp/tpz_out
    for target in "$HOME/.local/share/godot/export_templates/4.3.stable" \
                  "$HOME/.local/share/godot/templates/4.3.stable" \
                  "/root/.local/share/godot/export_templates/4.3.stable" \
                  "/root/.local/share/godot/templates/4.3.stable"; do
        mkdir -p "$target"
        cp -r /tmp/tpz_out/templates/* "$target/" || true
        echo "Downloaded and populated template directory: $target"
    done
fi

echo "=== 2. Discovering Android SDK & Build Tools ==="
ADB_PATHS=$(find / -name "adb" 2>/dev/null || true)
echo "Found adb at: $ADB_PATHS"

SDK_PATH=""
for adb in $ADB_PATHS; do
    CANDIDATE=$(dirname "$(dirname "$adb")")
    if [ -d "$CANDIDATE/platform-tools" ]; then
        SDK_PATH="$CANDIDATE"
        break
    fi
done

if [ -z "$SDK_PATH" ]; then
    SDK_PATH="${ANDROID_HOME:-/usr/lib/android-sdk}"
fi
echo "Selected SDK_PATH: $SDK_PATH"

echo "=== 3. Keystore Generation ==="
mkdir -p "$HOME/.android"
KEYSTORE_PATH="$HOME/.android/debug.keystore"
rm -f "$KEYSTORE_PATH" "./debug.keystore"
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore "$KEYSTORE_PATH" -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
cp "$KEYSTORE_PATH" "./debug.keystore"
echo "Generated keystore at: $KEYSTORE_PATH and ./debug.keystore"

echo "=== 4. Editor Settings Config ==="
for cfg in "$HOME/.config/godot" "/root/.config/godot"; do
    mkdir -p "$cfg"
    cat > "$cfg/editor_settings-4.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "${SDK_PATH}"
export/android/debug_keystore = "${KEYSTORE_PATH}"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
export/android/force_system_user = false
EOF
    echo "Wrote settings to $cfg/editor_settings-4.tres"
done

echo "=== 5. Running Export ==="
mkdir -p builds/android
godot -v --headless --export-debug "Android" builds/android/lumi-bubblewood.apk

echo "=== 6. Validating APK Output ==="
if [ -f "builds/android/lumi-bubblewood.apk" ]; then
    echo "SUCCESS: APK exported successfully!"
    ls -lh builds/android/lumi-bubblewood.apk
else
    echo "ERROR: builds/android/lumi-bubblewood.apk was not created!"
    exit 1
fi
