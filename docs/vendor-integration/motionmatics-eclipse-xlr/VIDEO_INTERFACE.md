# MotionMatics ECLIPSE X-LR — Video Interface Specification

## 1. Video Architecture Overview

The MotionMatics ECLIPSE X-LR payload features concurrent dual video output capability, streaming both an Electro-Optical (EO) daylight stream and an uncooled Thermal Infrared (TI) stream over Ethernet IP.

```
+-------------------------------------------------------------+
|               ECLIPSE X-LR Onboard Video Pipeline           |
|                                                             |
|  [EO Sensor] ---> [ISP / EIS] ----------> [H.264/H.265 Enc] -+
|  1080p @ 30/60fps                                           | |
|                                                             v v  RTSP Server
|  [TI Sensor] ---> [Palette / NUC / DDE] -> [H.264/H.265 Enc] -+  (:554 / :8554)
|  640x512 @ 25/30fps                                         |         |
+-------------------------------------------------------------+         |
                                                                        v
+-------------------------------------------------------------+    Ethernet /
|              IZI QGCS Dual Video Receiver Pipeline          |    PMDDL Link
|                                                             |         |
|  [CompanyNetworkSettings]                                   |<--------+
|    rgbVideoUrl:     "rtsp://<payload-ip>:554/live/eo"       |
|    thermalVideoUrl: "rtsp://<payload-ip>:554/live/ti"       |
|                                                             |
|  [CameraView.qml]                                           |
|    +-----------------------------+ +---------------------+  |
|    | Main Display (EO or TI)     | | PIP Window (Swap)   |  |
|    | [QGC GStreamer VideoItem 1] | | [VideoItem 2]       |  |
|    +-----------------------------+ +---------------------+  |
+-------------------------------------------------------------+
```

---

## 2. Stream Specifications

| Parameter | Daylight (EO) Stream | Thermal Infrared (TI) Stream | Status |
| :--- | :--- | :--- | :--- |
| **Sensor Resolution** | 1080p ($1920 \times 1080$) | $640 \times 512$ or $640 \times 480$ | `VERIFIED` |
| **Output Frame Rate** | 30 fps / 60 fps | 25 fps / 30 fps (PAL/NTSC base) | `VERIFIED` |
| **Compression Formats** | H.264 (AVC) / H.265 (HEVC) | H.264 (AVC) / H.265 (HEVC) | `VERIFIED` |
| **Streaming Protocol** | RTSP / RTP over TCP/UDP | RTSP / RTP over TCP/UDP | `VERIFIED` |
| **Encoding Bitrate** | 2.0 Mbps – 8.0 Mbps (configurable) | 1.0 Mbps – 3.0 Mbps (configurable) | `UNVERIFIED` |
| **Latency** | $< 120\text{ ms}$ glass-to-glass (claimed) | $< 120\text{ ms}$ glass-to-glass (claimed) | `HARDWARE TEST REQUIRED` |
| **OSD Overlay** | Target reticle, crosshair, zoom index | Reticle, palette label, temp scale | `UNVERIFIED` |

---

## 3. RTSP Endpoint Configuration

In Phase 7C, `CompanyNetworkSettings` was implemented to centrally manage and persist video endpoints:
- `rgbVideoUrl`: Configurable string (e.g. `rtsp://192.168.1.100:554/live/eo`)
- `thermalVideoUrl`: Configurable string (e.g. `rtsp://192.168.1.100:554/live/ti`)

### Vendor-Specific Endpoint Requirements (`VENDOR DOCUMENTATION REQUIRED`)
The exact URL mount points and factory default IP must be confirmed by MotionMatics:
- **Factory Default IP**: Commonly `192.168.1.100`, `192.168.144.25`, or `192.168.2.119`.
- **RTSP Port**: Standard port `554` or alternative `8554`.
- **Stream Paths**:
  - EO Path: `/live/eo`, `/stream1`, `/h264`, or `/ch0`
  - TI Path: `/live/ti`, `/stream2`, `/thermal`, or `/ch1`
- **Authentication**: Anonymous access vs RTSP digest authentication (username/password).

---

## 4. GCS Receiver Pipeline Integration

### 4.1 GStreamer Pipeline Architecture
QGroundControl utilizes a unified GStreamer pipeline backend (`src/VideoManager/`). The pipeline auto-negotiates RTSP stream parameters:
```text
rtspsrc location=<url> latency=50 protocols=tcp ! rtph264depay ! h264parse ! decodebin ! videoconvert ! qtvideosink
```
For H.265 payloads:
```text
rtspsrc location=<url> latency=50 protocols=tcp ! rtph265depay ! h265parse ! decodebin ! videoconvert ! qtvideosink
```

### 4.2 CameraView Integration
`custom/ui/CameraView.qml` contains the operational dual-view layout:
1. **Primary Feed Area**: High-resolution video surface with crosshair HUD, flight telemetry overlay, and tracking bounding boxes.
2. **Picture-in-Picture (PIP) Window**: Secondary feed rendered simultaneously in a draggable/dockable corner overlay.
3. **Swap Feed Action**: Single-click toggling between EO and TI feeds without dropping network connections or re-initializing the decoder pipeline.

---

## 5. Verification Status & Action Matrix

| Sub-Item | Status | Requirement to Resolve |
| :--- | :--- | :--- |
| Dual stream streaming capability | `VERIFIED` | Confirmed by MotionMatics product features |
| H.264 / H.265 compression support | `VERIFIED` | Supported by GCS GStreamer backend |
| Default IP address and netmask | `VENDOR DOCUMENTATION REQUIRED` | Obtain network configuration manual |
| Default RTSP URI mount points | `VENDOR DOCUMENTATION REQUIRED` | Obtain URI naming table |
| RTSP authentication scheme | `VENDOR DOCUMENTATION REQUIRED` | Confirm credentials if authentication is enforced |
| Glass-to-glass latency measurement | `HARDWARE TEST REQUIRED` | Bench test with hardware payload and PMDDL datalink |
| Decoder performance under CPU/GPU load | `HARDWARE TEST REQUIRED` | Evaluate simultaneous 1080p60 + 512p30 decode on target GCS PC |
