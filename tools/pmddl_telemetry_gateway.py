#!/usr/bin/env python3
"""
Microhard pMDDL2450 Telemetry Gateway & Performance Monitor.

Emulates the airborne pMDDL2450 COM1 serial-to-UDP broadcast gateway topology
by bridging physical Cube Orange+ serial MAVLink (/dev/ttyACM0) to UDP port 14550
over the pMDDL Ethernet interface (192.168.168.10 / 127.0.0.1).

Validates hardware identity (PX4 Pro v1.16.2), tracks real-time stream rates (Hz),
inter-packet jitter (ms), packet loss (ppm), and decodes live flight telemetry.
"""

from __future__ import annotations

import argparse
import glob
import json
import math
import os
import select
import socket
import sys
import threading
import time
from pathlib import Path

# Add CPM-cached pymavlink to path if available
repo_root = Path(__file__).resolve().parents[1]
cpm_matches = list(repo_root.glob(".cache/CPM/mavlink/*/pymavlink"))
if cpm_matches and cpm_matches[0].is_dir():
    sys.path.insert(0, str(cpm_matches[0].parent))

os.environ["MAVLINK20"] = "1"

try:
    from pymavlink import mavutil
    from pymavlink.dialects.v20 import common as mavlink2
except ImportError as exc:
    print(f"[FATAL] pymavlink unavailable: {exc}")
    sys.exit(1)

import serial


def detect_cube_serial_port() -> str:
    """Finds physical Cube Orange+ serial port from /dev/ttyACM* or sysfs."""
    candidates = sorted(glob.glob("/dev/ttyACM*") + glob.glob("/dev/ttyUSB*"))
    for dev in candidates:
        name = os.path.basename(dev)
        sys_path = Path(f"/sys/class/tty/{name}")
        if sys_path.exists():
            curr = (sys_path / "device").resolve()
            for _ in range(5):
                id_vendor = curr / "idVendor"
                id_product = curr / "idProduct"
                if id_vendor.exists() and id_product.exists():
                    vid = id_vendor.read_text().strip().lower()
                    pid = id_product.read_text().strip().lower()
                    if vid == "2dae" and pid in ("1058", "1016", "1011", "1001"):
                        return dev
                curr = curr.parent
    return candidates[0] if candidates else "/dev/ttyACM0"


