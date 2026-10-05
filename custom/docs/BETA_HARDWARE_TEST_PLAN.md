# Beta Hardware Test Plan & Verification Matrix
**Project:** IZI QGCS — DRDO Chandipur Evaluation Delivery  
**Target Environment:** Cube Orange Plus (ArduPilot 4.4.4) + Microhard pMDDL2450 + MotionMatics Eclipse X10 EO/IR  
**Document Purpose:** Verification protocols categorized by execution environment (Software-Only, Simulator, Real-Hardware).

---

## 1. Test Category Overview

To de-risk the integration process before physical equipment arrival at Chandipur, the 12 validation tests are divided into three operational tiers:

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ TIER 1: SOFTWARE-ONLY TESTS (Zero Hardware or Network Required)                        │
│   • Test 8:  CSV Telemetry Logging Engine                                              │
│   • Test 9:  DRDO UDP Telemetry Output                                                 │
│   • Test 11: Offline Map Operation & Ingestion                                         │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ TIER 2: SIMULATOR & BROADCASTER TESTS (Loopback & Virtual Aircraft)                    │
│   • Test 1:  QGCS ↔ ArduPilot SITL / Telemetry Simulator                              │
│   • Test 3:  Simulated EO RTSP Video Stream Ingestion                                  │
│   • Test 4:  Simulated Dual (RGB + Thermal) Video Ingestion                            │
│   • Test 5:  Simulated Gimbal Commands & Dynamics                                      │
│   • Test 6:  Simulated LRF Ingestion & Range Checking                                  │
│   • Test 10: Video Timestamp & Subtitle Synchronization                                │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ TIER 3: REAL-HARDWARE TESTS (Benchtop & Field Range Trials)                            │
│   • Test 1H:  QGCS ↔ Physical Cube Orange Plus (USB / Serial / UDP)                    │
│   • Test 2H:  QGCS ↔ Physical Microhard pMDDL2450 Ethernet Bridge                      │
│   • Test 3H:  Real Eclipse X10 Visible Camera RTSP Stream                              │
│   • Test 4H:  Real Eclipse X10 Thermal Camera RTSP Stream                              │
│   • Test 5H:  Physical Gimbal Stabilization & Steering Verification                    │
│   • Test 6H:  Physical LRF Ranging against Surveyed Ground Targets                     │
│   • Test 7H:  ArduPilot .BIN Flight Log Download via MAVLink FTP                       │
│   • Test 12H: PMDDL RF Link Interruption & Automatic Failover Recovery                 │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Tier 1: Software-Only Tests

### Test 8: CSV Telemetry Logging Engine
* **Execution Environment:** Host Linux workstation running IZI QGCS (no hardware required).
* **Objective:** Verify that `CompanyCsvLogger` records continuous time-series rows with all 16 DRDO-mandated fields, accurate floating-point precision, and distinct event markers.
* **Input / Action:**
  1. Launch IZI QGCS.
  2. Navigate to `Settings` $\to$ `Data Logging`.
  3. Set logging rate to 10 Hz. Click `Start CSV Logging`.
  4. Trigger a snapshot event and a recording start/stop event.
  5. Allow logging to run for 60 seconds, then click `Stop CSV Logging`.
* **Expected Output:**
  - A timestamped CSV file is created in `~/Documents/QGroundControl/Telemetry/`.
  - Header line contains exact columns: `Timestamp`, `Event`, `Latitude_deg`, `Longitude_deg`, `AltAMSL_m`, `AltRel_m`, `Satellites`, `HDOP`, `VDOP`, `Pitch_deg`, `Roll_deg`, `Yaw_deg`, `GimbalPitch_deg`, `GimbalRoll_deg`, `GimbalYaw_deg`, `LRF_Distance_m`, `BaroPressure_hPa`, `MagX_mG`, `MagY_mG`, `MagZ_mG`, `FOV_deg`, `EventDetails`.
  - Exactly $\approx 600$ periodic telemetry rows are recorded without missing fields or crash.
  - Event rows (`SNAPSHOT`, `RECORDING_START`, `RECORDING_STOP`) are interleaved with exact coordinates.
