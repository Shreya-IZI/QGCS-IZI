# MotionMatics ECLIPSE X-LR — Unknown Items & Clarification Register

This document provides an exhaustive inventory of unconfirmed technical specifications, vendor documentation dependencies, and required bench verification tasks for integrating the MotionMatics ECLIPSE X-LR payload.

---

## 1. Vendor Documentation Required (Blockers for Hardware Adapter Implementation)

These items cannot be resolved via public reverse-engineering or inference and must be formally requested from MotionMatics engineering:

| Item # | Interface Area | Missing Parameter / Information | Technical Impact | Risk Level |
| :--- | :--- | :--- | :--- | :--- |
| **V-01** | **MAVLink Protocol** | Exact MAVLink dialect XML (`motionmatics.xml` if applicable) or confirmation of 100% compliance with `common.xml` | Determines whether custom MAVLink code generation is required | **HIGH** |
| **V-02** | **Gimbal Control** | MAVLink Gimbal version supported: Gimbal Protocol v2 (`#1000` / `#285`) vs Mount Protocol v1 (`#205` / `#265`) | Affects command message IDs and parameter packing in GCS dispatch | **HIGH** |
| **V-03** | **Network / IP** | Factory default static IP address, subnet mask, gateway, and DNS | GCS network configuration and initial connection | **MEDIUM** |
| **V-04** | **Video Streams** | Exact RTSP URIs for Daylight (EO) and Thermal (TI) feeds (e.g. `rtsp://<ip>:554/live/eo` vs `/stream1`) | Video pipeline cannot connect without precise URI paths | **HIGH** |
| **V-05** | **RTSP Auth** | Authentication credentials (anonymous access vs digest/basic username and password) | Video pipeline connection failure if unauthorized | **MEDIUM** |
| **V-06** | **Serial Interface** | Factory default UART baud rate (115200, 460800, 921600, etc.), data bits, and hardware flow control | Autopilot serial telemetry port configuration (`SERIALn_BAUD`) | **MEDIUM** |
| **V-07** | **Electrical / Pinout** | Mechanical connector part numbers, pinout diagram for power, Ethernet, and serial lines | Fabrication of UAV airframe wiring harness | **HIGH** |
| **V-08** | **Thermal Control** | Command schema for Thermal Color Palette switching and Non-Uniformity Correction (NUC/FFC) shutter trigger | UI thermal controls cannot actuate payload without command definitions | **MEDIUM** |
| **V-09** | **Laser Rangefinder** | MAVLink message ID for slant range telemetry (`#173 RANGEFINDER` vs `#132 DISTANCE_SENSOR`) and fire command | LRF HUD and CSV logging integration | **HIGH** |
| **V-10** | **Laser Safety** | Class 1 Eye Safety certification dossier and operational safety interlocks | Mandatory DRDO safety clearance documentation | **HIGH** |
| **V-11** | **Edge AI Tracker** | Interface protocol for commanding the onboard tracker (target designation $(x,y)$, track start/stop) | GCS target tracking overlay integration | **MEDIUM** |

---

## 2. Hardware Test Required (Empirical Validation on Physical Payload)

These items must be systematically validated once the physical ECLIPSE X-LR hardware arrives for bench testing:

| Item # | Test Focus | Test Description & Acceptance Criteria | Hardware Equipment Needed |
| :--- | :--- | :--- | :--- |
| **H-01** | **Video Latency** | Measure glass-to-glass latency from camera optical input to GCS display output. Acceptance: $< 150\text{ ms}$ over Ethernet. | High-speed LED millisecond counter + oscilloscope |
| **H-02** | **Dual Decode Load** | Measure CPU and GPU utilization during simultaneous 1080p60 EO and 512p30 TI decoding on target GCS laptop. Acceptance: CPU $< 35\%$, zero frame drops. | Target GCS hardware running Linux |
| **H-03** | **Pitch Range Stop** | Verify physical and software travel limits from $-45^\circ$ to $+100^\circ$. Confirm no mechanical binding or slip-ring cable strain. | Digital inclinometer / protractor |
| **H-04** | **Gimbal Slew & Drift**| Test angular rate response at $30^\circ/\text{s}$, $60^\circ/\text{s}$, $90^\circ/\text{s}$. Measure steady-state drift over 15 minutes. | Gimbal test fixture / IMU log |
| **H-05** | **LRF Max Range** | Measure range accuracy at calibrated distance markers ($100\text{ m}, 500\text{ m}, 1000\text{ m}, 2000\text{ m}$). | Survey-grade target markers |
| **H-06** | **Snapshot Cycle Time**| Measure interval between snapshot command trigger and image file committed to MicroSD. | Serial protocol analyzer / SD card timer |
| **H-07** | **Thermal Drift & FFC**| Observe thermal image degradation over 30 minutes in varying ambient temperatures; verify NUC shutter recalibration. | Controlled thermal chamber / heat source |

---

## 3. Risk Mitigation Strategy for DRDO Chandipur Delivery

```
+-----------------------------------------------------------------------------------------------+
|                                DRDO Evaluation Risk Strategy                                  |
+-----------------------------+-----------------------------+-----------------------------------+
| Identified Risk             | Probability / Impact        | Engineering Mitigation            |
+-----------------------------+-----------------------------+-----------------------------------+
| Delay in Vendor ICD Delivery| High / High                 | Build against standard MAVLink    |
|                             |                             | Gimbal Protocol v2; isolate all   |
|                             |                             | commands in clean adapter layer   |
+-----------------------------+-----------------------------+-----------------------------------+
| Non-Standard RTSP Mount URI | Medium / Medium             | Centralized `CompanyNetworkSettings`|
|                             |                             | allows instant URI updates via UI |
|                             |                             | without code recompilation        |
+-----------------------------+-----------------------------+-----------------------------------+
| Custom Laser Fire Command   | Medium / High               | Configurable trigger command      |
|                             |                             | parameter abstraction in adapter  |
+-----------------------------+-----------------------------+-----------------------------------+
| Physical Pitch Limit Lock   | Low / High                  | Software clamping in CameraView UI|
|                             |                             | clamped to [-45.0, +100.0] deg    |
+-----------------------------+-----------------------------+-----------------------------------+
```