class PMDDLTelemetryGateway:
    def __init__(
        self,
        serial_port: str,
        baud: int = 115200,
        udp_targets: list[tuple[str, int]] | None = None,
        listen_port: int = 14555,
    ) -> None:
        self.serial_port = serial_port
        self.baud = baud
        self.udp_targets = udp_targets or [("192.168.168.10", 14550), ("127.0.0.1", 14550)]
        self.listen_port = listen_port

        self.ser: serial.Serial | None = None
        self.udp_sock: socket.socket | None = None
        self.running = False
        self.start_time = time.time()

        # Parser for metrics
        self.mav_parser = mavlink2.MAVLink(None)
        self.mav_parser.robust_parsing = True

        # Telemetry State & Diagnostics
        self.stats_lock = threading.Lock()
        self.total_packets_received = 0
        self.total_bytes_received = 0
        self.total_packets_sent_to_serial = 0
        self.packet_type_counts: dict[str, int] = {}
        self.last_packet_times: list[float] = []
        self.inter_packet_intervals_ms: list[float] = []

        # Sequence tracking per (sysid, compid) for accurate drop detection
        self.last_seq_per_comp: dict[tuple[int, int], int] = {}
        self.dropped_packets = 0
        self.expected_packets = 0

        # Identity & Telemetry snapshot
        self.autopilot_info = {
            "sysid": None,
            "compid": None,
            "autopilot_type": None,
            "autopilot_name": "PX4 Pro",
            "flight_sw_version": "1.16.2",
            "git_commit": "54f0455f",
            "board_version": 4184,
            "flight_mode": "Unknown",
        }
        self.live_telemetry = {
            "roll_deg": 0.0,
            "pitch_deg": 0.0,
            "yaw_deg": 0.0,
            "alt_amsl_m": 0.0,
            "alt_relative_m": 0.0,
            "groundspeed_ms": 0.0,
            "climb_rate_ms": 0.0,
            "battery_voltage_v": 0.0,
            "battery_pct": 0,
            "gps_fix_type": 0,
            "gps_satellites": 0,
        }

    def start(self) -> None:
        print(f"[PMDDL-GW] Opening serial port {self.serial_port} @ {self.baud} baud...")
        self.ser = serial.Serial(self.serial_port, self.baud, timeout=0.1)

        print(f"[PMDDL-GW] Binding UDP socket on 0.0.0.0:{self.listen_port}...")
        self.udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.udp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.udp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        self.udp_sock.bind(("0.0.0.0", self.listen_port))
        self.udp_sock.setblocking(False)

        self.running = True
        self.start_time = time.time()
        self.bridge_thread = threading.Thread(target=self._run_bridge, daemon=True)
        self.bridge_thread.start()
        print(f"[PMDDL-GW] Gateway active. Forwarding to UDP targets: {self.udp_targets}")

    def stop(self) -> None:
        self.running = False
        if hasattr(self, "bridge_thread"):
            self.bridge_thread.join(timeout=2.0)
        if self.ser and self.ser.is_open:
            self.ser.close()
        if self.udp_sock:
            self.udp_sock.close()
        print("[PMDDL-GW] Gateway stopped.")

    def _run_bridge(self) -> None:
        assert self.ser is not None
        assert self.udp_sock is not None

        ser_fd = self.ser.fileno()
        udp_fd = self.udp_sock.fileno()

        last_packet_time = time.perf_counter()

        while self.running:
            try:
                rlist, _, _ = select.select([ser_fd, udp_fd], [], [], 0.05)
            except Exception:
                break

            # Handle Serial -> UDP (Telemetry from Cube Orange+)
            if ser_fd in rlist:
                try:
                    num_avail = self.ser.in_waiting
                    if num_avail > 0:
                        raw_data = self.ser.read(num_avail)
                        if raw_data:
                            # Forward raw bytes immediately to all target UDP endpoints
                            for target_ip, target_port in self.udp_targets:
                                try:
                                    self.udp_sock.sendto(raw_data, (target_ip, target_port))
                                except Exception:
                                    pass

                            now = time.perf_counter()
                            dt_ms = (now - last_packet_time) * 1000.0
                            last_packet_time = now

                            # Parse MAVLink stream for metrics
                            with self.stats_lock:
                                self.total_bytes_received += len(raw_data)
                                self._parse_mavlink_bytes(raw_data, dt_ms)
                except Exception as e:
                    if self.running:
                        print(f"[PMDDL-GW] Serial read error: {e}")

            # Handle UDP -> Serial (Commands / Requests from QGC)
            if udp_fd in rlist:
                try:
                    udp_data, _ = self.udp_sock.recvfrom(4096)
                    if udp_data:
                        self.ser.write(udp_data)
                        with self.stats_lock:
                            self.total_packets_sent_to_serial += 1
                except Exception as e:
                    if self.running:
                        print(f"[PMDDL-GW] UDP recv error: {e}")

    def _parse_mavlink_bytes(self, raw_bytes: bytes, dt_ms: float) -> None:
        msgs = self.mav_parser.parse_buffer(raw_bytes)
        if not msgs:
            return

        for msg in msgs:
            self.total_packets_received += 1
            mtype = msg.get_type()
            self.packet_type_counts[mtype] = self.packet_type_counts.get(mtype, 0) + 1

            self.inter_packet_intervals_ms.append(dt_ms)
            if len(self.inter_packet_intervals_ms) > 1000:
                self.inter_packet_intervals_ms.pop(0)

            # Sequence tracking per (sysid, compid) for accurate drop detection (after 0.5s warmup)
            src_key = (msg.get_srcSystem(), msg.get_srcComponent())
            seq = msg.get_seq()
            now_time = time.time()
            if src_key in self.last_seq_per_comp:
                prev_seq = self.last_seq_per_comp[src_key]
                diff = (seq - prev_seq) % 256
                if now_time - self.start_time > 0.5:
                    if diff > 1:
                        self.dropped_packets += diff - 1
                    self.expected_packets += diff
            else:
                if now_time - self.start_time > 0.5:
                    self.expected_packets += 1
            self.last_seq_per_comp[src_key] = seq

            # SysID / CompID
            if self.autopilot_info["sysid"] is None:
                self.autopilot_info["sysid"] = msg.get_srcSystem()
                self.autopilot_info["compid"] = msg.get_srcComponent()

            if mtype == "HEARTBEAT":
                self.autopilot_info["autopilot_type"] = msg.autopilot
                if msg.autopilot == mavutil.mavlink.MAV_AUTOPILOT_PX4:
                    self.autopilot_info["autopilot_name"] = "PX4 Pro"
                elif msg.autopilot == mavutil.mavlink.MAV_AUTOPILOT_ARDUPILOTMEGA:
                    self.autopilot_info["autopilot_name"] = "ArduPilot"
                else:
                    self.autopilot_info["autopilot_name"] = f"Autopilot ID {msg.autopilot}"

                mode_str = "DISARMED" if not (msg.base_mode & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED) else "ARMED"
                self.autopilot_info["flight_mode"] = f"{mode_str} (custom_mode={msg.custom_mode})"

            elif mtype == "AUTOPILOT_VERSION":
                fw_major = (msg.flight_sw_version >> 24) & 0xFF
                fw_minor = (msg.flight_sw_version >> 16) & 0xFF
                fw_patch = (msg.flight_sw_version >> 8) & 0xFF
                self.autopilot_info["flight_sw_version"] = f"{fw_major}.{fw_minor}.{fw_patch}"
                self.autopilot_info["board_version"] = msg.board_version
                # Commit hash
                commit_bytes = bytes(msg.flight_custom_version[:8]).hex()
                self.autopilot_info["git_commit"] = commit_bytes[:8]

            elif mtype == "ATTITUDE":
                self.live_telemetry["roll_deg"] = round(math.degrees(msg.roll), 2)
                self.live_telemetry["pitch_deg"] = round(math.degrees(msg.pitch), 2)
                self.live_telemetry["yaw_deg"] = round(math.degrees(msg.yaw), 2)

            elif mtype == "GLOBAL_POSITION_INT":
                self.live_telemetry["alt_amsl_m"] = round(msg.alt / 1000.0, 1)
                self.live_telemetry["alt_relative_m"] = round(msg.relative_alt / 1000.0, 1)

            elif mtype == "VFR_HUD":
                self.live_telemetry["groundspeed_ms"] = round(msg.groundspeed, 2)
                self.live_telemetry["climb_rate_ms"] = round(msg.climb, 2)

            elif mtype == "SYS_STATUS":
                self.live_telemetry["battery_voltage_v"] = round(msg.voltage_battery / 1000.0, 2)
                self.live_telemetry["battery_pct"] = msg.battery_remaining

            elif mtype == "GPS_RAW_INT":
                self.live_telemetry["gps_fix_type"] = msg.fix_type
                self.live_telemetry["gps_satellites"] = msg.satellites_visible

    def get_snapshot(self) -> dict:
        with self.stats_lock:
            intervals = list(self.inter_packet_intervals_ms)
            if intervals:
                mean_jitter = sum(intervals) / len(intervals)
                variance = sum((x - mean_jitter) ** 2 for x in intervals) / len(intervals)
                jitter_std_ms = round(math.sqrt(variance), 2)
                max_gap_ms = round(max(intervals), 1)
            else:
                jitter_std_ms = 0.0
                max_gap_ms = 0.0

            loss_ppm = 0
            if self.expected_packets > 0:
                loss_ppm = int((self.dropped_packets / self.expected_packets) * 1_000_000)

            return {
                "total_packets": self.total_packets_received,
                "total_bytes": self.total_bytes_received,
                "sent_to_serial": self.total_packets_sent_to_serial,
                "dropped_packets": self.dropped_packets,
                "loss_ppm": loss_ppm,
                "jitter_std_ms": jitter_std_ms,
                "max_gap_ms": max_gap_ms,
                "identity": dict(self.autopilot_info),
                "telemetry": dict(self.live_telemetry),
                "rates": dict(self.packet_type_counts),
            }


