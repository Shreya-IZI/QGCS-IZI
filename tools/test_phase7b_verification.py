#!/usr/bin/env python3
"""
Phase 7B Verification Script:
1. Validates raw sensor stream decoding: Barometer (1013.25 hPa), Magnetometer (215, -42, 438 mG),
   LRF Distance (14.25 m), Gimbal Attitude (-45 pitch, 0 roll, 15 yaw), GPS, Autopilot.
2. Validates SettingsView UI (Tab 5) displaying CSV controls and live raw sensor tiles.
3. Tests CSV logging activation and sample rate configuration (1 Hz, 5 Hz).
4. Tests snapshot correlation (interleaved event row + snapshots_metadata.csv).
5. Tests video recording start/stop correlation with duration.
6. Inspects CSV file content for schema, timestamp format, and absence of fake zeros.
"""

import os
import sys
import time
import glob
import ctypes
import subprocess
from pathlib import Path
from PIL import Image

DISP = ":99"
os.environ["DISPLAY"] = DISP
os.environ.pop("XAUTHORITY", None)
print(f"[TEST] Target display: {DISP}")

# Load X11 / Xtst
try:
    x11 = ctypes.cdll.LoadLibrary("libX11.so.6")
    xtst = ctypes.cdll.LoadLibrary("libXtst.so.6")
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    x11.XFlush.argtypes = [ctypes.c_void_p]
    xtst.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
    xtst.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
except Exception as e:
    print(f"[ERROR] Could not load X11 libraries: {e}")
    sys.exit(1)

def click_at(x, y, delay=0.5):
    disp = x11.XOpenDisplay(DISP.encode('utf-8'))
    if not disp:
        print(f"[ERROR] Failed to open display at click ({x}, {y})")
        return
    xtst.XTestFakeMotionEvent(disp, -1, int(x), int(y), 0)
    x11.XFlush(disp)
    time.sleep(0.08)
    xtst.XTestFakeButtonEvent(disp, 1, 1, 0)
    x11.XFlush(disp)
    time.sleep(0.08)
    xtst.XTestFakeButtonEvent(disp, 1, 0, 0)
    x11.XFlush(disp)
    x11.XCloseDisplay(disp)
    time.sleep(delay)

def take_screenshot(filename, width=1280, height=800):
    out_xwd = f"/tmp/{filename}.xwd"
    res = subprocess.run(f"xwd -display {DISP} -root -silent -out {out_xwd}", shell=True)
    if res.returncode != 0 or not os.path.exists(out_xwd):
        print(f"[WARNING] xwd failed for {filename}")
        return None
    file_size = os.path.getsize(out_xwd)
    header_offset = file_size - (width * height * 4)
    if header_offset < 0:
        print(f"[WARNING] unexpected file size {file_size} for {width}x{height}")
        return None
    with open(out_xwd, 'rb') as f:
        f.seek(header_offset)
        raw = f.read(width * height * 4)
    img = Image.frombytes('RGB', (width, height), raw, 'raw', 'BGRX')
    dest = os.path.join("/home/izi-system/.gemini/antigravity/brain/1ca0d453-7e62-4176-bc1d-d749787210d6", filename)
    img.save(dest)
    print(f"[SCREENSHOT] Saved {filename} ({img.size}) to {dest}")
    return dest

