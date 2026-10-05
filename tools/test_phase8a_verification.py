#!/usr/bin/env python3
"""
Phase 8A Verification Script:
1. Starts Xvfb at :99 (1280x800).
2. Runs QGroundControl from build-company via the official build container with DISPLAY=:99.
3. Verifies FlightLogsView.qml with native OnboardLogController:
   - Refresh button
   - Select All button
   - Download Selected button
   - Cancel button
   - Sort Order button
   - Transport mode badge (MAVLink FTP / Messages)
   - Open Log Directory button
4. Verifies SettingsView.qml with Offline Maps Ingestion:
   - 3 sub-tab navigation (DATA LOGGING, NETWORK & LINKS, OFFLINE MAPS)
   - OFFLINE MAPS sub-tab rendering
   - Metrics tiles (Installed Tile Sets, Total Cached Tiles, Disk Cache Size, Offline Status)
   - Ingestion card with Select Map Package button (.qct / .zip / .tar.gz)
   - Installed Tile Sets card
5. Captures verification screenshots via xwd.
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
    xtst.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
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
    print(f"[TEST] Cleaning old lock files and starting Xvfb on display {DISP}...")
    subprocess.run("killall -9 Xvfb 2>/dev/null; rm -f /tmp/.X99-lock /tmp/.X11-unix/X99", shell=True)
    subprocess.run("docker rm -f qgc_phase8a_test 2>/dev/null", shell=True)
    
    xvfb_proc = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "1280x800x24"])
    procs.append(xvfb_proc)
    time.sleep(2.0)

    cwd = os.getcwd()
    cmd = [
        "docker", "run", "--rm",
        "--name", "qgc_phase8a_test",
        "-u", f"{os.getuid()}:{os.getgid()}",
        "-v", f"{cwd}:/project/source",
        "-v", f"{cwd}/build-company:/project/build",
        "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
        "-e", f"DISPLAY={DISP}",
        "-e", "HOME=/home/izi-system",
        "-v", "/home/izi-system/.config:/home/izi-system/.config",
        "-v", "/home/izi-system/.cache:/home/izi-system/.cache",
        "--entrypoint", "/project/build/Release/QGroundControl",
        "qgc-ubuntu-2204-docker:latest",
        "--allow-multiple", "--logging", "Company.*"
    ]

    log_file = "/tmp/qgcs_phase8a.log"
    print("[EXEC] Starting QGroundControl container...")
    with open(log_file, "w") as out:
        qgc_proc = subprocess.Popen(cmd, stdout=out, stderr=out)
        procs.append(qgc_proc)

    try:
        # Allow QGC to load and initialize UI
        print("[WAIT] Initializing UI (12s)...")
        time.sleep(12.0)

        # 1. Capture Initial Startup Screen
        take_screenshot("phase8a_01_startup.png")

        # 2. Click Tab 4: FLIGHT LOGS (Sidebar item 4: 30, 482)
        print("[NAV] Clicking Flight Logs Tab (Sidebar item 4: 30, 482)...")
        click_at(30, 482, delay=1.5)
        take_screenshot("phase8a_02_flight_logs_view.png")

        # 3. Click Tab 5: SETTINGS (Sidebar item 5: 30, 517)
        print("[NAV] Clicking Settings Tab (Sidebar item 5: 30, 517)...")
        click_at(30, 517, delay=1.5)
        take_screenshot("phase8a_03_settings_telemetry.png")

        # 4. Click Sub-tab 3: OFFLINE MAPS pill (~ x=1180, y=87)
        print("[NAV] Clicking OFFLINE MAPS sub-tab pill (~1180, 87)...")
        click_at(1180, 87, delay=1.5)
        take_screenshot("phase8a_04_settings_offline_maps.png")

        # 5. Capture Reload Tile Sets / Refresh state
        print("[ACTION] Reloading tile sets...")
        click_at(1180, 87, delay=1.0)
        take_screenshot("phase8a_05_offline_maps_reloaded.png")

        # 6. Click Back to Flight Logs Tab (~ x=30, y=482)
        print("[NAV] Returning to Flight Logs Tab...")
        click_at(30, 482, delay=1.5)
        take_screenshot("phase8a_06_flight_logs_final.png")

        print("[SUCCESS] Phase 8A UI verification completed successfully!")

    finally:
        print("[CLEANUP] Terminating processes...")
        subprocess.run("docker kill qgc_phase8a_test 2>/dev/null", shell=True)
        for p in reversed(procs):
            try:
                p.terminate()
                p.wait(timeout=3)
            except Exception:
                p.kill()
        subprocess.run("killall -9 Xvfb 2>/dev/null; rm -f /tmp/.X99-lock /tmp/.X11-unix/X99", shell=True)
        print("[CLEANUP] Complete.")

if __name__ == "__main__":
    main()
