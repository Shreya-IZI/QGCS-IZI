pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import QGroundControl
import QGroundControl.Controls
import Company.UI

Item {
    id: root

    // Supported Modes: "RGB_ONLY", "THERMAL_ONLY", "SIDE_BY_SIDE", "PIP"
    property string currentMode: "SIDE_BY_SIDE"

    readonly property bool _isNarrow: width < 1024 || ScreenTools.isMobile

    readonly property bool _isRgbActive: QGroundControl.videoManager.decoding
    readonly property bool _isThermalActive: QGroundControl.videoManager.hasThermal && QGroundControl.videoManager.decoding

    // ------------------------------------------------------------------------
    // Authoritative Millisecond Video Timestamp (Synced to Drone GPS Epoch)
    // ------------------------------------------------------------------------
    property string utcTimestampStr: ""
    property string hmsMsTimestampStr: ""
    property string utcDateStr: ""

    Timer {
        id: utcTimer
        interval: 33 // ~30 FPS refresh for smooth millisecond video timestamping
        running: true
        repeat: true
        onTriggered: {
            var nowMs = CompanyTelemetry.hasDroneGpsTime ?
                CompanyTelemetry.currentDroneTimeMs :
                Date.now();
            var d = new Date(nowMs);
            function pad(n, len) {
                var s = String(n);
                while (s.length < len) s = "0" + s;
                return s;
            }
            var y = d.getUTCFullYear();
            var mo = pad(d.getUTCMonth() + 1, 2);
            var day = pad(d.getUTCDate(), 2);
            var h = pad(d.getUTCHours(), 2);
            var m = pad(d.getUTCMinutes(), 2);
            var s = pad(d.getUTCSeconds(), 2);
            var ms = pad(d.getUTCMilliseconds(), 3);

            root.hmsMsTimestampStr = h + ":" + m + ":" + s + ":" + ms;
            root.utcDateStr = y + "-" + mo + "-" + day;
            root.utcTimestampStr = y + "-" + mo + "-" + day + " " + h + ":" + m + ":" + s + "." + ms + " Z";
        }
    }

    // ------------------------------------------------------------------------
    // Video Recording Timer State
    // ------------------------------------------------------------------------
    property int recordingElapsedSec: 0
    readonly property string recordingElapsedStr: {
        var h = Math.floor(recordingElapsedSec / 3600);
        var m = Math.floor((recordingElapsedSec % 3600) / 60);
        var s = recordingElapsedSec % 60;
        function pad(n) { return (n < 10 ? "0" : "") + n; }
        return (h > 0 ? pad(h) + ":" : "") + pad(m) + ":" + pad(s);
    }

    Timer {
        id: recTimer
        interval: 1000
        running: QGroundControl.videoManager.recording
        repeat: true
        onTriggered: root.recordingElapsedSec++
    }

    // ------------------------------------------------------------------------
    // Video Stream Telemetry Helpers
    // ------------------------------------------------------------------------
    readonly property string videoResolutionStr: {
        var sz = QGroundControl.videoManager.videoSize;
        if (sz && sz.width > 0 && sz.height > 0) {
            return sz.width + "x" + sz.height;
        }
        var cam = CompanyTelemetry._activeCamera;
        if (cam && cam.currentStreamInstance && cam.currentStreamInstance.resolution && cam.currentStreamInstance.resolution.width > 0) {
            return cam.currentStreamInstance.resolution.width + "x" + cam.currentStreamInstance.resolution.height;
        }
        return (root._isRgbActive || root._isThermalActive) ? "1920x1080" : "--";
    }

    readonly property string streamFpsStr: {
        var cam = CompanyTelemetry._activeCamera;
        if (cam && cam.currentStreamInstance && cam.currentStreamInstance.framerate > 0) {
            return Math.round(cam.currentStreamInstance.framerate) + " FPS";
        }
        return (root._isRgbActive || root._isThermalActive) ? "30 FPS" : "-- FPS";
    }

    // ------------------------------------------------------------------------
    // Action Handlers
    // ------------------------------------------------------------------------
    function triggerSnapshot() {
        shutterFlashAnim.restart();
        toastText.text = qsTr("CAPTURING SNAPSHOT...");
        toastAnim.restart();

        // 1. Send drone hardware trigger if active
        var cam = CompanyTelemetry._activeCamera;
        if (cam && cam.capturesPhotos) {
            cam.takePhoto();
        }

        // 2. Trigger payload interface (which also saves high-res tactical snapshot to phone storage)
        if (typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface) {
            CompanyPayloadInterface.triggerSnapshot();
        } else if (typeof companyPayload !== "undefined" && companyPayload) {
            companyPayload.triggerSnapshot();
        }

        // 3. Perform visual grab of videoCanvas to save directly to phone storage
        var targetDir = "";
        if (typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface && CompanyPayloadInterface.photoSaveDirectory) {
            targetDir = CompanyPayloadInterface.photoSaveDirectory();
        } else if (QGroundControl.settingsManager && QGroundControl.settingsManager.appSettings) {
            targetDir = QGroundControl.settingsManager.appSettings.photoSavePath;
        }

        if (targetDir && targetDir !== "") {
            var now = new Date();
            function pad(n) { return (n < 10 ? "0" : "") + n; }
            var dateStamp = now.getFullYear() + pad(now.getMonth() + 1) + pad(now.getDate()) + "_" + pad(now.getHours()) + pad(now.getMinutes()) + pad(now.getSeconds());
            var fileName = "IZI_SNAP_" + dateStamp + ".jpg";
            var fullPath = targetDir + "/" + fileName;

            videoCanvas.grabToImage(function(result) {
                var success = result.saveToFile(fullPath);
                if (success) {
                    toastText.text = qsTr("SAVED TO STORAGE: ") + fileName;
                    toastAnim.restart();
                    if (typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface && CompanyPayloadInterface.notifyMediaScan) {
                        CompanyPayloadInterface.notifyMediaScan(fullPath);
                    }
                }
            });
        }
    }

    function toggleRecording() {
        var cam = CompanyTelemetry._activeCamera;
        if (QGroundControl.videoManager.recording) {
            QGroundControl.videoManager.stopRecording();
            if (cam && cam.capturesVideo) {
                cam.stopVideoRecording();
            }
        } else {
            QGroundControl.videoManager.startRecording();
            if (cam && cam.capturesVideo) {
                cam.startVideoRecording();
            }
        }
        if (typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface) {
            CompanyPayloadInterface.toggleRecording();
        } else if (typeof companyPayload !== "undefined" && companyPayload) {
            companyPayload.toggleRecording();
        }
    }

    function stepZoom(direction) {
        var cam = CompanyTelemetry._activeCamera;
        if (cam && cam.hasZoom) {
            cam.stepZoom(direction);
        } else if (typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface) {
            CompanyPayloadInterface.stepZoom(direction);
        } else if (typeof companyPayload !== "undefined" && companyPayload) {
            companyPayload.stepZoom(direction);
        }
    }

    // React to video manager updates
    Connections {
        target: QGroundControl.videoManager
        function onImageFileChanged() {
            var fullPath = QGroundControl.videoManager.imageFile;
            if (fullPath && fullPath !== "") {
                var fileName = fullPath.substring(fullPath.lastIndexOf("/") + 1);
                toastText.text = qsTr("SAVED: ") + fileName;
            }
        }
        function onRecordingChanged() {
            if (QGroundControl.videoManager.recording) {
                root.recordingElapsedSec = 0;
            }
        }
    }

    // React to payload interface snapshot signals
    Connections {
        target: (typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface) ? CompanyPayloadInterface : ((typeof companyPayload !== "undefined" && companyPayload) ? companyPayload : null)
        function onSnapshotCaptured(filePath) {
            if (filePath && filePath !== "") {
                var fName = filePath.substring(filePath.lastIndexOf("/") + 1);
                toastText.text = qsTr("SAVED: ") + fName;
                toastAnim.restart();
            }
        }
    }

    // ------------------------------------------------------------------------
    // Deep Tactical Background
    // ------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: CompanyTheme.bgApp
    }

    // ------------------------------------------------------------------------
    // Primary Video Canvas Container
    // ------------------------------------------------------------------------
    Item {
        id: videoCanvas
        anchors.fill: parent

        // --------------------------------------------------------------------
        // Divider for SIDE_BY_SIDE mode
        // --------------------------------------------------------------------
        Rectangle {
            id: splitDivider
            width: 1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: CompanyTheme.borderCard
            visible: root.currentMode === "SIDE_BY_SIDE"
            z: 5
        }

        // --------------------------------------------------------------------
        // RGB Frame Container
        // --------------------------------------------------------------------
        Rectangle {
            id: rgbFrame
            color: CompanyTheme.bgApp
            clip: true

            x: 0
            y: 0
            width: {
                if (root.currentMode === "SIDE_BY_SIDE") {
                    return Math.floor((videoCanvas.width - 1) / 2)
                }
                return videoCanvas.width
            }
            height: videoCanvas.height
            visible: root.currentMode !== "THERMAL_ONLY"
            z: 1

            // Persistent VideoOutput for RGB Primary Stream
            VideoOutput {
                id: rgbVideoOutput
                objectName: "videoContent"
                anchors.fill: parent
                fillMode: QGroundControl.settingsManager.videoSettings.videoFit.rawValue === 2
                          ? VideoOutput.PreserveAspectCrop
                          : VideoOutput.PreserveAspectFit
                visible: root._isRgbActive
            }

            // Optical Center Reticle (RGB)
            Item {
                id: rgbReticle
                anchors.centerIn: parent
                width: 28
                height: 28
                visible: root._isRgbActive
                z: 15

                // Top tick
                Rectangle { x: 13; y: 0; width: 2; height: 8; color: "#000000" }
                Rectangle { x: 13.5; y: 0.5; width: 1; height: 7; color: CompanyTheme.primary }
                // Bottom tick
                Rectangle { x: 13; y: 20; width: 2; height: 8; color: "#000000" }
                Rectangle { x: 13.5; y: 20.5; width: 1; height: 7; color: CompanyTheme.primary }
                // Left tick
                Rectangle { x: 0; y: 13; width: 8; height: 2; color: "#000000" }
                Rectangle { x: 0.5; y: 13.5; width: 7; height: 1; color: CompanyTheme.primary }
                // Right tick
                Rectangle { x: 20; y: 13; width: 8; height: 2; color: "#000000" }
                Rectangle { x: 20.5; y: 13.5; width: 7; height: 1; color: CompanyTheme.primary }
                // Center subtle circle
                Rectangle {
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    radius: 5
                    color: "transparent"
                    border.color: CompanyTheme.primary
                    border.width: 1
                    opacity: 0.65
                }
            }

            // Fallback display when no stream is actively decoding
            Item {
                id: rgbWaitingCard
                anchors.centerIn: parent
                visible: !root._isRgbActive
                width: 260
                height: 140

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: CompanyTheme.spacingSm

                    IconVector {
                        Layout.alignment: Qt.AlignHCenter
                        name: "video"
                        size: 36
                        color: CompanyTheme.textMuted
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("RGB STREAM")
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontH2
                        font.bold: true
                        font.letterSpacing: 0.8
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("WAITING FOR STREAM")
                        color: CompanyTheme.textSecondary
                        font.pointSize: CompanyTheme.fontSmall
                        font.letterSpacing: 0.5
                    }

                    Item { Layout.preferredHeight: 4 }

                    StatusBadge {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("STANDBY")
                        badgeColor: CompanyTheme.warning
                        showDot: true
                        pulse: true
                    }
                }
            }

            // HUD Badge (Bottom-left overlay above telemetry strip)
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.bottomMargin: 62 + osdBottomLeft.height + 6
                anchors.leftMargin: CompanyTheme.spacingMd
                z: 10
                height: 22
                radius: CompanyTheme.radiusSm
                color: CompanyTheme.bgOverlayDark
                border.color: CompanyTheme.borderCard
                border.width: 1
                implicitWidth: rgbBadgeLayout.implicitWidth + CompanyTheme.spacingSm * 2

                RowLayout {
                    id: rgbBadgeLayout
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: root._isRgbActive ? CompanyTheme.success : CompanyTheme.warning
                    }

                    Text {
                        text: qsTr("RGB PRIMARY")
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.letterSpacing: 0.5
                    }
                }
            }
        }

        // --------------------------------------------------------------------
        // Thermal Frame Container
        // --------------------------------------------------------------------
        Rectangle {
            id: thermalFrame
            color: CompanyTheme.bgApp
            clip: true

            radius: root.currentMode === "PIP" ? CompanyTheme.radiusMd : 0
            border.color: root.currentMode === "PIP" ? CompanyTheme.primary : (root.currentMode === "SIDE_BY_SIDE" ? CompanyTheme.borderCard : "transparent")
            border.width: root.currentMode === "PIP" ? 2 : (root.currentMode === "SIDE_BY_SIDE" ? 0 : 0)

            x: {
                if (root.currentMode === "SIDE_BY_SIDE") {
                    return Math.floor((videoCanvas.width - 1) / 2) + 1
                } else if (root.currentMode === "PIP") {
                    return videoCanvas.width - width - CompanyTheme.spacingLg
                }
                return 0
            }
            y: {
                if (root.currentMode === "PIP") {
                    return videoCanvas.height - height - 62
                }
                return 0
            }
            width: {
                if (root.currentMode === "SIDE_BY_SIDE") {
                    return videoCanvas.width - rgbFrame.width - 1
                } else if (root.currentMode === "PIP") {
                    return 280
                }
                return videoCanvas.width
            }
            height: {
                if (root.currentMode === "PIP") {
                    return 160
                }
                return videoCanvas.height
            }
            visible: root.currentMode !== "RGB_ONLY"
            z: root.currentMode === "PIP" ? 20 : 1

            // Persistent VideoOutput for Thermal Video Stream
            VideoOutput {
                id: thermalVideoOutput
                objectName: "thermalVideo"
                anchors.fill: parent
                fillMode: QGroundControl.settingsManager.videoSettings.videoFit.rawValue === 2
                          ? VideoOutput.PreserveAspectCrop
                          : VideoOutput.PreserveAspectFit
                visible: root._isThermalActive
            }

            // Optical Center Reticle (Thermal)
            Item {
                id: thermalReticle
                anchors.centerIn: parent
                width: root.currentMode === "PIP" ? 18 : 28
                height: root.currentMode === "PIP" ? 18 : 28
                visible: root._isThermalActive && root.currentMode !== "PIP"
                z: 15

                // Top tick
                Rectangle { x: 13; y: 0; width: 2; height: 8; color: "#000000" }
                Rectangle { x: 13.5; y: 0.5; width: 1; height: 7; color: CompanyTheme.accent }
                // Bottom tick
                Rectangle { x: 13; y: 20; width: 2; height: 8; color: "#000000" }
                Rectangle { x: 13.5; y: 20.5; width: 1; height: 7; color: CompanyTheme.accent }
                // Left tick
                Rectangle { x: 0; y: 13; width: 8; height: 2; color: "#000000" }
                Rectangle { x: 0.5; y: 13.5; width: 7; height: 1; color: CompanyTheme.accent }
                // Right tick
                Rectangle { x: 20; y: 13; width: 8; height: 2; color: "#000000" }
                Rectangle { x: 20.5; y: 13.5; width: 7; height: 1; color: CompanyTheme.accent }
                // Center subtle circle
                Rectangle {
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    radius: 5
                    color: "transparent"
                    border.color: CompanyTheme.accent
                    border.width: 1
                    opacity: 0.65
                }
            }

            // Fallback display when no thermal stream is actively decoding
            Item {
                id: thermalWaitingCard
                anchors.centerIn: parent
                visible: !root._isThermalActive
                width: parent.width - 20
                height: parent.height - 20

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: root.currentMode === "PIP" ? 4 : CompanyTheme.spacingSm

                    IconVector {
                        Layout.alignment: Qt.AlignHCenter
                        name: "video"
                        size: root.currentMode === "PIP" ? 22 : 36
                        color: CompanyTheme.textMuted
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("THERMAL IR")
                        color: CompanyTheme.textPrimary
                        font.pointSize: root.currentMode === "PIP" ? CompanyTheme.fontSmall : CompanyTheme.fontH2
                        font.bold: true
                        font.letterSpacing: 0.8
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("WAITING FOR STREAM")
                        color: CompanyTheme.textSecondary
                        font.pointSize: root.currentMode === "PIP" ? CompanyTheme.fontTiny : CompanyTheme.fontSmall
                        font.letterSpacing: 0.5
                    }

                    Item {
                        Layout.preferredHeight: 2
                        visible: root.currentMode !== "PIP"
                    }

                    StatusBadge {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("STANDBY")
                        badgeColor: CompanyTheme.warning
                        showDot: true
                        pulse: true
                        visible: root.currentMode !== "PIP"
                    }
                }
            }

            // HUD Badge (Bottom-left in full/split modes, top-left inside PiP box)
            Rectangle {
                anchors.bottom: root.currentMode === "PIP" ? undefined : parent.bottom
                anchors.top: root.currentMode === "PIP" ? parent.top : undefined
                anchors.left: parent.left
                anchors.bottomMargin: root.currentMode === "PIP" ? 0 : (62 + osdBottomLeft.height + 6)
                anchors.topMargin: root.currentMode === "PIP" ? 6 : 0
                anchors.leftMargin: root.currentMode === "PIP" ? 6 : CompanyTheme.spacingMd
                z: 10
                height: root.currentMode === "PIP" ? 20 : 22
                radius: CompanyTheme.radiusSm
                color: CompanyTheme.bgOverlayDark
                border.color: CompanyTheme.borderCard
                border.width: 1
                implicitWidth: thermalBadgeLayout.implicitWidth + (root.currentMode === "PIP" ? 8 : CompanyTheme.spacingSm * 2)

                RowLayout {
                    id: thermalBadgeLayout
                    anchors.centerIn: parent
                    spacing: 5

                    Rectangle {
                        width: root.currentMode === "PIP" ? 5 : 6
                        height: root.currentMode === "PIP" ? 5 : 6
                        radius: 3
                        color: root._isThermalActive ? CompanyTheme.success : CompanyTheme.warning
                    }

                    Text {
                        text: qsTr("THERMAL IR")
                        color: CompanyTheme.accent
                        font.pointSize: root.currentMode === "PIP" ? 7.5 : CompanyTheme.fontTiny
                        font.bold: true
                        font.letterSpacing: 0.5
                    }
                }
            }
        }
    }

    // ========================================================================
    // TACTICAL VIDEO OSD OVERLAYS (z: 25)
    // ========================================================================
    Item {
        id: osdLayer
        anchors.fill: parent
        z: 25

        // --------------------------------------------------------------------
        // TOP-LEFT OSD: Vehicle & Positioning Telemetry
        // Offset below DashboardView sub-navigation switcher (topMargin: 52)
        // --------------------------------------------------------------------
        Rectangle {
            id: osdTopLeft
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: root._isNarrow ? 82 : 52
            anchors.leftMargin: CompanyTheme.spacingMd
            radius: CompanyTheme.radiusSm
            color: CompanyTheme.bgOverlayDark
            border.color: CompanyTheme.borderCard
            border.width: 1
            implicitWidth: osdTopLeftLayout.implicitWidth + 16
            implicitHeight: osdTopLeftLayout.implicitHeight + 12
            width: implicitWidth
            height: implicitHeight

            ColumnLayout {
                id: osdTopLeftLayout
                anchors.centerIn: parent
                spacing: 4

                // Row 1: UAS ID + Mode + Armed Status
                RowLayout {
                    spacing: 6
                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: CompanyTelemetry.hasVehicle ? (CompanyTelemetry.armed ? CompanyTheme.error : CompanyTheme.warning) : CompanyTheme.textMuted
                    }
                    Text {
                        text: CompanyTelemetry.hasVehicle ? ("UAS #" + String(CompanyTelemetry.vehicleId).padStart(2, "0")) : "UAS --"
                        color: CompanyTheme.primary
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.family: "Monospace"
                    }
                    Text {
                        text: "•"
                        color: CompanyTheme.borderCard
                        font.pointSize: CompanyTheme.fontTiny
                    }
                    Text {
                        text: CompanyTelemetry.flightMode !== "" ? CompanyTelemetry.flightMode : (CompanyTelemetry.hasVehicle ? "STANDBY" : "DISCONNECTED")
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.family: "Monospace"
                    }
                    Text {
                        text: CompanyTelemetry.armed ? qsTr("[ARMED]") : qsTr("[DISARMED]")
                        color: CompanyTelemetry.armed ? CompanyTheme.error : CompanyTheme.textMuted
                        font.pointSize: CompanyTheme.fontTiny
                        font.family: "Monospace"
                    }
                }

                // Row 2: Lat / Lon Coordinates
                RowLayout {
                    spacing: 8
                    Text {
                        text: "LAT: " + (CompanyTelemetry.hasValidCoord ? CompanyTelemetry.latitude.toFixed(6) + "°" : "--")
                        color: CompanyTheme.textSecondary
                        font.pointSize: CompanyTheme.fontTiny
                        font.family: "Monospace"
                    }
                    Text {
                        text: "LON: " + (CompanyTelemetry.hasValidCoord ? CompanyTelemetry.longitude.toFixed(6) + "°" : "--")
                        color: CompanyTheme.textSecondary
                        font.pointSize: CompanyTheme.fontTiny
                        font.family: "Monospace"
                    }
                }

                // Row 3: AGL / AMSL Altitudes
                RowLayout {
                    spacing: 8
                    Text {
                        text: "AGL: " + CompanyTelemetry.altitudeRelativeStr
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.family: "Monospace"
                    }
                    Text {
                        text: "AMSL: " + CompanyTelemetry.altitudeAMSLStr
                        color: CompanyTheme.textSecondary
                        font.pointSize: CompanyTheme.fontTiny
                        font.family: "Monospace"
                    }
                }
            }
        }


        // --------------------------------------------------------------------
        // TOP-RIGHT OSD: Time, Resolution, FPS & REC Status
        // --------------------------------------------------------------------
        Rectangle {
            id: osdTopRight
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: CompanyTheme.spacingMd
            anchors.rightMargin: CompanyTheme.spacingMd
            radius: CompanyTheme.radiusSm
            color: CompanyTheme.bgOverlayDark
            border.color: CompanyTheme.borderCard
            border.width: 1
            implicitWidth: osdTopRightLayout.implicitWidth + 16
            implicitHeight: osdTopRightLayout.implicitHeight + 12
            width: implicitWidth
            height: implicitHeight

            ColumnLayout {
                id: osdTopRightLayout
                anchors.centerIn: parent
                spacing: 4

                // Row 1: Authoritative Video Millisecond Timestamp with Source Tag
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 6

                    Rectangle {
                        height: 18
                        radius: CompanyTheme.radiusSm - 1
                        color: CompanyTelemetry.hasDroneGpsTime ? CompanyTheme.successDim : CompanyTheme.primaryDim
                        border.color: CompanyTelemetry.hasDroneGpsTime ? CompanyTheme.success : CompanyTheme.primary
                        border.width: 1
                        implicitWidth: tagLayout.implicitWidth + 8

                        RowLayout {
                            id: tagLayout
                            anchors.centerIn: parent
                            spacing: 4

                            Rectangle {
                                width: 5
                                height: 5
                                radius: 2.5
                                color: CompanyTelemetry.hasDroneGpsTime ? CompanyTheme.success : CompanyTheme.primary
                            }

                            Text {
                                text: CompanyTelemetry.timeSourceLabel
                                color: CompanyTelemetry.hasDroneGpsTime ? CompanyTheme.success : CompanyTheme.primary
                                font.pointSize: 7
                                font.bold: true
                                font.family: "Monospace"
                            }
                        }
                    }

                    // Milliseconds Video Timestamp badge (hh:mm:ss:ms)
                    Rectangle {
                        height: 18
                        radius: CompanyTheme.radiusSm - 1
                        color: CompanyTheme.bgApp
                        border.color: CompanyTelemetry.hasDroneGpsTime ? CompanyTheme.success : CompanyTheme.accent
                        border.width: 1
                        implicitWidth: hmsMsText.implicitWidth + 8

                        Text {
                            id: hmsMsText
                            anchors.centerIn: parent
                            text: root.hmsMsTimestampStr
                            color: CompanyTheme.accent
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                            font.family: "Monospace"
                        }
                    }

                    Text {
                        text: root.utcDateStr
                        color: CompanyTheme.textSecondary
                        font.pointSize: CompanyTheme.fontTiny
                        font.family: "Monospace"
                    }
                }

                // Row 2: Video Resolution & Stream FPS / Status
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    Text {
                        text: root.videoResolutionStr
                        color: CompanyTheme.textSecondary
                        font.pointSize: CompanyTheme.fontTiny
                        font.family: "Monospace"
                    }

                    Text {
                        text: root.streamFpsStr
                        color: CompanyTheme.textSecondary
                        font.pointSize: CompanyTheme.fontTiny
                        font.family: "Monospace"
                    }

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: (root._isRgbActive || root._isThermalActive) ? CompanyTheme.success : CompanyTheme.warning
                    }

                    Text {
                        text: (root._isRgbActive || root._isThermalActive) ? "DECODING" : "STANDBY"
                        color: (root._isRgbActive || root._isThermalActive) ? CompanyTheme.success : CompanyTheme.warning
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.family: "Monospace"
                    }
                }

                // Row 3: Recording Status Badge (Active when recording)
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 6
                    visible: QGroundControl.videoManager.recording

                    Rectangle {
                        id: recPulseDot
                        width: 8
                        height: 8
                        radius: 4
                        color: CompanyTheme.error

                        SequentialAnimation on opacity {
                            running: QGroundControl.videoManager.recording
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.2; duration: 500 }
                            NumberAnimation { from: 0.2; to: 1.0; duration: 500 }
                        }
                    }

                    Text {
                        text: "REC"
                        color: CompanyTheme.error
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.family: "Monospace"
                    }

                    Text {
                        text: root.recordingElapsedStr
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.family: "Monospace"
                    }
                }
            }
        }

        // --------------------------------------------------------------------
        // BOTTOM-LEFT OSD: Gimbal Telemetry & Sensor HFOV
        // Offset above DashboardView bottom telemetry strip (bottomMargin: 62)
        // --------------------------------------------------------------------
        Rectangle {
            id: osdBottomLeft
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 62
            anchors.leftMargin: CompanyTheme.spacingMd
            radius: CompanyTheme.radiusSm
            color: CompanyTheme.bgOverlayDark
            border.color: CompanyTheme.borderCard
            border.width: 1
            implicitWidth: osdBottomLeftLayout.implicitWidth + 16
            implicitHeight: osdBottomLeftLayout.implicitHeight + 12
            width: implicitWidth
            height: implicitHeight

            ColumnLayout {
                id: osdBottomLeftLayout
                anchors.centerIn: parent
                spacing: 4

                // Row 1: Gimbal Attitude (Pitch / Yaw / Roll)
                RowLayout {
                    spacing: 10
                    Text {
                        text: "GMB PITCH: " + CompanyTelemetry.gimbalPitchStr
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.family: "Monospace"
                    }
                    Text {
                        text: "GMB YAW: " + CompanyTelemetry.gimbalYawStr
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.family: "Monospace"
                    }
                    Text {
                        text: "ROLL: " + CompanyTelemetry.gimbalRollStr
                        color: CompanyTheme.textSecondary
                        font.pointSize: CompanyTheme.fontTiny
                        font.family: "Monospace"
                    }
                }

                // Row 2: Mode-Aware Sensor HFOV
                RowLayout {
                    spacing: 10
                    Text {
                        visible: root.currentMode !== "THERMAL_ONLY"
                        text: "RGB HFOV: " + CompanyTelemetry.rgbHfovStr
                        color: CompanyTheme.primary
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.family: "Monospace"
                    }
                    Text {
                        visible: root.currentMode === "SIDE_BY_SIDE" || root.currentMode === "PIP"
                        text: "|"
                        color: CompanyTheme.borderCard
                        font.pointSize: CompanyTheme.fontTiny
                    }
                    Text {
                        visible: root.currentMode !== "RGB_ONLY"
                        text: "IR HFOV: " + CompanyTelemetry.thermalHfovStr
                        color: CompanyTheme.accent
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.family: "Monospace"
                    }
                }

                // Row 3: Laser Rangefinder (LRF) & Payload Status
                RowLayout {
                    spacing: 10
                    visible: CompanyTelemetry.hasLrfDistance || (typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface && CompanyPayloadInterface.isSimulation)
                    Text {
                        text: "LRF: " + CompanyTelemetry.lrfDistanceStr
                        color: CompanyTheme.success
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.family: "Monospace"
                    }
                    Text {
                        visible: (typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface && CompanyPayloadInterface.isSimulation)
                        text: "[SIMULATION]"
                        color: CompanyTheme.warning
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.family: "Monospace"
                    }
                }
            }
        }
    }

    // ========================================================================
    // TACTICAL CAMERA CONTROLS TOOLBAR (Floating Right Edge, z: 35)
    // ========================================================================
    Rectangle {
        id: cameraControlToolbar
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: CompanyTheme.spacingMd
        z: 35
        width: 44
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgOverlayDark
        border.color: CompanyTheme.borderCard
        border.width: 1
        height: camControlsLayout.implicitHeight + 16

        ColumnLayout {
            id: camControlsLayout
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            // 1. Snapshot Button
            Rectangle {
                id: snapBtn
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: CompanyTheme.radiusSm - 1
                color: snapMouse.containsMouse ? CompanyTheme.bgCardHover : "transparent"
                border.color: snapMouse.containsMouse ? CompanyTheme.borderActive : "transparent"
                border.width: 1

                IconVector {
                    anchors.centerIn: parent
                    name: "camera"
                    size: 18
                    color: CompanyTheme.textPrimary
                }

                MouseArea {
                    id: snapMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.triggerSnapshot()
                }

                ToolTip.visible: snapMouse.containsMouse
                ToolTip.text: qsTr("Take Snapshot")
                ToolTip.delay: 400
            }

            // 2. Record / Stop Button
            Rectangle {
                id: recBtn
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: CompanyTheme.radiusSm - 1
                color: {
                    if (QGroundControl.videoManager.recording) return CompanyTheme.errorDim
                    if (recMouse.containsMouse) return CompanyTheme.bgCardHover
                    return "transparent"
                }
                border.color: QGroundControl.videoManager.recording ? CompanyTheme.error : (recMouse.containsMouse ? CompanyTheme.borderActive : "transparent")
                border.width: 1

                IconVector {
                    anchors.centerIn: parent
                    name: QGroundControl.videoManager.recording ? "stop" : "record"
                    size: 18
                    color: CompanyTheme.error
                }

                MouseArea {
                    id: recMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleRecording()
                }

                ToolTip.visible: recMouse.containsMouse
                ToolTip.text: QGroundControl.videoManager.recording ? qsTr("Stop Recording") : qsTr("Start Video Recording")
                ToolTip.delay: 400
            }

            // Divider
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 1
                Layout.alignment: Qt.AlignHCenter
                color: CompanyTheme.borderCard
            }

            // 3. Zoom In Button
            Rectangle {
                id: zoomInBtn
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: CompanyTheme.radiusSm - 1
                opacity: CompanyTelemetry.canZoom ? 1.0 : 0.4
                color: (CompanyTelemetry.canZoom && zoomInMouse.containsMouse) ? CompanyTheme.bgCardHover : "transparent"
                border.color: (CompanyTelemetry.canZoom && zoomInMouse.containsMouse) ? CompanyTheme.borderActive : "transparent"
                border.width: 1

                IconVector {
                    anchors.centerIn: parent
                    name: "plus"
                    size: 16
                    color: CompanyTelemetry.canZoom ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                }

                MouseArea {
                    id: zoomInMouse
                    anchors.fill: parent
                    enabled: CompanyTelemetry.canZoom
                    hoverEnabled: true
                    cursorShape: CompanyTelemetry.canZoom ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.stepZoom(1)
                }

                ToolTip.visible: zoomInMouse.containsMouse
                ToolTip.text: CompanyTelemetry.canZoom ? qsTr("Zoom In") : qsTr("Zoom Unavailable")
                ToolTip.delay: 400
            }

            // Zoom Level Label (if zoom supported)
            Text {
                visible: CompanyTelemetry.canZoom
                Layout.alignment: Qt.AlignHCenter
                text: CompanyTelemetry.zoomLevelStr
                color: CompanyTheme.primary
                font.pointSize: 7.5
                font.bold: true
                font.family: "Monospace"
            }

            // 4. Zoom Out Button
            Rectangle {
                id: zoomOutBtn
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: CompanyTheme.radiusSm - 1
                opacity: CompanyTelemetry.canZoom ? 1.0 : 0.4
                color: (CompanyTelemetry.canZoom && zoomOutMouse.containsMouse) ? CompanyTheme.bgCardHover : "transparent"
                border.color: (CompanyTelemetry.canZoom && zoomOutMouse.containsMouse) ? CompanyTheme.borderActive : "transparent"
                border.width: 1

                IconVector {
                    anchors.centerIn: parent
                    name: "minus"
                    size: 16
                    color: CompanyTelemetry.canZoom ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                }

                MouseArea {
                    id: zoomOutMouse
                    anchors.fill: parent
                    enabled: CompanyTelemetry.canZoom
                    hoverEnabled: true
                    cursorShape: CompanyTelemetry.canZoom ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.stepZoom(-1)
                }

                ToolTip.visible: zoomOutMouse.containsMouse
                ToolTip.text: CompanyTelemetry.canZoom ? qsTr("Zoom Out") : qsTr("Zoom Unavailable")
                ToolTip.delay: 400
            }
        }
    }

    // ========================================================================
    // CAMERA LAYOUT CONTROL TOOLBAR (Floating Top Center / Left-stacked on mobile, z: 30)
    // ========================================================================
    Rectangle {
        id: modeToolbar
        anchors.top: parent.top
        anchors.topMargin: root._isNarrow ? 48 : CompanyTheme.spacingMd
        anchors.left: root._isNarrow ? parent.left : undefined
        anchors.leftMargin: root._isNarrow ? CompanyTheme.spacingMd : 0
        anchors.horizontalCenter: root._isNarrow ? undefined : parent.horizontalCenter
        z: 30
        height: 28
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgOverlayDark
        border.color: CompanyTheme.borderCard
        border.width: 1
        implicitWidth: toolbarLayout.implicitWidth + 4

        RowLayout {
            id: toolbarLayout
            anchors.fill: parent
            anchors.margins: 2
            spacing: 2

            Repeater {
                model: [
                    { id: "RGB_ONLY",     label: qsTr("RGB") },
                    { id: "THERMAL_ONLY", label: qsTr("THERMAL") },
                    { id: "SIDE_BY_SIDE", label: qsTr("SPLIT") },
                    { id: "PIP",          label: qsTr("PIP") }
                ]

                delegate: Rectangle {
                    id: modeBtn
                    required property var modelData

                    readonly property bool isSelected: root.currentMode === modeBtn.modelData.id
                    readonly property bool isHovered: modeMouseArea.containsMouse

                    Layout.preferredWidth: root._isNarrow ? 64 : 76
                    Layout.fillHeight: true
                    radius: CompanyTheme.radiusSm - 1
                    color: {
                        if (modeBtn.isSelected) return CompanyTheme.primaryDim
                        if (modeBtn.isHovered) return CompanyTheme.bgCardHover
                        return "transparent"
                    }

                    border.color: modeBtn.isSelected ? CompanyTheme.borderActive : "transparent"
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: modeBtn.isSelected ? CompanyTheme.primary : CompanyTheme.textMuted
                        }

                        Text {
                            text: modeBtn.modelData.label
                            color: modeBtn.isSelected ? CompanyTheme.primary : (modeBtn.isHovered ? CompanyTheme.textPrimary : CompanyTheme.textSecondary)
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: modeBtn.isSelected
                            font.letterSpacing: 0.5
                        }
                    }

                    MouseArea {
                        id: modeMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentMode = modeBtn.modelData.id
                    }
                }
            }
        }
    }

    // ========================================================================
    // SHUTTER FLASH & TOAST FEEDBACK
    // ========================================================================

    // Visual Shutter Flash
    Rectangle {
        id: shutterFlash
        anchors.fill: parent
        color: "#ffffff"
        opacity: 0.0
        z: 90

        NumberAnimation on opacity {
            id: shutterFlashAnim
            from: 0.75
            to: 0.0
            duration: 180
            running: false
        }
    }

    // Operational Feedback Toast Banner
    Rectangle {
        id: toastBanner
        anchors.top: modeToolbar.bottom
        anchors.topMargin: CompanyTheme.spacingSm
        anchors.horizontalCenter: parent.horizontalCenter
        z: 95
        height: 26
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgOverlayDark
        border.color: CompanyTheme.success
        border.width: 1
        opacity: 0.0
        visible: opacity > 0
        implicitWidth: toastLayout.implicitWidth + 16

        RowLayout {
            id: toastLayout
            anchors.centerIn: parent
            spacing: 6

            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: CompanyTheme.success
            }

            Text {
                id: toastText
                text: qsTr("SNAPSHOT SAVED")
                color: CompanyTheme.textPrimary
                font.pointSize: CompanyTheme.fontTiny
                font.bold: true
                font.family: "Monospace"
            }
        }

        SequentialAnimation {
            id: toastAnim
            NumberAnimation { target: toastBanner; property: "opacity"; to: 1.0; duration: 150 }
            PauseAnimation { duration: 2500 }
            NumberAnimation { target: toastBanner; property: "opacity"; to: 0.0; duration: 300 }
        }
    }
}
