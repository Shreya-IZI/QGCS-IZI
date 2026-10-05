# Phase 9 Physical Bench-Test Procedure

**Project:** IZI QGCS — Chandipur DRDO Range Delivery  
**Target Hardware:** Cube Orange Plus (ArduPilot 4.4.4) + Microhard pMDDL2450 Datalink + MotionMatics ECLIPSE X-LR / X10 EO/IR Payload  
**Document Purpose:** Step-by-step modular benchtop test protocol allowing each physical interface to be validated independently before conducting complete integrated flight tests.

---

## 1. Safety & Benchtop Setup Rules

1. **PROPELLERS REMOVED:** All physical bench testing must be conducted with propellers removed from the aircraft motors.
2. **RF DUMMY LOADS / ATTENUATORS:** When operating the Microhard pMDDL2450 modems on the bench within close proximity (< 5 meters), 30 dB RF attenuators or 50 $\Omega$ RF dummy loads must be installed on the antenna ports to prevent receiver saturation or RF front-end damage.
3. **POWER ISOLATION:** The Cube Orange+ must be powered via its dedicated bench power module or USB-C isolator. The Eclipse X10 payload must be powered via its regulated 24V DC bench power supply.
4. **NO PROPRIETARY MAGIC BYTES:** Do not send arbitrary binary bytes to the payload serial/network interfaces until the official MotionMatics ICD is confirmed.

---

