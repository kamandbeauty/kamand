#!/usr/bin/env bash

echo "=============================================="
echo "    LUMI ANDROID EXPORT DIAGNOSTIC & BUILD    "
echo "=============================================="

# 1. Install Android SDK command line tools if not present
if ! command -v apksigner &> /dev/null || ! command -v zipalign &> /dev/null; then
    echo "Installing zipalign and apksigner..."
    apt-get update -qq && apt-get install -y -qq zipalign apksigner aapt android-sdk-build-tools || true
fi

# 2. Setup export templates in all expected paths
mkdir -p "$HOME/.local/share/godot/export_templates/4.3.stable"
mkdir -p "$HOME/.local/share/godot/templates/4.3.stable"

if [ -d "/root/.local/share/godot/export_templates" ]; then
    cp -r /root/.local/share/godot/export_templates/* "$HOME/.local/share/godot/export_templates/" || true
    cp -r /root/.local/share/godot/export_templates/* "$HOME/.local/share/godot/templates/" || true
fi

echo "Export templates directory contents:"
ls -la "$HOME/.local/share/godot/export_templates/4.3.stable/" || true

# 3. Setup debug keystore
mkdir -p /root/.android "$HOME/.android"
rm -f /root/.android/debug.keystore "$HOME/.android/debug.keystore"
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore /root/.android/debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
cp /root/.android/debug.keystore "$HOME/.android/debug.keystore"
echo "Keystore created at: $HOME/.android/debug.keystore"

# 4. Locate Android SDK
SDK_PATH="${ANDROID_HOME:-/usr/lib/android-sdk}"
if [ ! -d "$SDK_PATH" ]; then
    for p in /usr/lib/android-sdk /opt/android-sdk /root/android-sdk /usr/local/lib/android/sdk; do
        if [ -d "$p" ]; then
            SDK_PATH="$p"
            break
        fi
    done
fi
echo "Using Android SDK at: $SDK_PATH"
ls -la "$SDK_PATH" || true

# Ensure build-tools directory exists in SDK
if [ ! -d "$SDK_PATH/build-tools/34.0.0" ] && [ -d "$SDK_PATH/build-tools" ]; then
    mkdir -p "$SDK_PATH/build-tools/34.0.0"
    for tool in aapt zipalign apksigner; do
        TOOL_PATH=$(command -v "$tool" || true)
        if [ -n "$TOOL_PATH" ]; then
            ln -sf "$TOOL_PATH" "$SDK_PATH/build-tools/34.0.0/$tool" || true
        fi
    done
fi

# 5. Configure editor_settings-4.tres
for cfg in "$HOME/.config/godot" "/root/.config/godot"; do
    mkdir -p "$cfg"
    cat > "$cfg/editor_settings-4.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "${SDK_PATH}"
export/android/debug_keystore = "${HOME}/.android/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
export/android/force_system_user = false
EOF
    echo "Saved $cfg/editor_settings-4.tres"
done

# 6. Export APK with full stdout/stderr capture
mkdir -p builds/android
echo "Executing Godot headless export..."
godot -v --headless --export-debug "Android" builds/android/lumi-bubblewood.apk 2>&1 | tee /tmp/godot_export.log
EXPORT_EXIT=${PIPESTATUS[0]}

echo "Godot export exit code: $EXPORT_EXIT"

if [ $EXPORT_EXIT -ne 0 ]; then
    echo "==================== GODOT EXPORT FAILURE LOG ===================="
    cat /tmp/godot_export.log
    echo "=================================================================="
    exit $EXPORT_EXIT
fi

if [ -f "builds/android/lumi-bubblewood.apk" ]; then
    echo "=============================================="
    echo "SUCCESS: builds/android/lumi-bubblewood.apk created!"
    ls -lh builds/android/lumi-bubblewood.apk
    echo "=============================================="
    exit 0
else
    echo "ERROR: builds/android/lumi-bubblewood.apk was not generated."
    exit 1
fi
