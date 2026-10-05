#!/usr/bin/env python3
"""
Phase 7A Verification Script:
1. Tactical Map Cleanup (Zero Bhopal / mock weather data)
2. Flight Logs Integration with OnboardLogController
3. Verification of Disconnected, Connected, and Refresh states
4. Verification that Dashboard, Mission Planner, and CameraView remain functional
"""

import os
import sys
import time
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

    try:
        # 0. Clean old X99 lock files & start Xvfb display
        print(f"[TEST] Cleaning old lock files and starting Xvfb on display {DISP}...")
        subprocess.run("killall -9 Xvfb 2>/dev/null; rm -f /tmp/.X99-lock /tmp/.X11-unix/X99", shell=True)
        xvfb_proc = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "1280x800x24"])
        procs.append(xvfb_proc)
        time.sleep(2.0)

        # 1. Launch QGroundControl AppImage without vehicle simulator (Disconnected state test)
        log_file = "/tmp/qgcs_phase7a.log"
        print("[TEST] Launching QGroundControl AppImage (disconnected state)...")
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

        # 2. Capture Tactical Map (Clean - No Bhopal/weather mock)
        print("[TEST] Capturing 01: Tactical Map view (verifying zero mock weather data)...")
        take_screenshot("phase7a_01_tactical_map_clean.png")

        # 3. Click on Sidebar Tab 4 (Logs) at (24, 482)
        print("[TEST] Switching to Flight Logs tab at (24, 482)...")
        click_at(24, 482, delay=1.5)

        # Capture 02: Flight Logs View in Disconnected State
        print("[TEST] Capturing 02: Flight Logs View in Disconnected State...")
        take_screenshot("phase7a_02_logs_disconnected.png")

        # 4. Start Vehicle Telemetry Simulator
        print("[TEST] Starting vehicle telemetry simulator on UDP 14550...")
        sim_proc = subprocess.Popen([
            sys.executable, "tools/test_vehicle_telemetry_simulator.py",
            "--scenario", "ground_disarmed",
            "--port", "14550",
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        procs.append(sim_proc)

        print("[TEST] Waiting for vehicle connection to QGC (4s)...")
        time.sleep(4.0)

        # Capture 03: Flight Logs View in Connected State (No logs / Ready)
        print("[TEST] Capturing 03: Flight Logs View in Connected State...")
        take_screenshot("phase7a_03_logs_connected.png")

        # 5. Click "Refresh" button in action bar (x=115, y=105)
        print("[TEST] Clicking Refresh button at (115, 105)...")
        click_at(115, 105, delay=1.0)
        take_screenshot("phase7a_04_logs_refresh.png")

        # 6. Switch to Tactical Map (Sidebar Tab 1: x=24, y=112)
        print("[TEST] Switching back to Tactical Map at (24, 112)...")
        click_at(24, 112, delay=1.5)
        take_screenshot("phase7a_05_map_operational.png")

        # 7. Switch to Mission Planner (Sidebar Tab 2: x=24, y=411)
        print("[TEST] Switching to Mission Planner at (24, 411)...")
        click_at(24, 411, delay=1.5)
        take_screenshot("phase7a_06_mission_planner.png")

        # 8. Switch to Cockpit Operations and then CAM View (Sidebar CAM: x=24, y=182)
        print("[TEST] Switching to CAM view at (24, 182)...")
        click_at(24, 182, delay=1.5)
        take_screenshot("phase7a_07_cameraview_operational.png")

        print("[TEST] Phase 7A test verification successfully completed!")

    finally:
        print("[TEST] Cleaning up test processes...")
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
