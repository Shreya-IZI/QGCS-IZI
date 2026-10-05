# MotionMatics ECLIPSE X-LR — Camera Control Interface Specification

## 1. Camera System Architecture

The ECLIPSE X-LR camera system incorporates two independent optical sensors controlled via a unified payload processor:
1. **Electro-Optical (EO) Sensor**: Continuous optical zoom daylight camera with autofocus.
2. **Thermal Infrared (TI) Sensor**: Fixed focal length uncooled long-wave infrared (LWIR) thermal imager.

```
+-------------------------------------------------------------------------------+
|                      ECLIPSE X-LR Camera Subsystem                            |
|                                                                               |
|  +--------------------------------+   +------------------------------------+  |
|  |     EO Daylight Sensor         |   |     Thermal Infrared (TI) Sensor   |  |
|  |  - 10x / 30x / 55x Opt Zoom    |   |  - Fixed Athermalized (13mm/19mm)  |  |
|  |  - Continuous / Step Auto Focus|   |  - Digital Zoom (1x, 2x, 4x)       |  |
|  |  - Exposure / Iris / Shutter   |   |  - Color Palettes & NUC/FFC        |  |
|  +----------------+---------------+   +-----------------+------------------+  |
|                   |                                     |                     |
|                   v                                     v                     |
|         [Onboard Media Engine: MicroSD Recording & RTSP Streamer]             |
|         [Payload Command Processor: MAVLink / Proprietary Serial]             |
+-------------------------------------------------------------------------------+
```

---

## 2. Optical Zoom & Focus Specifications

### 2.1 EO Zoom Mechanics
- **Zoom Type**: Motorized continuous optical zoom (`VERIFIED`)
- **Variant Options**: 10x, 30x, or 55x optical magnification (`VERIFIED`)
- **Digital Magnification**: Up to 4x smooth digital zoom (`UNVERIFIED`)
- **Control Modes**:
  - Continuous zoom (zoom in / out at commanded speed)
  - Absolute zoom position (normalized $0.0 - 1.0$ or magnification factor $1\times - 30\times$)

### 2.2 EO Focus Control
- **Autofocus**: Contrast-detect / active phase autofocus (`VERIFIED`)
- **Manual Focus**: Fine step Near / Far jog commands (`UNVERIFIED`)
- **One-Push AF**: Trigger autofocus convergence on central reticle (`UNVERIFIED`)

### 2.3 Thermal Zoom & Digital Detail
- **Optical Zoom**: Fixed optical magnification ($1.0\times$) (`VERIFIED`)
- **Digital E-Zoom**: $1\times, 2\times, 4\times$ electronic magnification (`VERIFIED`)
- **Non-Uniformity Correction (NUC / FFC)**: One-touch mechanical shutter calibration (`VENDOR DOCUMENTATION REQUIRED`)

---

## 3. Imaging Modes & Palettes

| Feature | Description | Status |
| :--- | :--- | :--- |
| **White-Hot** | Standard military surveillance palette (hot targets render white) | `VERIFIED` |
| **Black-Hot** | Inverted thermal polarity (hot targets render black) | `VERIFIED` |
| **Ironbow / Rainbow** | Pseudocolor heat gradient palettes | `VENDOR DOCUMENTATION REQUIRED` |
| **Flat Field Correction (FFC)**| Shutter-based thermal calibration to eliminate drift | `VENDOR DOCUMENTATION REQUIRED` |
| **Electronic Stabilization** | Active gyro-assisted image stabilization | `VERIFIED` |

---

## 4. Capture & Recording Workflow

### 4.1 Still Image Capture
- **Storage Destination**: Onboard High-Speed MicroSD card (UHS-I / Class 10).
- **Format**: JPEG with embedded EXIF metadata (GPS latitude, longitude, altitude, gimbal pitch, roll, yaw).
- **GCS Hook**: Clicking Snapshot in `CameraView.qml` simultaneously commands payload capture and logs `snapshot_event = 1` in `CompanyCsvLogger`.

### 4.2 Onboard Video Recording
- **Recording Formats**: MP4 / MOV (H.264 or H.265).
- **Control Mechanism**: Start Recording / Stop Recording toggle.
- **GCS Hook**: Clicking Record in `CameraView.qml` updates `recording_event = 1 / 0` in `CompanyCsvLogger`.

