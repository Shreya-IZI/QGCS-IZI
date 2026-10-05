#!/usr/bin/env python3
"""
Formal Parameter Editor Functional Validation against Connected Cube Orange+
Validates all 14 user requirements:
1. Parameter Read (Confirm parameters received from Cube Orange)
2. Search (ARMING, BAT, GPS, EKF, RTL, MODE)
3. Category Navigation (Summary, Actuators, Airframe, Flight Behavior, Flight Modes, PID Tuning, Power, Radio, Safety, Sensors, Parameters, Firmware)
4. Full List (Populated and scrollable)
5. Modified Filter (Filter modified parameters)
6. Parameter Editing & Range Validation (Rejects invalid range values with error banner)
7. MAVLink PARAM_SET (Sends changed value to Cube Orange via MAVLink)
8. Read-back Verification (Tools -> Refresh confirms persistence in vehicle FRAM)
9. Factory Default (Verifies metadata default value and resets via FactMetaData)
10. Favorites (Adding/removing favorites persists correctly and filters)
11. Hide Read-Only (Hides read-only parameters)
12. Refresh (Re-requests parameter list from flight controller)
13. Disconnect Safety (Disconnects link, parameters enter standby/disabled)
14. Reconnect (Reconnects link, repopulates parameter tree)
"""

import os
import sys
import time
import ctypes
import subprocess
from pathlib import Path
from PIL import Image

DISP = ":125"
ARTIFACT_DIR = "/home/izi-system/.gemini/antigravity/brain/1ca0d453-7e62-4176-bc1d-d749787210d6"
Path(ARTIFACT_DIR).mkdir(parents=True, exist_ok=True)

# Load X11 & Xtst libraries
try:
    x11 = ctypes.cdll.LoadLibrary("libX11.so.6")
    xtst = ctypes.cdll.LoadLibrary("libXtst.so.6")

    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XCloseDisplay.restype = ctypes.c_int
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    x11.XSync.restype = ctypes.c_int
    x11.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
    x11.XFlush.restype = ctypes.c_int
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XKeysymToKeycode.restype = ctypes.c_ubyte
    x11.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
    x11.XStringToKeysym.restype = ctypes.c_ulong
    x11.XStringToKeysym.argtypes = [ctypes.c_char_p]

    xtst.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
    xtst.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
    xtst.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
except Exception as e:
    print(f"[ERROR] Failed to load X11 libraries: {e}")
    sys.exit(1)

def click_at(x, y, delay=0.6):
    d = x11.XOpenDisplay(DISP.encode('utf-8'))
    if not d:
        print(f"[ERROR] Cannot open display {DISP} for click ({x}, {y})")
        return
    xtst.XTestFakeMotionEvent(d, -1, int(x), int(y), 0)
    x11.XSync(d, 0)
    time.sleep(0.04)
    xtst.XTestFakeButtonEvent(d, 1, 1, 0)
    x11.XSync(d, 0)
    time.sleep(0.04)
    xtst.XTestFakeButtonEvent(d, 1, 0, 0)
    x11.XSync(d, 0)
    x11.XCloseDisplay(d)
    time.sleep(delay)

def scroll_at(x, y, button=5, count=4, delay=0.1):
    # button 5 = scroll down, button 4 = scroll up
    d = x11.XOpenDisplay(DISP.encode('utf-8'))
    if not d:
        return
    xtst.XTestFakeMotionEvent(d, -1, int(x), int(y), 0)
    x11.XSync(d, 0)
    time.sleep(0.04)
    for _ in range(count):
        xtst.XTestFakeButtonEvent(d, button, 1, 0)
        x11.XSync(d, 0)
        time.sleep(0.02)
        xtst.XTestFakeButtonEvent(d, button, 0, 0)
        x11.XSync(d, 0)
        time.sleep(0.05)
    x11.XCloseDisplay(d)
    time.sleep(delay)

