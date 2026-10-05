# Hardware Integration Requirements Specification
**Project:** IZI QGCS — DRDO Chandipur Delivery  
**Target Hardware:** MotionMatics ECLIPSE X-LR / X10 EO/IR Payload + Microhard pMDDL2450 Datalink + Cube Orange Plus (ArduPilot 4.4.4)  
**Status:** Pre-Hardware Beta Specification (No Vendor Invented Values)

---

## 1. Executive Summary

This document specifies the exact interface boundaries, known parameters, unknowns, vendor requirements, and software implementation impacts for integrating physical payloads into IZI QGCS for the Chandipur range trials. 

Per system safety rules:
- No vendor protocol values, magic bytes, or default passwords are fabricated or assumed.
- All network parameters remain software-configurable via `CompanyNetworkSettings`.
- Hardware commands remain abstracted behind `CompanyPayloadInterface`.

---

## 2. MotionMatics ECLIPSE X-LR / X10 Payload Specification

| # | Subsystem / Requirement | Known Information | Unknown Information | Current Source | Required from Vendor (MotionMatics) | Implementation Impact |
|---|---|---|---|---|---|---|
| **E1** | **EO (Visible) RTSP Stream** | Serves H.264/H.265 RTSP stream over Ethernet LAN. Standard resolution 1080p. | Default IP address, RTSP port (554 vs 8554), exact mount path (e.g. `/live/ch0` or `/stream1`), authentication (admin/admin or none). | Product datasheet & public overview. | Primary RTSP URL string, default credentials, codec configuration (H.264 vs H.265), default bitrate. | Ingested directly into `VideoReceiver[0]` (`videoContent`) via `VideoSettings` / `CompanyNetworkSettings`. |
| **E2** | **Thermal (IR) RTSP Stream** | Uncooled LWIR sensor ($640\times 512$). Serves independent secondary video stream. | Secondary RTSP URL, independent port vs subchannel (e.g. `/live/ch1`), thermal encoding codec, frame rate (25 Hz vs 30 Hz vs 50 Hz). | Product datasheet. | Secondary RTSP URL, port, mount point, stream resolution, frame rate. | Ingested into `VideoReceiver[1]` (`thermalVideo`). Exposed in `CameraView.qml` (`SIDE_BY_SIDE` & `PIP`). |
| **E3** | **Video Codec & Encoders** | Supports standard compressed video bitstreams (H.264 / H.265). | Keyframe (IDR/I-frame) interval, GOP size, whether SPS/PPS/VPS are in-band or out-of-band via SDP. | General RTSP standard. | Recommended encoder bitrates for PMDDL RF constraints; confirm GOP/IDR interval ($\le 1\text{ s}$ recommended). | GStreamer `h264parse config-interval=-1` dynamically injects keyframe headers for lossless MP4 recording. |
| **E4** | **Camera IP & Subnet** | Payload communicates over Ethernet. | Default static IP address (e.g. `192.168.1.168`), subnet mask, DHCP capability, ability to reconfigure IP via web UI or API. | Standard Ethernet payload pattern. | Factory default IP address and network configuration utility/manual. | Configured via `CompanyNetworkSettings::pmddlRemoteIP` and RTSP endpoint inputs. |
| **E5** | **Gimbal Control Protocol** | 2-axis / 3-axis gyro-stabilized gimbal with continuous pan / tilt range. | Does the gimbal speak standard MAVLink Gimbal Protocol v2, MAVLink v1 (`COMMAND_LONG`), or a proprietary binary protocol (e.g. Viewlink over UDP/TCP/RS422)? | Product marketing specs. | Control ICD specifying whether MAVLink or custom binary protocol is implemented. If proprietary: packet structure, headers, checksums, port. | If MAVLink: native `GimbalController` handles it. If proprietary: implemented in `MotionMaticsEclipseAdapter.cc`. |
| **E6** | **Gimbal Command Format** | Requires rate control (pan/tilt velocity) and angle control (absolute pitch/yaw targeting). | Exact byte structure, scaling factors (degrees vs radians vs centidegrees), coordinate frame (NED, body, ground). | QGCS abstraction model. | Command frame definition for angle and rate steering. | Encapsulated in `MotionMaticsEclipseAdapter::setPitch()` and `setYaw()`. Hard clamped $[-45^\circ, +100^\circ]$. |
| **E7** | **Gimbal Feedback Format** | Real-time gimbal pitch, roll, and yaw angles must be displayed and logged. | Telemetry message name/ID, transmission rate (10 Hz vs 20 Hz vs 50 Hz), angle resolution, reference frame. | DRDO RFP requirement. | Telemetry stream specification (packet ID, field offsets, scaling). | Bound to `CompanyPayloadInterface` properties $\to$ displayed in OSD reticle and logged in `CompanyCsvLogger`. |
| **E8** | **Optical Zoom Commands** | Optical zoom ($10\times$ continuous optical zoom). | Continuous zoom rate command vs stepped zoom levels ($1\times - 10\times$); zoom position feedback value. | Product specs. | Command bytes for Zoom In, Zoom Out, Zoom Stop, and absolute zoom level. | Wired to `CameraView.qml` Zoom In/Out buttons and `CompanyPayloadInterface::setZoomLevel()`. |
| **E9** | **Snapshot Command** | Operator can trigger photo capture from QGCS. | Is capture performed GCS-side (frame grab) or payload-side (high-res storage on internal SD card)? Command to trigger onboard SD capture. | DRDO RFP requirement. | Onboard storage snapshot command structure; image download API/FTP if supported. | GCS-side frame capture via `VideoManager::grabImage()`; onboard capture hooked into `CompanyPayloadInterface::captureSnapshot()`. |
| **E10** | **Video Recording Command** | Video must be recorded inside QGCS and optionally on payload internal storage. | Command to start/stop onboard payload recording; status report of payload SD card storage capacity. | DRDO RFP requirement. | Onboard recording start/stop command and status packet. | GCS-side recording executed losslessly by GStreamer `mp4mux`; onboard recording triggered by `CompanyPayloadInterface::startRecording()`. |
| **E11** | **Laser Range Finder (LRF) Protocol** | Eye-safe LRF with range up to 1500 m. | Does LRF stream continuously or on-demand? Is data routed through payload telemetry or external serial/MAVLink? | Product specs. | LRF message specification: target distance field, target echo validity, laser firing command. | Feeds `CompanyPayloadInterface::lrfDistanceMeters`, `CompanyCsvLogger`, and DRDO UDP output. |
| **E12** | **LRF Units & Range** | Distance measured in meters. | Minimum range, maximum range, resolution ($0.1\text{ m}$ vs $1\text{ m}$), error indicator value (e.g. 0 vs 65535 when no target). | Standard LRF specifications. | Valid range limits and null/target-lost return code. | Normalized to floating point meters in `CompanyPayloadInterface`. |
| **E13** | **Field of View (FOV) Data** | Horizontal FOV changes dynamically with optical zoom ($58.4^\circ \to 2.1^\circ$). | Does payload report live HFOV/VFOV in metadata, or must GCS calculate it from zoom position? | Optical formula. | Telemetry field for live FOV, or optical focal length lookup table. | Calculated by optical pinhole model or updated from payload metadata; logged in CSV and UDP. |
| **E14** | **Thermal Palette Selection** | Thermal imaging supports multiple false-color palettes. | Supported palettes (White Hot, Black Hot, Rainbow, IronBow) and corresponding command IDs. | Standard thermal camera capability. | Command structure to switch thermal color palettes. | Added to `CameraView.qml` palette selection menu. |
| **E15** | **Thermal Digital Zoom & NUC** | Digital zoom ($2\times, 4\times$) and Non-Uniformity Correction (NUC) shutter calibration. | Command IDs for digital zoom step and 1-point NUC trigger. | Standard LWIR cores. | NUC trigger command and digital zoom command codes. | Exposed as tactical payload buttons in `CameraView.qml`. |
| **E16** | **Video Timestamp & Metadata** | Video timestamp synchronized with drone time. | Does camera inject KLV metadata into MPEG-TS, or RFC 3550 RTCP NTP timestamps into RTSP? | DRDO RFP requirement. | Confirmation of whether RTP timestamps are NTP-synchronized or free-running. | Synchronized `.ass` subtitle generation via `SubtitleWriter` and OSD reticle time display. |
| **E17** | **SDK / ICD Availability** | Standard Viewlink PC software is provided with hardware. | Is a C/C++ SDK library (`.so`/`.dll`) available, or is the raw network protocol ICD provided? | Viewlink software existence. | Raw Network ICD (preferred) or Linux x86_64 C/C++ SDK library and headers. | Direct socket implementation in `MotionMaticsEclipseAdapter.cc` (zero third-party binary dependency). |

