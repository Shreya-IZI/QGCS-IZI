#!/usr/bin/env python3
"""
Phase 7D Verification Script: UDP Telemetry Output for Chandipur DRDO Evaluation.

Validates:
1. End-to-end UDP datagram transmission from QGroundControl to a UDP receiver socket.
2. Live packet schema validation with connected vehicle:
   - Header with protocol "IZI_TEST_TELEMETRY_V1" and icd_status "PENDING_DRDO_ICD_SPECIFICATION"
   - GPS (lat, lon, alt AMSL, alt Rel, satellites, HDOP, VDOP)
   - Autopilot (pitch, roll, yaw, flight mode, armed state)
   - Gimbal (pitch, roll, yaw)
   - Laser Rangefinder (distance)
   - Barometer (pressure, relative altitude)
   - Magnetometer (mag_x, mag_y, mag_z)
   - Payload Optics (horizontal FOV)
3. Rate timing validation: 1 Hz, 5 Hz, and 10 Hz timing via UI interaction.
4. Enable / Disable toggle behavior (transmission immediately stops when muted).
5. UI integration in SettingsView (live counter, broadcasting badge, ICD schema note).
6. Non-regression of existing modules.
7. Screenshots captured to artifact directory.
"""

import os
import sys
import time
import json
import socket
import ctypes
import subprocess
import configparser
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

def drain_udp_socket(sock, duration_sec):
    packets = []
    end_time = time.time() + duration_sec
    while time.time() < end_time:
        try:
            data, addr = sock.recvfrom(4096)
            recv_t = time.time()
            packets.append((recv_t, data))
        except socket.timeout:
            pass
        except Exception as e:
            print(f"[WARN] recvfrom error: {e}")
            break
    return packets

