# MotionMatics ECLIPSE X-LR — Gimbal Control Interface Specification

## 1. Mechanical Kinematics & Physical Bounds

| Axis | Angular Travel Range | Control Resolution | Slew Rate Limit | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Pitch (Elevation)** | $-45^\circ\text{ to }+100^\circ$ (Nadir to Zenith) | $\pm 0.01^\circ$ | Up to $90^\circ/\text{s}$ | `VERIFIED` |
| **Yaw (Azimuth)** | $-270^\circ\text{ to }+270^\circ\text{ (}540^\circ\text{)}$ or $360^\circ \times N$ continuous | $\pm 0.01^\circ$ | Up to $120^\circ/\text{s}$ | `VERIFIED` |
| **Roll (Bank)** | $\pm 35^\circ\text{ to }\pm 45^\circ\text{ (stabilization only)}$ | $\pm 0.01^\circ$ | Dynamic stabilization | `UNVERIFIED` |

> [!IMPORTANT]
> **Pitch Range Constraint**: MotionMatics ECLIPSE X-LR specifies pitch limits of $-45^\circ$ to $+100^\circ$. True vertical nadir ($-90^\circ$) depends on payload mounting orientation (inverted vs upright) and configuration. The GCS control UI must enforce software clamping within $[-45.0^\circ, +100.0^\circ]$ to prevent servo stall or gimbal lock.

---

## 2. Operating Modes & Behavior

```
+-------------------------------------------------------------------------------+
|                            Gimbal Operating Modes                             |
+---------------------+-----------------------+---------------------------------+
| Mode Name           | Description           | Target Reference                |
+---------------------+-----------------------+---------------------------------+
| RATE CONTROL        | Proportional velocity | Joystick / On-screen D-Pad deg/s|
| ANGLE (BODY FRAME)  | Absolute angle        | Relative to UAV nose / fuselage |
| ANGLE (EARTH FRAME) | Geo-stabilized angle  | Relative to True North / Horizon|
| GEO-POINTING (ROI)  | Track Lat/Lon/Alt     | Point at map coordinate / WP    |
| ACTIVE AI TRACKING  | Visual target lock    | Autonomous optical track box    |
| HOME / STOW         | Reset / Parking       | $0^\circ$ Pitch, $0^\circ$ Yaw  |
+---------------------+-----------------------+---------------------------------+
```

1. **Rate Mode (Manual Jogging)**:
   - Operator commands angular velocity in degrees/second ($\omega_p, \omega_y$).
   - Used for manual target searching and smooth panning.
2. **Angle Mode (Fixed Angle Targeting)**:
   - Operator specifies target Pitch and Yaw in degrees.
   - Slew velocity controlled by onboard motion controller.
3. **Geo-Lock / ROI Mode**:
   - Operator clicks a coordinate on `TacticalMapView.qml`.
   - Autopilot / payload computes line-of-sight vector using vehicle GPS/IMU and steers gimbal to keep coordinate centered.
4. **Active Target Tracking Mode**:
   - Onboard Edge AI locks onto designated target in video stream.
   - Closed-loop gimbal tracking keeps target centered in reticle.

---

## 3. MAVLink Protocol Mapping

### 3.1 Gimbal Protocol v2 (Preferred Standard)

If MotionMatics ECLIPSE X-LR firmware natively implements standard MAVLink Gimbal Protocol v2:

