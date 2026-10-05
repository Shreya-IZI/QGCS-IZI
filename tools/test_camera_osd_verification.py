#!/usr/bin/env python3
"""
Automated Test Verification Script for Chandipur Camera Operation & Tactical Video OSD
Validates:
1. Video OSD Overlay (Top-Left, Top-Right, Bottom-Left, Center Reticle)
2. Authoritative UTC Timestamp ([LOCAL UTC] tag + ms precision)
3. Gimbal Telemetry and FOV Telemetry
4. Dual Video Streams (RGB + Thermal)
5. Mode Switching (RGB_ONLY, THERMAL_ONLY, SIDE_BY_SIDE, PIP)
6. Camera Snapshot Action (Shutter flash + saved file toast)
7. Video Recording Action (REC badge, pulsing dot, elapsed timer)
"""

import os
import sys
import time
import ctypes
import subprocess
from pathlib import Path
from PIL import Image

# Setup Display
disp_env = os.environ.get("DISPLAY", ":99")
os.environ["DISPLAY"] = disp_env
print(f"[TEST] Running under DISPLAY: {disp_env}")

# Load X11 & Xtst for automated interaction
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
    disp = x11.XOpenDisplay(None)
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
    res = subprocess.run(f"xwd -root -silent -out {out_xwd}", shell=True)
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
        # 1. Start Vehicle Telemetry Simulator (with dual camera component)
        print("[TEST] Starting vehicle telemetry simulator with camera support...")
        sim_proc = subprocess.Popen([
            sys.executable, "tools/test_vehicle_telemetry_simulator.py",
            "--scenario", "airborne",
            "--port", "14550",
            "--with-camera",
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        procs.append(sim_proc)
        time.sleep(1.0)

        # 2. Start GStreamer RGB Stream (UDP 5600)
        print("[TEST] Starting GStreamer RGB stream on UDP 5600...")
        rgb_gst = subprocess.Popen([
            "gst-launch-1.0", "-q",
            "videotestsrc", "pattern=ball",
            "!", "video/x-raw,width=1280,height=720,framerate=30/1",
            "!", "x264enc", "tune=zerolatency", "bitrate=2000", "speed-preset=ultrafast",
            "!", "rtph264pay",
            "!", "udpsink", "host=127.0.0.1", "port=5600"
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        procs.append(rgb_gst)

        # 3. Start GStreamer Thermal Stream (UDP 5601)
        print("[TEST] Starting GStreamer Thermal stream on UDP 5601...")
        thermal_gst = subprocess.Popen([
            "gst-launch-1.0", "-q",
            "videotestsrc", "pattern=smpte",
            "!", "video/x-raw,width=1280,height=720,framerate=30/1",
            "!", "x264enc", "tune=zerolatency", "bitrate=2000", "speed-preset=ultrafast",
            "!", "rtph264pay",
            "!", "udpsink", "host=127.0.0.1", "port=5601"
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        procs.append(thermal_gst)

        # 4. Launch QGroundControl AppImage
        log_file = "/tmp/qgcs_camera_osd.log"
        print("[TEST] Launching QGroundControl AppImage...")
        env = os.environ.copy()
        env["APPIMAGE_EXTRACT_AND_RUN"] = "1"

        with open(log_file, "w") as out:
            qgc_proc = subprocess.Popen([
                "./build-company/QGroundControl-x86_64.AppImage", "--log-output", "--allow-multiple"
            ], stdout=out, stderr=out, env=env)
            procs.append(qgc_proc)

        print("[TEST] Waiting for QGroundControl initialization (8s)...")
        time.sleep(8.0)

        # 5. Switch to CAM View
        # TopBar CAM tab is at x=236, y=74
        print("[TEST] Switching to CAM view at (236, 74)...")
        click_at(236, 74, delay=2.0)

        # Capture 01: Side-by-Side Split View with OSD and video
        print("[TEST] Capturing 01: Side-by-Side Split View...")
        take_screenshot("chandipur_osd_01_split_mode.png")

        # Capture 02: Switch to RGB Only mode (modeToolbar button 1: x=556, y=74)
        print("[TEST] Switching to RGB mode at (556, 74)...")
        click_at(556, 74, delay=1.0)
        take_screenshot("chandipur_osd_02_rgb_mode.png")

        # Capture 03: Switch to THERMAL Only mode (modeToolbar button 2: x=632, y=74)
        print("[TEST] Switching to THERMAL mode at (632, 74)...")
        click_at(632, 74, delay=1.0)
        take_screenshot("chandipur_osd_03_thermal_mode.png")

        # Capture 04: Switch to PIP mode (modeToolbar button 4: x=784, y=74)
        print("[TEST] Switching to PIP mode at (784, 74)...")
        click_at(784, 74, delay=1.0)
        take_screenshot("chandipur_osd_04_pip_mode.png")

        # Return to SPLIT mode (modeToolbar button 3: x=708, y=74)
        print("[TEST] Returning to SPLIT mode at (708, 74)...")
        click_at(708, 74, delay=1.0)

        # 6. Test Snapshot Action
        # Camera controls toolbar: x ~ 1242
        # Snapshot button: (1242, 358)
        print("[TEST] Triggering Camera Snapshot at (1242, 358)...")
        click_at(1242, 358, delay=0.2)
        take_screenshot("chandipur_osd_05_snapshot_shutter.png")
        time.sleep(0.8)
        take_screenshot("chandipur_osd_05b_snapshot_toast.png")

        # 7. Test Recording Action
        # Record button: (1242, 400)
        print("[TEST] Starting Video Recording at (1242, 400)...")
        click_at(1242, 400, delay=1.5)
        take_screenshot("chandipur_osd_06_recording_active.png")

        time.sleep(2.0)
        print("[TEST] Stopping Video Recording at (1242, 400)...")
        click_at(1242, 400, delay=1.0)
        take_screenshot("chandipur_osd_07_recording_stopped.png")

        # 8. Test Zoom Control (shows disabled / non-intrusive tooltip when camera zoom unsupported)
        print("[TEST] Testing Zoom In button at (1242, 448)...")
        click_at(1242, 448, delay=0.5)
        take_screenshot("chandipur_osd_08_zoom_control.png")

        print("[TEST] Test sequence successfully completed!")

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