* **Evidence to Capture:**
  - Inspect generated `.csv` with `head -n 20` and row count via `wc -l`.
  - Verify zero NaN or undefined values.

### Test 9: DRDO UDP Telemetry Output
* **Execution Environment:** Host Linux workstation running loopback listener.
* **Objective:** Verify that `CompanyDataOutput` broadcasts valid JSON datagrams matching the DRDO schema to a configurable IP address and port at the configured rate (1–50 Hz).
* **Input / Action:**
  1. Start local UDP listener script: `python3 -c "import socket; s=socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.bind(('127.0.0.1', 15000)); print('Listening...'); print(s.recvfrom(2048)[0].decode())"`.
  2. In IZI QGCS `Settings` $\to$ `Network & Links`, configure:
     - Destination IP: `127.0.0.1`
     - Destination Port: `15000`
     - Rate: `20 Hz`
     - Enable UDP Telemetry: `ON`
* **Expected Output:**
  - UDP listener receives continuous JSON packets at 20 Hz ($\pm 1\text{ Hz}$).
  - JSON payload contains root keys: `header`, `gps`, `autopilot`, `gimbal`, `lrf`, `barometer`, `magnetometer`, `payload`.
  - Sequence numbers increment strictly by 1.
  - Timestamps are UTC ISO-8601 with millisecond precision (`yyyy-MM-ddTHH:mm:ss.zzzZ`).
* **Evidence to Capture:**
  - Captured JSON packet sample text.
  - Calculated packet reception rate from 100 consecutive datagrams.

### Test 11: Offline Map Operation & Ingestion
* **Execution Environment:** Host Linux workstation with all network interfaces disabled (`nmcli networking off` / airplane mode).
* **Objective:** Verify that IZI QGCS imports pre-packaged offline map tile archives (`.qct`, `.zip`) and renders high-resolution satellite imagery with zero internet access.
* **Input / Action:**
  1. Disable Wi-Fi and Ethernet on host machine.
  2. Launch IZI QGCS.
  3. Navigate to `Settings` $\to$ `Offline Maps`.
  4. Verify local tile cache status indicates valid tile count.
  5. Click `Import Offline Map Package` and select test archive (`chandipur_sample_tiles.zip` or `.qct`).
  6. Navigate to `Tactical Map` and `Mission Planner`. Pan and zoom into Chandipur range coordinates ($20.78^\circ\text{ N}, 86.99^\circ\text{ E}$) from zoom level 10 through 18.
* **Expected Output:**
  - Import dialog extracts and installs tile set into `qgcMapCache.db` with visual progress bar.
  - Tile set appears in Installed Tile Sets list with correct tile count and size.
  - Tactical map renders detailed terrain and satellite tiles smoothly without network errors or placeholder checkerboards.
* **Evidence to Capture:**
  - Screenshot of `Settings` $\to$ `Offline Maps` showing imported tile set.
  - Screenshot of `Tactical Map` displaying Chandipur tiles with network disconnected.

---

## 3. Tier 2: Simulator & Broadcaster Tests

### Test 1: QGCS ↔ ArduPilot SITL / Telemetry Simulator
* **Execution Environment:** SITL instance or `tools/test_vehicle_telemetry_simulator.py`.
* **Objective:** Validate end-to-end MAVLink communication, heartbeat acquisition, attitude/GPS ingestion, and flight mode changes.
* **Input / Action:**
  1. Launch `python3 tools/test_vehicle_telemetry_simulator.py --port 14550`.
  2. Launch IZI QGCS.
  3. Switch flight modes from UI (HOLD, Guided, Return).
  4. Perform ARM and DISARM sequence with safety confirmation dialog.
