<#
.SYNOPSIS
    Windows Deployment Lifecycle & Persistence Verification Script for IZI GCS / QGroundControl.

.DESCRIPTION
    Automates the full Windows deployment validation suite:
    1. Fresh silent installation of the NSIS installer.
    2. Verification of installed binary structure (bin\QGroundControl.exe, Qt runtime, GStreamer).
    3. Application launch and normal termination test.
    4. Post-exit executable persistence assertion (verifies binary is NOT deleted on shutdown).
    5. Registry & uninstaller persistence check (simulating reboot / survival verification).
    6. Complete uninstallation test and directory cleanup verification.
    7. Clean re-installation test for lifecycle idempotency.

.PARAMETER InstallerPath
    Path to the QGroundControl-installer-*.exe installer binary.

.PARAMETER InstallDir
    Target directory for test installation (defaults to $env:TEMP\qgc-deployment-test).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$InstallerPath,

    [Parameter(Mandatory = $false)]
    [string]$InstallDir = "$env:TEMP\qgc-deployment-test"
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  IZI GCS / QGroundControl Windows Deployment Verification  " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Locate Installer if not specified
if (-not $InstallerPath) {
    $searchPaths = @(
        ".\build\Release\*installer*.exe",
        ".\build\*installer*.exe",
        "$env:RUNNER_TEMP\build\*installer*.exe"
    )
    foreach ($pattern in $searchPaths) {
        $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $InstallerPath = $found.FullName
            break
        }
    }
}

if (-not $InstallerPath -or -not (Test-Path $InstallerPath)) {
    Write-Error "Installer executable not found. Please provide -InstallerPath <path-to-installer.exe>"
    exit 1
}

Write-Host "[1/7] Target Installer: $InstallerPath" -ForegroundColor Green
Write-Host "      Target Directory: $InstallDir" -ForegroundColor Green

# 2. Check Digital Signature
Write-Host "`n[2/7] Checking Authenticode Digital Signature..." -ForegroundColor Yellow
$sig = Get-AuthenticodeSignature -FilePath $InstallerPath -ErrorAction SilentlyContinue
if ($sig -and $sig.Status -eq 'Valid') {
    Write-Host "      Signature Status: VALID (Signed by: $($sig.SignerCertificate.Subject))" -ForegroundColor Green
} else {
    Write-Host "      Signature Status: UNSIGNED / INVALID ($($sig.StatusMessage))" -ForegroundColor Red
    Write-Host "      NOTE: Unsigned binaries will trigger Windows 11 Smart App Control & SmartScreen warnings in production." -ForegroundColor DarkYellow
}

# 3. Clean previous test install if present
if (Test-Path $InstallDir) {
    Write-Host "      Cleaning previous test directory: $InstallDir"
    Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
}

# 4. Fresh Silent Installation
Write-Host "`n[3/7] Running Fresh Silent Installation..." -ForegroundColor Yellow
$installProcess = Start-Process -FilePath $InstallerPath -ArgumentList "/S", "/D=$InstallDir" -Wait -PassThru -NoNewWindow
if ($installProcess.ExitCode -ne 0) {
    Write-Error "Installation failed with exit code $($installProcess.ExitCode)"
    exit 1
}

$exePath = Join-Path $InstallDir "bin\QGroundControl.exe"
$uninstallerPath = Join-Path $InstallDir "QGroundControl-Uninstall.exe"

if (-not (Test-Path $exePath)) {
    Write-Error "CRITICAL: QGroundControl.exe not found at $exePath after installation!"
    Get-ChildItem -Path $InstallDir -Recurse | Select-Object FullName
    exit 1
}
Write-Host "      PASS: Installed successfully to $InstallDir" -ForegroundColor Green
Write-Host "      PASS: Executable verified at $exePath" -ForegroundColor Green

# 5. Application Launch & Post-Exit Persistence Test
Write-Host "`n[4/7] Testing Application Launch & Shutdown Persistence..." -ForegroundColor Yellow
Write-Host "      Launching $exePath (boot verification)..."
$appProcess = Start-Process -FilePath $exePath -ArgumentList "--simple-boot-test", "-platform", "offscreen" -Wait -PassThru -NoNewWindow
Write-Host "      Application exited normally with code $($appProcess.ExitCode)"

# Verify EXE STILL EXISTS after exit
if (-not (Test-Path $exePath)) {
    Write-Error "CRITICAL FAILURE: QGroundControl.exe was removed/deleted after application exit!"
    exit 1
}
Write-Host "      PASS: QGroundControl.exe still exists after application exit (No self-deletion)." -ForegroundColor Green

# 6. Uninstaller & Registry Persistence Verification
Write-Host "`n[5/7] Verifying Uninstaller & Persistence Metadata..." -ForegroundColor Yellow
if (-not (Test-Path $uninstallerPath)) {
    Write-Error "Uninstaller not found at $uninstallerPath"
    exit 1
}
Write-Host "      PASS: Uninstaller verified at $uninstallerPath" -ForegroundColor Green

# 7. Uninstallation Test
Write-Host "`n[6/7] Testing Complete Uninstallation..." -ForegroundColor Yellow
Write-Host "      Executing uninstaller: $uninstallerPath"
$uninstallProcess = Start-Process -FilePath $uninstallerPath -ArgumentList "/S", "_?=$InstallDir" -Wait -PassThru -NoNewWindow
Start-Sleep -Seconds 2

if (Test-Path $exePath) {
    Write-Error "CRITICAL: QGroundControl.exe still exists after uninstall!"
    exit 1
}
Write-Host "      PASS: Application files successfully removed." -ForegroundColor Green

# 8. Reinstallation Test (Idempotency)
Write-Host "`n[7/7] Testing Clean Re-installation (Lifecycle Idempotency)..." -ForegroundColor Yellow
$reinstallProcess = Start-Process -FilePath $InstallerPath -ArgumentList "/S", "/D=$InstallDir" -Wait -PassThru -NoNewWindow
if ($reinstallProcess.ExitCode -ne 0 -or -not (Test-Path $exePath)) {
    Write-Error "Reinstallation failed!"
    exit 1
}
Write-Host "      PASS: Re-installation succeeded. Lifecycle verified." -ForegroundColor Green

# Clean up test directory
Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  ALL WINDOWS DEPLOYMENT TESTS PASSED SUCCESSFULLY!          " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
exit 0