| Action | MAVLink Message / Command | Parameters |
| :--- | :--- | :--- |
| **Set Attitude (Angle)** | `MAV_CMD_DO_GIMBAL_MANAGER_PITCHYAW` (#1000) | Param 1: Pitch (deg)<br>Param 2: Yaw (deg)<br>Param 3: Pitch Rate (deg/s)<br>Param 4: Yaw Rate (deg/s)<br>Param 5: Gimbal Flags (`GIMBAL_MANAGER_FLAGS`) |
| **Set Rate (Jog)** | `MAV_CMD_DO_GIMBAL_MANAGER_PITCHYAW` (#1000) | Param 1: `NaN`<br>Param 2: `NaN`<br>Param 3: Desired Pitch Rate (deg/s)<br>Param 4: Desired Yaw Rate (deg/s) |
| **Configure Manager** | `MAV_CMD_DO_GIMBAL_MANAGER_CONFIGURE` (#1001) | SysID/CompID pairing, primary control authority |
| **Receive Attitude Telemetry** | `GIMBAL_DEVICE_ATTITUDE_STATUS` (#285) | `target_system`, `target_component`, `q` (quaternion), `angular_velocity_x/y/z`, `failure_flags` |
| **Receive Status Telemetry** | `GIMBAL_MANAGER_STATUS` (#281) | `flags`, `primary_sysid`, `primary_compid`, `secondary_sysid`, `secondary_compid` |

### 3.2 Mount Protocol v1 (ArduPilot Legacy Fallback)

If payload integrates with ArduPilot via traditional Mount protocol:

| Action | MAVLink Message / Command | Parameters |
| :--- | :--- | :--- |
| **Steer Mount** | `MAV_CMD_DO_MOUNT_CONTROL` (#205) | Param 1: Pitch ($c^\circ$ or deg)<br>Param 2: Roll ($c^\circ$ or deg)<br>Param 3: Yaw ($c^\circ$ or deg)<br>Param 7: Mount Mode (`MAV_MOUNT_MODE_MAVLINK_TARGETING`) |
| **Configure Mount** | `MAV_CMD_DO_MOUNT_CONFIGURE` (#204) | Param 1: Mount Mode (`MAV_MOUNT_MODE_RC_TARGETING`, `MAV_MOUNT_MODE_GPS_POINT`) |
| **Receive Mount Attitude** | `MOUNT_ORIENTATION` (#265) | `pitch`, `roll`, `yaw_absolute` (deg) |
| **Receive Mount Status** | `MOUNT_STATUS` (#161) | `pointing_a`, `pointing_b`, `pointing_c` |

---

## 4. GCS Software Integration Mapping

### 4.1 UI Controls (`custom/ui/CameraView.qml`)
- **Pitch Control**: Vertical slider / D-Pad with range $[-45^\circ, +100^\circ]$.
- **Yaw Control**: Horizontal slider / D-Pad with continuous or $[-270^\circ, +270^\circ]$ range.
- **Center Button**: Sends `Pitch = 0.0, Yaw = 0.0` reset command.
- **Nadir Button**: Sends maximum depression command (`Pitch = -45.0` or $-90^\circ$ depending on mount orientation).

### 4.2 Telemetry Ingestion (`custom/ui/CompanyTelemetry.qml`)
- `gimbalPitch`: Real-time pitch angle in degrees (displayed on HUD and telemetry card).
- `gimbalRoll`: Real-time roll stabilization angle in degrees.
- `gimbalYaw`: Real-time heading relative to aircraft or North.

### 4.3 Data Logging & External UDP Output
- `CompanyCsvLogger.cc`: Gimbal Pitch, Roll, and Yaw are recorded to the CSV log at 5 Hz.
- `CompanyDataOutput.cc`: Real-time gimbal telemetry is serialized into the Chandipur UDP broadcast packet.

---

## 5. Verification Status & Action Matrix

| Requirement | Status | Resolution Action |
| :--- | :--- | :--- |
| Gimbal pitch physical limits ($-45^\circ\text{ to }+100^\circ$) | `VERIFIED` | Product specifications verified |
| Gimbal yaw physical limits ($-270^\circ\text{ to }+270^\circ$) | `VERIFIED` | Product specifications verified |
| Supported MAVLink Protocol version (v1 vs v2) | `VENDOR DOCUMENTATION REQUIRED` | Request MAVLink ICD from MotionMatics |
| Default MAVLink Component ID (`154` vs `1`) | `VENDOR DOCUMENTATION REQUIRED` | Confirm sysid/compid addressing |
| Rate-control deadband and sensitivity | `HARDWARE TEST REQUIRED` | Bench testing with physical joystick/UI |
| Angular drift and stabilization precision | `HARDWARE TEST REQUIRED` | Vibration bench testing |