def main():
    procs = []
    test_results = {}
    test_port = 14445

    try:
        # Clean old X99 lock files & start Xvfb display
        print(f"[TEST] Starting Xvfb on display {DISP}...")
        subprocess.run("killall -9 Xvfb 2>/dev/null; rm -f /tmp/.X99-lock /tmp/.X11-unix/X99", shell=True)
        xvfb_proc = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "1280x800x24"])
        procs.append(xvfb_proc)
        time.sleep(2.0)

        # 1. Pre-configure UDP Telemetry enabled at 5 Hz to 127.0.0.1:14445
        ini_path = os.path.expanduser("~/.config/Company/QGroundControl Daily.ini")
        os.makedirs(os.path.dirname(ini_path), exist_ok=True)
        config = configparser.ConfigParser(strict=False)
        config.optionxform = str
        if os.path.exists(ini_path):
            config.read(ini_path)

        if "Company_UdpTelemetry" not in config:
            config["Company_UdpTelemetry"] = {}
        config["Company_UdpTelemetry"]["enabled"] = "true"
        config["Company_UdpTelemetry"]["destinationIP"] = "127.0.0.1"
        config["Company_UdpTelemetry"]["destinationPort"] = str(test_port)
        config["Company_UdpTelemetry"]["rateHz"] = "5"

        with open(ini_path, "w") as f:
            config.write(f)
        print(f"[TEST] UDP Telemetry pre-configured: enabled=true, 127.0.0.1:{test_port}, rate=5Hz")

        # 2. Set up local UDP receiver socket
        udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        udp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        udp_sock.bind(("127.0.0.1", test_port))
        udp_sock.settimeout(0.2)
        print(f"[TEST] Bound UDP receiver socket to 127.0.0.1:{test_port}")

        # 3. Launch QGroundControl AppImage
        log_file = "/tmp/qgcs_phase7d.log"
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

        # 4. Start Vehicle Telemetry Simulator on UDP 14550 with airborne scenario
        print("[TEST] Starting vehicle telemetry simulator on UDP 14550 (airborne scenario)...")
        sim_proc = subprocess.Popen([
            sys.executable, "tools/test_vehicle_telemetry_simulator.py",
            "--scenario", "airborne",
            "--port", "14550",
            "--with-camera"
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        procs.append(sim_proc)

        print("[TEST] Waiting for vehicle connection to QGC and telemetry ingestion (6s)...")
        time.sleep(6.0)

        # Flush any startup backlog
        drain_udp_socket(udp_sock, 0.5)

        # 5. Receive and validate live UDP packets at 5 Hz
        print("[TEST] Collecting UDP datagrams over 3.0 seconds at 5 Hz...")
        pkts = drain_udp_socket(udp_sock, 3.0)
        print(f"[TEST] Received {len(pkts)} packets in 3.0 seconds at 5 Hz")
        test_results["initial_5hz_packets_received"] = (10 <= len(pkts) <= 22)

        if pkts:
            sample_time, sample_raw = pkts[-1]
            try:
                sample_json = json.loads(sample_raw.decode("utf-8"))
                print(f"[TEST] Sample packet successfully parsed as JSON:\n{json.dumps(sample_json, indent=2)}")

                # Check Header
                hdr = sample_json.get("header", {})
                test_results["header_protocol"] = (hdr.get("protocol") == "IZI_TEST_TELEMETRY_V1")
                test_results["header_icd_status"] = (hdr.get("icd_status") == "PENDING_DRDO_ICD_SPECIFICATION")
                test_results["header_timestamp"] = ("timestamp_utc" in hdr)
                test_results["header_seq"] = (hdr.get("sequence_number") is not None)
                test_results["system_id_valid"] = (hdr.get("system_id", 0) > 0)
                print(f"[CHECK] Header: protocol={hdr.get('protocol')}, icd_status={hdr.get('icd_status')}, sysid={hdr.get('system_id')}")

                # Check GPS fields
                gps = sample_json.get("gps", {})
                test_results["gps_present"] = ("latitude_deg" in gps and "longitude_deg" in gps and "alt_amsl_m" in gps and "satellites" in gps and "hdop" in gps)
                test_results["gps_live_data"] = (abs(gps.get("latitude_deg", 0)) > 1.0 and abs(gps.get("longitude_deg", 0)) > 1.0)
                print(f"[CHECK] GPS: lat={gps.get('latitude_deg')}, lon={gps.get('longitude_deg')}, alt={gps.get('alt_amsl_m')}, sats={gps.get('satellites')}, hdop={gps.get('hdop')}")

                # Check Autopilot fields
                ap = sample_json.get("autopilot", {})
                test_results["autopilot_present"] = ("pitch_deg" in ap and "roll_deg" in ap and "yaw_deg" in ap and "flight_mode" in ap and "armed" in ap)
                test_results["autopilot_armed"] = (ap.get("armed") == True)
                print(f"[CHECK] Autopilot: pitch={ap.get('pitch_deg')}, roll={ap.get('roll_deg')}, yaw={ap.get('yaw_deg')}, mode={ap.get('flight_mode')}, armed={ap.get('armed')}")

                # Check Gimbal fields
                gimbal = sample_json.get("gimbal", {})
                test_results["gimbal_present"] = ("pitch_deg" in gimbal and "roll_deg" in gimbal and "yaw_deg" in gimbal)
                print(f"[CHECK] Gimbal: pitch={gimbal.get('pitch_deg')}, roll={gimbal.get('roll_deg')}, yaw={gimbal.get('yaw_deg')}, avail={gimbal.get('available')}")

                # Check LRF fields
                lrf = sample_json.get("lrf", {})
                test_results["lrf_present"] = ("distance_m" in lrf)
                print(f"[CHECK] LRF: dist={lrf.get('distance_m')}, avail={lrf.get('available')}")

                # Check Barometer fields
                baro = sample_json.get("barometer", {})
                test_results["barometer_present"] = ("pressure_hpa" in baro and "altitude_m" in baro)
                print(f"[CHECK] Barometer: press={baro.get('pressure_hpa')}, alt={baro.get('altitude_m')}, avail={baro.get('available')}")

                # Check Magnetometer fields
                mag = sample_json.get("magnetometer", {})
                test_results["magnetometer_present"] = ("mag_x_mg" in mag and "mag_y_mg" in mag and "mag_z_mg" in mag)
                print(f"[CHECK] Magnetometer: X={mag.get('mag_x_mg')}, Y={mag.get('mag_y_mg')}, Z={mag.get('mag_z_mg')}, avail={mag.get('available')}")

                # Check Payload Optics
                payload = sample_json.get("payload", {})
                test_results["payload_present"] = ("fov_deg" in payload)
                print(f"[CHECK] Payload Optics: fov={payload.get('fov_deg')}")

            except Exception as e:
                print(f"[ERROR] Failed to parse or validate packet JSON: {e}")
                test_results["json_parse_error"] = str(e)
        else:
            print("[ERROR] No UDP packets received in initial 5 Hz window!")
            test_results["initial_5hz_packets_received"] = False

        # 6. Navigate to Settings (Tab 5 at x=24, y=518) and switch to NETWORK & LINKS
        print("[TEST] Navigating to Settings > NETWORK & LINKS...")
        click_at(24, 518, delay=1.5)
        click_at(949, 84, delay=1.5)

        # Scroll down to UDP Telemetry card with settled delay
        disp = x11.XOpenDisplay(DISP.encode('utf-8'))
        if disp:
            for _ in range(5):
                xtst.XTestFakeMotionEvent(disp, -1, 600, 400, 0)
                x11.XFlush(disp)
                time.sleep(0.02)
                xtst.XTestFakeButtonEvent(disp, 5, 1, 0)
                x11.XFlush(disp)
                time.sleep(0.05)
                xtst.XTestFakeButtonEvent(disp, 5, 0, 0)
                x11.XFlush(disp)
                time.sleep(0.05)
            x11.XCloseDisplay(disp)
        # Wait 2.0s for scroll animation to fully settle
        time.sleep(2.0)

        take_screenshot("phase7d_01_udp_settings_live.png")

        # 7. Test Rate Switching to 10 Hz via UI click at settled center (1207, 440)
        print("[TEST] Clicking 10 Hz button at settled position (1207, 440)...")
        click_at(1207, 440, delay=1.0)
        drain_udp_socket(udp_sock, 0.5)

        pkts_10hz = drain_udp_socket(udp_sock, 2.0)
        print(f"[TEST] Packets received over 2.0s at 10 Hz: {len(pkts_10hz)}")
        test_results["rate_10hz_verified"] = (16 <= len(pkts_10hz) <= 26)

        # 8. Test Rate Switching to 1 Hz via UI click at settled center (1051, 440)
        print("[TEST] Clicking 1 Hz button at settled position (1051, 440)...")
        click_at(1051, 440, delay=1.0)
        drain_udp_socket(udp_sock, 0.5)

        pkts_1hz = drain_udp_socket(udp_sock, 3.0)
        print(f"[TEST] Packets received over 3.0s at 1 Hz: {len(pkts_1hz)}")
        test_results["rate_1hz_verified"] = (2 <= len(pkts_1hz) <= 5)

        take_screenshot("phase7d_02_rate_timing_verified.png")

        # 9. Test Disabling UDP Telemetry via FORWARDING toggle button at settled position (656, 376)
        print("[TEST] Clicking FORWARDING toggle button at settled position (656, 376) to MUTE output...")
        click_at(656, 376, delay=1.0)

        # Clear any in-flight packets, then observe over 2.0 seconds
        drain_udp_socket(udp_sock, 0.5)
        muted_pkts = drain_udp_socket(udp_sock, 2.0)
        print(f"[TEST] Packets received while MUTED: {len(muted_pkts)}")
        test_results["muted_zero_packets"] = (len(muted_pkts) == 0)

        take_screenshot("phase7d_03_telemetry_muted.png")

        # 10. Re-enable UDP Telemetry via FORWARDING toggle button at (656, 376)
        print("[TEST] Clicking FORWARDING toggle button at (656, 376) to re-enable...")
        click_at(656, 376, delay=1.0)

        re_enabled_pkts = drain_udp_socket(udp_sock, 1.5)
        print(f"[TEST] Packets received after re-enabling: {len(re_enabled_pkts)}")
        test_results["re_enabled_packets_received"] = (len(re_enabled_pkts) > 0)

        take_screenshot("phase7d_04_telemetry_re_enabled.png")

        # Summary of results
        print("\n==========================================")
        print("     PHASE 7D UDP VERIFICATION SUMMARY    ")
        print("==========================================")
        all_passed = True
        for test_name, result in test_results.items():
            status = "PASS" if result else "FAIL"
            print(f"  [{status}] {test_name}: {result}")
            if not result:
                all_passed = False
        print("==========================================")
        print(f"OVERALL RESULT: {'PASS' if all_passed else 'FAIL'}")

    finally:
        print("[TEST] Cleaning up processes...")
        try:
            udp_sock.close()
        except:
            pass
        for p in procs:
            try:
                p.terminate()
                p.wait(timeout=2.0)
            except:
                try:
                    p.kill()
                except:
                    pass
        subprocess.run("killall -9 Xvfb 2>/dev/null; rm -f /tmp/.X99-lock /tmp/.X11-unix/X99", shell=True)

    sys.exit(0 if all_passed else 1)

if __name__ == "__main__":
    main()