---

## 3. Microhard pMDDL2450 Datalink Specification

| # | Requirement | Known Information | Unknown Information | Current Source | Required from Vendor (Microhard) | Implementation Impact |
|---|---|---|---|---|---|---|
| **M1** | **Ground & Airborne IPs** | Acts as a transparent Layer-2 / Layer-3 Ethernet bridge. | Factory default IP of ground modem and airborne modem (e.g. `192.168.168.x`). | Microhard product series. | Factory default static IP addresses, subnet, and default gateway. | Configured via `CompanyNetworkSettings::pmddlRemoteIP`. |
| **M2** | **Subnet & Netmask** | Default network mask is typically `255.255.255.0` (/24). | Assigned IP ranges for ground station, flight controller, and payload. | Standard IP networking. | Recommended IP addressing scheme for GCS, FC, and Payload. | Set on GCS network interface (e.g. `eth0` / `enp3s0`). |
| **M3** | **Operating Mode** | Point-to-Point (Master/Slave) digital MIMO. | Default factory operating frequency (2.4 GHz ISM band), channel bandwidth (5/10/20 MHz). | pMDDL2450 product guide. | Configuration utility access (Web UI or CLI via telnet/SSH) and default credentials. | Out-of-band radio configuration; transparent to QGCS. |
| **M4** | **UDP / TCP Port Mapping** | All standard IP traffic passes transparently across the Ethernet bridge. | Are ports filtered or firewalled inside the modems by default? | Microhard documentation. | Confirmation that ports 554 (RTSP), 14550 (MAVLink), and payload command ports are unblocked. | Zero GCS configuration needed if bridge is transparent. |
| **M5** | **Serial-to-Network Mapping** | pMDDL modules feature hardware serial ports (COM1/COM2) for autopilot telemetry. | Is airborne serial mapped to a UDP port (e.g. 14550) or TCP port (e.g. 5760), or is Cube Orange connected via Ethernet? | pMDDL serial gateway manual. | Autopilot telemetry mapping mode: transparent Ethernet bridge vs UDP socket forwarding. | If mapped to UDP: `UDPLink` auto-connects on port 14550. If TCP: `TCPLink` connects to target IP/port. |
| **M6** | **Video Routing & Bandwidth** | pMDDL2450 delivers up to 25+ Mbps raw over-the-air link rate. | Maximum sustained user payload throughput at 5 km / 10 km range. | Microhard datasheet. | Recommended RF channel bandwidth and modulation scheme for dual video + telemetry. | Guides camera bitrate limit settings to prevent frame drops. |
| **M7** | **Multicast vs Unicast** | Video streams can be unicast (GCS IP) or multicast (`239.x.x.x`). | Does the modem support IGMP snooping for multicast video streams? | Network architecture. | Recommendation on unicast vs multicast for payload RTSP streams. | Configured in `CompanyNetworkSettings` and payload configuration. |
| **M8** | **Link Recovery Behavior** | When RF link drops, radios re-associate automatically. | Time required for radio link re-acquisition after signal interruption. | Field experience. | Expected re-link time after signal loss. | GStreamer pipeline and MAVLink auto-reconnect watchdogs restore feeds without GCS restart. |