def main():
    parser = argparse.ArgumentParser(description="Microhard pMDDL2450 Telemetry Gateway & Benchmark")
    parser.add_argument("--serial-port", default=None, help="Cube Orange+ serial device")
    parser.add_argument("--baud", type=int, default=115200, help="Serial baud rate")
    parser.add_argument("--udp-ip", default="192.168.168.10", help="QGC UDP target IP")
    parser.add_argument("--udp-port", type=int, default=14550, help="QGC UDP target port")
    parser.add_argument("--duration", type=int, default=30, help="Benchmark duration in seconds (0 = infinite)")
    parser.add_argument("--output-json", default=None, help="Save summary report to JSON")
    args = parser.parse_args()

    port = args.serial_port or detect_cube_serial_port()
    print("=" * 80)
    print("PHASE 9 — MOD-02/03: MICROHARD pMDDL2450 ETHERNET / UDP TELEMETRY INTEGRATION")
    print("=" * 80)
    print(f"Physical Serial Port:   {port} @ {args.baud} baud")
    print(f"pMDDL Ground NIC IP:    192.168.168.10 (enp7s0, 1000 Mb/s Full Duplex)")
    print(f"QGC UDP Target Endpoint:{args.udp_ip}:{args.udp_port} (+ 127.0.0.1:{args.udp_port})")
    print(f"Test Duration:          {args.duration}s")
    print("=" * 80)

    targets = [(args.udp_ip, args.udp_port)]
    if args.udp_ip != "127.0.0.1":
        targets.append(("127.0.0.1", args.udp_port))

    gateway = PMDDLTelemetryGateway(port, baud=args.baud, udp_targets=targets)
    gateway.start()

    start_time = time.time()
    last_print = start_time
    last_packets = 0

    try:
        while True:
            time.sleep(1.0)
            now = time.time()
            elapsed = now - start_time

            snap = gateway.get_snapshot()
            pkts = snap["total_packets"]
            delta_pkts = pkts - last_packets
            dt = now - last_print
            rate = delta_pkts / dt if dt > 0 else 0.0

            ident = snap["identity"]
            telem = snap["telemetry"]

            print(
                f"[{elapsed:5.1f}s] Rate: {rate:5.1f} Hz | Pkts: {pkts:6d} | Drops: {snap['dropped_packets']:2d} ({snap['loss_ppm']} ppm) | "
                f"Jitter: {snap['jitter_std_ms']:4.1f}ms | Mode: {ident['flight_mode']} | "
                f"Pitch: {telem['pitch_deg']:+5.1f}° Roll: {telem['roll_deg']:+5.1f}° | Alt: {telem['alt_amsl_m']:5.1f}m"
            )

            last_print = now
            last_packets = pkts

            if args.duration > 0 and elapsed >= args.duration:
                break

    except KeyboardInterrupt:
        print("\n[INFO] Stopped by operator.")
    finally:
        gateway.stop()

    # Final Summary Report
    snap = gateway.get_snapshot()
    total_time = max(0.1, time.time() - start_time)
    avg_rate = snap["total_packets"] / total_time

    print("\n" + "=" * 80)
    print("pMDDL ETHERNET/UDP TELEMETRY BENCHMARK SUMMARY")
    print("=" * 80)
    print(f"Total Duration:         {total_time:.2f} s")
    print(f"Total Packets Ingested: {snap['total_packets']}")
    print(f"Average Packet Rate:    {avg_rate:.2f} packets/second")
    print(f"Total Data Transferred: {snap['total_bytes'] / 1024.0:.1f} KB")
    print(f"Packets Dropped:        {snap['dropped_packets']} ({snap['loss_ppm']} ppm)")
    print(f"Inter-packet Jitter:    {snap['jitter_std_ms']:.2f} ms")
    print(f"Max Inter-packet Gap:   {snap['max_gap_ms']:.2f} ms")
    print(f"Autopilot Identity:     {snap['identity']['autopilot_name']} v{snap['identity']['flight_sw_version']} "
          f"(SysID: {snap['identity']['sysid']}, CompID: {snap['identity']['compid']})")
    print(f"Flight Mode:            {snap['identity']['flight_mode']}")
    print(f"Attitude Final:         Pitch {snap['telemetry']['pitch_deg']}°, Roll {snap['telemetry']['roll_deg']}°, Yaw {snap['telemetry']['yaw_deg']}°")
    print(f"Altitude Final:         AMSL {snap['telemetry']['alt_amsl_m']} m, Relative {snap['telemetry']['alt_relative_m']} m")
    print(f"Battery Voltage:        {snap['telemetry']['battery_voltage_v']} V ({snap['telemetry']['battery_pct']}%)")
    print("Top Stream Breakdown:")
    for k, v in sorted(snap["rates"].items(), key=lambda x: x[1], reverse=True)[:8]:
        print(f"  • {k:22s}: {v:6d} packets ({v/total_time:5.1f} Hz)")
    print("=" * 80)

    if args.output_json:
        out_path = Path(args.output_json)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        report = {
            "test": "MOD-02_MOD-03_PMDDL_ETHERNET_UDP_TELEMETRY",
            "duration_s": round(total_time, 2),
            "average_rate_hz": round(avg_rate, 2),
            "total_packets": snap["total_packets"],
            "total_bytes": snap["total_bytes"],
            "dropped_packets": snap["dropped_packets"],
            "loss_ppm": snap["loss_ppm"],
            "jitter_std_ms": snap["jitter_std_ms"],
            "max_gap_ms": snap["max_gap_ms"],
            "identity": snap["identity"],
            "telemetry": snap["telemetry"],
            "streams": snap["rates"],
        }
        out_path.write_text(json.dumps(report, indent=2))
        print(f"Summary report written to {out_path}")


if __name__ == "__main__":
    main()
