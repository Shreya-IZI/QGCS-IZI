# MotionMatics ECLIPSE X-LR — QGCS Integration Mapping Specification

## 1. System Integration Architecture

This document defines the exact software mappings between the MotionMatics ECLIPSE X-LR payload subsystem interfaces and the existing IZI Ground Control Station (QGCS) codebase.

```
+---------------------------------------------------------------------------------------------------+
|                                  MotionMatics ECLIPSE X-LR                                        |
|                                                                                                   |
|  [Dual RTSP Video Engine]       [MAVLink / Serial Processor]        [Hardware Sensor Array]       |
|    - EO 1080p Stream              - Pitch / Yaw Servos                - EO Optical Zoom Engine    |
|    - TI 512p Stream               - Attitude Telemetry Feedback       - Uncooled Microbolometer   |
|                                   - Camera Protocol Engine            - Eye-Safe Laser Rangefinder|
+------------------+-----------------------------+----------------------------------+----------------+
                   |                             |                                  |
    RTSP (IP)      |               MAVLink (UDP) |                   Hardware       |
    Video Streams  |               Commands & TLM|                   Telemetry      |
                   v                             v                                  v
+------------------+-----------------------------+----------------------------------+---------------+
|                                     IZI QGCS Integration Layer                                    |
|                                                                                                   |
|  1. VIDEO SUBSYSTEM:                                                                              |
|     - `custom/ui/CameraView.qml`               <-- Dual RTSP Render Surfaces (Main & PIP)         |
|     - `custom/src/CompanyNetworkSettings.cc`   <-- Stores `rgbVideoUrl` and `thermalVideoUrl`     |
|                                                                                                   |
|  2. GCS HUD & CONTROLS:                                                                           |
|     - `custom/ui/CameraView.qml`               <-- Pan/Tilt Jog, Zoom, Focus, Snapshot, LRF Lase  |
|                                                                                                   |
|  3. TELEMETRY & FLIGHT MONITORING:                                                                |
|     - `custom/ui/CompanyTelemetry.qml`          <-- Displays Pitch, Roll, Yaw, LRF, FOV, SD Status |
|                                                                                                   |
|  4. MISSION LOGGING:                                                                              |
|     - `custom/src/CompanyCsvLogger.cc`         <-- Synchronous 5 Hz logging of Gimbal, LRF, FOV   |
|                                                                                                   |
|  5. EXTERNAL DRDO UDP OUTPUT:                                                                     |
|     - `custom/src/CompanyDataOutput.cc`        <-- Serializes Gimbal, LRF, and FOV into UDP stream|
+---------------------------------------------------------------------------------------------------+
```

---

## 2. Detailed Dataflow & Component Mapping Matrix

