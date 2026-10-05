# Phase 9 Hardware Integration Matrix

**Project:** IZI QGCS — Chandipur DRDO Range Delivery  
**Target Hardware:** Cube Orange Plus (ArduPilot 4.4.4) + Microhard pMDDL2450 Datalink + MotionMatics ECLIPSE X-LR / X10 EO/IR Payload  
**Status:** Pre-Bench Integration Baseline  
**Rule:** No vendor protocols or magic bytes are fabricated. Any subsystem awaiting MotionMatics documentation is strictly designated as **`BLOCKED — VENDOR ICD REQUIRED`**.

---

## 1. Hardware Integration Matrix

| # | Subsystem | Physical Interface | Protocol | IP / Port / Pinout | QGCS Component | Vendor ICD Required | Test Status |
|---|---|---|---|---|---|---|---|
| **1** | **Autopilot Telemetry (Cube Orange+)** | USB-C (Bench) / TELEM1/TELEM2 (Serial) $\to$ pMDDL COM1 | MAVLink 2.0 (ArduPilot 4.4.4) | Serial 57600/115200 baud or UDP port 14550 | `MAVLinkProtocol`, `Vehicle`, `MultiVehicleManager` | **NO** (Standard MAVLink 2.0 protocol) | `READY FOR BENCH TEST` |
| **2** | **Datalink Bridge (Microhard pMDDL2450)** | RJ45 10/100 Ethernet (GCS modem) $\leftrightarrow$ Airborne modem (MIMO RF) | Transparent Layer-2 Ethernet / IP Bridge | Ground Modem IP: `192.168.168.1` / Air: `192.168.168.2` (Subnet: `/24`) | `CompanyNetworkSettings`, `UDPLink` | **NO** (Standard IEEE 802.3 Ethernet) | `READY FOR BENCH TEST` |
| **3** | **Flight Telemetry (GPS, Attitude, Battery, Mode)** | Ethernet over pMDDL (Airborne serial gateway or Ethernet) | MAVLink 2.0 (`ATTITUDE`, `GLOBAL_POSITION_INT`, `SYS_STATUS`, `BATTERY_STATUS`, `HEARTBEAT`) | UDP port 14550 | `CompanyTelemetry`, `TacticalMapView`, `DashboardView`, `TopBar` | **NO** (Standard MAVLink telemetry) | `READY FOR BENCH TEST` |
| **4** | **EO (Daylight) Video Ingestion** | RJ45 10/100 Ethernet from Eclipse X10 $\to$ Airborne pMDDL LAN port | RTSP / RTP / UDP (H.264 / H.265) | `rtsp://<ECLIPSE_IP>:554/<eo_path>` or UDP port 5600 | `VideoManager`, `VideoReceiver[0]`, `CameraView.qml` | **NO** (Standard RTSP / H.264 bitstream) | `READY FOR BENCH TEST` (Awaiting physical IP/URL from vendor) |
| **5** | **Thermal (IR) Video Ingestion** | RJ45 10/100 Ethernet from Eclipse X10 $\to$ Airborne pMDDL LAN port | RTSP / RTP / UDP (H.264 / H.265) | `rtsp://<ECLIPSE_IP>:8554/<ir_path>` or UDP port 5601 | `VideoManager`, `VideoReceiver[1]`, `CameraView.qml` | **NO** (Standard RTSP / H.264 bitstream) | `READY FOR BENCH TEST` (Awaiting physical IP/URL from vendor) |
| **6** | **Dual Video Display Layouts (Split, Full, PIP)** | QGCS GPU/QML Surface Render Engine | Internal Qt Quick / OpenGL Texture Blending | N/A (Internal GCS Display Pipeline) | `CameraView.qml` (`modeToolbar`, `splitLayout`, `pipWindow`) | **NO** (Pure GCS software architecture) | `READY FOR BENCH TEST` (Empirically verified in Phase 8B) |
| **7** | **Gimbal Pitch / Yaw / Roll Control** | RS422 / Serial COM from Eclipse X10 OR Ethernet UDP/TCP | Proprietary binary payload protocol OR MAVLink Gimbal Protocol v2 | Awaiting vendor port / serial pinout | `CompanyPayloadInterface`, `MotionMaticsEclipseAdapter` | **YES** (MotionMatics Gimbal Control ICD) | **`BLOCKED — VENDOR ICD REQUIRED`** |
| **8** | **Camera Optical Zoom & Focus** | Ethernet UDP/TCP OR RS422 | Proprietary binary camera command packet | Awaiting vendor port / command IDs | `CameraView.qml` (Zoom buttons), `CompanyPayloadInterface` | **YES** (MotionMatics Camera Control ICD) | **`BLOCKED — VENDOR ICD REQUIRED`** |
| **9** | **Camera Snapshot & Video Recording** | *GCS-Side:* Local Frame Grab & GStreamer MP4 Encoder<br>*Onboard:* Internal SD Card Trigger | *GCS-Side:* Native QGC GStreamer<br>*Onboard:* Proprietary vendor trigger packet | *GCS-Side:* Local disk (`/tmp/qgc_save/Video`)<br>*Onboard:* Awaiting vendor command code | `CameraView.qml`, `VideoManager`, `CompanyPayloadInterface` | *GCS-Side:* **NO** (100% Ready)<br>*Onboard:* **YES** (Vendor Storage ICD) | *GCS-Side:* `READY FOR BENCH TEST`<br>*Onboard:* **`BLOCKED — VENDOR ICD REQUIRED`** |
| **10** | **Laser Range Finder (LRF) Telemetry** | Ethernet UDP datagram OR MAVLink `DISTANCE_SENSOR` from FC/Payload | Proprietary binary LRF packet OR MAVLink `DISTANCE_SENSOR` | Awaiting vendor LRF telemetry format | `CompanyPayloadInterface::lrfDistanceMeters`, Tactical OSD HUD | **YES** (MotionMatics LRF Telemetry ICD) | **`BLOCKED — VENDOR ICD REQUIRED`** |
| **11** | **CSV Telemetry Logging Engine** | Local Storage System | Periodic time-series CSV writer (16 DRDO fields + events) | Local filesystem (`/tmp/qgc_save/Telemetry/`) | `CompanyCsvLogger` | **NO** (Internal QGCS logging engine) | `READY FOR BENCH TEST` |
| **12** | **DRDO UDP Telemetry Output** | Host Ethernet NIC (connected to DRDO evaluation subnet) | Dedicated JSON datagram socket (16 DRDO telemetry fields) | Configurable Target IP: `192.168.1.55` / Port: `14600` (or local `14445`) | `CompanyDataOutput`, `CompanyNetworkSettings` | **NO** (DRDO JSON schema implemented) | `READY FOR BENCH TEST` |
| **13** | **Offline Map Operation** | Local SQLite tile database (`qgcMapCache.db`) | Local tile cache ingestion (`.qct` / `.zip`) | Local disk (Zero internet dependency) | `QGCMapEngineManager`, `SettingsView.qml`, `TacticalMapView.qml` | **NO** (Native QGC tile engine) | `READY FOR BENCH TEST` |
| **14** | **Onboard BIN Flight Log Listing / Download** | Ethernet over pMDDL $\to$ Cube Orange+ | MAVLink FTP (`LOG_REQUEST_LIST`, `LOG_REQUEST_DATA`) | UDP port 14550 | `OnboardLogController`, `FlightLogsView.qml` | **NO** (Standard ArduPilot MAVLink FTP) | `READY FOR BENCH TEST` |