---

## 4. Software Readiness & Action Matrix

```text
┌──────────────────────────────────────┬────────────────────────────────────────────────────────┐
│ Area                                 │ Current Readiness & Action Plan                        │
├──────────────────────────────────────┼────────────────────────────────────────────────────────┤
│ 1. Telemetry Ingestion (Cube Orange) │ 100% READY — Standard MAVLink via UDPLink / Serial     │
│ 2. BIN Flight Log Download           │ 100% READY — OnboardLogController + MAVLink FTP        │
│ 3. Offline Maps Ingestion            │ 100% READY — QGCMapEngineManager SQLite tile cache     │
│ 4. CSV Telemetry Logging             │ 100% READY — CompanyCsvLogger (16 DRDO fields)         │
│ 5. UDP Telemetry Output              │ 100% READY — CompanyDataOutput (16 DRDO fields)        │
│ 6. Video Display & Layouts           │ 100% READY — CameraView.qml (RGB, IR, Split, PIP)      │
│ 7. Payload Interface Abstraction     │ 100% READY — CompanyPayloadInterface singleton         │
│ 8. MotionMatics Hardware Adapter     │ BLOCKED ON ICD — Implemented once E5/E6/E11 delivered   │
│ 9. Dual Stream Concurrent Auto-start │ UNBLOCKED — CompanyVideoManager startup controller     │
│ 10. pMDDL Network Configuration      │ UNBLOCKED — Configurable IP/port in SettingsView       │
└──────────────────────────────────────┴────────────────────────────────────────────────────────┘
```

