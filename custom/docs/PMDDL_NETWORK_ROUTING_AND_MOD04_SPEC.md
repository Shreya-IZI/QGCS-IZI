# Microhard pMDDL2450 Network Routing Architecture & MOD-04 EO Video Ingestion Specification

## 1. Network Path & Port Role Specification

### 1.1 Overview: pMDDL Port 14555 vs QGCS Port 14550
A foundational architectural distinction exists between the **datalink management/auxiliary port (`14555`)** and the **standard MAVLink telemetry ingestion socket (`14550`)**:

| Parameter | pMDDL Auxiliary/Remote Port | QGCS MAVLink Ingestion Port |
|:---|:---|:---|
| **Port Number** | **`14555 / UDP`** | **`14550 / UDP`** |
| **Bound / Target IP** | Remote modem IP: `192.168.168.1` (Ground) / `192.168.168.2` (Airborne) | Local GCS host: `0.0.0.0:14550` (`192.168.168.10` / `127.0.0.1`) |
| **Role / Function** | Point-to-point datalink auxiliary diagnostics, radio health monitoring (RSSI, SNR, Tx/Rx byte counters), and optional encapsulated payload telemetry. | Primary vehicle MAVLink 2.0 communication channel. Receives heartbeats, vehicle status, attitude, GPS, battery, and sends operator commands. |
| **QGCS Software Handler** | `CompanyNetworkSettings::pmddlRemoteIP` & `pmddlDataPort` | `LinkManager` / `UDPLink` (`autoConnectUDP=true`) |
| **Standard Protocol** | Vendor-specific radio telemetry / auxiliary UDP encapsulation | Standard MAVLink 2.0 specification (`common.xml`) |

---

### 1.2 Hop-by-Hop Telemetry Routing Topology

```
+--------------------------------------------------------------------------------------------------------+
|                                    CHANDIPUR DRDO UAV BENCHTOP TELEMETRY PATH                          |
+--------------------------------------------------------------------------------------------------------+

  [HOP 1: Flight Controller]
     Cube Orange+ (PX4 Pro v1.16.2, SysID 1, CompID 1)
     └── Physical Port: TELEM1 / TELEM2 (JST-GH) or USB-C (/dev/ttyACM0 on bench)
     └── Protocol: Asynchronous Serial MAVLink 2.0
     └── Baud Rate: 115,200 baud (8-N-1, hardware flow control optional)
               │
               ▼
  [HOP 2: Airborne Datalink Gateway]
     Airborne pMDDL2450 Serial Port (COM1) / Gateway Bridge (tools/pmddl_telemetry_gateway.py)
     └── Physical Ingestion: RS-232 / TTL 3.3V serial RX/TX
     └── Framing Engine: Reads MAVLink packets from serial buffer
     └── Encapsulation: Packages MAVLink datagrams into UDP packets
     └── Destination Socket: UDP Port 14550 (Target: 192.168.168.10:14550 / 127.0.0.1:14550)
     └── Aux Diagnostics: Bridges radio status on UDP Port 14555
               │
               ▼
  [HOP 3: RF Datalink Bridge]
     Microhard pMDDL2450 Transceiver Pair (Airborne 192.168.168.2 <---> Ground 192.168.168.1)
     └── Frequency Band: 2.4 GHz ISM / MIMO Digital COFDM (5/10/20 MHz channel)
     └── Network Mode: Transparent Layer-2 Ethernet / IP Bridge
     └── Subnet: 192.168.168.0/24 (Broadcast Domain)
     └── RF Attenuators: 30 dB RF attenuators installed on antenna ports for bench operation
     └── Throughput Capacity: Up to 25+ Mbps raw over-the-air link rate
               │
               ▼
  [HOP 4: Ground Ethernet Physical Interface]
     Ground pMDDL2450 RJ-45 LAN Port <---> GCS Workstation NIC (enp7s0)
     └── Interface: Realtek RTL8125 2.5GbE Controller (PCI 0000:07:00.0)
     └── Physical Link: IEEE 802.3 1000BASE-T (1000 Mb/s Full Duplex, carrier: 1)
     └── Workstation IP: 192.168.168.10 / Netmask 255.255.255.0
     └── Kernel Route: 192.168.168.0/24 dev enp7s0 proto kernel scope link src 192.168.168.10
               │
               ▼
  [HOP 5: Operating System & Application Ingestion]
     Linux Kernel UDP Socket <---> IZI QGroundControl (AppImage)
     └── Ingestion Socket: UDP 0.0.0.0:14550
     └── QGC Subsystem: LinkManager / UDPLink (AutoConnect)
     └── Vehicle Model: Instantiates Vehicle object for SysID 1, PX4FirmwarePlugin
     └── UI Dispatch: Telemetry streams routed to:
           • TopBar (Flight mode, GPS sats, battery, link quality)
           • PrimaryFlightDisplay (Artificial horizon pitch ladder, roll pointer, altitude tape)
           • TacticalMapView (Live vehicle position badge UAS #1, heading)
           • SystemDiagnosticsView (Link statistics, packet counters, UID)
           • CompanyCsvLogger (High-frequency CSV mission logging)
```

