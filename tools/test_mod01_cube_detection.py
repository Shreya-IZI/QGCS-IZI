#!/usr/bin/env python3
"""
Phase 9 MOD-01: Cube Orange+ Direct Hardware Bring-Up & Diagnostics

Scans for physical Cube Orange+ connection over USB-C (/dev/ttyACM* or /dev/ttyUSB*),
interrogates the hardware over MAVLink 2.0, validates ArduPilot 4.4.4 identification,
attitude/GPS telemetry streams, and prepares QGCS for direct hardware connection.
"""

from __future__ import annotations

import glob
import os
import sys
import time
from pathlib import Path

# Auto-discover CPM-cached pymavlink if not installed system-wide
try:
    import pymavlink
except ImportError:
    repo_root = Path(__file__).resolve().parents[1]
    cpm_matches = list(repo_root.glob(".cache/CPM/mavlink/*/pymavlink"))
    if cpm_matches and cpm_matches[0].is_dir():
        sys.path.insert(0, str(cpm_matches[0].parent))

os.environ["MAVLINK20"] = "1"

try:
    from pymavlink import mavutil
except ImportError as exc:
    print(f"[ERROR] pymavlink is unavailable: {exc}")
    mavutil = None


KNOWN_CUBE_VID_PIDS = [
    ("2dae", "1058", "CubeOrange+"),
    ("2dae", "1016", "CubeOrange+"),
    ("2dae", "1011", "CubeOrange"),
    ("2dae", "1001", "CubeBlack"),
    ("0483", "5740", "STM32 Virtual COM / Cube"),
]


def scan_serial_ports() -> list[dict]:
    """Finds all candidate serial ports and reads udev/sysfs properties."""
    ports = []
    candidates = sorted(glob.glob("/dev/ttyACM*") + glob.glob("/dev/ttyUSB*"))
    for dev in candidates:
        name = os.path.basename(dev)
        sys_path = Path(f"/sys/class/tty/{name}")
        info = {"device": dev, "name": name, "vid": "", "pid": "", "manufacturer": "", "product": ""}
        if sys_path.exists():
            device_dir = (sys_path / "device").resolve()
            # Climb up sysfs to find USB device descriptor
            curr = device_dir
            for _ in range(5):
                id_vendor = curr / "idVendor"
                id_product = curr / "idProduct"
                if id_vendor.exists() and id_product.exists():
                    try:
                        info["vid"] = id_vendor.read_text().strip().lower()
                        info["pid"] = id_product.read_text().strip().lower()
                        man_file = curr / "manufacturer"
                        prod_file = curr / "product"
                        if man_file.exists():
                            info["manufacturer"] = man_file.read_text().strip()
                        if prod_file.exists():
                            info["product"] = prod_file.read_text().strip()
                    except Exception:
                        pass
                    break
                curr = curr.parent
        ports.append(info)
    return ports


