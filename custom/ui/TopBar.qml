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
                        IconVector {
                            name: "chevron_down"
                            size: 8
                            color: brandMouseArea.containsMouse ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                        }
                    }
                    Text {
                        visible: !root._isNarrow
                        text: "FLIGHT CONTROL SYSTEM"
                        color: CompanyTheme.textSecondary
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
                                    text: "v5.0.3"
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
                spacing: 1

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
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
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
                            return idStr + " • " + armStr + " • " + modeStr
                        }
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.family: CompanyTheme.fontMono
                        font.bold: true
                    }
                }
            }
        }

        // Expanding spacer
        Item {
            Layout.fillWidth: true
        }

        // --------------------------------------------------------------------
        // 3. Operational Indicators: UTC, Battery, GPS, Link (Compact Right Strip)
        // --------------------------------------------------------------------
        RowLayout {
            spacing: root._isNarrow ? CompanyTheme.spacingSm : CompanyTheme.spacingMd

            // UTC Clock
            RowLayout {
                spacing: 4
                Text {
                    text: "UTC"
                    color: CompanyTheme.textMuted
                    font.pointSize: CompanyTheme.fontTiny
                    font.bold: true
                }
                Text {
                    id: clockText
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
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

            // Divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 16
                color: CompanyTheme.borderCard
            }

            // Status Icons Group (Link, Signal, Wifi, RC)
            RowLayout {
                spacing: 12
                visible: !root._isNarrow

                IconVector {
                    name: "link"
                    size: 13
                    color: root._hasVehicle ? CompanyTheme.success : CompanyTheme.textMuted
                    ToolTip.visible: linkHover.containsMouse
                    ToolTip.delay: 300
                    ToolTip.text: root._hasVehicle ? (root._linkMgr ? root._linkMgr.primaryLinkName : qsTr("Link Connected")) : qsTr("No MAVLink Link")

                    MouseArea {
                        id: linkHover
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }

                IconVector {
                    name: "signal"
                    size: 13
                    color: {
                        if (!root._hasVehicle) return CompanyTheme.textMuted
                        return CompanyTelemetry.communicationLost ? CompanyTheme.danger : CompanyTheme.success
                    }
                    ToolTip.visible: signalHover.containsMouse
                    ToolTip.delay: 300
                    ToolTip.text: root._hasVehicle ? (qsTr("Telemetry Signal: ") + CompanyTelemetry.linkQualityPercent + "%") : qsTr("No Signal")

                    MouseArea {
                        id: signalHover
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }

                IconVector {
                    name: "wifi"
                    size: 13
                    color: root._hasVehicle ? CompanyTheme.info : CompanyTheme.textMuted
                    ToolTip.visible: wifiHover.containsMouse
                    ToolTip.delay: 300
                    ToolTip.text: qsTr("Network Communication Link")

                    MouseArea {
                        id: wifiHover
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }

                IconVector {
                    name: "rc"
                    size: 13
                    color: root._hasVehicle ? CompanyTheme.warning : CompanyTheme.textMuted
                    ToolTip.visible: rcHover.containsMouse
                    ToolTip.delay: 300
                    ToolTip.text: root._hasVehicle ? qsTr("RC Controller Online") : qsTr("RC Disconnected")

                    MouseArea {
                        id: rcHover
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
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
                        onClicked: mainWindow.close()
                    }
                }
            }
        }
    }
}