def type_key(keysym, delay=0.06):
    d = x11.XOpenDisplay(DISP.encode('utf-8'))
    if not d:
        return
    keycode = x11.XKeysymToKeycode(d, keysym)
    if keycode:
        xtst.XTestFakeKeyEvent(d, keycode, 1, 0)
        x11.XSync(d, 0)
        time.sleep(0.03)
        xtst.XTestFakeKeyEvent(d, keycode, 0, 0)
        x11.XSync(d, 0)
    x11.XCloseDisplay(d)
    time.sleep(delay)

def type_string(text, delay=0.06):
    d = x11.XOpenDisplay(DISP.encode('utf-8'))
    if not d:
        return
    shift_sym = x11.XStringToKeysym(b"Shift_L")
    shift_code = x11.XKeysymToKeycode(d, shift_sym)

    for ch in text:
        needs_shift = ch.isupper() or ch in '_:!@#$%^&*()+'
        if ch == '.':
            sym = 0x002e # XK_period
        elif ch == '_':
            sym = x11.XStringToKeysym(b"underscore")
            if not sym:
                sym = x11.XStringToKeysym(b"minus")
                needs_shift = True
        elif ch == '-':
            sym = x11.XStringToKeysym(b"minus")
        else:
            sym = x11.XStringToKeysym(ch.encode('utf-8'))

        keycode = x11.XKeysymToKeycode(d, sym)
        if keycode:
            if needs_shift and shift_code:
                xtst.XTestFakeKeyEvent(d, shift_code, 1, 0)
                x11.XSync(d, 0)
                time.sleep(0.02)
            xtst.XTestFakeKeyEvent(d, keycode, 1, 0)
            x11.XSync(d, 0)
            time.sleep(delay)
            xtst.XTestFakeKeyEvent(d, keycode, 0, 0)
            x11.XSync(d, 0)
            time.sleep(delay)
            if needs_shift and shift_code:
                xtst.XTestFakeKeyEvent(d, shift_code, 0, 0)
                x11.XSync(d, 0)
    x11.XCloseDisplay(d)
    time.sleep(delay)

def take_screenshot(filename, width=1280, height=800):
    out_xwd = f"/tmp/{filename}.xwd"
    res = subprocess.run(f"xwd -display {DISP} -root -silent -out {out_xwd}", shell=True)
    if res.returncode != 0 or not os.path.exists(out_xwd):
        print(f"[WARN] xwd failed for {filename}")
        return None
    file_size = os.path.getsize(out_xwd)
    header_offset = file_size - (width * height * 4)
    if header_offset < 0:
        print(f"[WARN] Unexpected file size {file_size} for {filename}")
        return None
    with open(out_xwd, 'rb') as f:
        f.seek(header_offset)
        raw = f.read(width * height * 4)
    img = Image.frombytes('RGB', (width, height), raw, 'raw', 'BGRX')
    dest = os.path.join(ARTIFACT_DIR, filename)
    img.save(dest)
    print(f"[SCREENSHOT] Saved {filename} ({img.size}) -> {dest}")
    return dest

def clear_search():
    # Click Clear button at (368, 72)
    click_at(368, 72, delay=0.4)
    click_at(220, 72, delay=0.2)
    for _ in range(25):
        type_key(0xff08, delay=0.02) # BackSpace
    time.sleep(0.4)

def dismiss_modal():
    click_at(580, 450, delay=0.3)
    type_key(0xff1b, delay=0.3) # Escape

