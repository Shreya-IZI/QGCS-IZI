# MotionMatics ECLIPSE X-LR — Laser Rangefinder (LRF) Interface Specification

## 1. Subsystem Overview

The ECLIPSE X-LR integrates a dedicated Laser Rangefinder (LRF) module mounted co-axially above the dual optical and thermal apertures (confirmed in engineering dimensional drawing `dim_5.jpg`).

```
+-------------------------------------------------------------+
|               ECLIPSE X-LR Turret Front Fascia              |
|                                                             |
|                   +-----------------------+                 |
|                   |  [LRF Laser Aperture] |                 |
|                   |  (Transmitter/Receiver|                 |
|                   +-----------------------+                 |
|                                                             |
|         +-------------------+   +--------------------+      |
|         |  [EO Zoom Lens]   |   |  [Thermal IR Lens] |      |
|         |  (10x/30x/55x)    |   |  (13mm / 19mm)     |      |
|         +-------------------+   +--------------------+      |
+-------------------------------------------------------------+
```

---

## 2. Technical Specifications

| Parameter | Specification | Status | Evidence / Notes |
| :--- | :--- | :--- | :--- |
| **Maximum Range** | $2000\text{ m}$ (Standard) / $6000\text{ m}$ (Long-Range option) | `VERIFIED` | Confirmed on official product page |
| **Minimum Range** | $5\text{ m} - 10\text{ m}$ (estimated blind zone) | `UNVERIFIED` | Typical pulsed time-of-flight sensor limit |
| **Measurement Accuracy** | $\pm 1.0\text{ m} - \pm 2.0\text{ m}$ | `UNVERIFIED` | Typical pulsed diode performance |
| **Laser Wavelength** | 905 nm (semiconductor diode) or 1535 nm (erbium glass eye-safe) | `UNVERIFIED` | Eye safety classification required |
| **Laser Safety Class** | Class 1 (Eye-safe under all operating conditions) | `VENDOR DOCUMENTATION REQUIRED` | Defense compliance certification needed |
| **Pulse Repetition Rate**| Single shot or $1\text{ Hz} - 10\text{ Hz}$ continuous | `VENDOR DOCUMENTATION REQUIRED` | Thermal duty cycle limits |

---

## 3. Operational Behavior & Ranging Modes

1. **Standby Mode**:
   - Laser emitter is disabled to conserve power and eliminate thermal accumulation.
   - Slant distance reports `0.0` or invalid (`-1.0`).
2. **Single-Shot Measurement**:
   - Operator presses "Lase Target" in `CameraView.qml`.
   - Payload fires a discrete pulse train (10–50 ms burst) and returns the verified target distance.
   - Distance holds on HUD for 5 seconds or until next lase.
3. **Continuous Tracking / Ranging Mode**:
   - Laser pulses continuously at $1 - 5\text{ Hz}$ during active target tracking.
   - Distance updates dynamically on HUD, CSV log, and external UDP telemetry stream.
4. **Target Geolocation (Geo-Lock)**:
   - Using vehicle GPS position $(\text{Lat}_v, \text{Lon}_v, \text{Alt}_v)$, vehicle heading/attitude, gimbal pitch/yaw, and LRF slant range ($R$), the system calculates the precise 3D target coordinates $(\text{Lat}_t, \text{Lon}_t, \text{Alt}_t)$:
     $$\vec{P}_{\text{target}} = \vec{P}_{\text{vehicle}} + \mathbf{R}_{\text{body}}^{\text{NED}} \mathbf{R}_{\text{gimbal}}^{\text{body}} \begin{bmatrix} R \cos(\theta_p) \cos(\theta_y) \\ R \cos(\theta_p) \sin(\theta_y) \\ -R \sin(\theta_p) \end{bmatrix}$$

---

## 4. MAVLink Protocol Mapping

### 4.1 Ingestion of Range Data

| Message Name | ID | Field | Data Type | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **`DISTANCE_SENSOR`** | #132 | `current_distance` | `uint16_t` (cm) | Standard MAVLink distance sensor; range up to 655 m (cm resolution) or scaled |
| **`RANGEFINDER`** | #173 | `distance` | `float` (m) | Preferred standard for high-range sensors (supports full $6000\text{ m}$ range) |
| **`TARGET_RELATIVE`** | #511 | `distance` | `float` (m) | Distance relative to target during active tracking |

### 4.2 LRF Triggering / Control Commands

| Action | Proposed MAVLink Command | Expected Parameters |
| :--- | :--- | :--- |
| **Fire Single Shot** | `MAV_CMD_DO_TRIGGER_CONTROL` (#2003) | Param 1: Trigger Enable (`1`)<br>Param 2: Laser Mode (`1`=Single) |
| **Continuous Lasing**| `MAV_CMD_DO_TRIGGER_CONTROL` (#2003) | Param 1: Trigger Enable (`1`)<br>Param 2: Laser Mode (`2`=Continuous)<br>Param 3: Frequency (Hz) |
| **Laser Safety Stop**| `MAV_CMD_DO_TRIGGER_CONTROL` (#2003) | Param 1: Trigger Enable (`0`) |

*(Note: If MotionMatics uses a proprietary payload command format, see `MAVLINK_INTERFACE.md` and `UNKNOWN_ITEMS.md`)*

---

## 5. Integration with IZI QGCS

### 5.1 Telemetry Display (`custom/ui/CompanyTelemetry.qml`)
- `lrfDistance`: Displayed in meters on the tactical telemetry panel.
- Visual warning indicator if distance is out of sensor range or returns error code.

### 5.2 HUD Overlay (`custom/ui/CameraView.qml`)
- Slant range prominently rendered directly beneath the optical crosshair reticle: `LRF: 2450 m`.
- Color coded: Green = Valid lock; Yellow = Weak signal / multipath; Red = Out of range / Error.

### 5.3 Data Logging & UDP Output
- `CompanyCsvLogger.cc`: Column `lrf_distance` written to the active telemetry log.
- `CompanyDataOutput.cc`: Serialized in the Chandipur UDP broadcast payload.

---

## 6. Verification Status & Action Matrix

| Parameter | Status | Required Action |
| :--- | :--- | :--- |
| LRF Maximum Range ($2000\text{ m} / 6000\text{ m}$) | `VERIFIED` | Product specifications verified |
| MAVLink telemetry message ID (`#173` vs `#132`) | `VENDOR DOCUMENTATION REQUIRED` | Request MAVLink telemetry schema from vendor |
| Laser firing command ID | `VENDOR DOCUMENTATION REQUIRED` | Request command ICD from vendor |
| Eye safety classification certificate | `VENDOR DOCUMENTATION REQUIRED` | Request Class 1 certification document for DRDO safety dossier |
| Measurement latency & update frequency | `HARDWARE TEST REQUIRED` | Bench testing with calibrated retro-reflector targets |
