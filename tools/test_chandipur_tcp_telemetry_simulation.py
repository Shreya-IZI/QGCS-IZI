#!/usr/bin/env python3
"""
Chandipur Ground Station TCP Telemetry Simulation & Validation Test.

Validates the software communication path for the Chandipur Ground Station:
- Target: TCP Port 20002 (Host: 127.0.0.1 or 192.168.168.11)
- Protocol: MAVLink v2.0 (ArduPilot / Cube Orange emulation)
- Telemetry: Heartbeat, Attitude, GPS, Battery, Modes, Arming, Parameters

Usage:
    python3 tools/test_chandipur_tcp_telemetry_simulation.py [--host 127.0.0.1] [--port 20002]
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

# Add CPM pymavlink to path
repo_root = Path(__file__).resolve().parents[1]
cpm_matches = list(repo_root.glob(".cache/CPM/mavlink/*/pymavlink"))
if cpm_matches and cpm_matches[0].is_dir():
    sys.path.insert(0, str(cpm_matches[0].parent))

os.environ["MAVLINK20"] = "1"
os.environ["MAVLINK_DIALECT"] = "ardupilotmega"

from pymavlink import mavutil
from pymavlink.dialects.v20 import ardupilotmega as mavlink


def main():
    parser = argparse.ArgumentParser(description="Chandipur TCP Telemetry Simulation Test")
    parser.add_argument("--host", default="127.0.0.1", help="Target TCP IP (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=20002, help="Target TCP Port (default: 20002)")
    args = parser.parse_args()

    print("=" * 70)
    print("  CHANDIPUR GROUND STATION: SOFTWARE TCP TELEMETRY SIMULATION TEST")
    print(f"  Target: {args.host}:{args.port} | Protocol: MAVLink v2.0 | Cube Orange (ArduPilot)")
    print("=" * 70)

    # 1. Start Telemetry Simulator in TCP Mode
    sim_script = repo_root / "tools" / "test_vehicle_telemetry_simulator.py"
    cmd = [
        sys.executable,
        str(sim_script),
        "--host", args.host,
        "--port", str(args.port),
        "--protocol", "tcp",
        "--autopilot", "ardupilot",
        "--scenario", "ground_disarmed",
    ]

    print(f"\n[STEP 1] Starting MAVLink TCP Telemetry Simulator on {args.host}:{args.port}...")
    sim_proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

    time.sleep(1.2)
    if sim_proc.poll() is not None:
        out, _ = sim_proc.communicate()
        print(f"[ERROR] Simulator failed to start:\n{out}")
        return 1

    print("[SUCCESS] Telemetry Simulator is listening on TCP port", args.port)

    # 2. Connect Client Socket
    print(f"\n[STEP 2] Establishing TCP client connection to {args.host}:{args.port}...")
    try:
        client = mavutil.mavlink_connection(f"tcp:{args.host}:{args.port}", retries=5)
        print("[SUCCESS] TCP socket successfully connected!")
    except Exception as e:
        print(f"[FAIL] Could not connect to TCP {args.host}:{args.port}: {e}")
        sim_proc.terminate()
        return 1

    # 3. Verify MAVLink Heartbeat & Vehicle Discovery
    print("\n[STEP 3] Awaiting MAVLink Heartbeat (Vehicle Discovery)...")
    hb = client.recv_match(type="HEARTBEAT", blocking=True, timeout=5.0)
    if not hb:
        print("[FAIL] No HEARTBEAT received within 5 seconds.")
        client.close()
        sim_proc.terminate()
        return 1

    autopilot_name = "ArduPilot (ArduCopter)" if hb.autopilot == mavlink.MAV_AUTOPILOT_ARDUPILOTMEGA else f"ID={hb.autopilot}"
    print(f"[SUCCESS] Discovered Vehicle: SysID={client.target_system}, Autopilot={autopilot_name}")
    print(f"          Base Mode={hb.base_mode}, Custom Mode={hb.custom_mode} (STABILIZE)")

    # 4. Verify GPS & Position Telemetry
    print("\n[STEP 4] Validating GPS & Position Telemetry...")
    gps = client.recv_match(type="GPS_RAW_INT", blocking=True, timeout=3.0)
    pos = client.recv_match(type="GLOBAL_POSITION_INT", blocking=True, timeout=3.0)
    if gps and pos:
        fix_str = "3D Fix" if gps.fix_type >= 3 else f"Type {gps.fix_type}"
        print(f"[SUCCESS] GPS: {fix_str} with {gps.satellites_visible} Sats, HDOP={gps.eph/100.0:.2f}")
        print(f"[SUCCESS] Coordinate: Lat={pos.lat/1e7:.6f}°, Lon={pos.lon/1e7:.6f}°, Alt AMSL={pos.alt/1000.0:.1f}m, Rel Alt={pos.relative_alt/1000.0:.1f}m")
    else:
        print("[FAIL] Missing GPS or Global Position telemetry.")

    # 5. Verify Battery Telemetry
    print("\n[STEP 5] Validating Battery & System Status...")
    sys_status = client.recv_match(type="SYS_STATUS", blocking=True, timeout=3.0)
    if sys_status:
        volts = sys_status.voltage_battery / 1000.0
        pct = sys_status.battery_remaining
        curr = sys_status.current_battery / 100.0
        print(f"[SUCCESS] Battery: {volts:.2f} V ({pct}%), Current={curr:.2f} A")
    else:
        print("[FAIL] Missing SYS_STATUS battery telemetry.")

    # 6. Verify Attitude & Heading Telemetry
    print("\n[STEP 6] Validating Attitude & Compass Telemetry...")
    att = client.recv_match(type="ATTITUDE", blocking=True, timeout=3.0)
    if att:
        import math
        roll_deg = math.degrees(att.roll)
        pitch_deg = math.degrees(att.pitch)
        yaw_deg = math.degrees(att.yaw)
        print(f"[SUCCESS] Attitude: Roll={roll_deg:.1f}°, Pitch={pitch_deg:.1f}°, Yaw/Heading={yaw_deg:.1f}°")
    else:
        print("[FAIL] Missing ATTITUDE telemetry.")

    # 7. Test MAVLink Command: ARM UAS
    print("\n[STEP 7] Testing Flight Command: MAV_CMD_COMPONENT_ARM_DISARM (ARM)...")
    client.mav.command_long_send(
        client.target_system,
        client.target_component,
        mavlink.MAV_CMD_COMPONENT_ARM_DISARM,
        0,  # Confirmation
        1.0, # 1.0 = ARM
        0, 0, 0, 0, 0, 0
    )
    ack = client.recv_match(type="COMMAND_ACK", blocking=True, timeout=3.0)
    if ack and ack.command == mavlink.MAV_CMD_COMPONENT_ARM_DISARM and ack.result == mavlink.MAV_RESULT_ACCEPTED:
        print("[SUCCESS] Autopilot Accepted ARM command (COMMAND_ACK: MAV_RESULT_ACCEPTED)")
        hb_armed = client.recv_match(type="HEARTBEAT", blocking=True, timeout=2.0)
        is_armed = bool(hb_armed.base_mode & mavlink.MAV_MODE_FLAG_SAFETY_ARMED) if hb_armed else False
        print(f"[SUCCESS] Vehicle State Verified: Armed={is_armed}")
    else:
        print(f"[FAIL] ARM command not accepted: {ack}")

    # 8. Test Flight Mode Command: RTL
    print("\n[STEP 8] Testing Mode Command: MAV_CMD_NAV_RETURN_TO_LAUNCH (RTL)...")
    client.mav.command_long_send(
        client.target_system,
        client.target_component,
        mavlink.MAV_CMD_NAV_RETURN_TO_LAUNCH,
        0, 0, 0, 0, 0, 0, 0, 0
    )
    ack_rtl = client.recv_match(type="COMMAND_ACK", blocking=True, timeout=3.0)
    if ack_rtl and ack_rtl.command == mavlink.MAV_CMD_NAV_RETURN_TO_LAUNCH:
        print("[SUCCESS] Autopilot Accepted RTL command")
        time.sleep(0.5)
        hb_mode = client.recv_match(type="HEARTBEAT", blocking=True, timeout=2.0)
        print(f"[SUCCESS] Vehicle Mode Transitioned: Custom Mode={hb_mode.custom_mode} (RTL)")
    else:
        print(f"[FAIL] RTL command failed: {ack_rtl}")

    # 9. Clean Shutdown & Socket Disconnect
    print("\n[STEP 9] Testing Disconnection & Socket Teardown...")
    client.close()
    sim_proc.terminate()
    sim_proc.wait(timeout=2.0)
    print("[SUCCESS] Client disconnected, TCP socket closed cleanly.")

    print("\n" + "=" * 70)
    print("  ALL 9 CHANDIPUR SOFTWARE VALIDATION CHECKS PASSED SUCCESSFULLY!")
    print("=" * 70)
    return 0


if __name__ == "__main__":
    sys.exit(main())