---

## 2. Summary of Interface Readiness

```text
┌──────────────────────────────────────────────┬───────┬────────────────────────────────────────────┐
│ Category                                     │ Count │ Subsystems                                 │
├──────────────────────────────────────────────┼───────┼────────────────────────────────────────────┤
│ 100% Ready for Bench Integration             │ 9     │ Autopilot, pMDDL Bridge, Flight Telemetry, │
│                                              │       │ Dual Layouts, GCS Recording, CSV Logging,  │
│                                              │       │ DRDO UDP Output, Offline Maps, Flight Logs │
├──────────────────────────────────────────────┼───────┼────────────────────────────────────────────┤
│ Ready for Bench (Awaiting Vendor IP/Mount)   │ 2     │ EO RTSP Video, Thermal RTSP Video          │
├──────────────────────────────────────────────┼───────┼────────────────────────────────────────────┤
│ Blocked on Vendor ICD (MotionMatics)         │ 4     │ Gimbal Control, Zoom/Focus, Onboard SD REC,│
│                                              │       │ LRF Telemetry                              │
└──────────────────────────────────────────────┴───────┴────────────────────────────────────────────┘
```

---

## 3. Risk Mitigation & Protocol Isolation Strategy

1. **Vendor Protocol Sandbox:** All MotionMatics hardware communications will be encapsulated exclusively inside `custom/src/MotionMaticsEclipseAdapter.cc`. Neither QGroundControl core nor `CompanyPayloadInterface` will be contaminated with vendor-specific structs or magic bytes.
2. **Dual-Path Fallback:** If the physical gimbal does not speak standard MAVLink Gimbal Protocol v2, the operator can steer the gimbal using the existing Viewlink software on a secondary monitor while QGCS maintains primary flight telemetry, dual-video display, CSV logging, and DRDO UDP data forwarding without disruption.
3. **Lossless GCS-Side Video Capture:** Because onboard SD recording requires vendor ICD commands, QGCS provides immediate GCS-side high-resolution snapshot capture and lossless MP4 recording directly from the incoming RTSP streams.