* **Expected Output:**
  - Vehicle card appears in TopBar with ID 1, ArduPilot firmware icon, and armed status.
  - Pitch, roll, heading, altitude, and GPS coordinates update smoothly at 10 Hz on `CompanyTelemetry` and PFD.
  - Disarm warning modal triggers when attempting disarm while vehicle reports airborne.
* **Evidence to Capture:**
  - Screenshot of active dashboard with simulated telemetry.
  - Terminal log of simulator confirming command acknowledgments.

### Test 3: Simulated EO RTSP Video Stream Ingestion
* **Execution Environment:** `tools/test_dual_stream_broadcaster.py` running local GStreamer RTSP server.
* **Objective:** Validate low-latency decoding of H.264 video into `CameraView.qml` primary viewport (`videoContent`).
* **Input / Action:**
  1. Launch test broadcaster: `python3 tools/test_dual_stream_broadcaster.py --port 8554`.
  2. Set RGB Video URL in QGCS Settings: `rtsp://127.0.0.1:8554/live/ch0`.
  3. Navigate to `Camera` view. Select `RGB ONLY` layout.
* **Expected Output:**
  - GStreamer pipeline starts; status badge updates from `WAITING` to `DECODING`.
  - Video renders at full 30 FPS without stutter or tearing.
  - Snapshot button captures crystal-clear frame to `~/Documents/QGroundControl/Photo/`.
* **Evidence to Capture:**
  - Screenshot of live video in `CameraView.qml`.
  - Saved snapshot image file.

### Test 4: Simulated Dual (RGB + Thermal) Video Ingestion
* **Execution Environment:** `tools/test_dual_stream_broadcaster.py` streaming both channels.
* **Objective:** Validate simultaneous decoding of Visible (`/live/ch0`) and Thermal (`/live/ch1`) streams.
* **Input / Action:**
  1. Set Primary URL to `rtsp://127.0.0.1:8554/live/ch0`.
  2. Set Thermal URL to `rtsp://127.0.0.1:8554/live/ch1`.
  3. Toggle view layout between `SIDE_BY_SIDE` and `PIP`.
  4. Click PIP thumbnail to swap main and PIP viewports.
* **Expected Output:**
  - Both viewports decode concurrently without mutual interference.
  - Side-by-side mode displays 50/50 split with independent OSD stream badges.
  - PIP mode displays primary video with floating thermal thumbnail in lower-right corner; clicking PIP smoothly swaps feeds.
* **Evidence to Capture:**
  - Screenshot of `SIDE_BY_SIDE` dual-stream mode.
  - Screenshot of `PIP` swapped mode.

### Test 5: Simulated Gimbal Commands & Dynamics
* **Execution Environment:** `SimulatedPayloadAdapter` active in `CompanyPayloadInterface`.
* **Objective:** Verify gimbal rate/angle commands, pitch safety clamping, and recentering.
* **Input / Action:**
  1. In `CameraView.qml`, steer gimbal pitch down to $-45.0^\circ$ and yaw to $+90.0^\circ$.
  2. Attempt to command pitch past $+100.0^\circ$ (zenith) or below $-45.0^\circ$ (nadir).
  3. Click `Recenter Gimbal` button.
* **Expected Output:**
  - OSD attitude reticle reflects commanded angles with realistic 20 Hz simulated inertia.
  - Pitch angle is strictly clamped to $[-45.0^\circ, +100.0^\circ]$; commands exceeding limits are rejected.
  - Recenter command returns pitch and yaw to $(0.0^\circ, 0.0^\circ)$.
* **Evidence to Capture:**
  - Screen recording of OSD reticle moving and clamping at boundaries.

### Test 6: Simulated LRF Ingestion & Range Checking
* **Execution Environment:** `SimulatedPayloadAdapter` providing synthetic LRF distance.
* **Objective:** Validate display, CSV logging, and UDP broadcast of LRF range data.
* **Input / Action:**
  1. Observe LRF distance on video HUD reticle.
  2. Verify distance changes realistically as synthetic target altitude varies.
  3. Check CSV log and UDP datagrams.