---

## 5. MAVLink Protocol Mapping

### 5.1 Standard MAVLink Camera Protocol

| Function | MAVLink Command / Message | Parameters |
| :--- | :--- | :--- |
| **Take Photo** | `MAV_CMD_IMAGE_START_CAPTURE` (#2000) | Param 1: Reserved (`0`)<br>Param 2: Interval (s)<br>Param 3: Total photos (`1`)<br>Param 4: Sequence number |
| **Stop Photo** | `MAV_CMD_IMAGE_STOP_CAPTURE` (#2001) | Param 1: Reserved |
| **Start Video** | `MAV_CMD_VIDEO_START_CAPTURE` (#2500) | Param 1: Stream ID (`0`=all, `1`=EO, `2`=TI)<br>Param 2: Status frequency |
| **Stop Video** | `MAV_CMD_VIDEO_STOP_CAPTURE` (#2501) | Param 1: Stream ID |
| **Set Zoom** | `MAV_CMD_SET_CAMERA_ZOOM` (#531) | Param 1: Zoom Type (`ZOOM_TYPE_RANGE` or `ZOOM_TYPE_CONTINUOUS`)<br>Param 2: Zoom Value ($0.0 - 100.0$ or rate $-100.0\text{ to }+100.0$) |
| **Set Focus** | `MAV_CMD_SET_CAMERA_FOCUS` (#532) | Param 1: Focus Type (`FOCUS_TYPE_AUTO` or `FOCUS_TYPE_CONTINUOUS`)<br>Param 2: Focus Value |
| **Camera Info** | `CAMERA_INFORMATION` (#259) | `vendor_name`, `model_name`, `firmware_version`, `focal_length`, `sensor_size_h/v`, `resolution_h/v` |
| **Camera Settings** | `CAMERA_SETTINGS` (#260) | `mode_id` (photo/video), `zoomLevel`, `focusLevel` |
| **Capture Status** | `CAMERA_CAPTURE_STATUS` (#262) | `image_status`, `video_status`, `available_capacity`, `image_count` |
| **FOV Telemetry** | `CAMERA_FOV_STATUS` (#271) | `lat_camera`, `lon_camera`, `alt_camera`, `hfov`, `vfov` |

---

## 6. Field of View (FOV) Computation

The Chandipur DRDO specification requires real-time logging and display of the payload FOV.
In the absence of a direct MAVLink `#271 CAMERA_FOV_STATUS` broadcast, GCS calculates the instantaneous Horizontal Field of View ($HFOV$) from sensor parameters and current zoom factor:

$$\text{HFOV} = 2 \times \arctan\left(\frac{W_{\text{sensor}}}{2 \times f_{\text{lens}} \times Z}\right) \times \frac{180^\circ}{\pi}$$

Where:
- $W_{\text{sensor}}$: Physical sensor width in mm (e.g. $1/2.8'' \approx 5.18\text{ mm}$)
- $f_{\text{lens}}$: Wide-angle focal length (e.g. $4.8\text{ mm}$)
- $Z$: Current optical zoom magnification factor ($1.0\times - 30.0\times$)

---

## 7. Verification Status & Action Matrix

| Item | Status | Action Required |
| :--- | :--- | :--- |
| EO optical zoom range (10x / 30x / 55x) | `VERIFIED` | Product specifications verified |
| TI fixed focal length (13 mm / 19 mm) | `VERIFIED` | Product specifications verified |
| MAVLink Camera Protocol compliance | `VENDOR DOCUMENTATION REQUIRED` | Request camera command specification |
| Thermal palette switching command | `VENDOR DOCUMENTATION REQUIRED` | Obtain proprietary parameter ID / MAVLink command |
| NUC/FFC shutter trigger command | `VENDOR DOCUMENTATION REQUIRED` | Obtain calibration command syntax |
| SD card status and storage feedback | `VENDOR DOCUMENTATION REQUIRED` | Verify `CAMERA_CAPTURE_STATUS` support |
| Snapshot latency from trigger to file | `HARDWARE TEST REQUIRED` | Bench testing with high-speed SD card |
