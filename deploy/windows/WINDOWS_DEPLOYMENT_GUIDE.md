# IZI GCS / QGroundControl — Windows Production Deployment & Code Signing Guide

## 1. Executive Summary & Problem Analysis

When deploying IZI GCS / QGroundControl to Windows 11 client machines, users may encounter security interventions from **Windows Smart App Control (SAC)**, **SmartScreen**, or **Windows Defender Real-Time Protection**.

### Confirmed Facts vs. Probable Cause

| Classification | Observation / Finding | Technical Details |
| :--- | :--- | :--- |
| **Confirmed Installer Behavior** | **Persistent, Clean Win32 Installation** | The NSIS installer writes all files to `$PROGRAMFILES64\QGroundControl` (`C:\Program Files\QGroundControl\bin\QGroundControl.exe`). It does **not** extract to `%TEMP%` and contains **no self-deletion, self-updating, or delayed removal code**. |
| **Confirmed Application Behavior** | **Clean Process Shutdown** | On exit, `QGCApplication::shutdown()` terminates GStreamer pipelines, closes QML engines, disconnects telemetry sockets, and yields the process without touching on-disk binaries. |
| **Confirmed Signature Status** | **Unsigned Binaries** | Binaries built from CI/CD currently lack an Authenticode digital signature and RFC 3161 timestamp. |
| **Confirmed Windows Security Action** | **Smart App Control Warning** | Windows 11 explicitly blocked execution with: *"Smart App Control blocked an app that may be unsafe"*. |
| **Probable Cause for Disappearing Executable** | **Windows Defender / Smart App Control Quarantine** | When an unsigned, low-reputation binary downloaded from the web (bearing `Zone.Identifier` Mark-of-the-Web) executes, Windows Defender heuristics or Smart App Control background evaluation can flag the binary upon process exit and quarantine or remove `QGroundControl.exe` to protection history. *(Note: To confirm on a specific machine, check Event Viewer under `Applications and Services Logs > Microsoft > Windows > Windows Defender > Operational` for Event IDs 1116/1117).* |

---

## 2. Windows 11 Security Mechanisms Explained

### A. Smart App Control (SAC)
Smart App Control is an AI-powered security layer in Windows 11 (build 22H2 and later).
- **Enforcement**: Blocks any binary that does not have a **valid, trusted digital signature** OR a high positive reputation score in Microsoft's Intelligent Security Graph (ISG).
- **Behavior with Unsigned Apps**: Blocks launch immediately or terminates/quarantines untrusted processes.

### B. Windows Defender Heuristic Scanning
When an unknown, unsigned application performs low-level network operations (UDP broadcast on 14550, RTSP video streaming, raw socket binding) and writes dumps/logs, cloud heuristic heuristics (e.g. `PUA` or generic heuristic signatures) may automatically move the `.exe` to Quarantine after process execution ends.

---

## 3. Production Remediation: Authenticode Code Signing

To achieve 100% reliable deployment on production Windows machines without requiring security exclusions or disabling Windows Defender:

### Requirements:
1. **Certificate Type**:
   - **Extended Validation (EV) Code Signing Certificate** (Recommended for immediate SmartScreen reputation), OR
   - **Azure Trusted Signing** (Microsoft's managed cloud code-signing service), OR
   - **Standard Organization Validation (OV) Certificate** (Requires building download reputation over time).
2. **Digest Algorithm**: SHA-256 (`/fd SHA256`).
3. **Timestamp Authority (TSA)**: RFC 3161 compliant timestamping server (e.g. `http://timestamp.digicert.com` or `http://timestamp.sectigo.com`).
4. **Scope**:
   - Both the main executable (`bin\QGroundControl.exe`) AND the installer (`QGroundControl-installer-AMD64.exe`) must be signed.

---

## 4. How to Sign Binaries with Signtool

### Step A: Sign the Application Executable (Prior to Packaging)
```cmd
signtool.exe sign /v /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /sha1 <CERTIFICATE_THUMBPRINT> "C:\Program Files\QGroundControl\bin\QGroundControl.exe"
```

### Step B: Sign the NSIS Installer (After Packaging)
```cmd
signtool.exe sign /v /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /sha1 <CERTIFICATE_THUMBPRINT> "QGroundControl-installer-AMD64.exe"
```

### Step C: Verify Signatures
```cmd
signtool.exe verify /pa /v "QGroundControl-installer-AMD64.exe"
```

---

## 5. CI/CD Integration Architecture (Azure Trusted Signing)

For automated, secure GitHub Actions releases without storing raw `.pfx` certificates or passwords in CI:

### Recommended: Azure Trusted Signing Action
In `.github/workflows/windows.yml`:

```yaml
      - name: Sign QGroundControl Executable
        if: env.ENABLE_CODE_SIGNING == 'true'
        uses: azure/trusted-signing-action@v0.5.1
        with:
          azure-tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          azure-client-id: ${{ secrets.AZURE_CLIENT_ID }}
          azure-client-secret: ${{ secrets.AZURE_CLIENT_SECRET }}
          endpoint: https://eus.codesigning.azure.net/
          trusted-signing-account-name: ${{ secrets.TRUSTED_SIGNING_ACCOUNT }}
          certificate-profile-name: ${{ secrets.TRUSTED_SIGNING_PROFILE }}
          files-folder: ${{ runner.temp }}\build\Release
          files-folder-filter: QGroundControl.exe
          file-digest: SHA256
          timestamp-rfc3161: http://timestamp.acs.microsoft.com
          timestamp-digest: SHA256

      - name: Create Installer
        uses: ./.github/actions/cmake-install
        with:
          build-dir: ${{ runner.temp }}\build
          build-type: ${{ matrix.build_type }}

      - name: Sign Windows Installer
        if: env.ENABLE_CODE_SIGNING == 'true'
        uses: azure/trusted-signing-action@v0.5.1
        with:
          azure-tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          azure-client-id: ${{ secrets.AZURE_CLIENT_ID }}
          azure-client-secret: ${{ secrets.AZURE_CLIENT_SECRET }}
          endpoint: https://eus.codesigning.azure.net/
          trusted-signing-account-name: ${{ secrets.TRUSTED_SIGNING_ACCOUNT }}
          certificate-profile-name: ${{ secrets.TRUSTED_SIGNING_PROFILE }}
          files-folder: ${{ runner.temp }}\build
          files-folder-filter: QGroundControl-installer-*.exe
          file-digest: SHA256
          timestamp-rfc3161: http://timestamp.acs.microsoft.com
          timestamp-digest: SHA256
```

---

## 6. Microsoft Security Intelligence Submission

Upon publishing a new production version:
1. Navigate to the [Microsoft Security Intelligence File Submission Portal](https://www.microsoft.com/en-us/wdsi/filesubmission).
2. Submit the newly signed installer as a **Software Developer Submission**.
3. Microsoft's automated scanner indexes the binary hashes in the Intelligent Security Graph, establishing immediate positive reputation across all Windows 11 Smart App Control installations worldwide.
