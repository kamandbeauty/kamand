#!/usr/bin/env python3
import os
import sys
import re
import subprocess
import shutil

def run_cmd(cmd, check=True):
    print(f"[RUN] {cmd}")
    res = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    if res.stdout:
        print(res.stdout)
    if res.stderr:
        print(res.stderr, file=sys.stderr)
    if check and res.returncode != 0:
        raise RuntimeError(f"Command failed with exit code {res.returncode}: {cmd}")
    return res

def main():
    print("==============================================")
    print("    LUMI PRODUCTION ANDROID APK PACKAGER      ")
    print("=============================================="

    work_dir = "/tmp/apk_build"
    shutil.rmtree(work_dir, ignore_errors=True)
    os.makedirs(work_dir, exist_ok=True)
    
    home_dir = os.path.expanduser("~")
    sdk_path = os.environ.get("ANDROID_HOME", "/usr/local/lib/android/sdk")
    keystore_path = f"{home_dir}/.android/debug.keystore"
    template_apk = f"{home_dir}/.local/share/godot/export_templates/4.3.stable/android_debug.apk"
    
    if not os.path.exists(template_apk):
        raise FileNotFoundError(f"Export template not found: {template_apk}")

    # 1. Export Godot PCK
    pck_path = f"{work_dir}/main.pck"
    print("--- Step 1: Exporting Game PCK with Godot 4.3 ---")
    run_cmd(f"godot --headless --export-pack 'Android' '{pck_path}'")
    if not os.path.exists(pck_path) or os.path.getsize(pck_path) == 0:
        raise RuntimeError("PCK export failed or resulted in 0 bytes!")
    print(f"Game PCK exported successfully ({os.path.getsize(pck_path)} bytes)")

    # 2. Decode template APK using apktool
    print("--- Step 2: Decoding Godot Android Template APK ---")
    decoded_dir = f"{work_dir}/decoded"
    run_cmd(f"apktool d -f '{template_apk}' -o '{decoded_dir}'")

    # 3. Modify AndroidManifest.xml (Package, Orientation, Labels)
    print("--- Step 3: Patching AndroidManifest.xml & Resources ---")
    manifest_path = f"{decoded_dir}/AndroidManifest.xml"
    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = f.read()

    # Change package name
    manifest = manifest.replace('package="com.godot.game"', 'package="com.lumi.bubblewood"')
    manifest = manifest.replace('package="org.godotengine.godot"', 'package="com.lumi.bubblewood"')
    
    # Force portrait orientation on all activities
    manifest = re.sub(r'android:screenOrientation="[^"]+"', 'android:screenOrientation="portrait"', manifest)
    if 'android:screenOrientation=' not in manifest:
        manifest = manifest.replace('<activity ', '<activity android:screenOrientation="portrait" ')

    # Change app name label
    manifest = re.sub(r'android:label="[^"]+"', 'android:label="Lumi"', manifest)

    with open(manifest_path, "w", encoding="utf-8") as f:
        f.write(manifest)
    print("Updated AndroidManifest.xml:")

    # Update strings.xml if present
    strings_path = f"{decoded_dir}/res/values/strings.xml"
    if os.path.exists(strings_path):
        with open(strings_path, "r", encoding="utf-8") as f:
            strings = f.read()
        strings = re.sub(r'<string name="godot_project_name_string">.*?</string>', '<string name="godot_project_name_string">Lumi</string>', strings)
        with open(strings_path, "w", encoding="utf-8") as f:
            f.write(strings)

    # 4. Inject Game PCK into assets
    print("--- Step 4: Injecting Assets (main.pck & Godot.pck) ---")
    assets_dir = f"{decoded_dir}/assets"
    os.makedirs(assets_dir, exist_ok=True)
    
    shutil.copyfile(pck_path, f"{assets_dir}/main.pck")
    shutil.copyfile(pck_path, f"{assets_dir}/lumi-bubblewood.pck")
    shutil.copyfile(pck_path, f"{assets_dir}/Godot.pck")
    print(f"Placed main.pck in {assets_dir}/ ({len(os.listdir(assets_dir))} assets files)")

    # 5. Rebuild APK with apktool
    print("--- Step 5: Compiling APK with apktool ---")
    unsigned_apk = f"{work_dir}/lumi_unsigned.apk"
    run_cmd(f"apktool b '{decoded_dir}' -o '{unsigned_apk}'")

    # 6. Align APK with zipalign
    print("--- Step 6: 4-Byte Aligning APK with zipalign ---")
    out_dir = "builds/android"
    os.makedirs(out_dir, exist_ok=True)
    aligned_apk = f"{out_dir}/lumi-bubblewood.apk"
    
    # Locate zipalign
    zipalign_bin = shutil.which("zipalign")
    if not zipalign_bin:
        build_tools = sorted([d for d in os.listdir(f"{sdk_path}/build-tools") if os.path.isdir(f"{sdk_path}/build-tools/{d}")])
        if build_tools:
            zipalign_bin = f"{sdk_path}/build-tools/{build_tools[-1]}/zipalign"
    if not zipalign_bin or not os.path.exists(zipalign_bin):
        zipalign_bin = "zipalign"

    run_cmd(f"'{zipalign_bin}' -v -f 4 '{unsigned_apk}' '{aligned_apk}'")

    # 7. Sign APK with apksigner
    print("--- Step 7: Signing APK with apksigner ---")
    apksigner_bin = shutil.which("apksigner")
    if not apksigner_bin:
        build_tools = sorted([d for d in os.listdir(f"{sdk_path}/build-tools") if os.path.isdir(f"{sdk_path}/build-tools/{d}")])
        if build_tools:
            candidate = f"{sdk_path}/build-tools/{build_tools[-1]}/apksigner"
            if os.path.exists(candidate):
                apksigner_bin = candidate
    
    if apksigner_bin and os.path.exists(apksigner_bin):
        run_cmd(f"'{apksigner_bin}' sign --ks '{keystore_path}' --ks-pass pass:android --ks-key-alias androiddebugkey --key-pass pass:android '{aligned_apk}'")
        run_cmd(f"'{apksigner_bin}' verify -v '{aligned_apk}'")
    else:
        run_cmd(f"jarsigner -keystore '{keystore_path}' -storepass android -keypass android '{aligned_apk}' androiddebugkey")

    print("==============================================")
    print("🎉 SUCCESS: FINAL LUMI ANDROID APK GENERATED!")
    print(f"File: {aligned_apk}")
    print(f"Size: {os.path.getsize(aligned_apk)} bytes")
    print("==============================================")

if __name__ == "__main__":
    main()
