#!/usr/bin/env python3
"""
Test Dual-Stream Video Broadcaster for QGroundControl / IZI GCS

This script simulates a MAVLink vehicle and camera component broadcasting
two video stream advertisements (RGB on UDP 5600 and Thermal on UDP 5601)
to validate QGroundControl's dual-receiver video pipeline without real UAV hardware.

Protocol compliance:
- Vehicle Heartbeat (MAV_TYPE_QUADROTOR, compid=1)
- Camera Heartbeat (MAV_TYPE_CAMERA, compid=MAV_COMP_ID_CAMERA / 100)
- Responds to CAMERA_INFORMATION requests (flags |= CAMERA_CAP_FLAGS_HAS_VIDEO_STREAM)
- Responds to VIDEO_STREAM_INFORMATION requests with 2 streams:
    1. RGB Stream (stream_id=1, VIDEO_STREAM_TYPE_RTPUDP, RUNNING, udp://0.0.0.0:5600)
    2. Thermal Stream (stream_id=2, VIDEO_STREAM_TYPE_RTPUDP, RUNNING|THERMAL, udp://0.0.0.0:5601)
- Safety: Only advertises metadata; never sends arming, mission, or flight commands.

Usage:
    python3 tools/test_dual_stream_broadcaster.py --help
    python3 tools/test_dual_stream_broadcaster.py [--host 127.0.0.1] [--port 14550] [--rate 1.0]
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

# Auto-discover CPM-cached pymavlink if not installed in current Python environment
try:
    import pymavlink
except ImportError:
    repo_root = Path(__file__).resolve().parents[1]
    cpm_matches = list(repo_root.glob(".cache/CPM/mavlink/*/pymavlink"))
    if cpm_matches and cpm_matches[0].is_dir():
        sys.path.insert(0, str(cpm_matches[0].parent))

os.environ.setdefault("MAVLINK20", "1")
os.environ.setdefault("MAVLINK_DIALECT", "common")

try:
    from pymavlink import mavutil
    from pymavlink.dialects.v20 import common as mavlink
except ImportError as exc:
    print(f"[ERROR] pymavlink is unavailable: {exc}", file=sys.stderr)
    print("[ERROR] Please install pymavlink or run 'python3 tools/setup/install_python.py dev'", file=sys.stderr)
    mavutil = None
    mavlink = None


class DualStreamBroadcaster:
    """Simulates a MAVLink vehicle with a dual-stream (RGB + Thermal) camera."""

    def __init__(
        self,
        host: str = "127.0.0.1",
        port: int = 14550,
        sysid: int = 1,
        rate: float = 1.0,
        camera_only: bool = False,
        rgb_res: tuple[int, int] = (1920, 1080),
        thermal_res: tuple[int, int] = (640, 512),
        rgb_fps: float = 30.0,
        thermal_fps: float = 30.0,
    ) -> None:
        if mavutil is None or mavlink is None:
            raise RuntimeError("pymavlink is not available in the environment")

        self.host = host
        self.port = port
        self.sysid = sysid
        self.rate = rate
        self.camera_only = camera_only
        self.rgb_res = rgb_res
        self.thermal_res = thermal_res
        self.rgb_fps = rgb_fps
        self.thermal_fps = thermal_fps
        self.running = False

        # Open UDP client connection targeting QGC listen port
        self.connection = mavutil.mavlink_connection(
            f"udpout:{self.host}:{self.port}",
            source_system=self.sysid,
            source_component=mavlink.MAV_COMP_ID_AUTOPILOT1,
        )

        # Vehicle component instance (sysid=1, compid=1)
        self.mav_vehicle = mavlink.MAVLink(
            self.connection,
            srcSystem=self.sysid,
            srcComponent=mavlink.MAV_COMP_ID_AUTOPILOT1,
        )

        # Camera component instance (sysid=1, compid=100)
        self.mav_camera = mavlink.MAVLink(
            self.connection,
            srcSystem=self.sysid,
            srcComponent=mavlink.MAV_COMP_ID_CAMERA,
        )

    def send_vehicle_heartbeat(self) -> None:
        """Send vehicle heartbeat as MAV_COMP_ID_AUTOPILOT1."""
        self.mav_vehicle.heartbeat_send(
            type=mavlink.MAV_TYPE_QUADROTOR,
            autopilot=mavlink.MAV_AUTOPILOT_GENERIC,
            base_mode=mavlink.MAV_MODE_FLAG_CUSTOM_MODE_ENABLED,
            custom_mode=0,
            system_status=mavlink.MAV_STATE_STANDBY,
        )
        print("[MAVLINK] Vehicle heartbeat sent")

    def send_camera_heartbeat(self) -> None:
        """Send camera heartbeat as MAV_COMP_ID_CAMERA."""
        self.mav_camera.heartbeat_send(
            type=mavlink.MAV_TYPE_CAMERA,
            autopilot=mavlink.MAV_AUTOPILOT_INVALID,
            base_mode=0,
            custom_mode=0,
            system_status=mavlink.MAV_STATE_ACTIVE,
        )
        print("[MAVLINK] Camera heartbeat sent")

    def send_camera_information(self, target_system: int = 0, target_component: int = 0) -> None:
        """Respond with CAMERA_INFORMATION advertising video streaming capability."""
        vendor_name = list(b"IZI GCS".ljust(32, b"\0"))
        model_name = list(b"Dual RGB/Thermal Cam".ljust(32, b"\0"))
        flags = mavlink.CAMERA_CAP_FLAGS_HAS_VIDEO_STREAM

        self.mav_camera.camera_information_send(
            time_boot_ms=0,
            vendor_name=vendor_name,
            model_name=model_name,
            firmware_version=0x01000000,
            focal_length=0.0,
            sensor_size_h=0.0,
            sensor_size_v=0.0,
            resolution_h=1920,
            resolution_v=1080,
            lens_id=0,
            flags=flags,
            cam_definition_version=0,
            cam_definition_uri=b"",
            gimbal_device_id=0,
            camera_device_id=0,
        )
        print("[MAVLINK] Camera information sent")

    def send_video_stream_information(
        self,
        stream_id: int = 0,
        target_system: int = 0,
        target_component: int = 0,
    ) -> None:
        """Respond with VIDEO_STREAM_INFORMATION for RGB (stream 1) and/or Thermal (stream 2)."""
        # Stream 1: RGB
        if stream_id in (0, 1):
            self.mav_camera.video_stream_information_send(
                stream_id=1,
                count=2,
                type=mavlink.VIDEO_STREAM_TYPE_RTPUDP,
                flags=mavlink.VIDEO_STREAM_STATUS_FLAGS_RUNNING,
                framerate=self.rgb_fps,
                resolution_h=self.rgb_res[0],
                resolution_v=self.rgb_res[1],
                bitrate=4000000,
                rotation=0,
                hfov=70,
                name=b"RGB TEST",
                uri=b"udp://0.0.0.0:5600",
                encoding=mavlink.VIDEO_STREAM_ENCODING_H264,
                camera_device_id=0,
            )
            print(f"[MAVLINK] RGB stream advertised: udp://0.0.0.0:5600 ({self.rgb_res[0]}x{self.rgb_res[1]} @ {self.rgb_fps}fps)")

        # Stream 2: Thermal
        if stream_id in (0, 2):
            thermal_flags = (
                mavlink.VIDEO_STREAM_STATUS_FLAGS_RUNNING
                | mavlink.VIDEO_STREAM_STATUS_FLAGS_THERMAL
            )
            self.mav_camera.video_stream_information_send(
                stream_id=2,
                count=2,
                type=mavlink.VIDEO_STREAM_TYPE_RTPUDP,
                flags=thermal_flags,
                framerate=self.thermal_fps,
                resolution_h=self.thermal_res[0],
                resolution_v=self.thermal_res[1],
                bitrate=1500000,
                rotation=0,
                hfov=57,
                name=b"THERMAL TEST",
                uri=b"udp://0.0.0.0:5601",
                encoding=mavlink.VIDEO_STREAM_ENCODING_H264,
                camera_device_id=0,
            )
            print(f"[MAVLINK] Thermal stream advertised: udp://0.0.0.0:5601 ({self.thermal_res[0]}x{self.thermal_res[1]} @ {self.thermal_fps}fps)")

        print("[MAVLINK] Video stream information sent")

    def send_video_stream_status(self, stream_id: int = 0) -> None:
        """Send VIDEO_STREAM_STATUS for requested streams."""
        if stream_id in (0, 1):
            self.mav_camera.video_stream_status_send(
                stream_id=1,
                flags=mavlink.VIDEO_STREAM_STATUS_FLAGS_RUNNING,
                framerate=self.rgb_fps,
                resolution_h=self.rgb_res[0],
                resolution_v=self.rgb_res[1],
                bitrate=4000000,
                rotation=0,
                hfov=70,
                camera_device_id=0,
            )
        if stream_id in (0, 2):
            thermal_flags = (
                mavlink.VIDEO_STREAM_STATUS_FLAGS_RUNNING
                | mavlink.VIDEO_STREAM_STATUS_FLAGS_THERMAL
            )
            self.mav_camera.video_stream_status_send(
                stream_id=2,
                flags=thermal_flags,
                framerate=self.thermal_fps,
                resolution_h=self.thermal_res[0],
                resolution_v=self.thermal_res[1],
                bitrate=1500000,
                rotation=0,
                hfov=57,
                camera_device_id=0,
            )

    def send_command_ack(
        self,
        command: int,
        result: int,
        result_param2: int = 0,
        target_system: int = 0,
        target_component: int = 0,
    ) -> None:
        """Send COMMAND_ACK from camera component."""
        self.mav_camera.command_ack_send(
            command=command,
            result=result,
            progress=0,
            result_param2=result_param2,
            target_system=target_system,
            target_component=target_component,
        )

    def handle_incoming_messages(self) -> None:
        """Process incoming MAVLink commands from QGC."""
        while True:
            msg = self.connection.recv_match(blocking=False)
            if msg is None:
                break

            msg_type = msg.get_type()
            target_sys = getattr(msg, "target_system", 0)
            target_comp = getattr(msg, "target_component", 0)

            # Ignore packets explicitly intended for other systems
            if target_sys not in (0, self.sysid):
                continue

            if msg_type == "COMMAND_LONG":
                cmd = msg.command
                param1 = int(msg.param1)
                param2 = int(msg.param2)

                print(
                    f"[INCOMING] COMMAND_LONG: cmd={cmd}, target_comp={target_comp}, "
                    f"param1={param1}, param2={param2}"
                )

                if cmd == mavlink.MAV_CMD_REQUEST_MESSAGE:
                    # Generic REQUEST_MESSAGE pattern (used by modern QGC)
                    req_msg_id = param1
                    print(f"[INCOMING] MAV_CMD_REQUEST_MESSAGE for msgid={req_msg_id}")

                    if req_msg_id == mavlink.MAVLINK_MSG_ID_CAMERA_INFORMATION:
                        self.send_camera_information(msg.get_srcSystem(), msg.get_srcComponent())
                        self.send_command_ack(
                            cmd,
                            mavlink.MAV_RESULT_ACCEPTED,
                            result_param2=req_msg_id,
                            target_system=msg.get_srcSystem(),
                            target_component=msg.get_srcComponent(),
                        )
                    elif req_msg_id == mavlink.MAVLINK_MSG_ID_VIDEO_STREAM_INFORMATION:
                        stream_id = param2
                        self.send_video_stream_information(
                            stream_id=stream_id,
                            target_system=msg.get_srcSystem(),
                            target_component=msg.get_srcComponent(),
                        )
                        self.send_command_ack(
                            cmd,
                            mavlink.MAV_RESULT_ACCEPTED,
                            result_param2=req_msg_id,
                            target_system=msg.get_srcSystem(),
                            target_component=msg.get_srcComponent(),
                        )
                    elif req_msg_id == mavlink.MAVLINK_MSG_ID_VIDEO_STREAM_STATUS:
                        stream_id = param2
                        self.send_video_stream_status(stream_id=stream_id)
                        self.send_command_ack(
                            cmd,
                            mavlink.MAV_RESULT_ACCEPTED,
                            result_param2=req_msg_id,
                            target_system=msg.get_srcSystem(),
                            target_component=msg.get_srcComponent(),
                        )
                    else:
                        self.send_command_ack(
                            cmd,
                            mavlink.MAV_RESULT_UNSUPPORTED,
                            result_param2=req_msg_id,
                            target_system=msg.get_srcSystem(),
                            target_component=msg.get_srcComponent(),
                        )

                elif cmd == mavlink.MAV_CMD_REQUEST_CAMERA_INFORMATION:
                    self.send_camera_information(msg.get_srcSystem(), msg.get_srcComponent())
                    self.send_command_ack(
                        cmd,
                        mavlink.MAV_RESULT_ACCEPTED,
                        target_system=msg.get_srcSystem(),
                        target_component=msg.get_srcComponent(),
                    )

                elif cmd == mavlink.MAV_CMD_REQUEST_VIDEO_STREAM_INFORMATION:
                    stream_id = param1
                    self.send_video_stream_information(
                        stream_id=stream_id,
                        target_system=msg.get_srcSystem(),
                        target_component=msg.get_srcComponent(),
                    )
                    self.send_command_ack(
                        cmd,
                        mavlink.MAV_RESULT_ACCEPTED,
                        target_system=msg.get_srcSystem(),
                        target_component=msg.get_srcComponent(),
                    )

                elif cmd == mavlink.MAV_CMD_REQUEST_VIDEO_STREAM_STATUS:
                    stream_id = param1
                    self.send_video_stream_status(stream_id=stream_id)
                    self.send_command_ack(
                        cmd,
                        mavlink.MAV_RESULT_ACCEPTED,
                        target_system=msg.get_srcSystem(),
                        target_component=msg.get_srcComponent(),
                    )

                elif cmd == mavlink.MAV_CMD_REQUEST_AUTOPILOT_CAPABILITIES:
                    # Acknowledge autopilot capabilities request defensively
                    self.mav_vehicle.command_ack_send(cmd, mavlink.MAV_RESULT_ACCEPTED)

                else:
                    # Safely ack other non-flight commands
                    self.send_command_ack(
                        cmd,
                        mavlink.MAV_RESULT_ACCEPTED,
                        target_system=msg.get_srcSystem(),
                        target_component=msg.get_srcComponent(),
                    )

    def run(self) -> None:
        """Main broadcaster loop."""
        self.running = True
        interval = 1.0 / self.rate
        last_heartbeat = 0.0

        print(
            f"Dual-Stream Broadcaster started -> target {self.host}:{self.port} "
            f"(sysid={self.sysid}, rate={self.rate} Hz)"
        )
        print("Press Ctrl+C to stop.")

        try:
            while self.running:
                now = time.time()

                # Check and process incoming requests
                self.handle_incoming_messages()

                # Periodic heartbeat broadcast
                if now - last_heartbeat >= interval:
                    if not self.camera_only:
                        self.send_vehicle_heartbeat()
                    self.send_camera_heartbeat()
                    last_heartbeat = now

                time.sleep(0.01)

        except KeyboardInterrupt:
            print("\nStopping broadcaster...")
        finally:
            self.running = False


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Test dual-stream video broadcaster for QGroundControl / IZI GCS",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--host",
        default="127.0.0.1",
        help="Target QGC host address (default: 127.0.0.1)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=14550,
        help="Target QGC UDP port (default: 14550)",
    )
    parser.add_argument(
        "--sysid",
        type=int,
        default=1,
        help="MAVLink system ID (default: 1)",
    )
    parser.add_argument(
        "--rate",
        type=float,
        default=1.0,
        help="Heartbeat rate in Hz (default: 1.0)",
    )
    parser.add_argument(
        "--camera-only",
        action="store_true",
        help="Only broadcast camera component without vehicle heartbeat",
    )
    parser.add_argument(
        "--rgb-res",
        default="1920x1080",
        help="RGB stream resolution WxH (default: 1920x1080)",
    )
    parser.add_argument(
        "--thermal-res",
        default="640x512",
        help="Thermal stream resolution WxH (default: 640x512)",
    )
    parser.add_argument(
        "--rgb-fps",
        type=float,
        default=30.0,
        help="RGB framerate (default: 30.0)",
    )
    parser.add_argument(
        "--thermal-fps",
        type=float,
        default=30.0,
        help="Thermal framerate (default: 30.0)",
    )
    return parser.parse_args()


def main() -> None:
    """Entry point."""
    args = parse_args()

    if mavutil is None or mavlink is None:
        print("[ERROR] Cannot run broadcaster without pymavlink.", file=sys.stderr)
        sys.exit(1)

    try:
        rgb_w, rgb_h = [int(v) for v in args.rgb_res.lower().split("x")]
    except ValueError:
        rgb_w, rgb_h = 1920, 1080

    try:
        th_w, th_h = [int(v) for v in args.thermal_res.lower().split("x")]
    except ValueError:
        th_w, th_h = 640, 512

    broadcaster = DualStreamBroadcaster(
        host=args.host,
        port=args.port,
        sysid=args.sysid,
        rate=args.rate,
        camera_only=args.camera_only,
        rgb_res=(rgb_w, rgb_h),
        thermal_res=(th_w, th_h),
        rgb_fps=args.rgb_fps,
        thermal_fps=args.thermal_fps,
    )
    broadcaster.run()


if __name__ == "__main__":
    main()