## 2. Modular Test Execution Matrix

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ PHASE 9 MODULAR BENCH-TEST SUITE                                                       │
├──────────┬─────────────────────────────────────────────────┬───────────────────────────┤
│ Module   │ Interface / Subsystem Under Test                │ Dependency                │
├──────────┼─────────────────────────────────────────────────┼───────────────────────────┤
│ MOD-01   │ Cube Orange+ Direct USB / Serial Telemetry      │ USB-C Cable               │
│ MOD-02   │ Microhard pMDDL2450 Layer-2 Ethernet Link       │ RF Attenuators + LAN      │
│ MOD-03   │ End-to-End MAVLink Telemetry over pMDDL         │ Cube Orange+ ↔ pMDDL      │
│ MOD-04   │ Physical Eclipse X10 EO (Daylight) RTSP Stream  │ Eclipse LAN ↔ pMDDL       │
│ MOD-05   │ Physical Eclipse X10 Thermal (IR) RTSP Stream   │ Eclipse LAN ↔ pMDDL       │
│ MOD-06   │ Dual Stream Layout Transitions (Split, PIP)     │ MOD-04 + MOD-05           │
│ MOD-07   │ Physical Gimbal Protocol & Command Verification │ MotionMatics ICD          │
│ MOD-08   │ Camera Zoom, Focus, Snapshot & Recording        │ MotionMatics ICD          │
│ MOD-09   │ Physical LRF Distance Ingestion & Calibration   │ MotionMatics ICD          │
│ MOD-10   │ 16-Field CSV Telemetry Logging Engine           │ MOD-03 Telemetry          │
│ MOD-11   │ DRDO UDP Telemetry Output Engine                │ MOD-03 Telemetry          │
│ MOD-12   │ Offline Map Ingestion & Field Subnet Operation  │ Local Tile Database       │
│ MOD-13   │ Physical ArduPilot BIN Log Download (MAVLink)   │ MOD-03 Telemetry          │
│ MOD-14   │ Integrated 30-Minute Full-System Bench Soak     │ All Modules Combined      │
└──────────┴─────────────────────────────────────────────────┴───────────────────────────┘
```

---

## 3. Module Details & Step-by-Step Procedures

### Module 1: Cube Orange+ Direct Telemetry Verification (USB / Serial)
* **Objective:** Verify physical connection, MAVLink auto-discovery, ArduPilot 4.4.4 firmware version reporting, and primary sensor telemetry directly from the flight controller.
* **Hardware Setup:**
  - Connect Cube Orange+ USB-C port to GCS workstation USB 3.0 port.
  - Verify device enumeration: `ls -l /dev/ttyACM*` or `/dev/ttyUSB*`.
* **Execution Procedure:**
  1. Launch IZI QGCS: `./build-company/Release/QGroundControl`.
  2. Verify top bar changes from `DISCONNECTED` to `CONNECTED (UAS #1)`.
  3. Verify top bar shows `ArduPilot Copter 4.4.4`.
  4. Tilt the Cube Orange+ physically by $+30^\circ$ pitch and $+45^\circ$ roll on the bench.
  5. Switch to `PFD` view and verify the artificial horizon reflects the physical tilt with $< 50\text{ ms}$ latency.
  6. Switch to `Dashboard` and verify Battery voltage, IMU status, and Baro altitude readouts.
* **Success Criteria:**
  - Zero communication link drops over a 5-minute continuous connection.
  - Telemetry rate $\ge 10\text{ Hz}$.

---

### Module 2: Microhard pMDDL2450 Datalink Network Verification
* **Objective:** Establish physical RF and Ethernet communication between the ground and airborne pMDDL modems and verify sustained throughput $\ge 15\text{ Mbps}$.
* **Hardware Setup:**
  - Connect Ground pMDDL2450 LAN port to GCS workstation Ethernet NIC (`eth0` / `enp3s0`).
  - Connect Airborne pMDDL2450 LAN port to a bench laptop or Ethernet switch.
  - Install 30 dB RF attenuators between the modem antenna ports.
  - Power both modems with 12V DC bench supplies.
  - Configure GCS workstation network interface: Static IP `192.168.168.10`, Netmask `255.255.255.0`.
* **Execution Procedure:**
  1. Ping ground modem: `ping -c 5 192.168.168.1`.
  2. Ping airborne modem across RF link: `ping -c 20 192.168.168.2`.
  3. Verify ping round-trip time: average RTT must be $< 10\text{ ms}$ with 0% packet loss.
  4. Run `iperf3 -s` on airborne laptop and `iperf3 -c 192.168.168.2 -u -b 20M -t 30` on GCS.
* **Success Criteria:**
  - Sustained UDP bandwidth $\ge 15.0\text{ Mbps}$ with jitter $< 2\text{ ms}$ and datagram loss $< 0.1\%$.

---

### Module 3: End-to-End MAVLink Telemetry over pMDDL
* **Objective:** Route Cube Orange+ MAVLink telemetry through the pMDDL serial gateway or airborne UDP link to IZI QGCS.
* **Hardware Setup:**
  - Connect Cube Orange+ TELEM1 port (JST-GH) to Airborne pMDDL COM1 serial port (RS232/TTL).
  - Configure Cube Orange+ `SERIAL1_BAUD = 115` (115200 baud) and `SERIAL1_PROTOCOL = 2` (MAVLink 2).
  - Configure pMDDL COM1 as UDP broadcast on port 14550 or transparent serial bridge.
  - Connect GCS Ethernet port to Ground pMDDL LAN port.
* **Execution Procedure:**
  1. Launch IZI QGCS.
  2. Verify auto-discovery on UDP port 14550 without manual connection intervention.
  3. Verify top bar displays live GPS satellites, battery percentage, and vehicle flight mode (`CUSTOM:0x0` or `STABILIZE`).
  4. Perform bench arming sequence check (with safety switch depressed and disarmed parameters).
* **Success Criteria:**
  - Sustained 10 Hz MAVLink packet ingestion over pMDDL Ethernet link.
  - Link quality indicator in TopBar displays $\ge 95\%$.

---

### Module 4: Physical Eclipse X10 EO (Daylight) RTSP Stream Ingestion
* **Objective:** Ingest the physical 1080p Daylight video stream from the Eclipse X10 payload into IZI QGCS via RTSP over Ethernet.
* **Hardware Setup:**
  - Power Eclipse X10 with 24V DC bench power supply.
  - Connect Eclipse X10 Ethernet port to Airborne pMDDL LAN port.
  - Obtain factory default IP and RTSP URL from MotionMatics documentation (e.g. `rtsp://192.168.168.120:554/live/ch0`).
* **Execution Procedure:**
  1. In IZI QGCS `Settings` $\to$ `Video`, configure Video Source: `RTSP Video Stream`, URL: `rtsp://<ECLIPSE_IP>:554/<path>`.
  2. Switch to `CAM` view in IZI QGCS.
  3. Verify live 1080p video renders smoothly on the left/primary video canvas.
  4. Check video latency using a millisecond optical stopwatch pointed at the camera lens.
* **Success Criteria:**
  - Decoded FPS $\ge 25\text{ FPS}$ (nominally 30 FPS).
  - End-to-end glass-to-glass latency $\le 120\text{ ms}$.
  - Zero GStreamer pipeline warnings or frame corruptions.

---

### Module 5: Physical Eclipse X10 Thermal (IR) RTSP Stream Ingestion
* **Objective:** Ingest the physical $640\times 512$ Long-Wave Infrared video stream from the Eclipse X10 payload into the secondary GStreamer receiver.
* **Hardware Setup:**
  - Secondary RTSP URL configured in `Settings` $\to$ `Network & Links` $\to$ `Thermal Video URL` (e.g. `rtsp://192.168.168.120:8554/thermal`).
* **Execution Procedure:**
  1. Enable Thermal Stream in IZI QGCS.
  2. Switch to `THERMAL` full-screen mode at top center toolbar.
  3. Point a warm object (e.g. human hand or heated target) in front of the LWIR sensor.
  4. Verify clear thermal signature and high-contrast false-color representation.
* **Success Criteria:**
  - Thermal decoded framerate $\ge 25\text{ FPS}$.
  - Zero frame drops or pixel tearing.

---

### Module 6: Dual Video Layout Transitions on Real Streams
* **Objective:** Validate real-time operator layout toggling between `SIDE_BY_SIDE`, `RGB_ONLY`, `THERMAL_ONLY`, and `PIP` with live physical sensors.
* **Execution Procedure:**
  1. Switch to `SPLIT` mode: verify both Daylight and Thermal streams display side-by-side with synchronized tactical OSD overlays.
  2. Switch to `RGB` mode: verify Daylight stream expands to 100% canvas width without pausing playback.
  3. Switch to `THERMAL` mode: verify Thermal stream expands to 100% canvas width.
  4. Switch to `PIP` mode: verify Daylight stream is full canvas and Thermal stream appears as an inset window in the bottom-right corner.
* **Success Criteria:**
  - Mode transition completes in $< 200\text{ ms}$ with zero pipeline crash or video stutter.

---

### Module 7: Physical Gimbal Protocol & Command Verification
* **Status:** **`BLOCKED — VENDOR ICD REQUIRED`**
* **Objective:** Verify gimbal pitch, yaw, and roll angular steering once MotionMatics protocol ICD is provided.
* **Procedure upon ICD Delivery:**
  1. Implement packet framing in `custom/src/MotionMaticsEclipseAdapter.cc`.
  2. In `CAM` view, command pitch to $-30^\circ$, $+45^\circ$, and zero.
  3. Command yaw continuous panning left and right.
  4. Click `Center` button and verify gimbal returns to $[0^\circ, 0^\circ, 0^\circ]$ reference.
* **Success Criteria:**
  - Physical gimbal moves to commanded angles within $\pm 0.5^\circ$ accuracy.
  - Motion adheres strictly to safety software clamps $[-45^\circ, +100^\circ]$ pitch.

---

### Module 8: Camera Zoom, Focus, Snapshot & Recording
* **Objective:** Verify optical zoom, autofocus, GCS-side MP4 recording, and onboard snapshot triggers.
* **Execution Procedure:**
  1. **GCS Snapshot:** Click camera snapshot button (camera icon on right tactical toolbar).
     - Verify visual white shutter flash animation on canvas.
     - Verify saved notification toast appears with file path: `Snapshot saved to: .../Photos/snapshot_*.jpg`.
     - Inspect captured image on disk and confirm $1920\times 1080$ resolution.
  2. **GCS Video Recording:** Click video record button (red dot).
     - Verify `REC` badge appears with blinking red indicator and running elapsed timer (`00:00:01`, `00:00:02`...).
     - Record 60 seconds of video, then click stop.
     - Inspect saved `.mp4` file in `.../Video/`: verify smooth playback at 30 FPS with VLC or ffplay.
  3. **Optical Zoom & Focus:** *(Gated on MotionMatics ICD)* Click `+` and `-` zoom buttons; verify physical lens moves and OSD dynamic HFOV updates from $58.4^\circ$ down to $2.1^\circ$.
* **Success Criteria:**
  - Lossless MP4 file created with valid H.264 video stream and audio/metadata sync.

---

### Module 9: Physical LRF Distance Ingestion & Calibration
* **Status:** **`BLOCKED — VENDOR ICD REQUIRED`**
* **Objective:** Validate real-time laser rangefinder distance reporting against surveyed physical bench targets.
* **Procedure upon ICD Delivery:**
  1. Place reflective target at surveyed bench distance ($5.0\text{ m}$ and $20.0\text{ m}$).
  2. Trigger LRF firing from QGCS or verify continuous distance reporting.
  3. Verify distance is displayed on tactical HUD OSD: `LRF: 5.0 m` and `LRF: 20.0 m`.
  4. Obscure target and verify `TARGET LOST` or `--- m` indication without software freeze.
* **Success Criteria:**
  - Range measurement accuracy within $\pm 1.0\text{ m}$.

---

### Module 10: 16-Field CSV Telemetry Logging Bench Verification
* **Objective:** Verify continuous logging of all 16 DRDO-mandated fields during active physical hardware bench testing.
* **Execution Procedure:**
  1. In IZI QGCS `Settings` $\to$ `Data Logging`, enable CSV logging at 10 Hz.
  2. Run physical test for 120 seconds while tilting Cube Orange+ and operating payload.
  3. Stop CSV logging and open generated file: `ls -lt /tmp/qgc_save/Telemetry/*.csv`.
  4. Inspect with `head -n 5` and verify all 16 required columns are populated:
     - `Latitude_deg`, `Longitude_deg`, `AltAMSL_m`, `Satellites`, `HDOP`, `VDOP`
     - `Pitch_deg`, `Roll_deg`, `Yaw_deg`
     - `GimbalPitch_deg`, `GimbalRoll_deg`, `GimbalYaw_deg`
     - `LRF_Distance_m`, `FOV_deg`, `BaroPressure_hPa`
* **Success Criteria:**
  - Exactly $\approx 1,200$ rows generated for 120 seconds without missing or malformed fields.

---

### Module 11: DRDO UDP Telemetry Output Validation
* **Objective:** Stream live physical telemetry to an external recipient on the DRDO evaluation network subnet.
* **Execution Procedure:**
  1. In `Settings` $\to$ `Network & Links`, configure Target IP to destination receiver (`192.168.1.55`), Port: `14600`, Rate: `10 Hz`. Enable UDP telemetry output.
  2. Start test listener on destination workstation: `nc -u -l -p 14600`.
  3. Verify JSON datagrams arrive at continuous 10 Hz rate with valid ISO-8601 UTC timestamps.
* **Success Criteria:**
  - 100% schema compliance with DRDO JSON specification. Zero socket transmission exceptions.

---

### Module 12: Offline Map Ingestion & Field Subnet Operation
* **Objective:** Validate offline tile rendering with physical GCS network configuration and zero internet connectivity.
* **Execution Procedure:**
  1. Disconnect GCS workstation from external internet.
  2. Configure GCS Ethernet NIC to bench subnet (`192.168.168.10/24`).
  3. Pan and zoom into Chandipur range area ($20.78^\circ\text{ N}, 86.99^\circ\text{ E}$) on `Tactical Map` and `Mission Planner`.
* **Success Criteria:**
  - High-resolution cached satellite tiles render without network timeout errors or missing tile artifacts.

---

### Module 13: Physical ArduPilot BIN Log Download (MAVLink FTP)
* **Objective:** Retrieve onboard `.BIN` flight logs from Cube Orange+ internal microSD card over MAVLink FTP.
* **Execution Procedure:**
  1. Navigate to `Flight Logs` tab in IZI QGCS.
  2. Click `Refresh Log List`. Verify table populates with log IDs, timestamps, and file sizes.
  3. Select the most recent log file and click `Download Selected`.
  4. Verify download progress bar advances continuously to 100%.
  5. Click `Open Saved Directory` and verify `.bin` file exists and matches reported file size.
* **Success Criteria:**
  - Log file transfers completely without checksum error or timeout abort.

---

### Module 14: Integrated 30-Minute Full-System Bench Soak
* **Objective:** Run all validated physical subsystems concurrently for 30 minutes to verify thermal and memory stability prior to field deployment.
* **Execution Procedure:**
  - Concurrently execute:
    * Live MAVLink telemetry from Cube Orange+ over pMDDL (10 Hz).
    * Dual physical video streaming (EO 1080p + Thermal 640×512).
    * CSV telemetry logging (10 Hz).
    * DRDO UDP telemetry output (10 Hz).
    * Periodic layout toggling every 5 minutes.
* **Success Criteria:**
  - 30-minute continuous operation with zero software crash, pipeline disconnection, or memory growth ($< 0.1\text{ MB/min}$).
