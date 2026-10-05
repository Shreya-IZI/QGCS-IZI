#!/usr/bin/env python3
"""
MAVLink Vehicle Telemetry Simulator for IZI GCS / QGroundControl

Simulates a MAVLink UAV broadcasting high-fidelity telemetry over UDP 14550.
Supports dynamic state transitions (ground_disarmed, ground_armed, airborne)
controlled via command line or by writing to /tmp/qgcs_sim_state.

Used to validate live telemetry display, PFD instruments, and dynamic
Safety Confirmation Modal behaviors (e.g. airborne critical crash alert).
"""

from __future__ import annotations

import argparse
import math
import os
import struct
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
os.environ["MAVLINK_DIALECT"] = "ardupilotmega"

from pymavlink import mavutil
from pymavlink.dialects.v20 import ardupilotmega as mavlink


class VehicleTelemetrySimulator:
    def __init__(
        self,
        host: str = "127.0.0.1",
        port: int = 14550,
        sysid: int = 1,
        state: str = "ground_disarmed",
        state_file: str = "/tmp/qgcs_sim_state",
        autopilot: str = "generic",
        cmd_log_file: str = "/tmp/qgcs_mavlink_cmds.log",
        with_camera: bool = False,
        protocol: str = "udp",
    ) -> None:
        self.host = host
        self.port = port
        self.sysid = sysid
        self.state = state
        self.state_file = state_file
        self.autopilot = autopilot
        self.cmd_log_file = cmd_log_file
        self.with_camera = with_camera
        self.protocol = protocol.lower()
        self.running = False

        if self.autopilot == "px4":
            self.autopilot_type = mavlink.MAV_AUTOPILOT_PX4
        elif self.autopilot == "ardupilot":
            self.autopilot_type = mavlink.MAV_AUTOPILOT_ARDUPILOTMEGA
        else:
            self.autopilot_type = mavlink.MAV_AUTOPILOT_GENERIC

        # Custom flight mode tracking
        self.custom_mode = 0  # 0 = STABILIZE in ArduCopter
        self.mode_map = {
            "STABILIZE": 0, "ALT_HOLD": 2, "AUTO": 3, "GUIDED": 4,
            "LOITER": 5, "RTL": 6, "LAND": 9, "POSHOLD": 16, "BRAKE": 17
        }

        # Simulated MAVLink Mission Storage
        self.mission_items = []
        self.incoming_mission_items = []
        self.expected_mission_count = 0

        # Clear/initialize command log file
        with open(self.cmd_log_file, "w") as f:
            f.write(f"=== MAVLink Command Log Initialized at {time.strftime('%Y-%m-%d %H:%M:%S')} ===\n")

        # Open connection (UDP broadcast or TCP listener)
        if self.protocol == "tcp":
            device = f"tcpin:{self.host}:{self.port}"
            for retry in range(10):
                try:
                    self.connection = mavutil.mavlink_connection(
                        device,
                        source_system=self.sysid,
                        source_component=mavlink.MAV_COMP_ID_AUTOPILOT1,
                    )
                    break
                except OSError as e:
                    if "already in use" in str(e) and retry < 9:
                        time.sleep(0.5)
                        continue
                    raise
        else:
            device = f"udpout:{self.host}:{self.port}"
            self.connection = mavutil.mavlink_connection(
                device,
                source_system=self.sysid,
                source_component=mavlink.MAV_COMP_ID_AUTOPILOT1,
            )

        self.mav = mavlink.MAVLink(
            self.connection,
            srcSystem=self.sysid,
            srcComponent=mavlink.MAV_COMP_ID_AUTOPILOT1,
        )

        if self.with_camera:
            self.mav_camera = mavlink.MAVLink(
                self.connection,
                srcSystem=self.sysid,
                srcComponent=mavlink.MAV_COMP_ID_CAMERA,
            )

        # Baseline coordinates (Bhopal, Madhya Pradesh)
        self.home_lat = 23.259933
        self.home_lon = 77.412613
        self.home_alt = 520.0  # AMSL (m)

        # Dynamic state parameters
        self.cur_lat = self.home_lat
        self.cur_lon = self.home_lon
        self.rel_alt = 0.0
        self.groundspeed = 0.0
        self.airspeed = 0.0
        self.heading = 45.0
        self.roll = 0.0
        self.pitch = 0.0
        self.climb = 0.0
        self.battery_pct = 88
        self.battery_mv = 15800
        self.battery_ca = 50
        self.armed = False
        self.flying = False

        # Simulated MAVLink Parameter Database
        if self.autopilot == "ardupilot":
            self.params = [
                # Flight Modes
                ["FLTMODE1", 0, mavlink.MAV_PARAM_TYPE_INT32],         # STABILIZE
                ["FLTMODE2", 1, mavlink.MAV_PARAM_TYPE_INT32],         # ACRO
                ["FLTMODE3", 2, mavlink.MAV_PARAM_TYPE_INT32],         # ALT_HOLD
                ["FLTMODE4", 3, mavlink.MAV_PARAM_TYPE_INT32],         # AUTO
                ["FLTMODE5", 5, mavlink.MAV_PARAM_TYPE_INT32],         # LOITER
                ["FLTMODE6", 6, mavlink.MAV_PARAM_TYPE_INT32],         # RTL
                ["FLTMODE_CH", 5, mavlink.MAV_PARAM_TYPE_INT32],
                ["INITIAL_MODE", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["SIMPLE", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["SUPER_SIMPLE", 0, mavlink.MAV_PARAM_TYPE_INT32],
                # RC Mapping
                ["RCMAP_ROLL", 1, mavlink.MAV_PARAM_TYPE_INT32],
                ["RCMAP_PITCH", 2, mavlink.MAV_PARAM_TYPE_INT32],
                ["RCMAP_THROTTLE", 3, mavlink.MAV_PARAM_TYPE_INT32],
                ["RCMAP_YAW", 4, mavlink.MAV_PARAM_TYPE_INT32],
                # RC Channels Calibration
                ["RC1_MIN", 1100, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC1_MAX", 1900, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC1_TRIM", 1500, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC1_REVERSED", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC1_DZ", 30, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC2_MIN", 1100, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC2_MAX", 1900, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC2_TRIM", 1500, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC2_REVERSED", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC2_DZ", 30, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC3_MIN", 1100, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC3_MAX", 1900, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC3_TRIM", 1500, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC3_REVERSED", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC3_DZ", 30, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC4_MIN", 1100, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC4_MAX", 1900, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC4_TRIM", 1500, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC4_REVERSED", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC4_DZ", 30, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC5_MIN", 1100, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC5_MAX", 1900, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC5_TRIM", 1500, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC5_REVERSED", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC5_DZ", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC6_MIN", 1100, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC6_MAX", 1900, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC6_TRIM", 1500, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC6_REVERSED", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC6_DZ", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC7_MIN", 1100, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC7_MAX", 1900, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC7_TRIM", 1500, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC7_REVERSED", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC7_DZ", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC8_MIN", 1100, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC8_MAX", 1900, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC8_TRIM", 1500, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC8_REVERSED", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC8_DZ", 0, mavlink.MAV_PARAM_TYPE_INT32],
                # Battery / Power
                ["BATT_MONITOR", 4, mavlink.MAV_PARAM_TYPE_INT32],
                ["BAT_MONITOR", 4, mavlink.MAV_PARAM_TYPE_INT32],
                ["BATT_CAPACITY", 3300, mavlink.MAV_PARAM_TYPE_INT32],
                ["BATT_VOLT_PIN", 2, mavlink.MAV_PARAM_TYPE_INT32],
                ["BATT_CURR_PIN", 3, mavlink.MAV_PARAM_TYPE_INT32],
                ["BATT_VOLT_MULT", 10.17793941, mavlink.MAV_PARAM_TYPE_REAL32],
                ["BATT_AMP_PERVLT", 17.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["BATT_FS_VOLT", 14.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["BATT_FS_MAH", 500, mavlink.MAV_PARAM_TYPE_INT32],
                ["BATT_LOW_VOLT", 14.2, mavlink.MAV_PARAM_TYPE_REAL32],
                ["BATT_CRT_VOLT", 13.8, mavlink.MAV_PARAM_TYPE_REAL32],
                # Compass / Sensors
                ["COMPASS_DEV_ID", 123456, mavlink.MAV_PARAM_TYPE_INT32],
                ["COMPASS_DEV_ID2", 123457, mavlink.MAV_PARAM_TYPE_INT32],
                ["COMPASS_DEV_ID3", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["COMPASS_USE", 1, mavlink.MAV_PARAM_TYPE_INT32],
                ["COMPASS_USE2", 1, mavlink.MAV_PARAM_TYPE_INT32],
                ["COMPASS_USE3", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["COMPASS_OFS_X", 5.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["COMPASS_OFS_Y", -10.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["COMPASS_OFS_Z", 12.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["COMPASS_OFS2_X", 0.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["COMPASS_OFS2_Y", 0.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["COMPASS_OFS2_Z", 0.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["COMPASS_OFS3_X", 0.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["COMPASS_OFS3_Y", 0.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["COMPASS_OFS3_Z", 0.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["INS_ACCOFFS_X", 0.01, mavlink.MAV_PARAM_TYPE_REAL32],
                ["INS_ACCOFFS_Y", -0.02, mavlink.MAV_PARAM_TYPE_REAL32],
                ["INS_ACCOFFS_Z", 0.05, mavlink.MAV_PARAM_TYPE_REAL32],
                ["INS_GYROFFS_X", 0.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["INS_GYROFFS_Y", 0.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["INS_GYROFFS_Z", 0.0, mavlink.MAV_PARAM_TYPE_REAL32],
                # Airframe & Safety
                ["FRAME_CLASS", 1, mavlink.MAV_PARAM_TYPE_INT32],      # Quad
                ["FRAME_TYPE", 1, mavlink.MAV_PARAM_TYPE_INT32],       # X
                ["ARMING_CHECK", 1, mavlink.MAV_PARAM_TYPE_INT32],
                ["FS_THR_ENABLE", 1, mavlink.MAV_PARAM_TYPE_INT32],
                ["FS_GCS_ENABLE", 1, mavlink.MAV_PARAM_TYPE_INT32],
                ["RTL_ALT", 1500.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["WP_YAW_BEHAVIOR", 2, mavlink.MAV_PARAM_TYPE_INT32],
                ["WPNAV_SPEED", 500.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["WPNAV_RADIUS", 200.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["PILOT_SPEED_UP", 250.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["PILOT_SPEED_DN", 150.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["ATC_ANG_RLL_P", 4.5, mavlink.MAV_PARAM_TYPE_REAL32],
                ["ATC_ANG_PIT_P", 4.5, mavlink.MAV_PARAM_TYPE_REAL32],
                ["ATC_ANG_YAW_P", 4.5, mavlink.MAV_PARAM_TYPE_REAL32],
                ["ATC_RAT_RLL_P", 0.135, mavlink.MAV_PARAM_TYPE_REAL32],
                ["ATC_RAT_RLL_I", 0.135, mavlink.MAV_PARAM_TYPE_REAL32],
                ["ATC_RAT_RLL_D", 0.0036, mavlink.MAV_PARAM_TYPE_REAL32],
                ["ATC_RAT_PIT_P", 0.135, mavlink.MAV_PARAM_TYPE_REAL32],
                ["ATC_RAT_PIT_I", 0.135, mavlink.MAV_PARAM_TYPE_REAL32],
                ["ATC_RAT_PIT_D", 0.0036, mavlink.MAV_PARAM_TYPE_REAL32],
                ["ATC_RAT_YAW_P", 0.18, mavlink.MAV_PARAM_TYPE_REAL32],
                ["ATC_RAT_YAW_I", 0.018, mavlink.MAV_PARAM_TYPE_REAL32],
                ["ATC_RAT_YAW_D", 0.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["SYSID_THISMAV", 1, mavlink.MAV_PARAM_TYPE_INT32],
                ["SYSID_MYGCS", 255, mavlink.MAV_PARAM_TYPE_INT32],
                ["TELEM_DELAY", 0, mavlink.MAV_PARAM_TYPE_INT32],
            ]
        else:
            self.params = [
                ["BAT_A_PER_V", 15.39103031, mavlink.MAV_PARAM_TYPE_REAL32],
                ["BAT_CAPACITY", -1, mavlink.MAV_PARAM_TYPE_INT32],
                ["BAT_CNT_V_CURR", 0.00080566, mavlink.MAV_PARAM_TYPE_REAL32],
                ["BAT_CNT_V_VOLT", 0.00080566, mavlink.MAV_PARAM_TYPE_REAL32],
                ["BAT_CRIT_THR", 0.07, mavlink.MAV_PARAM_TYPE_REAL32],
                ["BAT_EMERGEN_THR", 0.05, mavlink.MAV_PARAM_TYPE_REAL32],
                ["BAT_LOW_THR", 0.15, mavlink.MAV_PARAM_TYPE_REAL32],
                ["BAT_N_CELLS", 3, mavlink.MAV_PARAM_TYPE_INT32],
                ["BAT_R_INTERNAL", -1.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["BAT_SOURCE", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["BAT_V_CHARGED", 4.05, mavlink.MAV_PARAM_TYPE_REAL32],
                ["BAT_V_DIV", 10.17793941, mavlink.MAV_PARAM_TYPE_REAL32],
                ["BAT_V_EMPTY", 3.40, mavlink.MAV_PARAM_TYPE_REAL32],
                ["BAT_V_LOAD_DROP", 0.30, mavlink.MAV_PARAM_TYPE_REAL32],
                ["BAT_V_OFFS_CURR", 0.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["COM_ARM_MIS_REQ", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["MIS_ALTMODE", 1, mavlink.MAV_PARAM_TYPE_INT32],
                ["MIS_DIST_1WP", 900.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["MIS_LTRMIN_ALT", 10.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["MIS_ONBOARD_EN", 1, mavlink.MAV_PARAM_TYPE_INT32],
                ["MIS_TAKEOFF_ALT", 10.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["MIS_YAWMODE", 1, mavlink.MAV_PARAM_TYPE_INT32],
                ["MIS_YAW_ERR", 12.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["MIS_YAW_TMT", 10.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["FW_LND_FLALT", 8.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["FW_LND_FL_PMAX", 15.0, mavlink.MAV_PARAM_TYPE_REAL32],
                ["FW_LND_FL_PMIN", 2.5, mavlink.MAV_PARAM_TYPE_REAL32],
                ["LND_FLIGHT_T_HI", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["LND_FLIGHT_T_LO", 192140778, mavlink.MAV_PARAM_TYPE_INT32],
                ["EKF2_AID_MASK", 1, mavlink.MAV_PARAM_TYPE_INT32],
                ["EKF2_HGT_MODE", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["SYS_AUTOSTART", 4001, mavlink.MAV_PARAM_TYPE_INT32],
                ["CBRK_AIRSPD_CHK", 0, mavlink.MAV_PARAM_TYPE_INT32],
                ["COM_RC_IN_MODE", 1, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC_MAP_ROLL", 1, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC_MAP_PITCH", 2, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC_MAP_YAW", 4, mavlink.MAV_PARAM_TYPE_INT32],
                ["RC_MAP_THROTTLE", 3, mavlink.MAV_PARAM_TYPE_INT32],
                ["CAL_ACC0_ID", 123456, mavlink.MAV_PARAM_TYPE_INT32],
                ["CAL_GYRO0_ID", 123456, mavlink.MAV_PARAM_TYPE_INT32],
                ["CAL_MAG0_ID", 123456, mavlink.MAV_PARAM_TYPE_INT32],
            ]

        self.apply_scenario(self.state)

    def apply_scenario(self, scenario: str) -> None:
        scenario = scenario.strip().lower()
        if scenario in ("telemetry_loss", "paused", "disconnected"):
            self.state = scenario
            print(f"[SIMULATOR] Telemetry transmission paused ({scenario})")
            return

        self.state = scenario
        if scenario == "ground_disarmed":
            self.armed = False
            self.flying = False
            self.rel_alt = 0.0
            self.groundspeed = 0.0
            self.airspeed = 0.0
            self.climb = 0.0
            self.roll = 0.0
            self.pitch = 0.0
            self.heading = 45.0
            self.battery_pct = 88
            self.battery_mv = 15800
            self.battery_ca = 45
        elif scenario == "ground_armed":
            self.armed = True
            self.flying = False
            self.rel_alt = 0.0
            self.groundspeed = 0.0
            self.airspeed = 0.0
            self.climb = 0.0
            self.roll = 0.0
            self.pitch = 0.0
            self.heading = 45.0
            self.battery_pct = 87
            self.battery_mv = 15650
            self.battery_ca = 220
        elif scenario == "airborne":
            self.armed = True
            self.flying = True
            self.rel_alt = 45.2
            self.groundspeed = 12.4
            self.airspeed = 13.1
            self.climb = 0.4
            self.roll = 4.8
            self.pitch = 2.6
            self.heading = 72.0
            self.battery_pct = 84
            self.battery_mv = 15200
            self.battery_ca = 1450
            # Slight drift in position
            self.cur_lat = self.home_lat + 0.0018
            self.cur_lon = self.home_lon + 0.0024

    def check_state_file(self) -> None:
        if os.path.exists(self.state_file):
            try:
                with open(self.state_file, "r") as f:
                    new_state = f.read().strip()
                if new_state and new_state != self.state:
                    print(f"[SIMULATOR] Transitioning state: {self.state} -> {new_state}")
                    self.apply_scenario(new_state)
            except Exception as e:
                pass

    def send_heartbeat(self) -> None:
        base_mode = mavlink.MAV_MODE_FLAG_CUSTOM_MODE_ENABLED
        if self.armed:
            base_mode |= mavlink.MAV_MODE_FLAG_SAFETY_ARMED
        system_status = mavlink.MAV_STATE_ACTIVE if self.armed else mavlink.MAV_STATE_STANDBY
        self.mav.heartbeat_send(
            type=mavlink.MAV_TYPE_QUADROTOR,
            autopilot=self.autopilot_type,
            base_mode=base_mode,
            custom_mode=self.custom_mode,
            system_status=system_status,
            mavlink_version=3,
        )

    def send_sys_status(self) -> None:
        self.mav.sys_status_send(
            onboard_control_sensors_present=0xFFFFFFFF,
            onboard_control_sensors_enabled=0xFFFFFFFF,
            onboard_control_sensors_health=0xFFFFFFFF,
            load=150,
            voltage_battery=self.battery_mv,
            current_battery=self.battery_ca,
            battery_remaining=self.battery_pct,
            drop_rate_comm=0,
            errors_comm=0,
            errors_count1=0,
            errors_count2=0,
            errors_count3=0,
            errors_count4=0,
        )

    def send_extended_sys_state(self) -> None:
        landed_state = (
            mavlink.MAV_LANDED_STATE_IN_AIR
            if self.flying
            else mavlink.MAV_LANDED_STATE_ON_GROUND
        )
        self.mav.extended_sys_state_send(
            vtol_state=mavlink.MAV_VTOL_STATE_UNDEFINED,
            landed_state=landed_state,
        )

    def send_gps_raw(self) -> None:
        self.mav.gps_raw_int_send(
            time_usec=int(time.time() * 1e6),
            fix_type=3,  # 3D Fix
            lat=int(self.cur_lat * 1e7),
            lon=int(self.cur_lon * 1e7),
            alt=int((self.home_alt + self.rel_alt) * 1000),
            eph=70,  # HDOP 0.70
            epv=90,  # VDOP 0.90
            vel=int(self.groundspeed * 100),
            cog=int(self.heading * 100),
            satellites_visible=16,
        )

    def send_global_position(self) -> None:
        rad = math.radians(self.heading)
        vx = int(self.groundspeed * math.cos(rad) * 100)
        vy = int(self.groundspeed * math.sin(rad) * 100)
        vz = int(-self.climb * 100)
        self.mav.global_position_int_send(
            time_boot_ms=int(time.time() * 1000) & 0xFFFFFFFF,
            lat=int(self.cur_lat * 1e7),
            lon=int(self.cur_lon * 1e7),
            alt=int((self.home_alt + self.rel_alt) * 1000),
            relative_alt=int(self.rel_alt * 1000),
            vx=vx,
            vy=vy,
            vz=vz,
            hdg=int(self.heading * 100),
        )

    def send_attitude(self) -> None:
        self.mav.attitude_send(
            time_boot_ms=int(time.time() * 1000) & 0xFFFFFFFF,
            roll=math.radians(self.roll),
            pitch=math.radians(self.pitch),
            yaw=math.radians(self.heading),
            rollspeed=0.0,
            pitchspeed=0.0,
            yawspeed=0.0,
        )

    def send_vfr_hud(self) -> None:
        self.mav.vfr_hud_send(
            airspeed=self.airspeed,
            groundspeed=self.groundspeed,
            heading=int(self.heading),
            throttle=45 if self.flying else 0,
            alt=self.rel_alt,
            climb=self.climb,
        )

    def send_scaled_pressure(self) -> None:
        press_abs = 1013.25 - (self.rel_alt * 0.12)
        self.mav.scaled_pressure_send(
            time_boot_ms=int(time.time() * 1000) & 0xFFFFFFFF,
            press_abs=press_abs,
            press_diff=0.0,
            temperature=2500,
        )

    def send_raw_imu(self) -> None:
        rad = math.radians(self.heading)
        xmag = int(180 * math.cos(rad))
        ymag = int(180 * math.sin(rad))
        zmag = 390
        self.mav.raw_imu_send(
            time_usec=int(time.time() * 1e6),
            xacc=0,
            yacc=0,
            zacc=-980,
            xgyro=0,
            ygyro=0,
            zgyro=0,
            xmag=xmag,
            ymag=ymag,
            zmag=zmag,
        )

    def send_rangefinder(self) -> None:
        dist = max(0.1, self.rel_alt)
        self.mav.rangefinder_send(
            distance=dist,
            voltage=1.2,
        )

    def send_mount_status(self) -> None:
        self.mav.mount_status_send(
            target_system=0,
            target_component=0,
            pointing_a=-3000,
            pointing_b=0,
            pointing_c=int(self.heading * 100),
        )

    def send_home_position(self) -> None:
        self.mav.home_position_send(
            latitude=int(self.home_lat * 1e7),
            longitude=int(self.home_lon * 1e7),
            altitude=int(self.home_alt * 1000),
            x=0.0,
            y=0.0,
            z=0.0,
            q=[1.0, 0.0, 0.0, 0.0],
            approach_x=0.0,
            approach_y=0.0,
            approach_z=0.0,
            time_usec=int(time.time() * 1e6),
        )

    def send_autopilot_version(self) -> None:
        if self.autopilot == "ardupilot":
            fw_version = (4 << 24) | (7 << 16) | (1 << 8) | 0xFF  # 0x040701FF -> v4.7.1 official stable
        else:
            fw_version = 0x011002FF  # v1.16.2 official

        self.mav.autopilot_version_send(
            capabilities=(
                mavlink.MAV_PROTOCOL_CAPABILITY_MAVLINK2
                | mavlink.MAV_PROTOCOL_CAPABILITY_PARAM_FLOAT
                | mavlink.MAV_PROTOCOL_CAPABILITY_MISSION_FLOAT
                | mavlink.MAV_PROTOCOL_CAPABILITY_MISSION_INT
                | mavlink.MAV_PROTOCOL_CAPABILITY_COMMAND_INT
            ),
            flight_sw_version=fw_version,
            middleware_sw_version=fw_version,
            os_sw_version=fw_version,
            board_version=0,
            flight_custom_version=[0] * 8,
            middleware_custom_version=[0] * 8,
            os_custom_version=[0] * 8,
            vendor_id=0,
            product_id=0,
            uid=12345,
            uid2=[0] * 18,
        )

    def send_all_parameters(self) -> None:
        total = len(self.params)
        print(f"[SIMULATOR] Streaming {total} MAVLink parameters to QGCS...")
        for idx, (pname, pval, ptype) in enumerate(self.params):
            if ptype == mavlink.MAV_PARAM_TYPE_REAL32:
                fval = float(pval)
            else:
                fval = struct.unpack('f', struct.pack('i', int(pval)))[0]
            pname_bytes = pname.encode('ascii').ljust(16, b'\0')
            self.mav.param_value_send(
                param_id=pname_bytes,
                param_value=fval,
                param_type=ptype,
                param_count=total,
                param_index=idx,
            )
            time.sleep(0.003)

    def send_single_parameter(self, param_index: int, param_id: str | bytes) -> None:
        total = len(self.params)
        if isinstance(param_id, bytes):
            param_id = param_id.decode('ascii', errors='ignore').rstrip('\0')
        target_item = None
        target_idx = -1
        if 0 <= param_index < total:
            target_idx = param_index
            target_item = self.params[target_idx]
        elif param_id:
            for idx, p in enumerate(self.params):
                if p[0] == param_id:
                    target_idx = idx
                    target_item = p
                    break
        if target_item:
            pname, pval, ptype = target_item
            if ptype == mavlink.MAV_PARAM_TYPE_REAL32:
                fval = float(pval)
            else:
                fval = struct.unpack('f', struct.pack('i', int(pval)))[0]
            pname_bytes = pname.encode('ascii').ljust(16, b'\0')
            self.mav.param_value_send(
                param_id=pname_bytes,
                param_value=fval,
                param_type=ptype,
                param_count=total,
                param_index=target_idx,
            )

    def handle_param_set(self, param_id: str | bytes, param_value: float, param_type: int) -> None:
        if isinstance(param_id, bytes):
            param_id = param_id.decode('ascii', errors='ignore').rstrip('\0')
        for idx, (pname, pval, ptype) in enumerate(self.params):
            if pname == param_id:
                if ptype == mavlink.MAV_PARAM_TYPE_REAL32:
                    new_val = float(param_value)
                else:
                    new_val = struct.unpack('i', struct.pack('f', param_value))[0]
                self.params[idx] = [pname, new_val, ptype]
                print(f"[SIMULATOR MAVLINK RECEIVED] PARAM_SET: {pname} = {new_val}")
                with open(self.cmd_log_file, "a") as f:
                    f.write(f"[{time.strftime('%H:%M:%S')}] [SIMULATOR MAVLINK RECEIVED] PARAM_SET: {pname} = {new_val}\n")
                self.send_single_parameter(idx, pname)
                break

    def send_camera_heartbeat(self) -> None:
        if not self.with_camera:
            return
        self.mav_camera.heartbeat_send(
            type=mavlink.MAV_TYPE_CAMERA,
            autopilot=mavlink.MAV_AUTOPILOT_INVALID,
            base_mode=0,
            custom_mode=0,
            system_status=mavlink.MAV_STATE_ACTIVE,
        )

    def send_camera_information(self, target_system: int = 0, target_component: int = 0) -> None:
        if not self.with_camera:
            return
        vendor_name = list(b"IZI GCS".ljust(32, b"\0"))
        model_name = list(b"Dual RGB/Thermal Cam".ljust(32, b"\0"))
        self.mav_camera.camera_information_send(
            time_boot_ms=int(time.time() * 1000) & 0xFFFFFFFF,
            vendor_name=vendor_name,
            model_name=model_name,
            firmware_version=0x01000000,
            focal_length=4.5,
            sensor_size_h=6.4,
            sensor_size_v=4.8,
            resolution_h=1280,
            resolution_v=720,
            lens_id=0,
            flags=(
                mavlink.CAMERA_CAP_FLAGS_HAS_VIDEO_STREAM
                | mavlink.CAMERA_CAP_FLAGS_CAPTURE_VIDEO
                | mavlink.CAMERA_CAP_FLAGS_CAPTURE_IMAGE
            ),
            cam_mode=0,
            min_focal_length=4.5,
            max_focal_length=45.0,
        )

    def send_video_stream_information(
        self, stream_id: int = 0, target_system: int = 0, target_component: int = 0
    ) -> None:
        if not self.with_camera:
            return
        if stream_id in (0, 1):
            name = list(b"RGB Stream".ljust(32, b"\0"))
            uri = list(b"udp://0.0.0.0:5600".ljust(140, b"\0"))
            self.mav_camera.video_stream_information_send(
                stream_id=1,
                count=2,
                type=mavlink.VIDEO_STREAM_TYPE_RTPUDP,
                flags=mavlink.VIDEO_STREAM_STATUS_FLAGS_RUNNING,
                framerate=30.0,
                resolution_h=1920,
                resolution_v=1080,
                bitrate=4000000,
                rotation=0,
                hfov=70,
                name=name,
                uri=uri,
            )
        if stream_id in (0, 2):
            name = list(b"Thermal Stream".ljust(32, b"\0"))
            uri = list(b"udp://0.0.0.0:5601".ljust(140, b"\0"))
            self.mav_camera.video_stream_information_send(
                stream_id=2,
                count=2,
                type=mavlink.VIDEO_STREAM_TYPE_RTPUDP,
                flags=mavlink.VIDEO_STREAM_STATUS_FLAGS_RUNNING | mavlink.VIDEO_STREAM_STATUS_FLAGS_THERMAL,
                framerate=30.0,
                resolution_h=640,
                resolution_v=512,
                bitrate=1500000,
                rotation=0,
                hfov=57,
                name=name,
                uri=uri,
            )

    def send_video_stream_status(self, stream_id: int = 1) -> None:
        if not self.with_camera:
            return
        if stream_id == 1:
            self.mav_camera.video_stream_status_send(
                stream_id=1,
                flags=mavlink.VIDEO_STREAM_STATUS_FLAGS_RUNNING,
                framerate=30.0,
                resolution_h=1920,
                resolution_v=1080,
                bitrate=4000000,
                rotation=0,
                hfov=70,
            )
        elif stream_id == 2:
            self.mav_camera.video_stream_status_send(
                stream_id=2,
                flags=mavlink.VIDEO_STREAM_STATUS_FLAGS_RUNNING | mavlink.VIDEO_STREAM_STATUS_FLAGS_THERMAL,
                framerate=30.0,
                resolution_h=640,
                resolution_v=512,
                bitrate=1500000,
                rotation=0,
                hfov=57,
            )

    def handle_incoming_messages(self) -> None:
        try:
            while True:
                msg = self.connection.recv_match(blocking=False)
                if not msg:
                    break
                mtype = msg.get_type()
                timestamp = time.strftime("%H:%M:%S")

                if mtype == "COMMAND_LONG":
                    cmd = msg.command
                    target_comp = getattr(msg, "target_component", 0)
                    param1 = int(msg.param1)
                    param2 = int(msg.param2)
                    log_str = f"[{timestamp}] [SIMULATOR MAVLINK RECEIVED] COMMAND_LONG: cmd={cmd}, target_comp={target_comp}, param1={param1}, param2={param2}"
                    print(log_str)
                    with open(self.cmd_log_file, "a") as f:
                        f.write(log_str + "\n")

                    if cmd == mavlink.MAV_CMD_REQUEST_MESSAGE and param1 == mavlink.MAVLINK_MSG_ID_AUTOPILOT_VERSION:
                        self.send_autopilot_version()
                        self.mav.command_ack_send(
                            command=cmd,
                            result=mavlink.MAV_RESULT_ACCEPTED,
                            progress=0,
                            result_param2=param1,
                            target_system=msg.get_srcSystem(),
                            target_component=msg.get_srcComponent(),
                        )
                        continue

                    if cmd == mavlink.MAV_CMD_REQUEST_AUTOPILOT_CAPABILITIES:
                        self.send_autopilot_version()
                        self.mav.command_ack_send(
                            command=cmd,
                            result=mavlink.MAV_RESULT_ACCEPTED,
                            target_system=msg.get_srcSystem(),
                            target_component=msg.get_srcComponent(),
                        )
                        continue

                    if self.with_camera and cmd == mavlink.MAV_CMD_REQUEST_MESSAGE:
                        req_msg_id = param1
                        if req_msg_id == mavlink.MAVLINK_MSG_ID_CAMERA_INFORMATION:
                            self.send_camera_information(msg.get_srcSystem(), msg.get_srcComponent())
                            self.mav_camera.command_ack_send(
                                command=cmd,
                                result=mavlink.MAV_RESULT_ACCEPTED,
                                progress=0,
                                result_param2=req_msg_id,
                                target_system=msg.get_srcSystem(),
                                target_component=msg.get_srcComponent(),
                            )
                            continue
                        elif req_msg_id == mavlink.MAVLINK_MSG_ID_VIDEO_STREAM_INFORMATION:
                            self.send_video_stream_information(stream_id=param2, target_system=msg.get_srcSystem(), target_component=msg.get_srcComponent())
                            self.mav_camera.command_ack_send(
                                command=cmd,
                                result=mavlink.MAV_RESULT_ACCEPTED,
                                progress=0,
                                result_param2=req_msg_id,
                                target_system=msg.get_srcSystem(),
                                target_component=msg.get_srcComponent(),
                            )
                            continue
                        elif req_msg_id == mavlink.MAVLINK_MSG_ID_VIDEO_STREAM_STATUS:
                            self.send_video_stream_status(stream_id=param2)
                            self.mav_camera.command_ack_send(
                                command=cmd,
                                result=mavlink.MAV_RESULT_ACCEPTED,
                                progress=0,
                                result_param2=req_msg_id,
                                target_system=msg.get_srcSystem(),
                                target_component=msg.get_srcComponent(),
                            )
                            continue

                    elif self.with_camera and cmd == mavlink.MAV_CMD_REQUEST_CAMERA_INFORMATION:
                        self.send_camera_information(msg.get_srcSystem(), msg.get_srcComponent())
                        self.mav_camera.command_ack_send(
                            command=cmd,
                            result=mavlink.MAV_RESULT_ACCEPTED,
                            target_system=msg.get_srcSystem(),
                            target_component=msg.get_srcComponent(),
                        )
                        continue

                    elif self.with_camera and cmd == mavlink.MAV_CMD_REQUEST_VIDEO_STREAM_INFORMATION:
                        self.send_video_stream_information(stream_id=param1, target_system=msg.get_srcSystem(), target_component=msg.get_srcComponent())
                        self.mav_camera.command_ack_send(
                            command=cmd,
                            result=mavlink.MAV_RESULT_ACCEPTED,
                            target_system=msg.get_srcSystem(),
                            target_component=msg.get_srcComponent(),
                        )
                        continue

                    elif self.with_camera and cmd == mavlink.MAV_CMD_REQUEST_VIDEO_STREAM_STATUS:
                        self.send_video_stream_status(stream_id=param1)
                        self.mav_camera.command_ack_send(
                            command=cmd,
                            result=mavlink.MAV_RESULT_ACCEPTED,
                            target_system=msg.get_srcSystem(),
                            target_component=msg.get_srcComponent(),
                        )
                        continue

                    elif self.with_camera and cmd in (
                        mavlink.MAV_CMD_IMAGE_START_CAPTURE,
                        mavlink.MAV_CMD_VIDEO_START_CAPTURE,
                        mavlink.MAV_CMD_VIDEO_STOP_CAPTURE,
                    ):
                        self.mav_camera.command_ack_send(
                            command=cmd,
                            result=mavlink.MAV_RESULT_ACCEPTED,
                            target_system=msg.get_srcSystem(),
                            target_component=msg.get_srcComponent(),
                        )
                        continue

                    self.mav.command_ack_send(
                        command=cmd,
                        result=mavlink.MAV_RESULT_ACCEPTED,
                    )

                    if cmd == mavlink.MAV_CMD_COMPONENT_ARM_DISARM:
                        arm_req = bool(msg.param1 == 1.0)
                        detail_str = f"[{timestamp}] [SIMULATOR MAVLINK RECEIVED] MAV_CMD_COMPONENT_ARM_DISARM: arm={arm_req}"
                        print(detail_str)
                        with open(self.cmd_log_file, "a") as f:
                            f.write(detail_str + "\n")
                        self.apply_scenario("ground_armed" if arm_req else "ground_disarmed")
                    elif cmd == mavlink.MAV_CMD_NAV_RETURN_TO_LAUNCH:
                        self.custom_mode = self.mode_map.get("RTL", 6)
                        log_str = f"[{timestamp}] [SIMULATOR MAVLINK RECEIVED] MAV_CMD_NAV_RETURN_TO_LAUNCH (RTL) -> mode={self.custom_mode}"
                        print(log_str)
                        with open(self.cmd_log_file, "a") as f:
                            f.write(log_str + "\n")
                    elif cmd == mavlink.MAV_CMD_NAV_LAND:
                        self.custom_mode = self.mode_map.get("LAND", 9)
                        log_str = f"[{timestamp}] [SIMULATOR MAVLINK RECEIVED] MAV_CMD_NAV_LAND (LAND) -> mode={self.custom_mode}"
                        print(log_str)
                        with open(self.cmd_log_file, "a") as f:
                            f.write(log_str + "\n")
                    elif cmd in (mavlink.MAV_CMD_DO_PAUSE_CONTINUE, mavlink.MAV_CMD_DO_REPOSITION):
                        self.custom_mode = self.mode_map.get("LOITER", 5)
                        log_str = f"[{timestamp}] [SIMULATOR MAVLINK RECEIVED] PAUSE/HOLD_COMMAND (cmd={cmd}) -> mode={self.custom_mode}"
                        print(log_str)
                        with open(self.cmd_log_file, "a") as f:
                            f.write(log_str + "\n")
                    elif cmd == mavlink.MAV_CMD_MISSION_START:
                        self.custom_mode = self.mode_map.get("AUTO", 3)
                        log_str = f"[{timestamp}] [SIMULATOR MAVLINK RECEIVED] MAV_CMD_MISSION_START -> mode={self.custom_mode}"
                        print(log_str)
                        with open(self.cmd_log_file, "a") as f:
                            f.write(log_str + "\n")
                    elif cmd == mavlink.MAV_CMD_DO_SET_MODE:
                        self.custom_mode = int(msg.param2)
                        log_str = f"[{timestamp}] [SIMULATOR MAVLINK RECEIVED] MAV_CMD_DO_SET_MODE: mode={self.custom_mode}"
                        print(log_str)
                        with open(self.cmd_log_file, "a") as f:
                            f.write(log_str + "\n")

                elif mtype == "MISSION_REQUEST_LIST":
                    target_sys = getattr(msg, "target_system", 0)
                    target_comp = getattr(msg, "target_component", 0)
                    m_type = getattr(msg, "mission_type", 0)
                    count = len(self.mission_items)
                    log_str = f"[{timestamp}] [SIMULATOR MAVLINK RECEIVED] MISSION_REQUEST_LIST: count={count}, type={m_type}"
                    print(log_str)
                    with open(self.cmd_log_file, "a") as f:
                        f.write(log_str + "\n")
                    self.mav.mission_count_send(
                        target_system=target_sys,
                        target_component=target_comp,
                        count=count,
                        mission_type=m_type,
                    )
                elif mtype == "MISSION_COUNT":
                    target_sys = msg.get_srcSystem()
                    target_comp = msg.get_srcComponent()
                    m_type = getattr(msg, "mission_type", 0)
                    self.expected_mission_count = getattr(msg, "count", 0)
                    self.incoming_mission_items = []
                    log_str = f"[{timestamp}] [SIMULATOR MAVLINK RECEIVED] MISSION_COUNT: count={self.expected_mission_count}, type={m_type}"
                    print(log_str)
                    with open(self.cmd_log_file, "a") as f:
                        f.write(log_str + "\n")
                    if self.expected_mission_count == 0:
                        self.mission_items = []
                        self.mav.mission_ack_send(
                            target_system=target_sys,
                            target_component=target_comp,
                            type=mavlink.MAV_MISSION_ACCEPTED,
                            mission_type=m_type,
                        )
                    else:
                        self.mav.mission_request_int_send(
                            target_system=target_sys,
                            target_component=target_comp,
                            seq=0,
                            mission_type=m_type,
                        )
                elif mtype in ("MISSION_ITEM_INT", "MISSION_ITEM"):
                    target_sys = msg.get_srcSystem()
                    target_comp = msg.get_srcComponent()
                    m_type = getattr(msg, "mission_type", 0)
                    seq = getattr(msg, "seq", len(self.incoming_mission_items))
                    log_str = f"[{timestamp}] [SIMULATOR MAVLINK RECEIVED] {mtype}: seq={seq}, cmd={getattr(msg, 'command', 0)}"
                    print(log_str)
                    with open(self.cmd_log_file, "a") as f:
                        f.write(log_str + "\n")
                    self.incoming_mission_items.append(msg)
                    if len(self.incoming_mission_items) < self.expected_mission_count:
                        next_seq = len(self.incoming_mission_items)
                        self.mav.mission_request_int_send(
                            target_system=target_sys,
                            target_component=target_comp,
                            seq=next_seq,
                            mission_type=m_type,
                        )
                    else:
                        self.mission_items = list(self.incoming_mission_items)
                        self.mav.mission_ack_send(
                            target_system=target_sys,
                            target_component=target_comp,
                            type=mavlink.MAV_MISSION_ACCEPTED,
                            mission_type=m_type,
                        )
                        print(f"[SIMULATOR] Successfully received and stored {len(self.mission_items)} mission items!")
                elif mtype in ("MISSION_REQUEST_INT", "MISSION_REQUEST"):
                    target_sys = msg.get_srcSystem()
                    target_comp = msg.get_srcComponent()
                    req_seq = getattr(msg, "seq", 0)
                    m_type = getattr(msg, "mission_type", 0)
                    log_str = f"[{timestamp}] [SIMULATOR MAVLINK RECEIVED] {mtype}: seq={req_seq}, type={m_type}"
                    print(log_str)
                    with open(self.cmd_log_file, "a") as f:
                        f.write(log_str + "\n")
                    if 0 <= req_seq < len(self.mission_items):
                        item = self.mission_items[req_seq]
                        x = getattr(item, "x", 0)
                        y = getattr(item, "y", 0)
                        if isinstance(x, float) and abs(x) <= 180:
                            int_x = int(x * 1e7)
                            int_y = int(y * 1e7)
                        else:
                            int_x = int(x)
                            int_y = int(y)
                        self.mav.mission_item_int_send(
                            target_system=target_sys,
                            target_component=target_comp,
                            seq=req_seq,
                            frame=getattr(item, "frame", mavlink.MAV_FRAME_GLOBAL_RELATIVE_ALT),
                            command=getattr(item, "command", mavlink.MAV_CMD_NAV_WAYPOINT),
                            current=getattr(item, "current", 0),
                            autocontinue=getattr(item, "autocontinue", 1),
                            param1=getattr(item, "param1", 0.0),
                            param2=getattr(item, "param2", 0.0),
                            param3=getattr(item, "param3", 0.0),
                            param4=getattr(item, "param4", 0.0),
                            x=int_x,
                            y=int_y,
                            z=getattr(item, "z", 50.0),
                            mission_type=m_type,
                        )
                elif mtype == "MISSION_CLEAR_ALL":
                    target_sys = msg.get_srcSystem()
                    target_comp = msg.get_srcComponent()
                    m_type = getattr(msg, "mission_type", 0)
                    self.mission_items = []
                    log_str = f"[{timestamp}] [SIMULATOR MAVLINK RECEIVED] MISSION_CLEAR_ALL"
                    print(log_str)
                    with open(self.cmd_log_file, "a") as f:
                        f.write(log_str + "\n")
                    self.mav.mission_ack_send(
                        target_system=target_sys,
                        target_component=target_comp,
                        type=mavlink.MAV_MISSION_ACCEPTED,
                        mission_type=m_type,
                    )
                elif mtype == "MISSION_ACK":
                    ack_type = getattr(msg, "type", 0)
                    log_str = f"[{timestamp}] [SIMULATOR MAVLINK RECEIVED] MISSION_ACK: type={ack_type}"
                    print(log_str)
                    with open(self.cmd_log_file, "a") as f:
                        f.write(log_str + "\n")
                elif mtype == "PARAM_REQUEST_LIST":
                    log_str = f"[{timestamp}] [SIMULATOR MAVLINK RECEIVED] PARAM_REQUEST_LIST"
                    print(log_str)
                    with open(self.cmd_log_file, "a") as f:
                        f.write(log_str + "\n")
                    self.send_all_parameters()
                elif mtype == "PARAM_REQUEST_READ":
                    p_idx = getattr(msg, "param_index", -1)
                    p_id = getattr(msg, "param_id", "")
                    if isinstance(p_id, bytes):
                        p_id_str = p_id.decode("ascii", errors="ignore").rstrip("\0")
                    else:
                        p_id_str = str(p_id).rstrip("\0")
                    if p_id_str == "_HASH_CHECK":
                        pname_bytes = b"_HASH_CHECK".ljust(16, b"\0")
                        self.mav.param_value_send(
                            param_id=pname_bytes,
                            param_value=0.0,
                            param_type=mavlink.MAV_PARAM_TYPE_UINT32,
                            param_count=len(self.params),
                            param_index=65535,
                        )
                    else:
                        self.send_single_parameter(p_idx, p_id)
                elif mtype == "PARAM_SET":
                    p_id = getattr(msg, "param_id", "")
                    p_val = getattr(msg, "param_value", 0.0)
                    p_type = getattr(msg, "param_type", 0)
                    self.handle_param_set(p_id, p_val, p_type)
                elif mtype == "SET_MODE":
                    self.custom_mode = int(getattr(msg, "custom_mode", self.custom_mode))
                    log_str = f"[{timestamp}] [SIMULATOR MAVLINK RECEIVED] SET_MODE: custom_mode={self.custom_mode}"
                    print(log_str)
                    with open(self.cmd_log_file, "a") as f:
                        f.write(log_str + "\n")
                elif mtype == "COMMAND_INT":
                    log_str = f"[{timestamp}] [SIMULATOR MAVLINK RECEIVED] COMMAND_INT: {msg.to_dict()}"
                    print(log_str)
                    with open(self.cmd_log_file, "a") as f:
                        f.write(log_str + "\n")
        except Exception:
            pass

    def run(self) -> None:
        self.running = True
        if self.protocol == "tcp":
            print(f"[SIMULATOR] Chandipur Ground Station TCP Telemetry Server listening on {self.host}:{self.port} (sysid={self.sysid}, autopilot={self.autopilot})...")
            print(f"[SIMULATOR] Ready for IZI GCS TCP connection to {self.host}:{self.port}")
        else:
            print(f"[SIMULATOR] Starting telemetry broadcaster to {self.host}:{self.port} (sysid={self.sysid}, initial state={self.state}, autopilot={self.autopilot})...")
        with open(self.state_file, "w") as f:
            f.write(self.state)

        loop_count = 0
        try:
            while self.running:
                loop_count += 1
                self.check_state_file()
                self.handle_incoming_messages()

                if self.state in ("telemetry_loss", "paused", "disconnected"):
                    time.sleep(0.1)
                    continue

                # 10 Hz telemetry: Attitude & Global Position
                self.send_attitude()
                self.send_global_position()

                # 5 Hz: GPS Raw & VFR HUD & Baro & Mag & LRF & Gimbal
                if loop_count % 2 == 0:
                    self.send_gps_raw()
                    self.send_vfr_hud()
                    self.send_scaled_pressure()
                    self.send_raw_imu()
                    self.send_rangefinder()
                    self.send_mount_status()

                # 2 Hz: Sys Status & Extended Sys State
                if loop_count % 5 == 0:
                    self.send_sys_status()
                    self.send_extended_sys_state()

                # 1 Hz: Heartbeat & Home Position
                if loop_count % 10 == 0:
                    self.send_heartbeat()
                    self.send_home_position()
                    if self.with_camera:
                        self.send_camera_heartbeat()

                # Auto-stream all parameters to QGCS at 1.5s to ensure immediate parameter availability
                if loop_count == 15:
                    self.send_all_parameters()

                time.sleep(0.1)
        except KeyboardInterrupt:
            print("[SIMULATOR] Stopped by operator.")
        finally:
            self.running = False


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="MAVLink Vehicle Telemetry Simulator (Chandipur GS & UDP)")
    parser.add_argument("--host", default="127.0.0.1", help="Destination IP (for UDP) or Bind IP (for TCP)")
    parser.add_argument("--port", type=int, default=14550, help="Port (14550 for UDP, 20002 for TCP)")
    parser.add_argument("--protocol", choices=["udp", "tcp"], default="udp", help="Transport protocol (udp or tcp)")
    parser.add_argument("--tcp", action="store_true", help="Start as TCP server on port 20002 (Chandipur GS simulation mode)")
    parser.add_argument("--sysid", type=int, default=1, help="Vehicle System ID")
    parser.add_argument("--scenario", default="ground_disarmed", choices=["ground_disarmed", "ground_armed", "airborne", "telemetry_loss", "paused", "disconnected"], help="Initial scenario")
    parser.add_argument("--autopilot", default="generic", choices=["generic", "px4", "ardupilot"], help="Autopilot type")
    parser.add_argument("--cmd-log", default="/tmp/qgcs_mavlink_cmds.log", help="Command log file")
    parser.add_argument("--state-file", default="/tmp/qgcs_sim_state", help="State file for dynamic transitions")
    parser.add_argument("--with-camera", action="store_true", help="Simulate dual RGB/Thermal camera component (compid=100)")
    args = parser.parse_args()

    if args.tcp:
        args.protocol = "tcp"
        if args.port == 14550:
            args.port = 20002
        if args.host == "127.0.0.1":
            args.host = "0.0.0.0"

    sim = VehicleTelemetrySimulator(
        host=args.host,
        port=args.port,
        sysid=args.sysid,
        state=args.scenario,
        state_file=args.state_file,
        autopilot=args.autopilot,
        cmd_log_file=args.cmd_log,
        with_camera=args.with_camera,
        protocol=args.protocol,
    )
    sim.run()