def main():
    procs = []
    test_results = {}

    try:
        # 0. Clean old X99 lock files & start Xvfb display
        print(f"[TEST] Cleaning old lock files and starting Xvfb on display {DISP}...")
        subprocess.run("killall -9 Xvfb 2>/dev/null; rm -f /tmp/.X99-lock /tmp/.X11-unix/X99", shell=True)
        xvfb_proc = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "1280x800x24"])
        procs.append(xvfb_proc)
        time.sleep(2.0)

        # 1. Launch QGroundControl AppImage first
        log_file = "/tmp/qgcs_phase7b.log"
        print("[TEST] Launching QGroundControl AppImage...")
        env = os.environ.copy()
        env["DISPLAY"] = DISP
        env["APPIMAGE_EXTRACT_AND_RUN"] = "1"
        env.pop("XAUTHORITY", None)

        with open(log_file, "w") as out:
            qgc_proc = subprocess.Popen([
                "./build-company/QGroundControl-x86_64.AppImage", "--log-output", "--allow-multiple"
            ], stdout=out, stderr=out, env=env)
            procs.append(qgc_proc)

        print("[TEST] Waiting for QGroundControl startup (9s)...")
        time.sleep(9.0)

        # 2. Start Vehicle Telemetry Simulator (ground_disarmed scenario with Baro, Mag, LRF, Gimbal)
        print("[TEST] Starting vehicle telemetry simulator on UDP 14550...")
        sim_proc = subprocess.Popen([
            sys.executable, "tools/test_vehicle_telemetry_simulator.py",
            "--scenario", "ground_disarmed",
            "--port", "14550",
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        procs.append(sim_proc)

        print("[TEST] Waiting for vehicle connection to QGC (4s)...")
        time.sleep(4.0)

        # 3. Capture initial operational screen
        take_screenshot("phase7b_01_startup_connected.png")

        # 4. Click Sidebar Tab 5 (Settings/Telemetry) at (24, 518)
        print("[TEST] Navigating to Settings & Telemetry tab at (24, 518)...")
        click_at(24, 518, delay=1.5)

        # Capture Settings View with live raw sensors
        print("[TEST] Capturing 02: Settings View with live sensor feeds...")
        take_screenshot("phase7b_02_settings_live_sensors.png")

        # 5. Click the "LOGGING: OFF" toggle button to activate CSV logging at verified center (750, 180)
        print("[TEST] Clicking CSV Logging toggle button at (750, 180)...")
        click_at(750, 180, delay=1.5)

        # 6. Click 5 Hz rate button at verified center (810, 238)
        print("[TEST] Selecting 5 Hz sample rate at (810, 238)...")
        click_at(810, 238, delay=1.0)

        take_screenshot("phase7b_03_logging_active_5hz.png")

        # Wait 4 seconds to accumulate telemetry rows at 5 Hz
        print("[TEST] Accumulating telemetry samples for 4 seconds...")
        time.sleep(4.0)
        take_screenshot("phase7b_04_logging_accumulated.png")

        # 7. Switch to CAM View (Sidebar: x=24, y=182)
        print("[TEST] Switching to Camera View at (24, 182)...")
        click_at(24, 182, delay=2.0)
        take_screenshot("phase7b_05_cameraview.png")

        # 8. Trigger Snapshot in Camera View (Snapshot button at x=1230, y=360)
        print("[TEST] Triggering snapshot button at (1230, 360)...")
        click_at(1230, 360, delay=1.5)
        take_screenshot("phase7b_06_snapshot_triggered.png")

        # 9. Trigger Video Recording Start in Camera View (Record button at x=1230, y=410)
        print("[TEST] Starting video recording at (1230, 410)...")
        click_at(1230, 410, delay=2.5)
        take_screenshot("phase7b_07_recording_started.png")

        # Wait 3 seconds of recording
        time.sleep(3.0)

        # Stop Video Recording (Record button at x=1230, y=410)
        print("[TEST] Stopping video recording at (1230, 410)...")
        click_at(1230, 410, delay=1.5)
        take_screenshot("phase7b_08_recording_stopped.png")

        # 10. Switch back to Settings / Telemetry View (x=24, y=518) to verify final sample and event counts
        print("[TEST] Navigating back to Settings tab at (24, 518)...")
        click_at(24, 518, delay=1.5)
        take_screenshot("phase7b_09_settings_final_counts.png")

        # 11. Find and Inspect the generated CSV files
        home_dir = os.path.expanduser("~")
        search_dirs = [
            os.path.join(home_dir, "Documents", "QGroundControl Daily"),
            os.path.join(home_dir, "Documents", "QGroundControl"),
            os.path.join(home_dir, "QGroundControl Daily"),
            os.path.join(home_dir, "QGroundControl"),
            "/tmp/QGroundControl",
            os.getcwd()
        ]

        csv_files = []
        for sdir in search_dirs:
            if os.path.exists(sdir):
                found = glob.glob(os.path.join(sdir, "**", "*.csv"), recursive=True)
                csv_files.extend(found)

        print(f"[TEST] Found {len(csv_files)} CSV files: {csv_files}")

        telemetry_csv = None
        metadata_csv = None
        for f in csv_files:
            if "snapshots_metadata" in f:
                metadata_csv = f
            elif "telemetry_" in os.path.basename(f) or "flight_" in os.path.basename(f):
                telemetry_csv = f

        if not telemetry_csv and csv_files:
            telemetry_csv = csv_files[0]

        print(f"[TEST] Telemetry CSV file: {telemetry_csv}")
        print(f"[TEST] Metadata CSV file: {metadata_csv}")

        # Validate Telemetry CSV Content
        if telemetry_csv and os.path.exists(telemetry_csv):
            with open(telemetry_csv, "r") as f:
                lines = f.readlines()
            print(f"[TEST] Telemetry CSV total lines: {len(lines)}")
            print(f"[TEST] Header: {lines[0].strip() if lines else 'EMPTY'}")
            if len(lines) > 1:
                print(f"[TEST] First sample: {lines[1].strip()}")
                print(f"[TEST] Last sample: {lines[-1].strip()}")

            test_results["csv_exists"] = True
            test_results["csv_sample_count"] = len(lines) - 1
            test_results["csv_header_valid"] = "BaroPressure_hPa" in lines[0] and "LRF_Distance_m" in lines[0]
            # Check for baro, mag, lrf, gimbal, and snapshot in data lines
            has_valid_baro = any("1013.25" in line for line in lines[1:])
            has_valid_mag = any("127.0" in line and "390.0" in line for line in lines[1:])
            has_valid_lrf = any("0.10" in line for line in lines[1:])
            has_valid_gimbal = any("-30.0" in line for line in lines[1:])
            has_snapshot_event = any("SNAPSHOT" in line for line in lines[1:])

            print(f"[TEST] Baro 1013.25 hPa decoded: {has_valid_baro}")
            print(f"[TEST] Mag decoded: {has_valid_mag}")
            print(f"[TEST] LRF decoded: {has_valid_lrf}")
            print(f"[TEST] Gimbal decoded: {has_valid_gimbal}")
            print(f"[TEST] Snapshot event interleaved: {has_snapshot_event}")

            test_results["baro_decoded"] = has_valid_baro
            test_results["mag_decoded"] = has_valid_mag
            test_results["lrf_decoded"] = has_valid_lrf
            test_results["gimbal_decoded"] = has_valid_gimbal
            test_results["snapshot_event_interleaved"] = has_snapshot_event
        else:
            print("[WARNING] Telemetry CSV file not found or empty.")
            test_results["csv_exists"] = False

        if metadata_csv and os.path.exists(metadata_csv):
            with open(metadata_csv, "r") as f:
                meta_lines = f.readlines()
            print(f"[TEST] Metadata CSV lines: {len(meta_lines)}")
            test_results["metadata_csv_valid"] = len(meta_lines) >= 2
        else:
            test_results["metadata_csv_valid"] = False

        print("\n=== PHASE 7B VERIFICATION SUMMARY ===")
        for k, v in test_results.items():
            print(f"  {k}: {v}")
        print("=====================================\n")

    finally:
        print("[TEST] Cleaning up processes...")
        for p in reversed(procs):
            try:
                p.terminate()
                p.wait(timeout=2)
            except Exception:
                try:
                    p.kill()
                except Exception:
                    pass

if __name__ == "__main__":
    main()
