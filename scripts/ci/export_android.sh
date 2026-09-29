#!/usr/bin/env bash
set -e

echo "=============================================="
echo "    LUMI ANDROID EXPORT (barichello/godot-ci) "
echo "=============================================="

# 1. Setup export templates in all expected paths
mkdir -p "$HOME/.local/share/godot/export_templates"
mkdir -p "$HOME/.local/share/godot/templates"

if [ -d "/root/.local/share/godot/export_templates" ]; then
    cp -r /root/.local/share/godot/export_templates/* "$HOME/.local/share/godot/export_templates/" || true
    cp -r /root/.local/share/godot/export_templates/* "$HOME/.local/share/godot/templates/" || true
fi

# Ensure 4.3.stable folder name
if [ -d "$HOME/.local/share/godot/export_templates/4.3.stable" ]; then
    echo "Found 4.3.stable export templates:"
    ls -la "$HOME/.local/share/godot/export_templates/4.3.stable/"
fi

# 2. Setup debug keystore
mkdir -p /root/.android "$HOME/.android"
rm -f /root/.android/debug.keystore "$HOME/.android/debug.keystore"
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore /root/.android/debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
cp /root/.android/debug.keystore "$HOME/.android/debug.keystore"

# 3. Configure editor_settings-4.tres
SDK_PATH="${ANDROID_HOME:-/usr/lib/android-sdk}"
if [ ! -d "$SDK_PATH" ]; then
    for p in /usr/lib/android-sdk /opt/android-sdk /root/android-sdk /usr/local/lib/android/sdk; do
        if [ -d "$p" ]; then
            SDK_PATH="$p"
            break
        fi
    done
fi
echo "Using Android SDK: $SDK_PATH"

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
done

# 4. Export APK
mkdir -p builds/android
godot -v --headless --export-debug "Android" builds/android/lumi-bubblewood.apk

# 5. Verify output
if [ -f "builds/android/lumi-bubblewood.apk" ]; then
    echo "=============================================="
    echo "SUCCESS: builds/android/lumi-bubblewood.apk created!"
    ls -lh builds/android/lumi-bubblewood.apk
    echo "=============================================="
else
    echo "ERROR: Export failed, builds/android/lumi-bubblewood.apk missing!"
    exit 1
fi
