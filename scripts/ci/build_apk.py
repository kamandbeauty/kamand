#!/usr/bin/env python3
import os
import sys
import subprocess
import shutil
import zipfile
import traceback

def run_cmd(cmd, check=True):
    print(f"[RUN] {cmd}", flush=True)
    res = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    if res.stdout:
        print(f"[STDOUT]\n{res.stdout}", flush=True)
    if res.stderr:
        print(f"[STDERR]\n{res.stderr}", file=sys.stderr, flush=True)
    if check and res.returncode != 0:
        raise RuntimeError(f"Command failed (exit code {res.returncode}): {cmd}\nStderr: {res.stderr}")
    return res

def main():
    print("==============================================", flush=True)
    print("    LUMI PRODUCTION ANDROID APK PACKAGER      ", flush=True)
    print("==============================================", flush=True)

    try:
        work_dir = "/tmp/apk_build"
        shutil.rmtree(work_dir, ignore_errors=True)
        os.makedirs(work_dir, exist_ok=True)
        
        home_dir = os.path.expanduser("~")
        sdk_path = os.environ.get("ANDROID_HOME", "/usr/local/lib/android/sdk")
        keystore_path = f"{home_dir}/.android/debug.keystore"
        template_apk = f"{home_dir}/.local/share/godot/export_templates/4.3.stable/android_debug.apk"
        
        print(f"Checking template APK at: {template_apk}", flush=True)
        if not os.path.exists(template_apk):
            # Check alternative template locations
            alt = f"{home_dir}/.local/share/godot/templates/4.3.stable/android_debug.apk"
            if os.path.exists(alt):
                template_apk = alt
            else:
                raise FileNotFoundError(f"Export template not found: {template_apk}")
        print(f"Found template APK: {template_apk} ({os.path.getsize(template_apk)} bytes)", flush=True)

        # 1. Export Godot PCK
        pck_path = f"{work_dir}/main.pck"
        print("--- Step 1: Exporting Game PCK with Godot 4.3 ---", flush=True)
        
        # Test preset export
        res = run_cmd(f"godot --headless --export-pack 'Pack' '{pck_path}'", check=False)
        if not os.path.exists(pck_path) or os.path.getsize(pck_path) == 0:
            print("Preset 'Pack' failed, trying 'Android' preset...", flush=True)
            res2 = run_cmd(f"godot --headless --export-pack 'Android' '{pck_path}'", check=False)

        if not os.path.exists(pck_path) or os.path.getsize(pck_path) == 0:
            raise RuntimeError(f"Godot failed to export PCK! Output:\n{res.stdout}\n{res.stderr}")
        
        print(f"Game PCK exported successfully ({os.path.getsize(pck_path)} bytes)", flush=True)

        # 2. Package APK using pure zipfile
        print("--- Step 2: Injecting PCK into Godot Android Template ---", flush=True)
        unsigned_apk = f"{work_dir}/lumi_unsigned.apk"
        
        with open(pck_path, "rb") as pf:
            pck_bytes = pf.read()

        with zipfile.ZipFile(template_apk, "r") as zin:
            with zipfile.ZipFile(unsigned_apk, "w", compression=zipfile.ZIP_DEFLATED) as zout:
                for item in zin.infolist():
                    # Strip old template signatures to allow fresh signing
                    if item.filename.startswith("META-INF/"):
                        continue
                    # Copy original files
                    zout.writestr(item, zin.read(item.filename))
                
                # Write PCK under all standard Godot Android loader locations
                zout.writestr("assets/main.pck", pck_bytes)
                zout.writestr("assets/Godot.pck", pck_bytes)
                zout.writestr("assets/lumi-bubblewood.pck", pck_bytes)

        print(f"Unsigned APK created ({os.path.getsize(unsigned_apk)} bytes)", flush=True)

        # 3. 4-Byte Align APK with zipalign
        print("--- Step 3: Aligning APK with zipalign ---", flush=True)
        out_dir = "builds/android"
        os.makedirs(out_dir, exist_ok=True)
        aligned_apk = f"{out_dir}/lumi-bubblewood.apk"
        
        # Locate zipalign
        zipalign_bin = shutil.which("zipalign")
        if not zipalign_bin:
            build_tools_dir = f"{sdk_path}/build-tools"
            if os.path.isdir(build_tools_dir):
                versions = sorted([d for d in os.listdir(build_tools_dir) if os.path.isdir(f"{build_tools_dir}/{d}")])
                if versions:
                    cand = f"{build_tools_dir}/{versions[-1]}/zipalign"
                    if os.path.exists(cand):
                        zipalign_bin = cand
        if not zipalign_bin:
            zipalign_bin = "zipalign"

        run_cmd(f"'{zipalign_bin}' -v -f 4 '{unsigned_apk}' '{aligned_apk}'")

        # 4. Sign APK with apksigner or jarsigner
        print("--- Step 4: Signing APK with Debug Keystore ---", flush=True)
        apksigner_bin = shutil.which("apksigner")
        if not apksigner_bin:
            build_tools_dir = f"{sdk_path}/build-tools"
            if os.path.isdir(build_tools_dir):
                versions = sorted([d for d in os.listdir(build_tools_dir) if os.path.isdir(f"{build_tools_dir}/{d}")])
                if versions:
                    cand = f"{build_tools_dir}/{versions[-1]}/apksigner"
                    if os.path.exists(cand):
                        apksigner_bin = cand

        if apksigner_bin and os.path.exists(apksigner_bin):
            run_cmd(f"'{apksigner_bin}' sign --ks '{keystore_path}' --ks-pass pass:android --ks-key-alias androiddebugkey --key-pass pass:android '{aligned_apk}'")
            run_cmd(f"'{apksigner_bin}' verify -v '{aligned_apk}'")
        else:
            run_cmd(f"jarsigner -keystore '{keystore_path}' -storepass android -keypass android '{aligned_apk}' androiddebugkey")

        print("==============================================", flush=True)
        print("🎉 SUCCESS: FINAL LUMI ANDROID APK GENERATED!", flush=True)
        print(f"File: {aligned_apk}", flush=True)
        print(f"Size: {os.path.getsize(aligned_apk)} bytes", flush=True)
        print("==============================================", flush=True)
        
    except Exception as e:
        print("\n\n!!!!!!!!!!!!!!!! ERROR IN APK PACKAGER !!!!!!!!!!!!!!!!", flush=True)
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