| Payload Feature / Telemetry | Hardware Interface | QGCS Receiver Component | QGCS UI / Storage Hook | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Daylight Video Feed** | RTSP H.264/H.265 (IP) | `VideoManager` / GStreamer | `CameraView.qml` (`mainVideoItem`) | `VERIFIED` |
| **Thermal Video Feed** | RTSP H.264/H.265 (IP) | `VideoManager` / GStreamer | `CameraView.qml` (`pipVideoItem`) | `VERIFIED` |
| **Gimbal Pitch / Yaw Control**| `MAV_CMD_DO_GIMBAL_MANAGER_PITCHYAW` | `Vehicle` MAVLink dispatch | `CameraView.qml` Jog D-Pad / Sliders | `VERIFIED` |
| **Gimbal Attitude Feedback** | `GIMBAL_DEVICE_ATTITUDE_STATUS` / `MOUNT_ORIENTATION` | `Vehicle` MAVLink parser | `CompanyTelemetry.qml` (`gimbalPitch`, `gimbalYaw`) | `VERIFIED` |
| **Still Photo Trigger** | `MAV_CMD_IMAGE_START_CAPTURE` | MAVLink command handler | `CameraView.qml` "Snapshot" $\rightarrow$ `CompanyCsvLogger::triggerSnapshot()` | `VERIFIED` |
| **Video Recording Trigger** | `MAV_CMD_VIDEO_START_CAPTURE` | MAVLink command handler | `CameraView.qml` "Record" $\rightarrow$ `CompanyCsvLogger::startRecording()` | `VERIFIED` |
| **Optical Zoom Control** | `MAV_CMD_SET_CAMERA_ZOOM` | MAVLink command handler | `CameraView.qml` Zoom Slider ($1\times - 30\times$) | `VERIFIED` |
| **Focus Control** | `MAV_CMD_SET_CAMERA_FOCUS` | MAVLink command handler | `CameraView.qml` Focus Near/Far Buttons | `VERIFIED` |
| **LRF Slant Distance** | `RANGEFINDER` (#173) / `DISTANCE_SENSOR` (#132) | `Vehicle` MAVLink parser | `CompanyTelemetry.qml` (`lrfDistance`), `CameraView.qml` HUD, `CompanyCsvLogger` | `VERIFIED` |
| **Field of View (FOV)** | `CAMERA_FOV_STATUS` (#271) or Zoom Formula | Telemetry calculation | `CompanyTelemetry.qml` (`fov`), `CompanyCsvLogger.cc`, `CompanyDataOutput.cc` | `VERIFIED` |
| **Thermal Palette Toggle** | Custom MAVLink / Serial command | `MotionMaticsEclipseAdapter` | `CameraView.qml` Palette Dropdown | `VENDOR DOCUMENTATION REQUIRED` |
| **NUC / Calibration Shutter**| Custom MAVLink / Serial command | `MotionMaticsEclipseAdapter` | `CameraView.qml` "Calibrate" Button | `VENDOR DOCUMENTATION REQUIRED` |
| **Edge AI Tracking Box** | `CAMERA_TRACKING_IMAGE_STATUS` | Video overlay painter | `CameraView.qml` Bounding Box Canvas | `VENDOR DOCUMENTATION REQUIRED` |

---

## 3. Proposed Hardware-Ready Architecture

To ensure strict separation of concerns and maintain a zero-regression baseline on core QGC, a clean abstraction model is proposed for future implementation:

```
                  +-----------------------------------+
                  |      CompanyPayloadInterface      |
                  |     (Abstract C++ Base Class)     |
                  +-----------------+-----------------+
                                    |
            +-----------------------+-----------------------+
            |                                               |
+-----------v-----------------------+   +-------------------v-----------------------+
|    SimulatedPayloadAdapter        |   |     MotionMaticsEclipseAdapter            |
|   (Software / Test Emulation)     |   |    (Hardware Production Adapter)          |
|                                   |   |                                           |
| - Simulates Pitch/Yaw Dynamics    |   | - Connects to MotionMatics MAVLink sysid  |
| - Generates synthetic LRF distance|   | - Handles vendor-specific dialects        |
| - Emulates camera capture events  |   | - Translates UI commands to MAV_CMD       |
+-----------------------------------+   +-------------------------------------------+
```

### 3.1 Class Specification: `CompanyPayloadInterface`
```cpp
class CompanyPayloadInterface : public QObject {
    Q_OBJECT
    Q_PROPERTY(float gimbalPitch READ gimbalPitch NOTIFY attitudeChanged)
    Q_PROPERTY(float gimbalRoll READ gimbalRoll NOTIFY attitudeChanged)
    Q_PROPERTY(float gimbalYaw READ gimbalYaw NOTIFY attitudeChanged)
    Q_PROPERTY(float lrfDistance READ lrfDistance NOTIFY lrfDistanceChanged)
    Q_PROPERTY(float fov READ fov NOTIFY fovChanged)
    Q_PROPERTY(bool isRecording READ isRecording NOTIFY recordingStateChanged)

public:
    virtual void setPitchYaw(float pitchDeg, float yawDeg) = 0;
    virtual void setPitchYawRate(float pitchRateDegS, float yawRateDegS) = 0;
    virtual void setZoom(float zoomFactor) = 0;
    virtual void setFocus(float focusValue) = 0;
    virtual void triggerSnapshot() = 0;
    virtual void startRecording() = 0;
    virtual void stopRecording() = 0;
    virtual void triggerLrf() = 0;
    virtual void setThermalPalette(int paletteId) = 0;
    virtual void triggerNuc() = 0;

signals:
    void attitudeChanged(float pitch, float roll, float yaw);
    void lrfDistanceChanged(float distanceMeters, bool valid);
    void fovChanged(float hfovDeg, float vfovDeg);
    void recordingStateChanged(bool active);
    void snapshotCaptured(const QString& filename);
};
```

---

## 4. Verification Status & Roadmap

| Architectural Component | Status | Next Milestone |
| :--- | :--- | :--- |
| `CameraView.qml` UI Controls Layout | `VERIFIED` | Existing implementation validated |
| `CompanyTelemetry.qml` Field Bindings | `VERIFIED` | Existing bindings connected |
| `CompanyCsvLogger.cc` Schema Fields | `VERIFIED` | Verified in Phase 7B |
| `CompanyDataOutput.cc` Packet Fields | `VERIFIED` | Verified in Phase 7D |
| `CompanyPayloadInterface` Class Design | `VERIFIED` | Specification complete; ready for implementation |
| `MotionMaticsEclipseAdapter` Implementation| `VENDOR DOCUMENTATION REQUIRED` | Awaiting vendor ICD and dialect files |
| End-to-end hardware-in-the-loop validation | `HARDWARE TEST REQUIRED` | To be executed upon payload hardware arrival |
