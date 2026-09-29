#!/usr/bin/env bash
set -e

echo "=== 1. Copying Export Templates ==="
mkdir -p "$HOME/.local/share/godot/export_templates"
mkdir -p "$HOME/.local/share/godot/templates"
if [ -d "/root/.local/share/godot/export_templates" ]; then
    cp -r /root/.local/share/godot/export_templates/* "$HOME/.local/share/godot/export_templates/" || true
    cp -r /root/.local/share/godot/export_templates/* "$HOME/.local/share/godot/templates/" || true
fi
ls -la "$HOME/.local/share/godot/export_templates/" || true

echo "=== 2. Locating Android SDK ==="
SDK_PATH="${ANDROID_HOME:-${ANDROID_SDK_ROOT}}"
if [ -z "$SDK_PATH" ] || [ ! -d "$SDK_PATH" ]; then
    for p in /usr/lib/android-sdk /opt/android-sdk /root/android-sdk /usr/local/lib/android/sdk; do
        if [ -d "$p" ]; then
            SDK_PATH="$p"
            break
        fi
    done
fi
echo "Using Android SDK: ${SDK_PATH}"
ls -la "${SDK_PATH}" || true

echo "=== 3. Generating Debug Keystore ==="
mkdir -p "$HOME/.android"
rm -f "$HOME/.android/debug.keystore" "./debug.keystore"
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore "$HOME/.android/debug.keystore" -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
cp "$HOME/.android/debug.keystore" "./debug.keystore"

echo "=== 4. Writing Editor Settings ==="
for cfg_dir in "$HOME/.config/godot" "/root/.config/godot"; do
    mkdir -p "$cfg_dir"
    cat > "$cfg_dir/editor_settings-4.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "${SDK_PATH}"
export/android/debug_keystore = "${HOME}/.android/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
export/android/force_system_user = false
EOF
done

echo "=== 5. Running Godot Android Export ==="
mkdir -p builds/android
godot -v --headless --export-debug "Android" builds/android/lumi-bubblewood.apk
ls -lh builds/android/