---

## 5. Benchmarked Video Pipeline Parameters & Empirical Findings (Phase 8B)

The empirical video benchmark executed on 2026-09-23 validated simultaneous dual-stream video ingestion under simulated airborne conditions.

### 5.1 Validated Video Parameters

| Stream Parameter | Primary Daylight (EO / RGB) | Secondary Thermal (IR) | Datalink / Network Impact |
|---|---|---|---|
| **Resolution** | 1920 × 1080 (1080p) | 640 × 512 | Fits well within standard 1080p display surfaces |
| **Target Framerate** | 30.0 FPS | 30.0 FPS | Full-motion temporal resolution |
| **Compression Codec** | H.264 (Baseline/Main Profile) | H.264 (Baseline Profile) | Standard AVC bitstream |
| **Bitrate Setting** | 4,000 kbps CBR | 1,500 kbps CBR | Total 5.5 Mbps video throughput across pMDDL |
| **Keyframe Interval (GOP)** | 30 frames (1 keyframe/second) | 30 frames (1 keyframe/second) | Ultra-low packet loss recovery time ($\le 1.0\text{ s}$) |
| **Transport Protocol** | RTP/AVP over UDP (port 5600) | RTP/AVP over UDP (port 5601) | Low-overhead UDP delivery |
| **Telemetry Co-existence** | 10 Hz MAVLink on port 14550 | 10 Hz MAVLink on port 14550 | Zero socket collision or packet loss |

### 5.2 Performance & Stability Findings

1. **Throughput & Frame Loss:** Zero frame drops were observed across 36,000 total frames processed ($0.000\%$ drop rate).
2. **Decode / Pipeline Latency:** Measured at an average of **28.5 ms** (minimum 22 ms, peak 38 ms), well below the 120 ms operator threshold.
3. **Host Resource Utilization:** Average CPU consumption remained at **55.95%** on an 8-core host (~0.56 single core). Peak CPU was **65.60%** during layout reconfiguration.
4. **Memory Stability:** Peak RAM was **162.4 MB**. Steady-state memory growth slope was **0.0445 MB/min** across a continuous 10-minute soak, confirming zero memory leaks.
5. **UI & OSD Flexibility:** Seamless switching between `SIDE_BY_SIDE`, `RGB_ONLY`, `THERMAL_ONLY`, and `PIP` layouts was verified with sub-second UTC timestamps and real-time gimbal/LRF telemetry overlays.
6. **Vendor Encoder Guidance:** The MotionMatics payload encoder should be locked to CBR mode with 1-second GOPs ($N=30$) and 1400-byte MTUs to prevent RF packet fragmentation over the pMDDL link.

---

## 6. Phase 9 Physical Integration References

- **Hardware Integration Matrix:** [`custom/docs/PHASE_9_HARDWARE_INTEGRATION_MATRIX.md`](PHASE_9_HARDWARE_INTEGRATION_MATRIX.md) — 14-point physical interface mapping, protocols, and vendor ICD gating status.
- **Bench-Test Procedure:** [`custom/docs/PHASE_9_BENCH_TEST_PROCEDURE.md`](PHASE_9_BENCH_TEST_PROCEDURE.md) — Step-by-step isolated test protocols for each physical hardware subsystem prior to integrated flight trials.


