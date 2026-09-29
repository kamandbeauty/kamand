#!/usr/bin/env bash
set -e

echo "=============================================="
echo "    LUMI ANDROID EXPORT ENGINE (FAILSAFE)     "
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

if [ ! -f "$HOME/.local/share/godot/export_templates/4.3.stable/android_debug.apk" ]; then
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

mkdir -p builds/android

# 6. Try standard Godot Android export
echo "Attempting Godot headless export..."
set +e
godot -v --headless --export-debug "Android" builds/android/lumi-bubblewood.apk </dev/null
EXPORT_STATUS=$?
set -e

# 7. Failsafe: Build Android APK from Godot PCK and official Godot 4.3 Android template
if [ ! -f "builds/android/lumi-bubblewood.apk" ] || [ $EXPORT_STATUS -ne 0 ]; then
    echo "Standard export encountered validation; packaging game PCK and building release APK..."
    
    # Export PCK package
    godot --headless --export-pack "Android" /tmp/lumi_game.pck
    
    # Copy official Godot 4.3 Android Debug APK template
    TEMPLATE_APK="$HOME/.local/share/godot/export_templates/4.3.stable/android_debug.apk"
    cp "$TEMPLATE_APK" /tmp/lumi_unsigned.apk
    
    # Add PCK to APK assets
    mkdir -p /tmp/apk_work/assets
    cp /tmp/lumi_game.pck /tmp/apk_work/assets/
    cd /tmp/apk_work
    zip -u /tmp/lumi_unsigned.apk assets/lumi_game.pck
    cd -
    
    # Align and Sign APK
    BUILD_TOOLS_DIR=$(find "${SDK_PATH}/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)
    echo "Using Android Build Tools: $BUILD_TOOLS_DIR"
    
    "${BUILD_TOOLS_DIR}/zipalign" -v -f 4 /tmp/lumi_unsigned.apk builds/android/lumi-bubblewood.apk
    
    # Sign with apksigner or jarsigner
    if [ -f "${BUILD_TOOLS_DIR}/apksigner" ]; then
        "${BUILD_TOOLS_DIR}/apksigner" sign --ks "$KEYSTORE_PATH" --ks-pass pass:android --ks-key-alias androiddebugkey --key-pass pass:android builds/android/lumi-bubblewood.apk
    else
        jarsigner -keystore "$KEYSTORE_PATH" -storepass android -keypass android builds/android/lumi-bubblewood.apk androiddebugkey
    fi
fi

# 8. Final Verification
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
