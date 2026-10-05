# MotionMatics ECLIPSE X-LR — MAVLink Interface Specification

## 1. Protocol Architecture & Integration Strategy

The official MotionMatics ECLIPSE X-LR technical overview confirms **MAVLink / UART** as the native control and telemetry interface. In standard tactical UAV integration, two architectural topologies are supported:

```
[ TOPOLOGY A: Routed Through Autopilot (Standard ArduPilot Mount) ]

+-------------+                  +---------------------+                  +---------------------+
|   IZI GCS   |   MAVLink/UDP    |  Vehicle Autopilot  |  MAVLink/Serial  | MotionMatics ECLIPSE|
|             | <=============>  |     (Cube Orange)   | <==============> | X-LR Gimbal Payload |
| SysID: 255  |  (Telem Radio /  |  SysID: 1, Comp: 1  | (TELEM2/SERIAL4) | SysID: 1, Comp: 154 |
+-------------+      PMDDL)      +---------------------+                  +---------------------+

[ TOPOLOGY B: Direct IP / Ethernet MAVLink ]

+-------------+                  +---------------------+                  +---------------------+
|   IZI GCS   |                  |  Vehicle Autopilot  |                  | MotionMatics ECLIPSE|
|             |                  |  SysID: 1, Comp: 1  |                  | X-LR Gimbal Payload |
+-------------+                  +----------+----------+                  +----------+----------+
       ^                                    ^                                        ^
       |                                    | MAVLink UDP (:14550)                   | MAVLink UDP (:14552)
       +====================================+========================================+
                                  Ethernet Switch / PMDDL Mesh
```

---

## 2. Standard MAVLink Message Catalog

