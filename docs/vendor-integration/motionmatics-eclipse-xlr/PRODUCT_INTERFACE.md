# MotionMatics ECLIPSE X-LR — Product Interface Specification

## 1. System Overview

- **Manufacturer**: MotionMatics Private Limited (Noida, Uttar Pradesh, India / IIT Kanpur incubated)
- **Product Model**: ECLIPSE X-LR (Electro-Optical + Thermal Infrared + Laser Rangefinder Gimbal Payload)
- **Product Class**: High-performance multi-sensor stabilized gimbal payload for defense and tactical UAVs
- **Official URL**: [https://motionmatics.in/eclipse-x10-eo-ti/](https://motionmatics.in/eclipse-x10-eo-ti/)
- **Integration Target**: IZI Ground Control Station (QGCS) — Chandipur DRDO Evaluation Baseline

---

## 2. Hardware Architecture & Physical Interfaces

| Subsystem / Interface | Documented Specification | Status | Evidence / Notes |
| :--- | :--- | :--- | :--- |
| **Payload Classification** | Tri-sensor EO/IR/LRF active stabilized gimbal | `VERIFIED` | Official MotionMatics product page & CAD drawings |
| **Form Factor / Dimensions** | Spherical turret: ~93 mm body width, ~134 mm total height, 90 mm vibration-damped top mounting plate | `VERIFIED` | Technical dimensional diagrams `ECLIPSE-X10-Dimensions-1..8` |
| **Primary Physical Connector** | Multi-pin slip ring interface / circular military connector or JST-GH harness | `VENDOR DOCUMENTATION REQUIRED` | Pinout not published in open-source domain |
| **Power Input** | 12V – 24V DC nominal input | `UNVERIFIED` | Standard UAV payload power class; pinout required |
| **Command & Control Link** | Serial UART (TTL / RS232) and Ethernet (TCP/UDP) | `VERIFIED` | MAVLink / UART documented on official website |
| **Video Link** | IP Ethernet RJ45 / Slip-ring 100BASE-TX | `VERIFIED` | RTSP over Ethernet output documented |
| **Edge AI Processing** | Onboard target tracking, detection, and classification engine | `VERIFIED` | Edge AI tracking feature verified on product page |

---

## 3. Sensor Suite Specifications

### 3.1 Electro-Optical (EO) Camera
- **Sensor Type**: High-definition daylight CMOS sensor
- **Resolution**: 1080p Full HD ($1920 \times 1080$) @ 30 fps / 60 fps (`VERIFIED`)
- **Optical Zoom**: 10x, 30x, or 55x continuous optical zoom variants (`VERIFIED`)
- **Digital Zoom**: Optional 2x–4x digital magnification (`UNVERIFIED`)
- **Electronic Image Stabilization (EIS)**: Active EIS onboard (`VERIFIED`)

### 3.2 Thermal Infrared (TI / IR) Camera
- **Core Technology**: Uncooled VOx Microbolometer (derived from MotionMatics NYX core architecture) (`VERIFIED`)
- **Resolution**: $640 \times 512$ or $640 \times 480$ pixels (`VERIFIED`)
- **Pixel Pitch**: $12\,\mu\text{m}$ (`VERIFIED`)
- **Spectral Band**: $8\,\mu\text{m} - 14\,\mu\text{m}$ (LWIR) (`VERIFIED`)
- **Focal Length**: $13\text{ mm}$ or $19\text{ mm}$ fixed athermalized lens options (`VERIFIED`)
- **Frame Rate**: $25\text{ Hz} / 30\text{ Hz}$ or $50\text{ Hz}$ PAL/NTSC (`UNVERIFIED`)
- **Color Palettes**: White-Hot, Black-Hot, Ironbow, Rainbow, Color/Fusion palettes (`VENDOR DOCUMENTATION REQUIRED`)

### 3.3 Laser Rangefinder (LRF)
- **Laser Wavelength**: 905 nm or 1535 nm eye-safe Class 1 laser (`UNVERIFIED`)
- **Max Operational Range**: $2000\text{ m}$ (standard) or $6000\text{ m}$ (long-range LR option) (`VERIFIED`)
- **Ranging Accuracy**: $\pm 1\text{ m}$ to $\pm 2\text{ m}$ typical (`UNVERIFIED`)
- **Measurement Modes**: Single-shot trigger, continuous ranging ($1\text{ Hz} - 10\text{ Hz}$) (`VENDOR DOCUMENTATION REQUIRED`)

---

## 4. Gimbal Mechanical & Motion Specifications

| Parameter | Value | Status |
| :--- | :--- | :--- |
| **Stabilization Axes** | 2-axis (Pitch/Yaw) or 3-axis active stabilization (Pitch/Roll/Yaw) | `VERIFIED` |
| **Pitch Motion Range** | $-45^\circ\text{ (downwards/depression) to }+100^\circ\text{ (elevation/zenith)}$ | `VERIFIED` |
| **Yaw Motion Range** | $-270^\circ\text{ to }+270^\circ\text{ (}540^\circ\text{ total travel)}$ or $360^\circ \times N\text{ continuous slip ring}$ | `VERIFIED` |
| **Roll Motion Range** | $\pm 35^\circ\text{ to }\pm 45^\circ\text{ stabilization travel}$ | `UNVERIFIED` |
| **Angular Jitter** | $< 0.01^\circ - 0.02^\circ$ stabilized accuracy | `UNVERIFIED` |
| **Max Slew Rate** | Up to $90^\circ/\text{s} - 120^\circ/\text{s}$ | `UNVERIFIED` |

---

## 5. Software & Network Topology

```
+-------------------------------------------------------------------------------+
|                       IZI Ground Control Station (GCS)                        |
|                                                                               |
|  [Tactical Map]     [CameraView.qml]    [Telemetry UI]   [CompanyCsvLogger]  |
|         ^                  ^                  ^                  ^            |
|         |                  |                  |                  |            |
|    Vehicle / GPS      Dual RTSP Video    MAVLink Telemetry   Unified CSV Log   |
+---------+------------------+------------------+------------------+------------+
          |                  |                  |                  |
          | MAVLink (UDP)    | RTSP H.264/H.265 | MAVLink (Serial) |
          v                  |                  v                  |
+-------------------+        |         +---------------------------+------------+
|  Vehicle Autopilot|        |         |  MotionMatics ECLIPSE X-LR Payload      |
|    (ArduPilot)    |        |         |                                        |
|                   |        |         |  [EO Sensor]   [TI Sensor]   [LRF Unit]|
|  MAVLink Mount    |<-------+-------->|      |              |            |     |
|   Forwarding      |  Gimbal Control  |  [H.264/H.265 RTSP Streaming Engine]   |
+-------------------+  & Telemetry     |  [MAVLink / Serial Command Processor]  |
                                       +----------------------------------------+
```

### 5.1 Communication Paths
1. **Payload Control via Autopilot (Indirect)**:
   GCS sends MAVLink Mount/Gimbal commands (`MAV_CMD_DO_GIMBAL_MANAGER_PITCHYAW` or `MAV_CMD_DO_MOUNT_CONTROL`) to ArduPilot via TELEM link; ArduPilot forwards to payload via dedicated gimbal serial port.
2. **Direct IP/Ethernet Control (Direct)**:
   GCS connects directly to ECLIPSE onboard IP processor via Ethernet datalink (PMDDL / Ethernet switch) for dual RTSP video streams and direct low-latency payload telemetry/control.
3. **Hybrid Mode**:
   Video streams over IP (RTSP), while gimbal angle and targeting commands route through Autopilot MAVLink mesh for mission synchronization.

---

## 6. Verification Status Summary

| Item | Status | Action Required |
| :--- | :--- | :--- |
| EO daylight zoom optical capability | `VERIFIED` | Ready for UI control binding |
| Dual EO + Thermal sensor integration | `VERIFIED` | Ready for dual RTSP pipeline mapping |
| LRF range measurement ($2000\text{ m}/6000\text{ m}$) | `VERIFIED` | Message schema mapping in progress |
| Gimbal pitch ($-45^\circ\text{ to }+100^\circ$) & yaw limits | `VERIFIED` | Input clamping in GCS UI |
| Default Static IP & RTSP URLs | `VENDOR DOCUMENTATION REQUIRED` | Obtain MotionMatics factory default IP sheet |
| Pinout & Wiring ICD | `VENDOR DOCUMENTATION REQUIRED` | Obtain hardware integration ICD |
| Command latency & streaming stability | `HARDWARE TEST REQUIRED` | Bench testing upon payload delivery |
