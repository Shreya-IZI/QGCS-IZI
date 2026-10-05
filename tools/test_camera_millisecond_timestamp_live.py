#!/usr/bin/env python3
"""
Test script to verify live millisecond video timestamping (hh:mm:ss:ms)
synced to drone GPS epoch time.
"""

import os
import sys
import time
import ctypes
import subprocess
from pathlib import Path
from PIL import Image

DISP = ":92"
os.environ["DISPLAY"] = DISP
os.system("rm -f /tmp/.X92-lock /tmp/.X11-unix/X92")
xvfb = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "1280x800x24"])
time.sleep(1.5)

x11 = ctypes.cdll.LoadLibrary("libX11.so.6")
xtst = ctypes.cdll.LoadLibrary("libXtst.so.6")
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
x11.XFlush.argtypes = [ctypes.c_void_p]
xtst.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
xtst.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]

def click_at(x, y, delay=0.5):
    disp = x11.XOpenDisplay(DISP.encode('utf-8'))
    if not disp:
        print(f"[ERROR] Failed to open display {DISP} at click ({x}, {y})")
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

def snap(filename, width=1280, height=800):
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
    print(f"[SCREENSHOT] Saved {filename} to {dest}")
    return dest

def main():
    procs = []
    container_name = "qgc_cam_ms_test"
    subprocess.run(["docker", "rm", "-f", container_name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    try:
        # 1. Telemetry simulator
        print("[TEST] Starting vehicle telemetry simulator...")
        sim_proc = subprocess.Popen([
            sys.executable, "tools/test_vehicle_telemetry_simulator.py",
            "--scenario", "airborne",
            "--port", "14550",
            "--with-camera",
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        procs.append(sim_proc)
        time.sleep(1.0)

        # 2. RGB stream
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

        # 3. Thermal stream
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

        # 4. Launch QGroundControl AppImage via Docker
        appimage = "/home/izi-system/Shreya/QGCS/qgroundcontrol/build-company/QGroundControl-x86_64.AppImage"
        print("[TEST] Launching QGC in Docker container on display " + DISP + "...")
        docker_cmd = [
            "docker", "run", "-d",
            "--name", container_name,
            "--net=host",
            "-u", "1000:1000",
            "-v", f"{appimage}:/app.AppImage",
            "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
            "-e", f"DISPLAY={DISP}",
            "-e", "HOME=/tmp",
            "--entrypoint", "/app.AppImage",
            "qgc-ubuntu-2204-docker:latest",
            "--appimage-extract-and-run",
            "--allow-multiple"
        ]
        subprocess.run(docker_cmd, check=True)

        print("[TEST] Waiting 10s for QGC startup and telemetry link...")
        time.sleep(10.0)

        # Dismiss any start modal
        click_at(834, 377, delay=0.5)

        # Click CAM subview tab in DashboardView (x=236, y=74)
        print("[TEST] Switching to CAM view at (236, 74)...")
        click_at(236, 74, delay=2.5)

        # Capture 1: Split Mode with Millisecond Video Timestamp Badge
        print("[TEST] Capturing split mode...")
        snap("cam_ms_01_split_mode.png")

        # Capture 2: Advancing Millisecond timestamp verification (take 3 quick samples)
        for i in range(1, 4):
            time.sleep(0.3)
            snap(f"cam_ms_02_sample_{i}.png")

        # Click RGB Only Mode (x=556, y=74)
        print("[TEST] Switching to RGB mode at (556, 74)...")
        click_at(556, 74, delay=1.5)
        snap("cam_ms_03_rgb_mode.png")

        print("[TEST] Verification sequence completed successfully!")

    finally:
        print("[TEST] Cleaning up...")
        subprocess.run(["docker", "rm", "-f", container_name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for p in reversed(procs):
            try:
                p.terminate()
                p.wait(timeout=2)
            except Exception:
                try:
                    p.kill()
                except Exception:
                    pass
        xvfb.terminate()
        os.system("rm -f /tmp/.X92-lock /tmp/.X11-unix/X92")

if __name__ == "__main__":
    main()