* **Expected Output:**
  - LRF distance displays in meters (e.g. `1250.0 m`) on the reticle center.
  - `CompanyCsvLogger` records valid distance in `LRF_Distance_m` column.
  - `CompanyDataOutput` populates `lrf.distance_m` and sets `lrf.available = true`.
* **Evidence to Capture:**
  - Matching readout comparison between HUD reticle, CSV line, and UDP packet.

### Test 10: Video Timestamp & Subtitle Synchronization
* **Execution Environment:** Simulated vehicle + live test video broadcaster.
* **Objective:** Verify that recorded MP4 video has frame-accurate synchronized subtitle telemetry.
* **Input / Action:**
  1. Start video recording from `CameraView.qml`.
  2. Allow recording for 30 seconds while changing vehicle altitude and gimbal angle.
  3. Stop video recording.
* **Expected Output:**
  - Both `.mp4` and `.ass` files are generated in `~/Documents/QGroundControl/Video/`.
  - Opening the video in VLC or MPV displays subtitle telemetry overlay.
  - Subtitle timestamps correlate directly with vehicle GPS UTC clock and recording elapsed time.
* **Evidence to Capture:**
  - Media player screenshot showing video playback with synchronized subtitle telemetry.

---

## 4. Tier 3: Real-Hardware Tests

### Test 1H: QGCS ↔ Physical Cube Orange Plus
* **Equipment:** Cube Orange Plus running ArduPilot 4.4.4, USB-C or FTDI telemetry cable.
* **Objective:** Verify real-hardware MAVLink communication, parameter sync, and sensor calibration.
* **Input / Action:**
  1. Connect Cube Orange Plus to GCS computer via USB or serial link.
  2. Launch IZI QGCS.
  3. Verify automatic connection on serial port (`/dev/ttyACM0`).
  4. Perform vehicle parameter download and verify all sensor Facts (`RAW_IMU`, `SCALED_PRESSURE`).
* **Expected Output:**
  - MAVLink parameters download within 15 seconds.
  - Barometric pressure, magnetometer $X/Y/Z$, and attitude respond to physical Cube movement in real time.
* **Evidence to Capture:**
  - Video of Cube Orange physically tilted with corresponding PFD attitude response.

### Test 2H: QGCS ↔ Physical Microhard pMDDL2450 Link
* **Equipment:** Ground pMDDL2450 unit, Airborne pMDDL2450 unit, power supplies, Ethernet switch.
* **Objective:** Verify Layer-2/Layer-3 network bridge throughput, latency, and MAVLink UDP routing.
* **Input / Action:**
  1. Connect GCS Ethernet port to Ground pMDDL unit.
  2. Power airborne pMDDL unit connected to Cube Orange Plus Ethernet/serial port.
  3. Execute `ping <airborne_ip> -c 100` and measure round-trip time and packet loss.
* **Expected Output:**
  - Ping latency $< 5\text{ ms}$ with $0\%$ packet loss.
  - QGCS automatically establishes MAVLink telemetry session over UDP port 14550.
* **Evidence to Capture:**
  - Terminal log of 100-packet ping statistics.
  - QGCS TopBar link quality indicator showing $> 95\%$.

### Test 3H & 4H: Real Eclipse X10 Visible & Thermal RTSP Ingestion
* **Equipment:** MotionMatics Eclipse X10 payload powered on bench, connected to airborne pMDDL Ethernet.
* **Objective:** Validate real optical EO and LWIR thermal video streams inside IZI QGCS.
* **Input / Action:**
  1. Configure vendor RTSP URLs in QGCS Settings:
     - EO: `rtsp://<camera_ip>:554/<eo_mount>`
     - Thermal: `rtsp://<camera_ip>:554/<thermal_mount>`
  2. Open `Camera` view. Test `RGB_ONLY`, `THERMAL_ONLY`, `SIDE_BY_SIDE`, and `PIP`.
  3. Measure glass-to-glass latency using optical stopwatch timer.
