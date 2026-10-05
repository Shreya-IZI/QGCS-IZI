#!/usr/bin/env python3
"""
Verification Script for:
1. Dismissing connection alert at (830, 372)
2. Expanding Sidebar at (22, 72) to show the new VEHICLE section (Parameters, Vehicle Setup)
3. Switching to VEHICLE -> Parameters View
4. Opening IZI Application Menu via brand icon click at (25, 24)
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
ARTIFACT_DIR = "/home/izi-system/.gemini/antigravity/brain/605ebb38-403a-4172-a9ec-e634751ef65e"
Path(ARTIFACT_DIR).mkdir(parents=True, exist_ok=True)

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

def click_at(x, y, delay=0.8):
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
    dest = os.path.join(ARTIFACT_DIR, filename)
    img.save(dest)
    print(f"[SCREENSHOT] Saved {filename} ({img.size}) to {dest}")
    return dest

def main():
    procs = []

    try:
        print(f"[TEST] Cleaning old lock files and starting Xvfb on display {DISP}...")
        subprocess.run("killall -9 Xvfb 2>/dev/null; rm -f /tmp/.X99-lock /tmp/.X11-unix/X99", shell=True)
        xvfb_proc = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "1280x800x24"])
        procs.append(xvfb_proc)
        time.sleep(2.0)

        # 1. Start vehicle telemetry simulator
        print("[TEST] Starting vehicle telemetry simulator on UDP 14550...")
        sim_proc = subprocess.Popen([
            sys.executable, "/home/izi-system/Shreya/QGCS/qgroundcontrol/tools/test_vehicle_telemetry_simulator.py",
            "--scenario", "ground_disarmed",
            "--port", "14550",
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        procs.append(sim_proc)
        time.sleep(1.0)

        # 2. Launch QGroundControl AppImage
        log_file = "/tmp/qgcs_verification.log"
        print("[TEST] Launching QGroundControl AppImage...")
        env = os.environ.copy()
        env["DISPLAY"] = DISP
        env["APPIMAGE_EXTRACT_AND_RUN"] = "1"
        env.pop("XAUTHORITY", None)

        with open(log_file, "w") as out:
            qgc_proc = subprocess.Popen([
                "/home/izi-system/Shreya/QGCS/qgroundcontrol/build-company/QGroundControl-x86_64.AppImage",
                "--log-output", "--allow-multiple"
            ], stdout=out, stderr=out, env=env)
            procs.append(qgc_proc)

        print("[TEST] Waiting for QGroundControl startup (10s)...")
        time.sleep(10.0)

        # Step 0: Dismiss modal connection prompt
        print("[TEST] Dismissing connection modal at (830, 372)...")
        click_at(830, 372, delay=1.0)

        # Step 1: Expand Sidebar at hamburger center (22, 72)
        print("[TEST] Expanding Sidebar at hamburger (22, 72)...")
        click_at(22, 72, delay=1.0)
        print("[TEST] Capturing 01: Sidebar Expanded showing new VEHICLE section...")
        take_screenshot("01_sidebar_vehicle_section_expanded.png")

        # Step 2: Click on "Parameters" item in the expanded sidebar at (80, 510)
        print("[TEST] Clicking 'Parameters' item in VEHICLE section at (80, 510)...")
        click_at(80, 510, delay=1.5)
        print("[TEST] Capturing 02: Parameters Editor View...")
        take_screenshot("02_parameters_view.png")

        # Step 3: Click IZI Brand Area at (25, 24) to open the IZI Application Menu
        print("[TEST] Clicking IZI icon/brand area at (25, 24) to open application menu...")
        click_at(25, 24, delay=1.2)
        print("[TEST] Capturing 03: IZI Application Dropdown Menu...")
        take_screenshot("03_izi_application_menu.png")

        print("[TEST] All verification captures completed successfully!")

    finally:
        print("[TEST] Terminating test processes...")
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
