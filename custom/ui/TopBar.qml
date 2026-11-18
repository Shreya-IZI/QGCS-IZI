pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import Company.UI

Rectangle {
    id: root

    height: CompanyTheme.topBarHeight
    color: CompanyTheme.bgTopBar

    readonly property bool _hasVehicle:      CompanyTelemetry.hasVehicle
    readonly property bool _isArmed:         CompanyTelemetry.armed
    readonly property string _flightMode:    CompanyTelemetry.flightMode
    readonly property bool _isNarrow:        width < 1024 || ScreenTools.isMobile

    signal tabRequested(int tabIndex)
    signal toggleDrawerRequested()
    signal showUserGuideRequested()
    signal flightActionRequested(string actionType)
    signal safetyModalRequested()
    signal preFlightModalRequested()
    signal openJoystickSettingsRequested()

    // Bottom border separator line
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: CompanyTheme.borderCard
    }

    // Window drag and double-click maximize area (Desktop Frameless Mode)
    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: {
            if (typeof mainWindow !== "undefined" && mainWindow.startSystemMove) {
                mainWindow.startSystemMove()
            }
        }
        onDoubleClicked: {
            if (typeof mainWindow !== "undefined") {
                if (mainWindow.visibility === Window.Maximized) {
                    mainWindow.showNormal()
                } else {
                    mainWindow.showMaximized()
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root._isNarrow ? CompanyTheme.spacingSm : CompanyTheme.spacingMd
        anchors.rightMargin: root._isNarrow ? CompanyTheme.spacingSm : 0
        spacing: root._isNarrow ? CompanyTheme.spacingSm : CompanyTheme.spacingMd

        // Mobile / Narrow Drawer Toggle Button
        Rectangle {
            id: drawerToggleBtn
            visible: root._isNarrow
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: CompanyTheme.radiusSm
            color: drawerToggleMouse.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
            border.color: drawerToggleMouse.containsMouse ? CompanyTheme.borderActive : CompanyTheme.borderCard
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 3
                Rectangle { width: 14; height: 2; radius: 1; color: CompanyTheme.textPrimary }
                Rectangle { width: 14; height: 2; radius: 1; color: CompanyTheme.textPrimary }
                Rectangle { width: 14; height: 2; radius: 1; color: CompanyTheme.textPrimary }
            }

            MouseArea {
                id: drawerToggleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleDrawerRequested()
            }
        }

        // --------------------------------------------------------------------
        // 1. Brand & Logo Area ("IZI GCS" + "INTELLIGENCE | SURVEILLANCE | IMPACT")
        // --------------------------------------------------------------------
        Rectangle {
            id: brandBtn
            Layout.preferredHeight: 36
            implicitWidth: brandRow.implicitWidth + 12
            radius: CompanyTheme.radiusSm
            color: brandMouseArea.containsMouse ? CompanyTheme.bgCard : "transparent"
            border.color: brandMouseArea.containsMouse ? CompanyTheme.borderCard : "transparent"

            RowLayout {
                id: brandRow
                anchors.centerIn: parent
                spacing: CompanyTheme.spacingSm

                IziLogo {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 20
                    color: brandMouseArea.containsMouse ? CompanyTheme.textLight : CompanyTheme.textPrimary
                }

                ColumnLayout {
                    spacing: 0
                    RowLayout {
                        spacing: 4
                        Text {
                            text: "IZI GCS"
                            color: CompanyTheme.textPrimary
                            font.pointSize: CompanyTheme.fontH2
                            font.bold: true
                            font.letterSpacing: 1.0
                        }
                        Rectangle {
                            readonly property bool isTether: (typeof SafeTManager !== "undefined" && SafeTManager) || (typeof safeTManager !== "undefined" && safeTManager)
                            visible: isTether
                            height: 16
                            implicitWidth: tetherBadgeText.implicitWidth + 8
                            radius: 3
                            color: CompanyTheme.primaryDim
                            border.color: CompanyTheme.primary
                            border.width: 1
                            Text {
                                id: tetherBadgeText
                                anchors.centerIn: parent
                                text: "TETHERED"
                                color: CompanyTheme.primary
                                font.pointSize: 7
                                font.bold: true
                            }
                        }
                        IconVector {
                            name: "chevron_down"
                            size: 8
                            color: brandMouseArea.containsMouse ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                        }
                    }
                    Text {
                        visible: !root._isNarrow
                        text: ((typeof SafeTManager !== "undefined" && SafeTManager) || (typeof safeTManager !== "undefined" && safeTManager)) ? "TETHERED v0.1.0-alpha" : "FLIGHT CONTROL SYSTEM"
                        color: ((typeof SafeTManager !== "undefined" && SafeTManager) || (typeof safeTManager !== "undefined" && safeTManager)) ? CompanyTheme.primary : CompanyTheme.textSecondary
                        font.pointSize: 7
                        font.bold: true
                        font.letterSpacing: 1.2
                    }
                }
            }

            MouseArea {
                id: brandMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: iziMenuPopup.open()
            }

            ToolTip.visible: brandMouseArea.containsMouse && !iziMenuPopup.visible
            ToolTip.delay: 300
            ToolTip.text: qsTr("Click to open IZI Application Menu")
        }

        Popup {
            id: iziMenuPopup
            y: root.height + 4
            x: Math.max(8, Math.min(0, root.width - width - 8))
            width: Math.min(380, root.width - 16)
            padding: 0
            modal: true
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            // Desired natural height based on items + header (48px)
            readonly property real naturalHeight: 48 + scrollItemsCol.implicitHeight
            readonly property real maxHeight: root.parent ? Math.max(200, root.parent.height - root.height - 16) : 520
            height: Math.min(naturalHeight > 100 ? naturalHeight : 500, maxHeight)

            background: Rectangle {
                color: CompanyTheme.bgSidebar
                radius: CompanyTheme.radiusMd
                border.color: CompanyTheme.borderCard
                border.width: 1
                clip: true
            }

            contentItem: Item {
                implicitHeight: iziMenuPopup.height
                clip: true

                ColumnLayout {
                    id: popupContentCol
                    anchors.fill: parent
                    spacing: 0

                    // Pinned Header
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        color: CompanyTheme.bgCard
                        radius: CompanyTheme.radiusMd

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: CompanyTheme.spacingMd
                            anchors.rightMargin: CompanyTheme.spacingMd
                            spacing: CompanyTheme.spacingSm

                            IziLogo {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 21
                                color: CompanyTheme.textLight
                            }

                            ColumnLayout {
                                spacing: 1
                                Text {
                                    text: qsTr("IZI Enterprise GCS")
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: CompanyTheme.fontH2
                                    font.bold: true
                                }
                                Text {
                                    text: root._hasVehicle ? qsTr("Connected: UAS #1 • Cube Orange") : qsTr("Standby • No Vehicle Link")
                                    color: root._hasVehicle ? CompanyTheme.success : CompanyTheme.textMuted
                                    font.pointSize: 8
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.preferredHeight: 20
                                implicitWidth: verText.implicitWidth + 10
                                radius: 3
                                color: CompanyTheme.primaryDim
                                Text {
                                    id: verText
                                    anchors.centerIn: parent
                                    text: ((typeof SafeTManager !== "undefined" && SafeTManager) || (typeof safeTManager !== "undefined" && safeTManager)) ? "v0.1.0-alpha" : "v5.0.3"
                                    color: CompanyTheme.primary
                                    font.pointSize: 8
                                    font.bold: true
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: CompanyTheme.borderCard
                    }

                    // Vertically Scrollable Content (Flickable + ScrollBar)
                    Flickable {
                        id: menuScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: scrollItemsCol.implicitHeight
                        implicitHeight: scrollItemsCol.implicitHeight
                        contentWidth: width
                        contentHeight: scrollItemsCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            id: menuScrollBar
                            policy: menuScroll.contentHeight > menuScroll.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                            active: menuScroll.moving || menuScroll.flicking
                        }

                        ColumnLayout {
                            id: scrollItemsCol
                            width: menuScroll.width
                            spacing: 0

                            // Navigation Items
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.margins: 8
                                spacing: 4

                                Repeater {
                                    model: [
                                        { id: 1, title: qsTr("Flight Operations"), desc: qsTr("Tactical map, PFD HUD & camera feeds"), icon: "flight" },
                                        { id: 2, title: qsTr("Mission Planner"), desc: qsTr("Autonomous waypoints, surveys & geofences"), icon: "missions" },
                                        { id: 6, title: qsTr("Vehicle Parameters"), desc: qsTr("Cube Orange MAVLink parameter database & tuning"), icon: "params" },
                                        { id: 7, title: qsTr("Vehicle Setup"), desc: qsTr("Sensors, Radio, Flight Modes & Calibration"), icon: "setup" },
                                        { id: 3, title: qsTr("Fleet & Swarm"), desc: qsTr("Multi-UAS tracking & asset management"), icon: "fleet" },
                                        { id: 4, title: qsTr("Flight Logs"), desc: qsTr("Dataflash logs, telemetry replay & analysis"), icon: "logs" },
                                        { id: 5, title: qsTr("System Settings"), desc: qsTr("Comm links, units & application config"), icon: "settings" }
                                    ]

                                    delegate: Rectangle {
                                        id: menuItem
                                        required property var modelData

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        radius: CompanyTheme.radiusSm
                                        color: menuMouseArea.containsMouse ? CompanyTheme.bgCardHover : "transparent"
                                        border.color: menuMouseArea.containsMouse ? CompanyTheme.borderActive : "transparent"
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: CompanyTheme.spacingSm

                                            Rectangle {
                                                Layout.preferredWidth: 26
                                                Layout.preferredHeight: 26
                                                radius: 4
                                                color: menuItem.modelData.id === 6 ? Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.15) : CompanyTheme.bgCard

                                                IconVector {
                                                    anchors.centerIn: parent
                                                    name: menuItem.modelData.icon
                                                    size: 14
                                                    color: menuItem.modelData.id === 6 ? CompanyTheme.warning : CompanyTheme.primary
                                                }
                                            }

                                            ColumnLayout {
                                                spacing: 0
                                                Layout.fillWidth: true

                                                Text {
                                                    text: menuItem.modelData.title
                                                    color: CompanyTheme.textPrimary
                                                    font.pointSize: CompanyTheme.fontSmall
                                                    font.bold: true
                                                }
                                                Text {
                                                    text: menuItem.modelData.desc
                                                    color: CompanyTheme.textSecondary
                                                    font.pointSize: 7
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: menuMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                iziMenuPopup.close()
                                                root.tabRequested(menuItem.modelData.id)
                                            }
                                        }
                                    }
                                }

                                // Field User Guide & Walkthrough
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    radius: CompanyTheme.radiusSm
                                    color: guideMouseArea.containsMouse ? CompanyTheme.bgCardHover : "transparent"
                                    border.color: guideMouseArea.containsMouse ? CompanyTheme.borderActive : "transparent"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: CompanyTheme.spacingSm

                                        Rectangle {
                                            Layout.preferredWidth: 26
                                            Layout.preferredHeight: 26
                                            radius: 4
                                            color: CompanyTheme.bgCard

                                            IconVector {
                                                anchors.centerIn: parent
                                                name: "dashboard"
                                                size: 14
                                                color: CompanyTheme.primary
                                            }
                                        }

                                        ColumnLayout {
                                            spacing: 0
                                            Layout.fillWidth: true

                                            Text {
                                                text: qsTr("User Guide & Walkthrough")
                                                color: CompanyTheme.textPrimary
                                                font.pointSize: CompanyTheme.fontSmall
                                                font.bold: true
                                            }
                                            Text {
                                                text: qsTr("Step-by-step interactive field operator guide")
                                                color: CompanyTheme.textSecondary
                                                font.pointSize: 7
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: guideMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            iziMenuPopup.close()
                                            root.showUserGuideRequested()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: CompanyTheme.borderCard
                            }

                            // Quick Actions Footer (Reboot vehicle, dismiss)
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                Layout.leftMargin: 12
                                Layout.rightMargin: 12
                                spacing: 8

                                Text {
                                    text: root._hasVehicle ? qsTr("MAVLink v2.0 • Online") : qsTr("Autopilot: Disconnected")
                                    color: CompanyTheme.textMuted
                                    font.pointSize: 8
                                    Layout.fillWidth: true
                                }

                                Button {
                                    visible: root._hasVehicle
                                    text: qsTr("Reboot FC")
                                    contentItem: Text {
                                        text: parent.text
                                        color: CompanyTheme.danger
                                        font.pointSize: 8
                                        font.bold: true
                                    }
                                    background: Rectangle {
                                        radius: 3
                                        color: parent.hovered ? CompanyTheme.bgCardHover : "transparent"
                                    }
                                    onClicked: {
                                        iziMenuPopup.close()
                                        if (typeof mainWindow !== "undefined" && mainWindow._showRebootVehicleDialog) {
                                            mainWindow._showRebootVehicleDialog(qsTr("Reboot Autopilot"), qsTr("Are you sure you want to reboot the Cube Orange flight controller?"))
                                        }
                                    }
                                }

                                Button {
                                    text: qsTr("Exit GCS")
                                    contentItem: RowLayout {
                                        spacing: 4
                                        IconVector {
                                            name: "power"
                                            size: 11
                                            color: CompanyTheme.danger
                                        }
                                        Text {
                                            text: qsTr("Exit")
                                            color: CompanyTheme.danger
                                            font.pointSize: 8
                                            font.bold: true
                                        }
                                    }
                                    background: Rectangle {
                                        radius: 3
                                        color: parent.hovered ? CompanyTheme.dangerDim : "transparent"
                                        border.color: parent.hovered ? CompanyTheme.danger : "transparent"
                                        border.width: 1
                                    }
                                    onClicked: {
                                        iziMenuPopup.close()
                                        if (typeof mainWindow !== "undefined" && mainWindow.finishCloseProcess) {
                                            mainWindow.finishCloseProcess()
                                        } else {
                                            Qt.quit()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Vertical divider
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 22
            color: CompanyTheme.borderCard
        }

        // --------------------------------------------------------------------
        // 2. Center: Enterprise Flight Control with Status Breadcrumb
        // --------------------------------------------------------------------
        RowLayout {
            spacing: CompanyTheme.spacingSm

            ColumnLayout {
                spacing: 2

                Text {
                    visible: !root._isNarrow
                    text: qsTr("ENTERPRISE FLIGHT CONTROL")
                    color: CompanyTheme.textSecondary
                    font.pointSize: CompanyTheme.fontTiny
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                RowLayout {
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: {
                            if (!root._hasVehicle) return CompanyTheme.warning
                            if (root._isArmed) return CompanyTheme.danger
                            return CompanyTheme.success
                        }
                    }

                    Text {
                        text: {
                            if (!root._hasVehicle) return qsTr("STANDBY • NO VEHICLE")
                            var idStr = qsTr("UAS #%1").arg(CompanyTelemetry.vehicleId)
                            var armStr = root._isArmed ? qsTr("ARMED") : qsTr("DISARMED")
                            var modeStr = root._flightMode !== "" ? root._flightMode.toUpperCase() : "HOLD"
                            var result = idStr + " • " + armStr + " • " + modeStr
                            if (CompanyTelemetry.altitudeRelativeStr !== "--") {
                                result += " • ALT " + CompanyTelemetry.altitudeRelativeStr
                            }
                            return result
                        }
                        color: CompanyTheme.textPrimary
                        font.pointSize: 11
                        font.family: CompanyTheme.fontMono
                        font.bold: true
                    }
                }
            }
        }

        // Emergency Motor Kill (E-STOP) Button — Prominently visible when vehicle is Armed
        Rectangle {
            id: topBarEstopBtn
            visible: root._hasVehicle && root._isArmed
            Layout.preferredHeight: 28
            implicitWidth: estopRow.implicitWidth + 18
            radius: CompanyTheme.radiusSm
            color: topBarEstopMouse.containsMouse ? Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.35) : Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.18)
            border.color: CompanyTheme.danger
            border.width: 1.5

            RowLayout {
                id: estopRow
                anchors.centerIn: parent
                spacing: 5

                IconVector {
                    name: "alert-triangle"
                    size: 13
                    color: CompanyTheme.danger
                }

                Text {
                    text: qsTr("E-STOP")
                    color: CompanyTheme.danger
                    font.pointSize: 10
                    font.bold: true
                    font.letterSpacing: 0.8
                }
            }

            MouseArea {
                id: topBarEstopMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.flightActionRequested("EMERGENCY_STOP")
            }

            ToolTip.visible: topBarEstopMouse.containsMouse
            ToolTip.delay: 200
            ToolTip.text: qsTr("CRITICAL SAFETY: Click to trigger Emergency Motor Kill for UAS #%1 (Requires confirmation)").arg(CompanyTelemetry.vehicleId)
        }

        // Expanding spacer
        Item {
            Layout.fillWidth: true
        }

        // --------------------------------------------------------------------
        // 3. Operational Indicators: GPS, Battery (mAh), RSSI/Link, UTC
        // --------------------------------------------------------------------
        RowLayout {
            spacing: root._isNarrow ? CompanyTheme.spacingXs : CompanyTheme.spacingSm

            // 3A. GPS Satellite, RTK & Precision Chip
            Rectangle {
                id: gpsChip
                Layout.preferredHeight: 28
                implicitWidth: gpsChipRow.implicitWidth + 16
                radius: CompanyTheme.radiusSm
                color: CompanyTelemetry.isRtkFixed ? Qt.rgba(CompanyTheme.info.r, CompanyTheme.info.g, CompanyTheme.info.b, 0.15) : CompanyTheme.bgCardSecondary
                border.color: {
                    if (!root._hasVehicle) return CompanyTheme.borderCard
                    if (CompanyTelemetry.isRtkFixed) return CompanyTheme.info
                    if (CompanyTelemetry.isRtkFloat) return CompanyTheme.primary
                    if (CompanyTelemetry.gpsLock >= 3) return CompanyTheme.borderCard
                    if (CompanyTelemetry.gpsLock >= 2) return CompanyTheme.warning
                    return CompanyTheme.danger
                }
                border.width: CompanyTelemetry.isRtkActive ? 1.5 : 1

                RowLayout {
                    id: gpsChipRow
                    anchors.centerIn: parent
                    spacing: 5

                    IconVector {
                        name: "satellite"
                        size: 14
                        color: {
                            if (!root._hasVehicle) return CompanyTheme.textMuted
                            if (CompanyTelemetry.isRtkFixed) return CompanyTheme.info
                            if (CompanyTelemetry.isRtkFloat) return CompanyTheme.primary
                            if (CompanyTelemetry.gpsLock >= 3) return CompanyTheme.success
                            if (CompanyTelemetry.gpsLock >= 2) return CompanyTheme.warning
                            return CompanyTheme.danger
                        }
                    }

                    Text {
                        text: {
                            if (!root._hasVehicle) return qsTr("GPS --")
                            var sats = CompanyTelemetry.gpsSatellites + " Sats"
                            var lock = CompanyTelemetry.gpsFixType
                            if (CompanyTelemetry.isRtkFixed) return sats + " • RTK FIX"
                            if (CompanyTelemetry.isRtkFloat) return sats + " • RTK FLT"
                            if (CompanyTelemetry.gpsHdopStr !== "--" && !root._isNarrow) {
                                return sats + " • " + lock + " (H:" + CompanyTelemetry.gpsHdopStr + ")"
                            }
                            return sats + " • " + lock
                        }
                        color: {
                            if (!root._hasVehicle) return CompanyTheme.textMuted
                            if (CompanyTelemetry.isRtkFixed) return CompanyTheme.info
                            if (CompanyTelemetry.isRtkFloat) return CompanyTheme.primary
                            if (CompanyTelemetry.gpsLock >= 3) return CompanyTheme.textPrimary
                            if (CompanyTelemetry.gpsLock >= 2) return CompanyTheme.warning
                            return CompanyTheme.danger
                        }
                        font.pointSize: 11
                        font.family: CompanyTheme.fontMono
                        font.bold: true
                    }
                }

                ToolTip.visible: gpsMouseArea.containsMouse
                ToolTip.delay: 300
                ToolTip.text: {
                    if (!root._hasVehicle) return qsTr("GPS: Disconnected")
                    var info = [
                        qsTr("GNSS Positioning: %1").arg(CompanyTelemetry.gpsFixType),
                        qsTr("Satellites Tracked: %1").arg(CompanyTelemetry.gpsSatellites)
                    ]
                    if (CompanyTelemetry.gpsHdopStr !== "--") {
                        info.push(qsTr("Precision: HDOP %1 • VDOP %2").arg(CompanyTelemetry.gpsHdopStr).arg(CompanyTelemetry.gpsVdopStr))
                    }
                    if (CompanyTelemetry.hasRtkBase) {
                        info.push(qsTr("RTK Base Station: CONNECTED"))
                        if (CompanyTelemetry.isRtkBaseSurveying) {
                            info.push(qsTr("Base Survey-In: Active (%1s • Acc: %2)").arg(CompanyTelemetry.rtkBaseDuration).arg(CompanyTelemetry.rtkBaseAccuracyStr))
                        } else if (CompanyTelemetry.isRtkBaseValid) {
                            info.push(qsTr("Base Survey-In: VALID (Acc: %1)").arg(CompanyTelemetry.rtkBaseAccuracyStr))
                        }
                    }
                    info.push(qsTr("Aircraft Position: %1").arg(CompanyTelemetry.coordString))
                    return info.join("\n")
                }

                MouseArea {
                    id: gpsMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }

            // 3B. Battery & Power Monitoring Chip (V, %, A, mAh consumed)
            Rectangle {
                id: batChip
                Layout.preferredHeight: 28
                implicitWidth: batChipRow.implicitWidth + 16
                radius: CompanyTheme.radiusSm
                color: CompanyTheme.bgCardSecondary
                border.color: {
                    if (!CompanyTelemetry.hasBattery) return CompanyTheme.borderCard
                    if (CompanyTelemetry.isCriticalEndurance) return CompanyTheme.danger
                    if (CompanyTelemetry.isLowEndurance) return CompanyTheme.warning
                    var pct = CompanyTelemetry.batteryPercent
                    if (pct <= 15) return CompanyTheme.danger
                    if (pct <= 25) return CompanyTheme.warning
                    return CompanyTheme.borderCard
                }
                border.width: 1

                RowLayout {
                    id: batChipRow
                    anchors.centerIn: parent
                    spacing: 6

                    IconVector {
                        name: "battery"
                        size: 14
                        color: {
                            if (!CompanyTelemetry.hasBattery) return CompanyTheme.textMuted
                            if (CompanyTelemetry.isCriticalEndurance) return CompanyTheme.danger
                            if (CompanyTelemetry.isLowEndurance) return CompanyTheme.warning
                            var pct = CompanyTelemetry.batteryPercent
                            if (pct > 25) return CompanyTheme.success
                            if (pct > 15) return CompanyTheme.warning
                            return CompanyTheme.danger
                        }
                    }

                    // Remaining percentage
                    Text {
                        text: CompanyTelemetry.batteryPercentStr
                        color: {
                            if (!CompanyTelemetry.hasBattery) return CompanyTheme.textMuted
                            if (CompanyTelemetry.isCriticalEndurance) return CompanyTheme.danger
                            if (CompanyTelemetry.isLowEndurance) return CompanyTheme.warning
                            var pct = CompanyTelemetry.batteryPercent
                            if (pct > 25) return CompanyTheme.success
                            if (pct > 15) return CompanyTheme.warning
                            return CompanyTheme.danger
                        }
                        font.pointSize: 11
                        font.family: CompanyTheme.fontMono
                        font.bold: true
                    }

                    // Voltage
                    Text {
                        visible: !isNaN(CompanyTelemetry.batteryVoltage)
                        text: "• " + CompanyTelemetry.batteryVoltageStr
                        color: CompanyTheme.textPrimary
                        font.pointSize: 11
                        font.family: CompanyTheme.fontMono
                        font.bold: true
                    }

                    // Current draw (amps)
                    Text {
                        visible: !root._isNarrow && !isNaN(CompanyTelemetry.batteryCurrent) && CompanyTelemetry.batteryCurrent > 0.05
                        text: "• " + CompanyTelemetry.batteryCurrentStr
                        color: CompanyTheme.textSecondary
                        font.pointSize: 10
                        font.family: CompanyTheme.fontMono
                    }

                    // Consumed Capacity (mAh)
                    Text {
                        visible: !root._isNarrow && CompanyTelemetry.hasBatteryConsumed
                        text: "• " + CompanyTelemetry.batteryConsumedMahStr
                        color: CompanyTheme.info
                        font.pointSize: 10
                        font.family: CompanyTheme.fontMono
                        font.bold: true
                    }

                    // Remaining Flight Time (Endurance)
                    Text {
                        visible: !root._isNarrow && CompanyTelemetry.hasBatteryTimeRemaining
                        text: "• " + CompanyTelemetry.batteryEnduranceShortStr
                        color: CompanyTelemetry.isCriticalEndurance ? CompanyTheme.danger : (CompanyTelemetry.isLowEndurance ? CompanyTheme.warning : CompanyTheme.success)
                        font.pointSize: 10
                        font.family: CompanyTheme.fontMono
                        font.bold: true
                    }
                }

                ToolTip.visible: batMouseArea.containsMouse
                ToolTip.delay: 300
                ToolTip.text: {
                    if (!CompanyTelemetry.hasBattery) return qsTr("Battery: No Telemetry")
                    var lines = [
                        qsTr("Remaining: %1").arg(CompanyTelemetry.batteryPercentStr),
                        qsTr("Voltage: %1").arg(CompanyTelemetry.batteryVoltageStr),
                        qsTr("Current Draw: %1").arg(!isNaN(CompanyTelemetry.batteryCurrent) ? CompanyTelemetry.batteryCurrentStr : "N/A"),
                        qsTr("Consumed: %1").arg(CompanyTelemetry.hasBatteryConsumed ? CompanyTelemetry.batteryConsumedMahStr : "N/A"),
                        qsTr("Estimated Endurance: %1").arg(CompanyTelemetry.hasBatteryTimeRemaining ? CompanyTelemetry.batteryTimeRemainingStr : "Calculating..."),
                        qsTr("Pack Temperature: %1").arg(CompanyTelemetry.hasBatteryTemperature ? CompanyTelemetry.batteryTemperatureStr : "N/A")
                    ]
                    return lines.join("\n")
                }

                MouseArea {
                    id: batMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }

            // 3T. SAFE-T Tether Power & Tension Chip (Tethered GCS Mode Only)
            Rectangle {
                id: tetherChip
                readonly property var _tether: (typeof SafeTManager !== "undefined" && SafeTManager) ? SafeTManager : (typeof safeTManager !== "undefined" ? safeTManager : null)
                visible: _tether !== null && _tether.isConnected
                Layout.preferredHeight: 28
                implicitWidth: tetherChipRow.implicitWidth + 16
                radius: CompanyTheme.radiusSm
                color: CompanyTheme.bgCardSecondary
                border.color: {
                    if (!_tether) return CompanyTheme.borderCard
                    if (_tether.highTensionAlarm || _tether.powerCutoffAlarm) return CompanyTheme.danger
                    if (_tether.isStale || _tether.lengthLimitAlarm) return CompanyTheme.warning
                    return CompanyTheme.borderCard
                }
                border.width: (_tether && (_tether.highTensionAlarm || _tether.powerCutoffAlarm || _tether.isStale)) ? 1.5 : 1

                RowLayout {
                    id: tetherChipRow
                    anchors.centerIn: parent
                    spacing: 6

                    IconVector {
                        name: "activity"
                        size: 13
                        color: {
                            if (!tetherChip._tether) return CompanyTheme.textMuted
                            if (tetherChip._tether.highTensionAlarm || tetherChip._tether.powerCutoffAlarm) return CompanyTheme.danger
                            if (tetherChip._tether.isStale) return CompanyTheme.warning
                            return CompanyTheme.primary
                        }
                    }

                    Text {
                        text: qsTr("TETHER")
                        color: CompanyTheme.textSecondary
                        font.pointSize: 9
                        font.bold: true
                    }

                    Text {
                        text: tetherChip._tether ? (tetherChip._tether.tensionN.toFixed(1) + " N") : "-- N"
                        color: (tetherChip._tether && tetherChip._tether.highTensionAlarm) ? CompanyTheme.danger : CompanyTheme.textPrimary
                        font.pointSize: 10
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }

                    Text {
                        visible: !root._isNarrow && tetherChip._tether
                        text: "• " + (tetherChip._tether ? (tetherChip._tether.tetherLengthM.toFixed(0) + "m") : "")
                        color: CompanyTheme.primary
                        font.pointSize: 10
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }

                    Text {
                        visible: !root._isNarrow && tetherChip._tether
                        text: "• " + (tetherChip._tether ? (tetherChip._tether.stationVoltageV.toFixed(0) + "V") : "")
                        color: (tetherChip._tether && tetherChip._tether.powerCutoffAlarm) ? CompanyTheme.danger : CompanyTheme.textPrimary
                        font.pointSize: 10
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }
                }

                ToolTip.visible: tetherMouseArea.containsMouse
                ToolTip.delay: 300
                ToolTip.text: {
                    if (!_tether) return qsTr("Tether: Disconnected")
                    var lines = [
                        qsTr("Tether Station: %1").arg(_tether.connectionStatus),
                        qsTr("Line Tension: %1 N").arg(_tether.tensionN.toFixed(1)),
                        qsTr("Deployed Length: %1 m").arg(_tether.tetherLengthM.toFixed(1)),
                        qsTr("Station Bus: %1 V • %2 A").arg(_tether.stationVoltageV.toFixed(1)).arg(_tether.stationCurrentA.toFixed(1)),
                        qsTr("Drum Temp: %1 °C").arg(_tether.drumTempC.toFixed(1)),
                        qsTr("Winch State: %1").arg(_tether.winchStatus)
                    ]
                    return lines.join("\n")
                }

                MouseArea {
                    id: tetherMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }

            // 3C. RSSI & Communication Link Chip
            Rectangle {
                id: rssiChip
                Layout.preferredHeight: 28
                implicitWidth: rssiChipRow.implicitWidth + 16
                radius: CompanyTheme.radiusSm
                color: {
                    if (CompanyTelemetry.communicationLost) return Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.2)
                    return CompanyTheme.bgCardSecondary
                }
                border.color: {
                    if (!root._hasVehicle) return CompanyTheme.borderCard
                    if (CompanyTelemetry.isSignalCritical) return CompanyTheme.danger
                    if (CompanyTelemetry.isSignalWeak) return CompanyTheme.warning
                    return CompanyTheme.borderCard
                }
                border.width: 1

                RowLayout {
                    id: rssiChipRow
                    anchors.centerIn: parent
                    spacing: 5

                    IconVector {
                        name: "signal"
                        size: 14
                        color: {
                            if (!root._hasVehicle) return CompanyTheme.textMuted
                            if (CompanyTelemetry.isSignalCritical) return CompanyTheme.danger
                            if (CompanyTelemetry.isSignalWeak) return CompanyTheme.warning
                            return CompanyTheme.success
                        }
                    }

                    // Main readout: "RSSI -68 dBm" or "LINK LOST" or "LINK 100%"
                    Text {
                        text: {
                            if (!root._hasVehicle) return qsTr("LINK --")
                            if (CompanyTelemetry.communicationLost) return qsTr("LINK LOST")
                            if (CompanyTelemetry.hasRadioStatus) {
                                return qsTr("RSSI %1").arg(CompanyTelemetry.radioLrssiStr)
                            }
                            if (CompanyTelemetry.hasRcRSSI) {
                                return qsTr("RC %1").arg(CompanyTelemetry.rcRSSIStr)
                            }
                            return qsTr("LINK %1%").arg(CompanyTelemetry.linkQualityPercent)
                        }
                        color: {
                            if (!root._hasVehicle) return CompanyTheme.textMuted
                            if (CompanyTelemetry.isSignalCritical) return CompanyTheme.danger
                            if (CompanyTelemetry.isSignalWeak) return CompanyTheme.warning
                            return CompanyTheme.textPrimary
                        }
                        font.pointSize: 11
                        font.family: CompanyTheme.fontMono
                        font.bold: true
                    }

                    // Secondary Link Quality readout when RSSI is showing
                    Text {
                        visible: !root._isNarrow && root._hasVehicle && !CompanyTelemetry.communicationLost && CompanyTelemetry.hasRadioStatus
                        text: "• " + CompanyTelemetry.linkQualityPercent + "%"
                        color: CompanyTelemetry.linkQualityPercent > 80 ? CompanyTheme.success : (CompanyTelemetry.linkQualityPercent > 50 ? CompanyTheme.warning : CompanyTheme.danger)
                        font.pointSize: 10
                        font.family: CompanyTheme.fontMono
                        font.bold: true
                    }
                }

                ToolTip.visible: rssiMouseArea.containsMouse
                ToolTip.delay: 300
                ToolTip.text: {
                    if (!root._hasVehicle) return qsTr("Communication Link: Disconnected")
                    if (CompanyTelemetry.communicationLost) return qsTr("WARNING: MAVLink Telemetry Link Lost!")
                    var info = [
                        qsTr("Link Quality: %1%").arg(CompanyTelemetry.linkQualityPercent),
                        qsTr("Loss Rate: %1%").arg(Math.round(CompanyTelemetry.mavlinkLossPercent))
                    ]
                    if (CompanyTelemetry.hasRadioStatus) {
                        info.push(qsTr("Local Radio RSSI: %1").arg(CompanyTelemetry.radioLrssiStr))
                        if (!isNaN(CompanyTelemetry.radioRrssi)) {
                            info.push(qsTr("Remote Radio RSSI: %1").arg(CompanyTelemetry.radioRrssiStr))
                        }
                    }
                    if (CompanyTelemetry.hasRcRSSI) {
                        info.push(qsTr("RC Controller RSSI: %1").arg(CompanyTelemetry.rcRSSIStr))
                    }
                    if (root._linkMgr && root._linkMgr.primaryLinkName) {
                        info.push(qsTr("Primary Link: %1").arg(root._linkMgr.primaryLinkName))
                    }
                    return info.join("\n")
                }

                MouseArea {
                    id: rssiMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }

            // 3J. Joystick & RC Transmitter Status Chip
            Rectangle {
                id: joystickChip
                readonly property var _activeJoystick: (typeof joystickManager !== "undefined" && joystickManager) ? joystickManager.activeJoystick : null
                readonly property bool _hasJoystick: _activeJoystick !== null
                readonly property bool _isEnabled: _hasJoystick && (typeof joystickManager !== "undefined") && joystickManager.activeJoystickEnabledForActiveVehicle
                readonly property bool _isCalibrated: _hasJoystick && _activeJoystick.settings && _activeJoystick.settings.calibrated ? _activeJoystick.settings.calibrated.rawValue : false

                Layout.preferredHeight: 28
                implicitWidth: joystickChipRow.implicitWidth + 16
                radius: CompanyTheme.radiusSm
                color: {
                    if (!_hasJoystick) return CompanyTheme.bgCardSecondary
                    if (_isEnabled) return Qt.rgba(CompanyTheme.success.r, CompanyTheme.success.g, CompanyTheme.success.b, 0.2)
                    return Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.2)
                }
                border.color: {
                    if (!_hasJoystick) return CompanyTheme.borderCard
                    if (_isEnabled) return CompanyTheme.success
                    return CompanyTheme.warning
                }
                border.width: (_hasJoystick && _isEnabled) ? 1.5 : 1

                RowLayout {
                    id: joystickChipRow
                    anchors.centerIn: parent
                    spacing: 5

                    IconVector {
                        name: "joystick"
                        size: 13
                        color: {
                            if (!joystickChip._hasJoystick) return CompanyTheme.textMuted
                            if (joystickChip._isEnabled) return CompanyTheme.success
                            return CompanyTheme.warning
                        }
                    }

                    Text {
                        text: {
                            if (!joystickChip._hasJoystick) return qsTr("RC: NONE")
                            if (joystickChip._isEnabled) return qsTr("RC: ACTIVE")
                            if (!joystickChip._isCalibrated) return qsTr("RC: UNCAL")
                            return qsTr("RC: OFF")
                        }
                        color: {
                            if (!joystickChip._hasJoystick) return CompanyTheme.textMuted
                            if (joystickChip._isEnabled) return CompanyTheme.success
                            return CompanyTheme.warning
                        }
                        font.pointSize: 10
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }
                }

                MouseArea {
                    id: joystickChipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (joystickQuickPopup.visible) {
                            joystickQuickPopup.close()
                        } else {
                            joystickQuickPopup.open()
                        }
                    }
                }

                ToolTip.visible: joystickChipMouse.containsMouse && !joystickQuickPopup.visible
                ToolTip.delay: 300
                ToolTip.text: {
                    if (!joystickChip._hasJoystick) {
                        return qsTr("No Joystick / Gamepad Detected\nConnect a USB controller or configure Skydroid HID mode.")
                    }
                    var lines = [
                        qsTr("Controller: %1").arg(joystickChip._activeJoystick.name),
                        qsTr("Status: %1").arg(joystickChip._isEnabled ? qsTr("ENABLED for vehicle") : qsTr("DISABLED (Click to enable)")),
                        qsTr("Calibration: %1").arg(joystickChip._isCalibrated ? qsTr("Calibrated") : qsTr("Requires Calibration")),
                        qsTr("Axes: %1 • Buttons: %2").arg(joystickChip._activeJoystick.axisCount).arg(joystickChip._activeJoystick.buttonCount),
                        qsTr("Click to open quick control & live monitor")
                    ]
                    return lines.join("\n")
                }
            }

            // Divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 16
                color: CompanyTheme.borderCard
            }

            // UTC Clock
            RowLayout {
                spacing: 4
                visible: !root._isNarrow
                Text {
                    text: "UTC"
                    color: CompanyTheme.textMuted
                    font.pointSize: CompanyTheme.fontTiny
                    font.bold: true
                }
                Text {
                    id: clockText
                    color: CompanyTheme.textPrimary
                    font.pointSize: 10
                    font.bold: true
                    font.family: CompanyTheme.fontMono

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: {
                            var now = new Date()
                            clockText.text = Qt.formatDateTime(now, "hh:mm:ss")
                        }
                    }
                }
            }

            // Voice Annunciator Audio Mute Toggle Button
            Rectangle {
                id: audioMuteBtn
                Layout.preferredHeight: 28
                implicitWidth: 32
                radius: CompanyTheme.radiusSm
                color: CompanyTelemetry.voiceMuted ? Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.15) : CompanyTheme.bgCardSecondary
                border.color: CompanyTelemetry.voiceMuted ? CompanyTheme.warning : CompanyTheme.borderCard
                border.width: 1

                IconVector {
                    anchors.centerIn: parent
                    name: CompanyTelemetry.voiceMuted ? "volume-x" : "volume-2"
                    size: 14
                    color: CompanyTelemetry.voiceMuted ? CompanyTheme.warning : CompanyTheme.textPrimary
                }

                MouseArea {
                    id: audioMuteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CompanyTelemetry.toggleVoiceMute()
                }

                ToolTip.visible: audioMuteMouse.containsMouse
                ToolTip.delay: 300
                ToolTip.text: CompanyTelemetry.voiceMuted ? qsTr("Voice Annunciator: MUTED\nClick to unmute spoken alerts") : qsTr("Voice Annunciator: ACTIVE\nClick to mute spoken alerts")
            }

            // Safety Failsafes Dashboard Button
            Rectangle {
                id: safetyDashboardBtn
                Layout.preferredHeight: 28
                implicitWidth: 32
                radius: CompanyTheme.radiusSm
                color: safetyHover.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCardSecondary
                border.color: CompanyTheme.borderCard
                border.width: 1

                IconVector {
                    anchors.centerIn: parent
                    name: "shield"
                    size: 14
                    color: CompanyTheme.info
                }

                MouseArea {
                    id: safetyHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.safetyModalRequested()
                }

                ToolTip.visible: safetyHover.containsMouse
                ToolTip.delay: 300
                ToolTip.text: qsTr("Flight Safety & Failsafes Dashboard\nClick to inspect RC, Telemetry, Battery, and Geofence failsafes")
            }

            // Vehicle Warning & Messages Indicator Button
            Rectangle {
                id: warningMsgBtn
                readonly property bool _hasTetherCritical: tetherChip._tether && (tetherChip._tether.highTensionAlarm || tetherChip._tether.powerCutoffAlarm)
                readonly property bool _hasTetherWarning: tetherChip._tether && tetherChip._tether.lengthLimitAlarm
                Layout.preferredHeight: 28
                implicitWidth: warningMsgRow.implicitWidth + 14
                radius: CompanyTheme.radiusSm
                color: {
                    if (_hasTetherCritical || CompanyTelemetry.errorCount > 0 || (CompanyTelemetry.hasVehicle && CompanyTelemetry.activeVehicle.messageTypeError)) {
                        return Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.25)
                    }
                    if (_hasTetherWarning || CompanyTelemetry.warningCount > 0 || (CompanyTelemetry.hasVehicle && CompanyTelemetry.activeVehicle.messageTypeWarning)) {
                        return Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.2)
                    }
                    return warningMsgHover.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCardSecondary
                }
                border.color: {
                    if (_hasTetherCritical || CompanyTelemetry.errorCount > 0 || (CompanyTelemetry.hasVehicle && CompanyTelemetry.activeVehicle.messageTypeError)) {
                        return CompanyTheme.danger
                    }
                    if (_hasTetherWarning || CompanyTelemetry.warningCount > 0 || (CompanyTelemetry.hasVehicle && CompanyTelemetry.activeVehicle.messageTypeWarning)) {
                        return CompanyTheme.warning
                    }
                    return CompanyTheme.borderCard
                }
                border.width: (_hasTetherCritical || _hasTetherWarning || CompanyTelemetry.errorCount > 0 || CompanyTelemetry.warningCount > 0) ? 1.5 : 1

                RowLayout {
                    id: warningMsgRow
                    anchors.centerIn: parent
                    spacing: 5

                    IconVector {
                        name: "alert-triangle"
                        size: 13
                        color: {
                            if (warningMsgBtn._hasTetherCritical || CompanyTelemetry.errorCount > 0 || (CompanyTelemetry.hasVehicle && CompanyTelemetry.activeVehicle.messageTypeError)) {
                                return CompanyTheme.danger
                            }
                            if (warningMsgBtn._hasTetherWarning || CompanyTelemetry.warningCount > 0 || (CompanyTelemetry.hasVehicle && CompanyTelemetry.activeVehicle.messageTypeWarning)) {
                                return CompanyTheme.warning
                            }
                            return CompanyTheme.textSecondary
                        }
                    }

                    Text {
                        text: {
                            var tetherAlertCount = (warningMsgBtn._hasTetherCritical || warningMsgBtn._hasTetherWarning) ? 1 : 0
                            var total = CompanyTelemetry.errorCount + CompanyTelemetry.warningCount + tetherAlertCount
                            if (total > 0) return qsTr("ALERTS (%1)").arg(total)
                            return qsTr("MESSAGES")
                        }
                        color: {
                            if (warningMsgBtn._hasTetherCritical || CompanyTelemetry.errorCount > 0 || (CompanyTelemetry.hasVehicle && CompanyTelemetry.activeVehicle.messageTypeError)) {
                                return CompanyTheme.danger
                            }
                            if (warningMsgBtn._hasTetherWarning || CompanyTelemetry.warningCount > 0 || (CompanyTelemetry.hasVehicle && CompanyTelemetry.activeVehicle.messageTypeWarning)) {
                                return CompanyTheme.warning
                            }
                            return CompanyTheme.textSecondary
                        }
                        font.pointSize: 10
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }
                }

                MouseArea {
                    id: warningMsgHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (messagesPopup.visible) {
                            messagesPopup.close()
                        } else {
                            messagesPopup.open()
                        }
                    }
                }

                ToolTip.visible: warningMsgHover.containsMouse && !messagesPopup.visible
                ToolTip.delay: 300
                ToolTip.text: qsTr("Vehicle Alerts & MAVLink Warning Messages\nClick to inspect message history")
            }

            // Connection Action Button
            Button {
                id: connectBtn
                Layout.preferredHeight: 28
                implicitHeight: 28
                implicitWidth: connRow.implicitWidth + 24

                contentItem: RowLayout {
                    id: connRow
                    spacing: 7
                    Rectangle {
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: root._hasVehicle ? CompanyTheme.success : CompanyTheme.textPrimary
                    }
                    Text {
                        id: connText
                        text: root._hasVehicle ? qsTr("DISCONNECT") : qsTr("CONNECT VEHICLE")
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        font.letterSpacing: 0.6
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                background: Rectangle {
                    radius: 14
                    color: {
                        if (!connectBtn.enabled) return CompanyTheme.bgInput
                        if (root._hasVehicle) {
                            return connectBtn.hovered ? Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.2) : CompanyTheme.bgCard
                        }
                        return connectBtn.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                    }
                    border.color: {
                        if (!connectBtn.enabled) return CompanyTheme.borderSubtle
                        if (root._hasVehicle) {
                            return connectBtn.hovered ? CompanyTheme.danger : CompanyTheme.borderCard
                        }
                        return connectBtn.hovered ? CompanyTheme.borderActive : CompanyTheme.borderCard
                    }
                    border.width: 1
                }

                onClicked: {
                    if (CompanyTelemetry.hasVehicle && CompanyTelemetry.activeVehicle) {
                        CompanyTelemetry.activeVehicle.closeVehicle()
                        if (QGroundControl.linkManager && QGroundControl.linkManager.linkConfigurations) {
                            for (var i = 0; i < QGroundControl.linkManager.linkConfigurations.count; i++) {
                                var cfg = QGroundControl.linkManager.linkConfigurations.get(i)
                                if (cfg && cfg.linkActive) {
                                    QGroundControl.linkManager.disconnectLinkConfiguration(cfg)
                                }
                            }
                        }
                    } else if (QGroundControl.linkManager && QGroundControl.linkManager.linkConfigurations) {
                        for (var j = 0; j < QGroundControl.linkManager.linkConfigurations.count; j++) {
                            var config = QGroundControl.linkManager.linkConfigurations.get(j)
                            if (config && !config.linkActive) {
                                QGroundControl.linkManager.createConnectedLink(config)
                            }
                        }
                    }
                }
            }

            // Automated Pre-Flight Safety Audit Button
            Rectangle {
                id: preFlightBtn
                Layout.preferredHeight: 28
                implicitWidth: preFlightRow.implicitWidth + 18
                radius: 14
                color: preFlightMouse.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                border.color: preFlightMouse.containsMouse ? CompanyTheme.djiCyan : CompanyTheme.borderCard
                border.width: 1

                RowLayout {
                    id: preFlightRow
                    anchors.centerIn: parent
                    spacing: 6

                    IconVector {
                        name: "shield"
                        size: 13
                        color: CompanyTheme.djiCyan
                    }

                    Text {
                        text: qsTr("PRE-FLIGHT")
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        font.letterSpacing: 0.5
                    }
                }

                MouseArea {
                    id: preFlightMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.preFlightModalRequested()
                }

                ToolTip.visible: preFlightMouse.containsMouse
                ToolTip.delay: 300
                ToolTip.text: qsTr("Automated Pre-Flight Readiness Audit\nVerify IMU, GNSS fix, Battery/Tether, Failsafes, and Motors before takeoff")
            }

            // High-Contrast Sunlight Mode Toggle
            Rectangle {
                id: sunlightBtn
                Layout.preferredHeight: 28
                implicitWidth: 32
                radius: CompanyTheme.radiusSm
                color: CompanyTheme.isSunlightMode ? Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.25) : (sunlightMouse.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCardSecondary)
                border.color: CompanyTheme.isSunlightMode ? CompanyTheme.warning : CompanyTheme.borderCard
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: CompanyTheme.isSunlightMode ? "☀️" : "🌙"
                    font.pointSize: 11
                }

                MouseArea {
                    id: sunlightMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        CompanyTheme.isSunlightMode = !CompanyTheme.isSunlightMode
                    }
                }

                ToolTip.visible: sunlightMouse.containsMouse
                ToolTip.delay: 300
                ToolTip.text: CompanyTheme.isSunlightMode ? qsTr("Sunlight Mode: ACTIVE (High-Contrast Outdoor)\nClick for Tactical Night Mode") : qsTr("Sunlight Mode: OFF (Tactical Dark)\nClick for High-Contrast Outdoor Sunlight Mode")
            }

            // Window Management Controls (Minimize, Maximize/Restore, Close)
            RowLayout {
                visible: !ScreenTools.isMobile && (mainWindow.flags & Qt.FramelessWindowHint)
                spacing: 0
                Layout.fillHeight: true

                // Minimize Button
                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.fillHeight: true
                    color: minMouse.containsMouse ? CompanyTheme.bgCardHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "—"
                        color: minMouse.containsMouse ? CompanyTheme.textPrimary : CompanyTheme.textSecondary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                    }

                    MouseArea {
                        id: minMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mainWindow.showMinimized()
                    }
                }

                // Maximize / Restore Button
                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.fillHeight: true
                    color: maxMouse.containsMouse ? CompanyTheme.bgCardHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: mainWindow.visibility === Window.Maximized ? "❐" : "□"
                        color: maxMouse.containsMouse ? CompanyTheme.textPrimary : CompanyTheme.textSecondary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                    }

                    MouseArea {
                        id: maxMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (mainWindow.visibility === Window.Maximized) {
                                mainWindow.showNormal()
                            } else {
                                mainWindow.showMaximized()
                            }
                        }
                    }
                }

                // Close Button
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.fillHeight: true
                    color: closeMouse.containsMouse ? CompanyTheme.danger : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeMouse.containsMouse ? CompanyTheme.textLight : CompanyTheme.textSecondary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof mainWindow !== "undefined" && mainWindow.attemptWindowClose) {
                                mainWindow.attemptWindowClose()
                            } else if (typeof mainWindow !== "undefined") {
                                mainWindow.close()
                            }
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    // Quick Joystick / RC Transmitter Control & Diagnostics Popup
    // ========================================================================
    Popup {
        id: joystickQuickPopup
        x: Math.max(10, Math.min(root.width - width - 10, joystickChip.mapToItem(root, 0, 0).x - width/2 + joystickChip.width/2))
        y: root.height + 4
        width: 360
        implicitHeight: quickCol.implicitHeight + 24
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property real liveRoll: 0
        property real livePitch: 0
        property real liveYaw: 0
        property real liveThrottle: 0
        property bool isPolling: false

        onOpened: {
            if (joystickChip._activeJoystick && !isPolling) {
                try {
                    joystickChip._activeJoystick.startConfiguration()
                    isPolling = true
                } catch(e) {}
            }
        }

        onClosed: {
            if (joystickChip._activeJoystick && isPolling) {
                try {
                    joystickChip._activeJoystick.stopConfiguration()
                    isPolling = false
                } catch(e) {}
            }
        }

        Connections {
            target: joystickChip._activeJoystick
            ignoreUnknownSignals: true
            function onAxisValues(roll, pitch, yaw, throttle) {
                joystickQuickPopup.liveRoll = roll
                joystickQuickPopup.livePitch = pitch
                joystickQuickPopup.liveYaw = yaw
                joystickQuickPopup.liveThrottle = throttle
            }
            function onRawChannelValuesChanged(values) {
                if (!values || values.length === 0) return
                if (values.length > 0) joystickQuickPopup.liveRoll = Math.max(-1.0, Math.min(1.0, values[0] / 32768.0))
                if (values.length > 1) joystickQuickPopup.livePitch = Math.max(-1.0, Math.min(1.0, values[1] / 32768.0))
                if (values.length > 2) joystickQuickPopup.liveYaw = Math.max(-1.0, Math.min(1.0, values[2] / 32768.0))
                if (values.length > 3) joystickQuickPopup.liveThrottle = Math.max(0.0, Math.min(1.0, (values[3] + 32768.0) / 65536.0))
            }
        }

        background: Rectangle {
            color: CompanyTheme.bgSidebar
            radius: CompanyTheme.radiusMd
            border.color: CompanyTheme.borderCard
            border.width: 1
        }

        contentItem: ColumnLayout {
            id: quickCol
            spacing: 10

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                IconVector {
                    name: "joystick"
                    size: 16
                    color: joystickChip._isEnabled ? CompanyTheme.success : (joystickChip._hasJoystick ? CompanyTheme.warning : CompanyTheme.textSecondary)
                }

                Text {
                    text: qsTr("TRANSMITTER & JOYSTICK CONTROL")
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.bold: true
                    Layout.fillWidth: true
                }

                Button {
                    text: "✕"
                    contentItem: Text {
                        text: parent.text
                        color: CompanyTheme.textMuted
                        font.pointSize: 9
                    }
                    background: Rectangle { color: "transparent" }
                    onClicked: joystickQuickPopup.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: CompanyTheme.borderCard
            }

            // Device Status Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: CompanyTheme.radiusSm
                color: CompanyTheme.bgCard
                border.color: CompanyTheme.borderCard

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: joystickChip._activeJoystick ? joystickChip._activeJoystick.name : qsTr("No Controller Detected")
                            color: CompanyTheme.textPrimary
                            font.pointSize: 10
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            height: 18
                            implicitWidth: calBadgeText.implicitWidth + 8
                            radius: 3
                            color: joystickChip._isCalibrated ? Qt.rgba(CompanyTheme.success.r, CompanyTheme.success.g, CompanyTheme.success.b, 0.2) : Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.2)
                            Text {
                                id: calBadgeText
                                anchors.centerIn: parent
                                text: joystickChip._isCalibrated ? qsTr("CALIBRATED") : qsTr("UNCALIBRATED")
                                color: joystickChip._isCalibrated ? CompanyTheme.success : CompanyTheme.warning
                                font.pointSize: 7
                                font.bold: true
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: joystickChip._hasJoystick ? qsTr("Axes: %1 • Buttons: %2").arg(joystickChip._activeJoystick.axisCount).arg(joystickChip._activeJoystick.buttonCount) : qsTr("Check USB cable or Skydroid HID setting")
                            color: CompanyTheme.textSecondary
                            font.pointSize: 8
                            Layout.fillWidth: true
                        }
                        Text {
                            visible: joystickChip._hasJoystick && joystickChip._activeJoystick && joystickChip._activeJoystick.batteryPercent >= 0
                            text: (joystickChip._hasJoystick && joystickChip._activeJoystick && joystickChip._activeJoystick.batteryPercent >= 0) ? qsTr("Batt: %1%").arg(joystickChip._activeJoystick.batteryPercent) : ""
                            color: CompanyTheme.info
                            font.pointSize: 8
                            font.bold: true
                        }
                    }
                }
            }

            // Master Enable / Disable Flight Control Action Button
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                enabled: joystickChip._hasJoystick
                contentItem: RowLayout {
                    spacing: 6
                    anchors.centerIn: parent
                    IconVector {
                        name: joystickChip._isEnabled ? "lock" : "arm"
                        size: 13
                        color: joystickChip._isEnabled ? CompanyTheme.danger : CompanyTheme.textLight
                    }
                    Text {
                        text: joystickChip._isEnabled ? qsTr("DISABLE JOYSTICK CONTROL") : qsTr("ENABLE JOYSTICK FOR FLIGHT CONTROL")
                        color: joystickChip._isEnabled ? CompanyTheme.danger : CompanyTheme.textLight
                        font.pointSize: 8
                        font.bold: true
                    }
                }
                background: Rectangle {
                    radius: CompanyTheme.radiusSm
                    color: {
                        if (!joystickChip._hasJoystick) return CompanyTheme.bgCard
                        if (joystickChip._isEnabled) return parent.hovered ? CompanyTheme.dangerDim : CompanyTheme.bgCardSecondary
                        return parent.hovered ? CompanyTheme.primaryHover : CompanyTheme.primary
                    }
                    border.color: joystickChip._isEnabled ? CompanyTheme.danger : CompanyTheme.primary
                    border.width: 1
                }
                onClicked: {
                    if (typeof joystickManager !== "undefined" && joystickManager) {
                        if (!joystickChip._isCalibrated && !joystickChip._isEnabled) {
                            if (joystickChip._activeJoystick && joystickChip._activeJoystick.settings && joystickChip._activeJoystick.settings.calibrated) {
                                joystickChip._activeJoystick.settings.calibrated.rawValue = true
                            }
                        }
                        joystickManager.activeJoystickEnabledForActiveVehicle = !joystickManager.activeJoystickEnabledForActiveVehicle
                    }
                }
            }

            // Live Axis Deflection Meters
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 116
                radius: CompanyTheme.radiusSm
                color: CompanyTheme.bgCard
                border.color: CompanyTheme.borderCard

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Text {
                        text: qsTr("LIVE STICK DEFLECTION")
                        color: CompanyTheme.textMuted
                        font.pointSize: 7
                        font.bold: true
                    }

                    // Roll
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text { text: "ROLL"; color: CompanyTheme.textSecondary; font.pointSize: 8; font.family: CompanyTheme.fontMono; Layout.preferredWidth: 42 }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 7; radius: 3.5; color: CompanyTheme.bgCardSecondary
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.abs(joystickQuickPopup.liveRoll) * (parent.width / 2)
                                height: parent.height; radius: 3.5
                                color: CompanyTheme.primary
                                x: joystickQuickPopup.liveRoll >= 0 ? parent.width / 2 : (parent.width / 2) - width
                            }
                            Rectangle { anchors.centerIn: parent; width: 2; height: parent.height + 4; color: CompanyTheme.borderCard }
                        }
                        Text { text: (joystickQuickPopup.liveRoll >= 0 ? "+" : "") + joystickQuickPopup.liveRoll.toFixed(2); color: CompanyTheme.textPrimary; font.pointSize: 8; font.family: CompanyTheme.fontMono; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
                    }

                    // Pitch
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text { text: "PITCH"; color: CompanyTheme.textSecondary; font.pointSize: 8; font.family: CompanyTheme.fontMono; Layout.preferredWidth: 42 }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 7; radius: 3.5; color: CompanyTheme.bgCardSecondary
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.abs(joystickQuickPopup.livePitch) * (parent.width / 2)
                                height: parent.height; radius: 3.5
                                color: CompanyTheme.primary
                                x: joystickQuickPopup.livePitch >= 0 ? parent.width / 2 : (parent.width / 2) - width
                            }
                            Rectangle { anchors.centerIn: parent; width: 2; height: parent.height + 4; color: CompanyTheme.borderCard }
                        }
                        Text { text: (joystickQuickPopup.livePitch >= 0 ? "+" : "") + joystickQuickPopup.livePitch.toFixed(2); color: CompanyTheme.textPrimary; font.pointSize: 8; font.family: CompanyTheme.fontMono; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
                    }

                    // Yaw
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text { text: "YAW"; color: CompanyTheme.textSecondary; font.pointSize: 8; font.family: CompanyTheme.fontMono; Layout.preferredWidth: 42 }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 7; radius: 3.5; color: CompanyTheme.bgCardSecondary
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.abs(joystickQuickPopup.liveYaw) * (parent.width / 2)
                                height: parent.height; radius: 3.5
                                color: CompanyTheme.primary
                                x: joystickQuickPopup.liveYaw >= 0 ? parent.width / 2 : (parent.width / 2) - width
                            }
                            Rectangle { anchors.centerIn: parent; width: 2; height: parent.height + 4; color: CompanyTheme.borderCard }
                        }
                        Text { text: (joystickQuickPopup.liveYaw >= 0 ? "+" : "") + joystickQuickPopup.liveYaw.toFixed(2); color: CompanyTheme.textPrimary; font.pointSize: 8; font.family: CompanyTheme.fontMono; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
                    }

                    // Throttle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text { text: "THR"; color: CompanyTheme.textSecondary; font.pointSize: 8; font.family: CompanyTheme.fontMono; Layout.preferredWidth: 42 }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 7; radius: 3.5; color: CompanyTheme.bgCardSecondary
                            Rectangle {
                                anchors.left: parent.left
                                width: Math.max(0, Math.min(parent.width, joystickQuickPopup.liveThrottle * parent.width))
                                height: parent.height; radius: 3.5
                                color: CompanyTheme.success
                            }
                        }
                        Text { text: Math.round(joystickQuickPopup.liveThrottle * 100) + "%"; color: CompanyTheme.textPrimary; font.pointSize: 8; font.family: CompanyTheme.fontMono; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
                    }
                }
            }

            // Bottom Navigation Link to Full Settings
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    IconVector { name: "settings"; size: 12; color: CompanyTheme.primary }
                    Text {
                        text: qsTr("OPEN FULL JOYSTICK & RC SETTINGS ➔")
                        color: CompanyTheme.primary
                        font.pointSize: 8
                        font.bold: true
                    }
                }
                background: Rectangle {
                    radius: CompanyTheme.radiusSm
                    color: parent.hovered ? CompanyTheme.primaryDim : "transparent"
                    border.color: CompanyTheme.borderCard
                }
                onClicked: {
                    joystickQuickPopup.close()
                    root.openJoystickSettingsRequested()
                }
            }
        }
    }

    // ========================================================================
    // Autopilot Message History & Warning Popup
    // ========================================================================
    Popup {
        id: messagesPopup
        x: Math.max(10, Math.min(root.width - width - 10, warningMsgBtn.mapToItem(root, 0, 0).x - width + warningMsgBtn.width))
        y: root.height + 4
        width: 460
        height: 340
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: CompanyTheme.bgSidebar
            radius: CompanyTheme.radiusMd
            border.color: CompanyTheme.borderCard
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 8

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                IconVector {
                    name: "alert-triangle"
                    size: 15
                    color: CompanyTelemetry.errorCount > 0 ? CompanyTheme.danger : (CompanyTelemetry.warningCount > 0 ? CompanyTheme.warning : CompanyTheme.info)
                }

                Text {
                    text: qsTr("VEHICLE MESSAGES & WARNINGS")
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.bold: true
                    Layout.fillWidth: true
                }

                Button {
                    text: qsTr("Clear")
                    contentItem: Text {
                        text: parent.text
                        color: CompanyTheme.textSecondary
                        font.pointSize: 8
                        font.bold: true
                    }
                    background: Rectangle {
                        radius: 3
                        color: parent.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                        border.color: CompanyTheme.borderCard
                    }
                    onClicked: CompanyTelemetry.resetMessages()
                }

                Button {
                    text: "✕"
                    contentItem: Text {
                        text: parent.text
                        color: CompanyTheme.textMuted
                        font.pointSize: 9
                    }
                    background: Rectangle {
                        color: "transparent"
                    }
                    onClicked: messagesPopup.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: CompanyTheme.borderCard
            }

            // Active Tether Alert Banner (Tethered Drone GCS)
            Rectangle {
                id: tetherAlertBanner
                readonly property var _tether: tetherChip._tether
                visible: _tether !== null && (_tether.highTensionAlarm || _tether.powerCutoffAlarm || _tether.lengthLimitAlarm)
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 34 : 0
                radius: CompanyTheme.radiusSm
                color: (_tether && (_tether.highTensionAlarm || _tether.powerCutoffAlarm)) ? Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.25) : Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.25)
                border.color: (_tether && (_tether.highTensionAlarm || _tether.powerCutoffAlarm)) ? CompanyTheme.danger : CompanyTheme.warning
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    IconVector {
                        name: "alert-triangle"
                        size: 14
                        color: tetherAlertBanner.border.color
                    }

                    Text {
                        text: tetherAlertBanner._tether ? tetherAlertBanner._tether.activeAlertMessage : ""
                        color: CompanyTheme.textPrimary
                        font.pointSize: 9
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }

            // Messages ListView
            ListView {
                id: msgListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: CompanyTelemetry.messageHistory

                delegate: Rectangle {
                    id: msgDelegate
                    required property var modelData
                    width: msgListView.width
                    implicitHeight: msgCol.implicitHeight + 12
                    radius: CompanyTheme.radiusSm
                    color: {
                        if (msgDelegate.modelData.severity === "ERROR") return Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.15)
                        if (msgDelegate.modelData.severity === "WARNING") return Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.12)
                        return CompanyTheme.bgCard
                    }
                    border.color: {
                        if (msgDelegate.modelData.severity === "ERROR") return CompanyTheme.danger
                        if (msgDelegate.modelData.severity === "WARNING") return CompanyTheme.warning
                        return CompanyTheme.borderCard
                    }
                    border.width: 1

                    ColumnLayout {
                        id: msgCol
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                radius: 2
                                height: 14
                                implicitWidth: sevText.implicitWidth + 6
                                color: msgDelegate.modelData.severity === "ERROR" ? CompanyTheme.danger : (msgDelegate.modelData.severity === "WARNING" ? CompanyTheme.warning : CompanyTheme.info)

                                Text {
                                    id: sevText
                                    anchors.centerIn: parent
                                    text: msgDelegate.modelData.severity
                                    color: CompanyTheme.textLight
                                    font.pointSize: 6.5
                                    font.bold: true
                                }
                            }

                            Text {
                                text: msgDelegate.modelData.timestamp
                                color: CompanyTheme.textMuted
                                font.pointSize: 7.5
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: msgDelegate.modelData.text
                            color: CompanyTheme.textPrimary
                            font.pointSize: 8.5
                            wrapMode: Text.Wrap
                        }
                    }
                }

                // Empty State
                Text {
                    anchors.centerIn: parent
                    visible: CompanyTelemetry.messageHistory.length === 0
                    text: qsTr("No alerts or warning messages received.")
                    color: CompanyTheme.textMuted
                    font.pointSize: CompanyTheme.fontSmall
                }
            }
        }
    }

    // ========================================================================
    // Slide-Down Warning & Alert Toast Banner
    // ========================================================================
    Rectangle {
        id: toastBanner
        anchors.top: root.bottom
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        z: 9999
        visible: false
        opacity: visible ? 1.0 : 0.0
        implicitWidth: toastRow.implicitWidth + 24
        implicitHeight: 34
        radius: CompanyTheme.radiusSm
        color: {
            if (CompanyTelemetry.latestWarningSeverity === "ERROR") return Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.95)
            if (CompanyTelemetry.latestWarningSeverity === "WARNING") return Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.95)
            return Qt.rgba(CompanyTheme.bgSidebar.r, CompanyTheme.bgSidebar.g, CompanyTheme.bgSidebar.b, 0.95)
        }
        border.color: CompanyTelemetry.latestWarningSeverity === "ERROR" ? CompanyTheme.danger : CompanyTheme.warning
        border.width: 1

        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }

        RowLayout {
            id: toastRow
            anchors.centerIn: parent
            spacing: 8

            IconVector {
                name: "alert-triangle"
                size: 14
                color: CompanyTelemetry.latestWarningSeverity === "ERROR" ? CompanyTheme.textLight : (CompanyTelemetry.latestWarningSeverity === "WARNING" ? CompanyTheme.bgSidebar : CompanyTheme.textPrimary)
            }

            Text {
                text: "[" + CompanyTelemetry.latestWarningSeverity + "] " + CompanyTelemetry.latestWarningText
                color: CompanyTelemetry.latestWarningSeverity === "ERROR" ? CompanyTheme.textLight : (CompanyTelemetry.latestWarningSeverity === "WARNING" ? CompanyTheme.bgSidebar : CompanyTheme.textPrimary)
                font.pointSize: 8.5
                font.bold: true
                elide: Text.ElideRight
                Layout.maximumWidth: 500
            }

            Text {
                text: qsTr("(Click to view)")
                color: CompanyTelemetry.latestWarningSeverity === "ERROR" ? Qt.rgba(1, 1, 1, 0.7) : Qt.rgba(0, 0, 0, 0.6)
                font.pointSize: 7.5
            }

            Rectangle {
                width: 16
                height: 16
                radius: 8
                color: Qt.rgba(0, 0, 0, 0.2)

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: CompanyTelemetry.latestWarningSeverity === "ERROR" ? CompanyTheme.textLight : (CompanyTelemetry.latestWarningSeverity === "WARNING" ? CompanyTheme.bgSidebar : CompanyTheme.textPrimary)
                    font.pointSize: 7.5
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        toastTimer.stop()
                        toastBanner.visible = false
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                toastTimer.stop()
                toastBanner.visible = false
                messagesPopup.open()
            }
        }

        Timer {
            id: toastTimer
            interval: 6000
            repeat: false
            onTriggered: toastBanner.visible = false
        }
    }

    Connections {
        target: CompanyTelemetry
        function onLatestWarningTextChanged() {
            if (CompanyTelemetry.latestWarningText !== "") {
                toastBanner.visible = true
                toastTimer.restart()
            }
        }
    }
}