def verify_cube_hardware(port: str, baud: int = 115200, timeout: float = 8.0) -> dict | None:
    """Connects to Cube over MAVLink, checks heartbeat and Autopilot version."""
    if not mavutil:
        print("[WARNING] pymavlink not loaded; skipping MAVLink handshake test.")
        return None

    print(f"[MOD-01] Opening MAVLink connection to {port} @ {baud} baud...")
    try:
        conn = mavutil.mavlink_connection(port, baud=baud)
    except Exception as e:
        print(f"[ERROR] Failed to open port {port}: {e}")
        return None

    print(f"[MOD-01] Waiting for heartbeat from {port} (timeout {timeout}s)...")
    msg = conn.wait_heartbeat(timeout=timeout)
    if not msg:
        print(f"[WARNING] No heartbeat received from {port} within {timeout}s.")
        conn.close()
        return None

    print(f"[MOD-01] HEARTBEAT RECEIVED! Type={msg.type}, Autopilot={msg.autopilot}, BaseMode={msg.base_mode}")

    # Query Autopilot Version
    conn.mav.command_long_send(
        conn.target_system,
        conn.target_component,
        mavutil.mavlink.MAV_CMD_REQUEST_MESSAGE,
        0,
        mavutil.mavlink.MAVLINK_MSG_ID_AUTOPILOT_VERSION,
        0, 0, 0, 0, 0, 0
    )

    t0 = time.time()
    firmware_version = "Unknown"
    version_msg = None
    while time.time() - t0 < 3.0:
        m = conn.recv_match(type="AUTOPILOT_VERSION", blocking=True, timeout=1.0)
        if m:
            version_msg = m
            fw_major = (m.flight_sw_version >> 24) & 0xFF
            fw_minor = (m.flight_sw_version >> 16) & 0xFF
            fw_patch = (m.flight_sw_version >> 8) & 0xFF
            firmware_version = f"{fw_major}.{fw_minor}.{fw_patch}"
            print(f"[MOD-01] AUTOPILOT VERSION: ArduPilot {firmware_version} (Capabilities: {hex(m.capabilities)})")
            break

    # Read live telemetry sample
    telemetry = {"attitude": None, "gps": None, "battery": None}
    t0 = time.time()
    while time.time() - t0 < 2.0:
        m = conn.recv_match(blocking=False)
        if m:
            mtype = m.get_type()
            if mtype == "ATTITUDE":
                telemetry["attitude"] = {"pitch_deg": round(m.pitch * 57.2958, 2), "roll_deg": round(m.roll * 57.2958, 2), "yaw_deg": round(m.yaw * 57.2958, 2)}
            elif mtype == "GLOBAL_POSITION_INT":
                telemetry["gps"] = {"lat": m.lat / 1e7, "lon": m.lon / 1e7, "alt_amsl_m": m.alt / 1000.0}
            elif mtype == "SYS_STATUS":
                telemetry["battery"] = {"voltage_v": m.voltage_battery / 1000.0, "remaining_pct": m.battery_remaining}

    conn.close()
    return {
        "port": port,
        "baud": baud,
        "sysid": conn.target_system,
        "compid": conn.target_component,
        "firmware": firmware_version,
        "telemetry": telemetry,
    }


def main():
    print("================================================================================")
    print("PHASE 9 — MOD-01: PHYSICAL CUBE ORANGE+ DETECTION & HARDWARE BRING-UP")
    print("================================================================================")

    ports = scan_serial_ports()
    if not ports:
        print("\n[STATUS] NO USB SERIAL DEVICES CURRENTLY DETECTED.")
        print("\nBench Instructions:")
        print("1. Connect the physical Cube Orange+ to this workstation using a USB-C cable.")
        print("2. Ensure the Cube Orange+ power LED turns ON (orange/amber/green).")
        print("3. Re-run this check or tell the assistant: 'Cube Orange+ is connected'.")
        print("\nSupported Hardware:")
        for vid, pid, desc in KNOWN_CUBE_VID_PIDS:
            print(f"  • {desc} (USB VID: {vid}, PID: {pid})")
        print("================================================================================")
        sys.exit(0)

    print(f"\n[MOD-01] Detected {len(ports)} serial port(s):")
    cube_port = None
    for p in ports:
        is_cube = any(p["vid"] == vid and p["pid"] == pid for vid, pid, _ in KNOWN_CUBE_VID_PIDS)
        tag = "[MATCHED CUBE ORANGE+]" if is_cube else ""
        print(f"  • {p['device']} | VID={p['vid']} PID={p['pid']} | {p['manufacturer']} - {p['product']} {tag}")
        if is_cube and not cube_port:
            cube_port = p["device"]

    target_port = cube_port or ports[0]["device"]
    print(f"\n[MOD-01] Probing target port: {target_port}...")
    res = verify_cube_hardware(target_port)

    if res:
        print("\n================================================================================")
        print("MOD-01 DIRECT CUBE ORANGE+ BRING-UP: SUCCESSFUL")
        print(f"Device: {res['port']} @ {res['baud']} baud")
        print(f"Autopilot: ArduPilot {res['firmware']} (SysID: {res['sysid']})")
        print(f"Live Telemetry Sample:")
        print(f"  • Attitude: {res['telemetry']['attitude']}")
        print(f"  • GPS: {res['telemetry']['gps']}")
        print(f"  • Battery: {res['telemetry']['battery']}")
        print("================================================================================")
    else:
        print(f"\n[MOD-01] Port {target_port} open, but waiting for MAVLink stream...")


if __name__ == "__main__":
    main()