---

### 1.3 Preservation of Direct-USB Serial Fallback
The direct-USB serial baseline remains completely preserved and operational:
- When operating in **Datalink (pMDDL/UDP)** mode:
  * `autoConnectPixhawk = false` (prevents QGC from acquiring exclusive serial locks on `/dev/ttyACM0`).
  * `autoConnectUDP = true` (enables automatic ingestion of MAVLink on port 14550).
- When operating in **Direct-USB Fallback** mode:
  * `autoConnectPixhawk = true` in `~/.config/Company/QGroundControl Daily.ini`.
  * Connecting the Cube Orange+ directly via USB-C exposes `/dev/ttyACM0`.
  * QGroundControl automatically detects VID `0x2DAE` / PID `0x1058` and connects within 2.0 seconds with zero operator intervention.

---

## 2. MOD-04: Physical EO Video Ingestion Specification

### 2.1 Rule of Non-Fabrication
In strict compliance with user instructions:
> **DO NOT INVENT AN RTSP PATH, IP, PORT, CODEC, OR CREDENTIALS.**
> All technical parameters must be formally established from the physical hardware, vendor interface control document (ICD), or factory setup sheet.

### 2.2 Physical Interface Audit Findings (Current Bench State)
A network port scan across standard RTSP ports (`554` and `8554`) was executed across the `192.168.168.0/24` subnet (pMDDL interface) and `192.168.1.0/24` subnet:
- **`enp7s0` (`192.168.168.0/24`)**: Zero RTSP listening endpoints detected. No physical camera payload is currently transmitting video packets on this subnet.
- **Localhost (`127.0.0.1`)**: Zero active RTSP servers running.
- **`wlp8s0` (`192.168.1.0/24`)**: One open RTSP endpoint detected at `192.168.1.240:554`. OUI fingerprinting (`5C:35:48`) and RTSP authentication handshake identified this device as an Aditya Infotech / CP PLUS commercial CCTV security camera on the facility WiFi network, unrelated to the UAV payload.

### 2.3 Vendor Parameters Required from MotionMatics
Before physical EO video decoding can commence in `CameraView.qml`, the following official vendor specifications must be provided:

| # | Parameter | Required Information | Standard Expected Options |
|:---:|:---|:---|:---|
| **1** | **Camera Static IP** | Factory default IPv4 address on the payload Ethernet interface | Typically `192.168.168.xxx` (to match pMDDL subnet) or `192.168.1.xxx` |
| **2** | **Daylight (EO) RTSP URI** | Exact mount point path for the 1080p Daylight sensor | e.g., `/stream1`, `/live/ch0`, `/live/eo`, `/h264` |
| **3** | **RTSP Service Port** | TCP/UDP port where RTSP server listens | Standard `554` or alternative `8554` |
| **4** | **Transport Protocol** | RTP transport mode supported by onboard encoder | `RTP/AVP/UDP` (Unicast UDP) vs `RTP/AVP/TCP` (Interleaved TCP) |
| **5** | **Video Codec & Profile**| Compression standard and profile | `H.264 (AVC) Baseline/Main` or `H.265 (HEVC)` |
| **6** | **RTSP Authentication** | Credential requirement for stream negotiation | Anonymous access vs Basic/Digest authentication (`user:password`) |

### 2.4 Payload Control Isolation (ICD Gate)
All proprietary MotionMatics payload controls remain strictly blocked behind the ICD gate:
- Gimbal rate/angle steering commands (Pitch $[-45^\circ, +100^\circ]$, continuous Yaw)
- Optical continuous/step zoom commands
- Autofocus trigger & manual focus adjustments
- Laser Rangefinder (LRF) firing commands
- Onboard MicroSD snapshot and recording triggers

These controls will only be integrated into `custom/src/MotionMaticsEclipseAdapter.cc` once the official binary framing, headers, checksums, and message IDs are delivered.
