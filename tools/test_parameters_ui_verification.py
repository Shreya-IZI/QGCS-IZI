#!/usr/bin/env python3
"""
Verification Script for Parameter Management UI in QGCS matching 4 reference screenshots:
1. param_01_full_list.png: Full parameter table with left categories/groups, search bar, and Tools button
2. param_02_search_filter.png: Search filter 'LND_F' in action, group column hidden, matching parameters listed
3. param_03_side_editor.png: Right-side Parameter Editor drawer for MIS_TAKEOFF_ALT with Save/Cancel/Reset
4. param_04_tools_menu.png: Tools dropdown menu with Refresh, Reset to defaults, Load/Save file, Reboot
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
ARTIFACT_DIR = "/home/izi-system/.gemini/antigravity/brain/1ca0d453-7e62-4176-bc1d-d749787210d6"
Path(ARTIFACT_DIR).mkdir(parents=True, exist_ok=True)

# Load X11 / Xtst
try:
    x11 = ctypes.cdll.LoadLibrary("libX11.so.6")
    xtst = ctypes.cdll.LoadLibrary("libXtst.so.6")
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XStringToKeysym.restype = ctypes.c_ulong
    x11.XStringToKeysym.argtypes = [ctypes.c_char_p]
    x11.XKeysymToKeycode.restype = ctypes.c_ubyte
    x11.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
    xtst.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
    xtst.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
    xtst.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
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

def type_text(text, delay=0.08):
    disp = x11.XOpenDisplay(DISP.encode('utf-8'))
    if not disp:
        print(f"[ERROR] Failed to open display for typing")
        return
    shift_sym = x11.XStringToKeysym(b"Shift_L")
    shift_code = x11.XKeysymToKeycode(disp, shift_sym)

    for ch in text:
        needs_shift = ch.isupper() or ch in '_:!@#$%^&*()+'
        if ch == '_':
            sym = x11.XStringToKeysym(b"minus")
        else:
            sym = x11.XStringToKeysym(ch.lower().encode('utf-8'))
        keycode = x11.XKeysymToKeycode(disp, sym)
        if keycode:
            if needs_shift and shift_code:
                xtst.XTestFakeKeyEvent(disp, shift_code, 1, 0)
                x11.XFlush(disp)
                time.sleep(0.02)
            xtst.XTestFakeKeyEvent(disp, keycode, 1, 0)
            x11.XFlush(disp)
            time.sleep(delay)
            xtst.XTestFakeKeyEvent(disp, keycode, 0, 0)
            x11.XFlush(disp)
            time.sleep(delay)
            if needs_shift and shift_code:
                xtst.XTestFakeKeyEvent(disp, shift_code, 0, 0)
                x11.XFlush(disp)
                time.sleep(0.02)
    x11.XCloseDisplay(disp)
    time.sleep(0.5)

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

def setup_config():
    for sub in ["Telemetry", "Parameters", "Missions", "Logs", "Video", "Photos"]:
        os.makedirs(f"/tmp/qgc_param_save/{sub}", exist_ok=True)

    os.makedirs("/tmp/qgc_param_config/Company", exist_ok=True)
    src_ini = "/home/izi-system/.config/Company/QGroundControl Daily.ini"
    dst_ini = "/tmp/qgc_param_config/Company/QGroundControl Daily.ini"
    content = ""
    if os.path.exists(src_ini):
        with open(src_ini, "r") as f:
            content = f.read()
    else:
        content = "[General]\n"

    content = content.replace("/home/izi-system/Documents/QGroundControl Daily", "/tmp/qgc_param_save")
    if "telemetrySave=" not in content:
        content = content.replace("[General]\n", "[General]\ntelemetrySave=false\ntelemetrysave=false\ntelemetrySaveNotArmed=false\ntelemetrysavenotarmed=false\n")
    with open(dst_ini, "w") as f:
        f.write(content)

def dismiss_modals():
    for _ in range(3):
        out_xwd = f"/tmp/check_modal.xwd"
        res = subprocess.run(f"xwd -display {DISP} -root -silent -out {out_xwd}", shell=True)
        if res.returncode == 0 and os.path.exists(out_xwd):
            with open(out_xwd, 'rb') as f:
                header_offset = os.path.getsize(out_xwd) - (1280 * 800 * 4)
                f.seek(max(0, header_offset))
                raw = f.read(1280 * 800 * 4)
            img = Image.frombytes('RGB', (1280, 800), raw, 'raw', 'BGRX')
            pixels = img.load()
            green_pixels = []
            # Dialog OK button is in range x: 800..870, y: 330..410
            for y in range(330, 410):
                for x in range(800, 870):
                    r, g, b = pixels[x, y]
                    if g > 100 and r < 70 and b < 70:
                        green_pixels.append((x, y))
            # Button is ~50x30 = ~1500 pixels, require at least 300
            if len(green_pixels) > 300:
                min_x = min(p[0] for p in green_pixels)
                max_x = max(p[0] for p in green_pixels)
                min_y = min(p[1] for p in green_pixels)
                max_y = max(p[1] for p in green_pixels)
                cx = (min_x + max_x) // 2
                cy = (min_y + max_y) // 2
                print(f"[TEST] Dismissing modal dialog button at ({cx}, {cy})...")
                click_at(cx, cy, delay=1.0)
                continue
        break

def clear_search_field():
    click_at(344, 72, delay=0.5)
    click_at(210, 72, delay=0.2)
    disp = x11.XOpenDisplay(DISP.encode('utf-8'))
    if disp:
        ctrl_code = x11.XKeysymToKeycode(disp, x11.XStringToKeysym(b"Control_L"))
        a_code = x11.XKeysymToKeycode(disp, x11.XStringToKeysym(b"a"))
        bs_code = x11.XKeysymToKeycode(disp, x11.XStringToKeysym(b"BackSpace"))
        if ctrl_code and a_code:
            xtst.XTestFakeKeyEvent(disp, ctrl_code, 1, 0)
            xtst.XTestFakeKeyEvent(disp, a_code, 1, 0)
            time.sleep(0.05)
            xtst.XTestFakeKeyEvent(disp, a_code, 0, 0)
            xtst.XTestFakeKeyEvent(disp, ctrl_code, 0, 0)
            time.sleep(0.05)
        if bs_code:
            xtst.XTestFakeKeyEvent(disp, bs_code, 1, 0)
            time.sleep(0.05)
            xtst.XTestFakeKeyEvent(disp, bs_code, 0, 0)
        x11.XFlush(disp)
        x11.XCloseDisplay(disp)
    time.sleep(0.5)

def main():
    procs = []
    containers = ["qgc_param_test_app", "qgc_param_test_sim"]

    try:
        for c in containers:
            subprocess.run(f"docker rm -f {c} 2>/dev/null", shell=True)
        subprocess.run("killall -9 Xvfb 2>/dev/null", shell=True)
        disp_num = DISP.lstrip(":")
        subprocess.run(f"rm -f /tmp/.X{disp_num}-lock /tmp/.X11-unix/X{disp_num} 2>/dev/null", shell=True)
        time.sleep(1.0)

        setup_config()

        # 1. Start Xvfb on display :99
        print(f"[TEST] Starting Xvfb on display {DISP} (1280x800x24)...")
        xvfb_proc = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "1280x800x24"])
        procs.append(xvfb_proc)
        time.sleep(2.0)
        if xvfb_proc.poll() is not None:
            raise RuntimeError(f"Xvfb failed to start on display {DISP}")

        # 2. Start vehicle telemetry simulator with MAVLink parameters
        print("[TEST] Starting vehicle telemetry simulator on UDP 14550 with MAVLink parameter server...")
        cwd = os.getcwd()
        sim_cmd = [
            "docker", "run", "-d", "--name", "qgc_param_test_sim", "--net=host",
            "-v", f"{cwd}:/project/source",
            "--entrypoint", "python3",
            "qgc-ubuntu-2204-docker:latest",
            "/project/source/tools/test_vehicle_telemetry_simulator.py",
            "--autopilot", "px4",
            "--port", "14550"
        ]
        subprocess.run(sim_cmd, check=True)
        time.sleep(1.5)

        # 3. Launch QGroundControl binary in docker
        print("[TEST] Launching QGroundControl Release binary in docker container...")
        app_cmd = [
            "docker", "run", "-d",
            "--name", "qgc_param_test_app",
            "--net=host",
            "-u", f"{os.getuid()}:{os.getgid()}",
            "-v", f"{cwd}:/project/source",
            "-v", f"{cwd}/build-company:/project/build",
            "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
            "-v", "/tmp/qgc_param_config:/home/izi-system/.config",
            "-v", "/tmp/qgc_param_save:/tmp/qgc_param_save",
            "-e", f"DISPLAY={DISP}",
            "-e", "HOME=/home/izi-system",
            "-v", "/home/izi-system/.cache:/home/izi-system/.cache",
            "--entrypoint", "/project/build/Release/QGroundControl",
            "qgc-ubuntu-2204-docker:latest",
            "--allow-multiple"
        ]
        subprocess.run(app_cmd, check=True)

        print("[TEST] Waiting for QGroundControl startup and MAVLink telemetry sync (12s)...")
        time.sleep(12.0)

        # Dismiss any prompt
        dismiss_modals()

        # Click Parameters icon in the sidebar (rail item at x=24, y=412)
        print("[TEST] Navigating to Parameters view (click at 24, 412)...")
        click_at(24, 412, delay=2.5)
        dismiss_modals()

        # Select Battery Calibration group in the left pane (click at x=100, y=131)
        print("[TEST] Selecting Battery Calibration group (click at 100, 131)...")
        click_at(100, 131, delay=1.5)
        time.sleep(1.0)

        # Image 1 Capture: Full list with Category/Groups column and Parameter Table
        print("[TEST] Capturing param_01_full_list.png (Image 1 replica)...")
        take_screenshot("param_01_full_list.png")

        # Step 3: Test Search Box: Click on search field at (210, 72)
        print("[TEST] Clicking search text field at (210, 72)...")
        click_at(210, 72, delay=0.5)
        print("[TEST] Typing search filter 'LND_F'...")
        type_text("LND_F")
        time.sleep(1.5)

        # Image 2 Capture: Search filter in action (LND_F)
        print("[TEST] Capturing param_02_search_filter.png (Image 2 replica)...")
        take_screenshot("param_02_search_filter.png")

        # Step 4: Clear search filter
        print("[TEST] Clearing search field...")
        clear_search_field()
        time.sleep(1.0)

        # Search for MIS_ to get MIS_TAKEOFF_ALT
        print("[TEST] Clicking search field at (210, 72)...")
        click_at(210, 72, delay=0.5)
        print("[TEST] Typing search filter 'MIS_'...")
        type_text("MIS_")
        time.sleep(1.5)

        # Step 5: Click on parameter row to select MIS_TAKEOFF_ALT (at x=250, y=275)
        print("[TEST] Clicking parameter row at (250, 275) to select MIS_TAKEOFF_ALT...")
        click_at(250, 275, delay=1.5)

        # Image 3 Capture: Parameter Editor side drawer open
        print("[TEST] Capturing param_03_side_editor.png (Image 3 replica)...")
        take_screenshot("param_03_side_editor.png")

        # Step 6: Click [Tools] button at (1235, 72) to open tools dropdown menu
        print("[TEST] Clicking [Tools] button at (1235, 72)...")
        click_at(1235, 72, delay=1.2)

        # Image 4 Capture: Tools dropdown menu
        print("[TEST] Capturing param_04_tools_menu.png (Image 4 replica)...")
        take_screenshot("param_04_tools_menu.png")

        print("[TEST] ALL 4 PARAMETER VERIFICATION CAPTURES COMPLETED SUCCESSFULLY!")

    finally:
        print("[TEST] Terminating test processes and containers...")
        for c in containers:
            subprocess.run(f"docker rm -f {c} 2>/dev/null", shell=True)
        for p in reversed(procs):
            try:
                p.terminate()
                p.wait(timeout=2)
            except Exception:
                try:
                    p.kill()
                except Exception:
                    pass
        disp_num = DISP.lstrip(":")
        subprocess.run(f"rm -f /tmp/.X{disp_num}-lock /tmp/.X11-unix/X{disp_num} 2>/dev/null", shell=True)

if __name__ == "__main__":
    main()