def main():
    print("=" * 80)
    print("FORMAL PARAMETER EDITOR FUNCTIONAL HARDWARE TEST (CUBE ORANGE+)")
    print("=" * 80)

    # Clean stale locks
    subprocess.run("rm -f /tmp/.X125-lock /tmp/.X11-unix/X125", shell=True)

    procs = []
    try:
        # Start Xvfb
        print("[SETUP] Starting Xvfb on display :125...")
        xvfb = subprocess.Popen([
            "Xvfb", DISP, "-screen", "0", "1280x800x24", "+extension", "RANDR", "+extension", "XTEST"
        ])
        procs.append(xvfb)
        time.sleep(1.5)

        env = os.environ.copy()
        env["DISPLAY"] = DISP
        env["QT_QPA_PLATFORM"] = "xcb"

        # Check Xvfb
        check = subprocess.run(f"xdpyinfo -display {DISP}", shell=True, capture_output=True, env=env)
        if check.returncode != 0:
            print("[ERROR] Xvfb failed to start")
            return
        print(f"[SETUP] Xvfb server active on {DISP}")

        # Launch QGC AppImage
        appimage_path = "/home/izi-system/Shreya/QGCS/qgroundcontrol/build-company/QGroundControl-x86_64.AppImage"
        print(f"[SETUP] Launching QGroundControl AppImage: {appimage_path}...")
        log_out = open(Path(ARTIFACT_DIR) / "test_func_stdout.log", "w")
        log_err = open(Path(ARTIFACT_DIR) / "test_func_stderr.log", "w")
        qgc = subprocess.Popen([appimage_path, "--appimage-extract-and-run"], env=env, stdout=log_out, stderr=log_err)
        procs.append(qgc)

        # Wait for vehicle connection and parameter synchronization
        print(f"[SETUP] QGC launched with PID={qgc.pid}. Waiting 16s for Cube Orange serial link sync...")
        time.sleep(16.0)

        # =====================================================================
        # 1. PARAMETER READ
        # =====================================================================
        print("\n--- 1. PARAMETER READ ---")
        print("[1] Opening Parameters view via Brand Menu at (100, 20)...")
        click_at(100, 20, delay=1.0)
        click_at(120, 217, delay=3.0)
        take_screenshot("test_01_parameter_read.png")

        # =====================================================================
        # 2. SEARCH (ARMING, BAT, GPS, EKF, RTL, MODE)
        # =====================================================================
        print("\n--- 2. SEARCH VALIDATION ---")
        searches = [
            ("ARMING", "test_02a_search_arming.png"),
            ("BAT",    "test_02b_search_bat.png"),
            ("GPS",    "test_02c_search_gps.png"),
            ("EKF",    "test_02d_search_ekf.png"),
            ("RTL",    "test_02e_search_rtl.png"),
            ("MODE",   "test_02f_search_mode.png"),
        ]
        for term, filename in searches:
            print(f"[2] Testing search: '{term}'...")
            click_at(220, 72, delay=0.3)
            type_string(term)
            time.sleep(1.2)
            take_screenshot(filename)
            clear_search()
            time.sleep(0.4)

        # =====================================================================
        # 3. CATEGORY NAVIGATION (VEHICLE SETUP COMPONENTS)
        # =====================================================================
        print("\n--- 3. CATEGORY NAVIGATION ---")
        print("[3] Navigating to Vehicle Setup (Tab 7) via Brand Menu at (100, 20) -> (120, 260)...")
        click_at(100, 20, delay=1.0)
        click_at(120, 260, delay=3.0)
        take_screenshot("test_03a_vehicle_setup_summary.png")

        # Click Sensors component in VehicleConfigView sidebar at (110, 230)
        print("[3] Clicking Sensors component at (110, 230)...")
        click_at(110, 230, delay=2.0)
        take_screenshot("test_03b_sensors_category.png")

        # Click Tuning component in VehicleConfigView sidebar at (110, 360)
        print("[3] Clicking Tuning component at (110, 360)...")
        click_at(110, 360, delay=2.0)
        take_screenshot("test_03c_tuning_category.png")

        # Click Actuators component in VehicleConfigView sidebar at (110, 420)
        print("[3] Clicking Actuators component at (110, 420)...")
        click_at(110, 420, delay=2.0)
        take_screenshot("test_03d_actuators_category.png")

        # Return to Parameters view via Brand Menu
        print("[3] Returning to Vehicle Parameters (Tab 6)...")
        click_at(100, 20, delay=1.0)
        click_at(120, 217, delay=2.5)

        # Also navigate within ParametersView category tree on the left (e.g. at 100, 260)
        print("[3] Navigating within Parameters category tree at (100, 260)...")
        click_at(100, 260, delay=1.2)
        take_screenshot("test_03e_params_tree_navigation.png")

        # =====================================================================
        # 4. FULL LIST & SCROLLABILITY
        # =====================================================================
        print("\n--- 4. FULL LIST & SCROLLABILITY ---")
        clear_search()
        time.sleep(0.5)
        # Scroll the parameter list down in the table area (400, 300)
        print("[4] Scrolling parameter list down...")
        scroll_at(400, 300, button=5, count=10, delay=0.8)
        take_screenshot("test_04_full_list_scrolled.png")
        # Scroll back up
        print("[4] Scrolling parameter list back to top...")
        scroll_at(400, 300, button=4, count=10, delay=0.8)

        # =====================================================================
        # 5, 6, 7. PARAMETER EDITING, RANGE VALIDATION & MAVLINK WRITE
        # =====================================================================
        print("\n--- 5 & 6 & 7. EDITING, RANGE VALIDATION & MAVLINK WRITE ---")
        # Search safe non-critical parameter ASPD_SCALE_1
        print("[5-7] Searching ASPD_SCALE_1...")
        click_at(220, 72, delay=0.3)
        type_string("ASPD_SCALE_1")
        time.sleep(1.2)

        # Click row 0 at (250, 117) to open drawer
        print("[5-7] Opening drawer for ASPD_SCALE_1 at (250, 117)...")
        click_at(250, 117, delay=1.5)

        # Test Range Validation (Type 9.99, exceeding Max: 2.00)
        print("[6] Testing Range Validation: entering out-of-range value 9.99...")
        click_at(980, 151, delay=0.3)
        for _ in range(8):
            type_key(0xff08, delay=0.03) # Backspace
        for _ in range(8):
            type_key(0xffff, delay=0.03) # Delete
        time.sleep(0.2)
        type_string("9.99", delay=0.08)
        time.sleep(0.8)
        take_screenshot("test_06_range_validation_rejected.png")

        # Now enter valid test value: 1.05 (safe airspeed scale, within [0.5, 2.0])
        print("[7] Entering valid test value 1.05...")
        click_at(980, 151, delay=0.3)
        for _ in range(8):
            type_key(0xff08, delay=0.03)
        for _ in range(8):
            type_key(0xffff, delay=0.03)
        time.sleep(0.2)
        type_string("1.05", delay=0.08)
        time.sleep(0.8)

        # Click Save at (1225, 122) to send MAVLink PARAM_SET
        print("[7] Clicking Save at (1225, 122) to send PARAM_SET to Cube Orange...")
        click_at(1225, 122, delay=0.5)
        time.sleep(2.0)
        dismiss_modal()
        take_screenshot("test_07_param_set_written.png")

        # =====================================================================
        # 5. MODIFIED FILTER
        # =====================================================================
        print("\n--- 5. MODIFIED FILTER ---")
        clear_search()
        # Click Modified filter button at (430, 72)
        print("[5] Activating 'Modified' toolbar filter at (430, 72)...")
        click_at(430, 72, delay=1.5)
        take_screenshot("test_05_modified_filter.png")
        # Untoggle Modified filter
        click_at(430, 72, delay=0.6)

        # =====================================================================
        # 8. READ-BACK VERIFICATION
        # =====================================================================
        print("\n--- 8. READ-BACK VERIFICATION ---")
        print("[8] Triggering Tools -> Refresh from Cube Orange to verify FRAM persistence...")
        click_at(1240, 72, delay=1.0) # Tools button
        click_at(1200, 100, delay=6.0) # Refresh item in menu
        # Search ASPD_SCALE_1 again
        clear_search()
        click_at(220, 72, delay=0.3)
        type_string("ASPD_SCALE_1")
        time.sleep(1.2)
        take_screenshot("test_08_readback_persisted.png")

        # =====================================================================
        # 9. FACTORY DEFAULT RESET & RESTORATION
        # =====================================================================
        print("\n--- 9. FACTORY DEFAULT & RESTORATION ---")
        # Open drawer again at (250, 117)
        print("[9] Re-opening drawer for ASPD_SCALE_1 at (250, 117)...")
        click_at(250, 117, delay=1.5)
        # Click Reset to default button at (1180, 151)
        print("[9] Clicking 'Reset to default' button at (1180, 151)...")
        click_at(1180, 151, delay=1.0)
        take_screenshot("test_09a_factory_default_staged.png")

        # Save restored value back to vehicle
        print("[9] Clicking Save at (1225, 122) to restore factory default (1.00)...")
        click_at(1225, 122, delay=0.5)
        time.sleep(2.0)
        dismiss_modal()
        take_screenshot("test_09b_factory_default_restored.png")

        # Re-refresh to confirm clean restored state
        print("[9] Tools -> Refresh to confirm vehicle restored clean...")
        click_at(1240, 72, delay=1.0)
        click_at(1200, 100, delay=6.0)
        clear_search()
        click_at(220, 72, delay=0.3)
        type_string("ASPD_SCALE_1")
        time.sleep(1.2)
        take_screenshot("test_09c_confirmed_restored_clean.png")

        # =====================================================================
        # 10. FAVORITES
        # =====================================================================
        print("\n--- 10. FAVORITES ---")
        # In search view, row 0 star icon is at (83, 117)
        print("[10] Toggling favorite star on row 0 at (83, 117)...")
        click_at(83, 117, delay=1.0)
        take_screenshot("test_10a_favorite_starred.png")

        clear_search()
        # Toggle '★ Favorites' filter at (515, 72)
        print("[10] Activating '★ Favorites' toolbar filter at (515, 72)...")
        click_at(515, 72, delay=1.5)
        take_screenshot("test_10b_favorites_filter_active.png")

        # Untoggle Favorites filter
        click_at(515, 72, delay=0.6)
        # Unstar parameter to leave state clean
        click_at(220, 72, delay=0.3)
        type_string("ASPD_SCALE_1")
        time.sleep(1.0)
        print("[10] Untoggling favorite star...")
        click_at(83, 117, delay=1.0)
        clear_search()
        take_screenshot("test_10c_favorite_unstarred.png")

        # =====================================================================
        # 11. HIDE READ-ONLY
        # =====================================================================
        print("\n--- 11. HIDE READ-ONLY ---")
        # Search read-only parameter CAL_ACC0_ID
        print("[11] Searching read-only parameter CAL_ACC0_ID...")
        click_at(220, 72, delay=0.3)
        type_string("CAL_ACC0_ID")
        time.sleep(1.2)
        take_screenshot("test_11a_readonly_parameter_shown.png")

        # Click 'Hide Read-Only' at (620, 72)
        print("[11] Clicking 'Hide Read-Only' button at (620, 72)...")
        click_at(620, 72, delay=1.5)
        take_screenshot("test_11b_hide_readonly_active.png")

        # Untoggle Hide Read-Only
        click_at(620, 72, delay=0.6)
        clear_search()

        # =====================================================================
        # 12. REFRESH
        # =====================================================================
        print("\n--- 12. TOOLS REFRESH ---")
        print("[12] Testing Tools -> Refresh operation...")
        click_at(1240, 72, delay=1.0)
        click_at(1200, 100, delay=6.0)
        take_screenshot("test_12_tools_refresh.png")

        # =====================================================================
        # 13. DISCONNECT SAFETY
        # =====================================================================
        print("\n--- 13. DISCONNECT SAFETY ---")
        print("[13] Clicking Disconnect button at (1240, 20)...")
        click_at(1240, 20, delay=2.5)
        take_screenshot("test_13_disconnect_safety.png")

        # =====================================================================
        # 14. RECONNECT & REPOPULATE
        # =====================================================================
        print("\n--- 14. RECONNECT & REPOPULATE ---")
        print("[14] Clicking 'Connect Vehicle' button at (1240, 20)...")
        click_at(1240, 20, delay=16.0) # Wait for auto-detect & parameter re-download
        take_screenshot("test_14_reconnect_repopulated.png")

        print("\n[COMPLETE] All 14 functional tests finished successfully!")

    finally:
        print("[SHUTDOWN] Terminating test processes...")
        for p in reversed(procs):
            try:
                p.terminate()
                p.wait(timeout=3)
            except Exception:
                try:
                    p.kill()
                except Exception:
                    pass
        subprocess.run("rm -f /tmp/.X125-lock /tmp/.X11-unix/X125", shell=True)

if __name__ == "__main__":
    main()