* **Expected Output:**
  - Both video streams render smoothly at full resolution.
  - Glass-to-glass latency $\le 180\text{ ms}$ on local LAN.
  - Zero GStreamer pipeline crashes or memory leaks during 60-minute endurance run.
* **Evidence to Capture:**
  - High-res photo showing stopwatch display on physical timer vs QGCS screen (latency measurement).
  - Screenshots of EO, Thermal, and Split-screen modes.

### Test 5H: Physical Gimbal Stabilization & Steering Verification
* **Equipment:** Eclipse X10 payload mounted on test bench.
* **Objective:** Verify physical gimbal response to QGCS steering commands and check stabilization.
* **Input / Action:**
  1. Issue pan/tilt rate and angle commands from QGCS right control rail.
  2. Move test bench vigorously to test gyro stabilization.
  3. Click `Recenter Gimbal`.
* **Expected Output:**
  - Gimbal physically steers to commanded angles smoothly.
  - Horizon remains stable on camera view during bench disturbance.
  - Recenter command restores gimbal to boresight $(0^\circ, 0^\circ)$.
* **Evidence to Capture:**
  - Video recording showing physical gimbal movement alongside QGCS control UI.

### Test 6H: Physical LRF Ranging against Surveyed Ground Targets
* **Equipment:** Eclipse X10 payload with active LRF, laser safety goggles, surveyed targets at $200\text{ m}, 500\text{ m}, 1000\text{ m}$.
* **Objective:** Verify LRF accuracy and integration into QGCS HUD and data logging.
* **Input / Action:**
  1. Align payload optical crosshair with surveyed benchmark target.
  2. Fire LRF command.
  3. Verify distance readout on video reticle, CSV log, and UDP broadcast.
* **Expected Output:**
  - Measured distance matches surveyed range within vendor accuracy specification ($\pm 1\text{ m}$).
  - Readout updates on HUD reticle without hesitation.
* **Evidence to Capture:**
  - Target range survey sheet vs QGCS screen capture.

### Test 7H: ArduPilot .BIN Flight Log Download via MAVLink FTP
* **Equipment:** Cube Orange Plus with recorded flight logs on microSD card.
* **Objective:** Verify high-speed listing and download of large binary flight logs.
* **Input / Action:**
  1. In IZI QGCS, navigate to `Flight Logs`.
  2. Click `Refresh`.
  3. Select a $50\text{ MB}$ `.BIN` log file. Click `Download Selected`.
  4. Monitor progress and transfer rate.
  5. Click `Open Log Directory` after completion.
* **Expected Output:**
  - Log list displays ID, date, time, and file size accurately.
  - Transfer utilizes MAVLink FTP transport (`TRANSPORT: MAVLINK FTP (FAST)`) achieving $> 300\text{ KB/s}$.
  - Downloaded `.BIN` file is intact, uncorrupted, and can be parsed by `mavlogdump.py` or DroneLogBook.
* **Evidence to Capture:**
  - Screen recording of download progress bar.
  - File integrity check (`md5sum` on onboard vs downloaded file).

### Test 12H: PMDDL RF Link Interruption & Automatic Failover Recovery
* **Equipment:** Full integrated benchtop setup (GCS + pMDDL + Cube Orange + Eclipse X10).
* **Objective:** Validate system resilience and automated reconnection under RF dropouts.
* **Input / Action:**
  1. While streaming dual video and logging telemetry, disconnect the PMDDL RF antenna or power-cycle the airborne radio for 15 seconds.
  2. Reconnect the link.
* **Expected Output:**
  - QGCS gracefully indicates `LINK LOST` on TopBar and displays tactical standby cards on video viewports without freezing or crashing.
  - Upon radio re-link, MAVLink telemetry reconnects within 2 seconds.
  - GStreamer video pipelines automatically re-establish decoding within 3 seconds.
  - CSV logger logs `LINK_LOST` and `LINK_RECOVERED` events without file corruption.
* **Evidence to Capture:**
  - Continuous screen recording showing disconnect, warning states, and seamless recovery.
