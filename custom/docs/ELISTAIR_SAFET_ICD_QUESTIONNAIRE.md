# Elistair SAFE-T Hardware Interface Control Document (ICD) Questionnaire

**Document Reference:** `IZI-TETHER-ICD-REQ-01`  
**Target System:** Elistair SAFE-T / SAFE-T 2 Smart Tether Station Integration  
**Integration Module:** `SafeTManager` / `SafeTTransport` HAL (`custom/src/tether/`)  
**Prepared By:** GCS Software Engineering Team  

---

## 1. Executive Context
The IZI Ground Control Station (IZI GCS) software has implemented a modular **Hardware Abstraction Layer (HAL)** (`SafeTTransport`) supporting real-time line tension monitoring, automatic winch tracking, tether deployed payout tracking, station power telemetry, and high-voltage emergency cutoff.

To connect the physical Elistair SAFE-T tether ground station to the GCS, the software team requires confirmation on the physical, electrical, and protocol specifications outlined below.

---

## 2. Technical Questionnaire for Hardware / Vendor Team

### A. Physical & Data Link Layer
1. **Primary Interface:**
   - [ ] **Ethernet (RJ45)**: 10/100 Mbps Ethernet.
   - [ ] **Serial / RS-485**: Half-duplex / Full-duplex.
   - [ ] **USB / Virtual COM**: FTDI / CP210x serial bridge.
2. **Network Parameters (if Ethernet):**
   - Default Station IP Address: `________________________` (e.g. `192.168.1.150` or DHCP)
   - Subnet Mask: `________________________` (e.g. `255.255.255.0`)
   - Default Gateway: `________________________`
   - Transport Protocol: `[ ] UDP  [ ] TCP Client  [ ] TCP Server`
   - Port Number: `________________________` (e.g. `50000`, `14550`, or `8080`)
3. **Serial Parameters (if RS-485 / Virtual COM):**
   - Baud Rate: `[ ] 9600  [ ] 57600  [ ] 115200  [ ] 921600`
   - Data Bits: `8`, Parity: `None`, Stop Bits: `1`, Flow Control: `None / Hardware`

---

### B. Telemetry Packet Structure (Downlink: Station $\to$ GCS)
1. **Message Framing:**
   - [ ] **ASCII / NMEA Sentences** (e.g. `$PSAFT,...*CS\r\n`)
   - [ ] **Binary Frame** (e.g. `0xEB 0x90 [Len] [ID] [Payload] [CRC16]`)
   - [ ] **Modbus TCP / RTU** (Registers for Tension, Length, Voltage, Temp)
   - [ ] **MAVLink Extension** (Custom or standard MAVLink `WINCH_STATUS` message)
   - [ ] **REST API / JSON Stream**
2. **Telemetry Field Availability & Units:**
   | Telemetry Field | Vendor Availability | Data Type / Units | Scaling Factor |
   | :--- | :---: | :--- | :--- |
   | **Line Tension** | Yes / No | N (Newtons) or kgf | e.g. `0.1 N/LSB` |
   | **Deployed Length** | Yes / No | meters (m) | e.g. `0.01 m/LSB` |
   | **Payout / Retrieve Speed** | Yes / No | m/s | e.g. `0.01 m/s` |
   | **Drum Temperature** | Yes / No | °C | e.g. `0.1 °C/LSB` |
   | **Station Bus Voltage** | Yes / No | V (HVDC, e.g. 400V) | e.g. `0.1 V/LSB` |
   | **Station Bus Current** | Yes / No | A (Amperes) | e.g. `0.01 A/LSB` |
   | **Winch Mode / State** | Yes / No | Enum / Bitmask | `AUTO / REEL_IN / BRAKE` |
   | **Alarms & Fault Bitmask** | Yes / No | Bitfield | High Tension, Over-temp, Cutoff |
3. **Transmission Frequency:**
   - Desired GCS ingestion: **10 Hz** (100 ms interval).
   - What is the default station broadcast rate? `_______ Hz`

---

### C. Winch & Station Commands (Uplink: GCS $\to$ Station)
1. **Command Capability:**
   - Does the station accept control commands from the GCS over the data link? `[ ] Yes  [ ] No`
2. **Supported Command Set:**
   - [ ] **Set Mode**: Auto Tension / Constant Tension Mode
   - [ ] **Set Tension Setpoint**: Target line tension (e.g. 30 N – 80 N)
   - [ ] **Reel-In (Retrieve)**: Controlled retrieval speed (m/s)
   - [ ] **Reel-Out (Payout)**: Controlled payout speed (m/s)
   - [ ] **Station Brake / Lock**: Engage mechanical/electrical drum lock
   - [ ] **Zero Length Calibration**: Ground reset of cable encoder
   - [ ] **Emergency Power Cutoff**: Immediate HVDC supply disconnect
3. **Command Frame Format:**
   - Detail packet syntax, acknowledgment handshake (ACK/NACK), and retry timeout requirements.

---

### D. Safety & Failover Handling
1. **Heartbeat & Watchdog:**
   - If communication between GCS and SAFE-T is interrupted for >1.5 seconds, what is the station's autonomous fallback?
   - [ ] Maintain last auto-tension setpoint.
   - [ ] Lock drum.
   - [ ] Slow retrieval.
2. **Airborne Buffer Battery Reporting:**
   - Does the airborne tether module transmit buffer battery voltage/state over the tether data channel, or does it report strictly over MAVLink autopilot telemetry?

---

### E. Documentation & Sample Deliverables Requested
- [ ] Official Elistair SAFE-T Protocol Specification PDF.
- [ ] Sample raw hex packet logs from a running bench unit.
- [ ] Test PC utility / emulator (if available).