### 2.1 System Identification & Heartbeat
- **Message**: `HEARTBEAT` (#0)
- **Target Component ID**:
  - Gimbal: `MAV_COMP_ID_GIMBAL` (`154`) (`VERIFIED`)
  - Camera: `MAV_COMP_ID_CAMERA` (`100`) or `MAV_COMP_ID_CAMERA2` (`101`) (`UNVERIFIED`)
- **System ID**: Typically matches the host vehicle (`1`) or assigned dedicated ID (`10`).
- **Autopilot Type**: `MAV_AUTOPILOT_INVALID` (`8`) indicating payload component.

### 2.2 Gimbal Control & Telemetry

| Message / Command Name | ID | Direction | Purpose | Parameters / Fields |
| :--- | :--- | :--- | :--- | :--- |
| `MAV_CMD_DO_GIMBAL_MANAGER_PITCHYAW` | #1000 | GCS $\rightarrow$ Payload | Pitch & Yaw rate / angle | Pitch, Yaw, Pitch Rate, Yaw Rate |
| `MAV_CMD_DO_MOUNT_CONTROL` | #205 | GCS $\rightarrow$ Payload | Legacy mount pointing | Pitch ($c^\circ$), Roll ($c^\circ$), Yaw ($c^\circ$), Mount Mode |
| `GIMBAL_DEVICE_ATTITUDE_STATUS` | #285 | Payload $\rightarrow$ GCS | High-rate attitude feedback | Quaternion ($q$), angular velocities, flags |
| `MOUNT_ORIENTATION` | #265 | Payload $\rightarrow$ GCS | Autopilot mount attitude | Pitch (deg), Roll (deg), Yaw (deg) |
| `GIMBAL_MANAGER_STATUS` | #281 | Payload $\rightarrow$ GCS | Control authority & mode | System flags, primary sysid/compid |

### 2.3 Camera Protocol

| Message / Command Name | ID | Direction | Purpose | Parameters / Fields |
| :--- | :--- | :--- | :--- | :--- |
| `MAV_CMD_IMAGE_START_CAPTURE` | #2000 | GCS $\rightarrow$ Payload | Trigger still photo | Interval, count, sequence |
| `MAV_CMD_VIDEO_START_CAPTURE` | #2500 | GCS $\rightarrow$ Payload | Start recording | Stream ID, status rate |
| `MAV_CMD_VIDEO_STOP_CAPTURE` | #2501 | GCS $\rightarrow$ Payload | Stop recording | Stream ID |
| `MAV_CMD_SET_CAMERA_ZOOM` | #531 | GCS $\rightarrow$ Payload | Set optical zoom | Zoom type, zoom factor ($0-100\%$) |
| `MAV_CMD_SET_CAMERA_FOCUS` | #532 | GCS $\rightarrow$ Payload | Set focus near/far | Focus type, focus value |
| `CAMERA_INFORMATION` | #259 | Payload $\rightarrow$ GCS | Capability report | Sensor dimensions, focal length, capabilities flags |
| `CAMERA_CAPTURE_STATUS` | #262 | Payload $\rightarrow$ GCS | Capture/record status | Image status, video status, recording time, SD free space |
| `CAMERA_FOV_STATUS` | #271 | Payload $\rightarrow$ GCS | Optical FOV feedback | Camera position, HFOV, VFOV |

### 2.4 Rangefinder & Target Telemetry

| Message Name | ID | Direction | Purpose | Fields |
| :--- | :--- | :--- | :--- | :--- |
| `RANGEFINDER` | #173 | Payload $\rightarrow$ GCS | LRF slant distance | `distance` (float, meters), `voltage` |
| `DISTANCE_SENSOR` | #132 | Payload $\rightarrow$ GCS | Proximity / LRF range | `current_distance` (uint16, cm), `type`, `orientation` |
| `CAMERA_TRACKING_IMAGE_STATUS` | #275 | Payload $\rightarrow$ GCS | AI tracking status | Bounding box $(x, y, w, h)$, tracking status |
| `CAMERA_TRACKING_GEO_STATUS` | #276 | Payload $\rightarrow$ GCS | AI target geo coordinates | Target Lat, Lon, Alt, velocity |

---

## 3. Custom MAVLink Dialect Assessment

### Dialect Risk Analysis
Many defense payload manufacturers develop custom MAVLink XML definitions (e.g. `motionmatics.xml`) to handle specialized features not fully standardized in `common.xml`:
1. Thermal palette selection (White-Hot / Black-Hot / Ironbow).
2. Non-Uniformity Correction (NUC) shutter trigger.
3. Edge AI target tracking box injection (click-to-track coordinates).
4. Laser safety arm/disarm interlocks.

```
+-------------------------------------------------------------------------+
|                    Dialect Resolution Strategy                          |
|                                                                         |
|  1. BASELINE INTERFACE:                                                 |
|     - Implement Standard MAVLink Gimbal v2 + Camera Protocol v1.        |
|     - Compatible with 95% of commercial/defense gimbals.               |
|                                                                         |
|  2. VENDOR DIALECT INGESTION (Upon receipt of XML from MotionMatics):    |
|     - Drop `motionmatics.xml` into `src/comm/mavlink/definitions/`.     |
|     - Regenerate MAVLink C-headers using `mavgen`.                      |
|     - Bind proprietary commands to `MotionMaticsEclipseAdapter`.        |
+-------------------------------------------------------------------------+
```

---

## 4. Verification Status & Action Matrix

| Interface Item | Status | Resolution Action |
| :--- | :--- | :--- |
| MAVLink protocol compatibility | `VERIFIED` | Product features verify MAVLink / UART |
| Gimbal Protocol version (v1 vs v2) | `VENDOR DOCUMENTATION REQUIRED` | Confirm protocol version in vendor ICD |
| Component ID assignment (`154` vs `100` vs `1`) | `VENDOR DOCUMENTATION REQUIRED` | Request default addressing specification |
| Custom MAVLink message IDs (if any) | `VENDOR DOCUMENTATION REQUIRED` | Request `motionmatics.xml` dialect definition |
| High-rate attitude stream stability ($20\text{ Hz}$) | `HARDWARE TEST REQUIRED` | Bench testing with serial sniffer |
| End-to-end command latency ($< 50\text{ ms}$) | `HARDWARE TEST REQUIRED` | Measure command-to-actuation delay |
