#!/usr/bin/env bash
# ==============================================================================
# Development-only SITL launcher for Company GCS with PX4 / Gazebo
#
# Launches PX4 SITL (gz_x500) in a dedicated visible GNOME Terminal window,
# waits for PX4/Gazebo initialization, and launches Company GCS AppImage.
#
# This script is strictly a development/testing utility and does NOT modify or
# create any dependency between Company GCS and PX4/Gazebo.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration & Paths
# ------------------------------------------------------------------------------
PX4_DIR="${PX4_AUTOPILOT_DIR:-"$HOME/PX4-Autopilot"}"
DEFAULT_APPIMAGE="$HOME/Shreya/QGCS/qgroundcontrol/build-company/QGroundControl-x86_64.AppImage"
APPIMAGE_PATH="${COMPANY_GCS_APPIMAGE:-"$DEFAULT_APPIMAGE"}"
PX4_TARGET="gz_x500"

# ------------------------------------------------------------------------------
# Preflight Validation
# ------------------------------------------------------------------------------
if ! command -v gnome-terminal &> /dev/null; then
    echo "Error: gnome-terminal is required to launch visible PX4 SITL console." >&2
    exit 1
fi

if [[ ! -d "$PX4_DIR" ]]; then
    echo "Error: PX4-Autopilot directory not found at: $PX4_DIR" >&2
    echo "Please clone PX4-Autopilot or set PX4_AUTOPILOT_DIR to the valid path." >&2
    exit 1
fi

if [[ ! -f "$APPIMAGE_PATH" ]]; then
    echo "Error: Company GCS AppImage not found at: $APPIMAGE_PATH" >&2
    echo "Please build the AppImage or set COMPANY_GCS_APPIMAGE to the valid path." >&2
    exit 1
fi

# Ensure AppImage is executable
if [[ ! -x "$APPIMAGE_PATH" ]]; then
    chmod +x "$APPIMAGE_PATH"
fi

# ------------------------------------------------------------------------------
# Step 1: Launch PX4 SITL in a Visible GNOME Terminal
# ------------------------------------------------------------------------------
if pgrep -f "px4.*sitl" > /dev/null 2>&1 || pgrep -x "px4" > /dev/null 2>&1; then
    echo "PX4 SITL process is already running."
else
    echo "Starting PX4 SITL ($PX4_TARGET) in a visible GNOME Terminal..."
    gnome-terminal \
        --title="PX4 SITL Console ($PX4_TARGET)" \
        --working-directory="$PX4_DIR" \
        -- bash -c "make px4_sitl $PX4_TARGET; echo ''; echo 'PX4 process exited.'; exec bash"

    # --------------------------------------------------------------------------
    # Step 2: Wait for PX4 / Gazebo to Initialize
    # --------------------------------------------------------------------------
    echo -n "Waiting for PX4 SITL and Gazebo to initialize"
    TIMEOUT_SECONDS=45
    ELAPSED=0
    INITIALIZED=false

    while (( ELAPSED < TIMEOUT_SECONDS )); do
        # Check if px4 binary is running and MAVLink UDP port is open
        if pgrep -x "px4" > /dev/null 2>&1 || pgrep -f "px4.*sitl" > /dev/null 2>&1; then
            if command -v ss &> /dev/null && ss -lun | grep -E -q ':(14550|14540|14580)\b'; then
                INITIALIZED=true
                break
            elif command -v lsof &> /dev/null && lsof -iUDP:14550 > /dev/null 2>&1; then
                INITIALIZED=true
                break
            fi
        fi
        sleep 1
        ELAPSED=$((ELAPSED + 1))
        echo -n "."
    done
    echo ""

    if [[ "$INITIALIZED" == true ]]; then
        echo "PX4 SITL & MAVLink server ready (elapsed: ${ELAPSED}s)."
        # Brief stabilization delay for Gazebo physics & model spawning
        sleep 2
    else
        echo "Warning: Timeout waiting for MAVLink port. Proceeding with launch attempt..."
    fi
fi

# ------------------------------------------------------------------------------
# Step 3: Handle Company GCS AppImage Launch Gracefully
# ------------------------------------------------------------------------------
EXISTING_GCS_PID=$(pgrep -f "QGroundControl-x86_64.AppImage" 2>/dev/null | head -n 1 || true)
if [[ -z "$EXISTING_GCS_PID" ]]; then
    EXISTING_GCS_PID=$(pgrep -f "build-company/QGroundControl" 2>/dev/null | head -n 1 || true)
fi

if [[ -n "$EXISTING_GCS_PID" ]]; then
    echo "Company GCS is already running (PID: $EXISTING_GCS_PID). Reusing existing instance."
else
    echo "Launching Company GCS in a separate window..."
    "$APPIMAGE_PATH" > /dev/null 2>&1 &
    GCS_PID=$!
    echo "Company GCS launched (PID: $GCS_PID)."
fi

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo ""
echo "=================================================================="
echo " Company GCS SITL Environment Ready"
echo "=================================================================="
echo " PX4 Terminal : Visible GNOME Terminal with interactive 'pxh>' console"
echo " Company GCS  : Running in separate application window"
echo " MAVLink Link : QGC automatically connects to SITL on UDP 14550"
echo "=================================================================="
