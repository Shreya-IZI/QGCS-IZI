// qmllint disable unqualified

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import Company.UI

Rectangle {
    id: root

    color: CompanyTheme.bgApp

    // Navigation and Action Signals
    signal navigateToWorkspace(int tabIndex, string subView)
    signal openSettingsRequested()
    signal openPreFlightChecklistRequested()

    readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool _hasVehicle: _activeVehicle !== null && CompanyTelemetry.hasVehicle
    readonly property bool _isNarrow: width < 760

    // Tracks the currently selected workspace or card
    property int currentTabIndex: 1
    property string activeCard: "fly"

    onCurrentTabIndexChanged: {
        switch (currentTabIndex) {
        case 0:
        case 1:
            activeCard = "fly"
            break
        case 2:
            activeCard = "plan"
            break
        case 3:
            activeCard = "fleet"
            break
        case 4:
            activeCard = "analyze"
            break
        case 5:
            activeCard = "settings"
            break
        case 7:
            activeCard = "configure"
            break
        }
    }

    // ------------------------------------------------------------------------
    // 1. AERIAL LANDSCAPE BACKDROP & TACTICAL VIGNETTE
    // ------------------------------------------------------------------------
    Image {
        id: bgLandscape
        anchors.fill: parent
        source: "qrc:/res/images/home_aerial_bg.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: 0.88
    }

    // Left card matrix darkened backdrop for maximum readability
    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root._isNarrow ? parent.width : Math.max(520, parent.width * 0.52)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0.043, 0.067, 0.094, 0.95) }
            GradientStop { position: 0.75; color: Qt.rgba(0.043, 0.067, 0.094, 0.88) }
            GradientStop { position: 1.0; color: Qt.rgba(0.043, 0.067, 0.094, 0.20) }
        }
    }

    // Top Header Vignette Bar
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.043, 0.067, 0.094, 0.96) }
            GradientStop { position: 1.0; color: Qt.rgba(0.043, 0.067, 0.094, 0.40) }
        }
    }

    // Bottom Telemetry Strip Vignette Bar
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 72
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.043, 0.067, 0.094, 0.40) }
            GradientStop { position: 1.0; color: Qt.rgba(0.043, 0.067, 0.094, 0.98) }
        }
    }

    // ------------------------------------------------------------------------
    // 2. TOP HEADER BAR
    // ------------------------------------------------------------------------
    Rectangle {
        id: headerBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48
        color: "transparent"
        z: 20

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
            anchors.leftMargin: CompanyTheme.spacingLg
            anchors.rightMargin: CompanyTheme.spacingLg
            spacing: CompanyTheme.spacingMd

            // Left Branding: Official IZI Wordmark + Arc + GCS Version
            RowLayout {
                spacing: 10
                Layout.alignment: Qt.AlignVCenter

                // Back arrow indicator (Subtle chevron)
                Text {
                    text: "‹"
                    color: CompanyTheme.textSecondary
                    font.pointSize: 18
                    font.bold: true
                    visible: false // Visible when returning from an active mission
                }

                // Official IZI Brand Logo & Title
                RowLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    IziLogo {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 18
                        color: "#FFFFFF"
                    }

                    Text {
                        text: "IZI GCS"
                        color: CompanyTheme.textPrimary
                        font.pointSize: 11.5
                        font.bold: true
                        font.letterSpacing: 0.8
                    }
                }

                Rectangle {
                    width: 1
                    height: 14
                    color: CompanyTheme.borderCard
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: qsTr("Ground Control Station v1.0.0")
                    color: CompanyTheme.textSecondary
                    font.pointSize: 9
                    font.family: CompanyTheme.fontMono
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Item { Layout.fillWidth: true }

            // Right Status Indicators (Connected, Drone, Battery, RC, GPS, Settings)
            RowLayout {
                spacing: 14
                Layout.alignment: Qt.AlignVCenter

                // Connection Status Chip
                Rectangle {
                    Layout.preferredHeight: 24
                    implicitWidth: connRow.implicitWidth + 18
                    radius: 12
                    color: root._hasVehicle ? Qt.rgba(0.545, 0.918, 0.408, 0.15) : Qt.rgba(0.937, 0.267, 0.267, 0.15)
                    border.color: root._hasVehicle ? CompanyTheme.success : CompanyTheme.danger
                    border.width: 1

                    RowLayout {
                        id: connRow
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: root._hasVehicle ? CompanyTheme.success : CompanyTheme.danger
                        }

                        Text {
                            text: root._hasVehicle ? qsTr("Connected") : qsTr("Disconnected")
                            color: root._hasVehicle ? CompanyTheme.success : CompanyTheme.danger
                            font.pointSize: 9
                            font.bold: true
                        }
                    }
                }

                // Aircraft Model Indicator Icon
                IconVector {
                    name: "drone"
                    size: 16
                    color: root._hasVehicle ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                }

                // Battery Indicator
                RowLayout {
                    spacing: 5
                    IconVector {
                        name: "battery"
                        size: 14
                        color: {
                            if (!root._hasVehicle || !CompanyTelemetry.hasBattery) return CompanyTheme.textMuted
                            if (CompanyTelemetry.batteryPercent > 25) return CompanyTheme.success
                            if (CompanyTelemetry.batteryPercent > 15) return CompanyTheme.warning
                            return CompanyTheme.danger
                        }
                    }
                    Text {
                        text: (root._hasVehicle && CompanyTelemetry.hasBattery) ? CompanyTelemetry.batteryPercentStr : "--%"
                        color: (root._hasVehicle && CompanyTelemetry.hasBattery) ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                        font.pointSize: 9
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }
                }

                // RC Signal Indicator
                RowLayout {
                    spacing: 5
                    IconVector {
                        name: "rc"
                        size: 14
                        color: (root._hasVehicle && CompanyTelemetry.hasRcRSSI) ? CompanyTheme.success : CompanyTheme.textMuted
                    }
                    Text {
                        text: "RC"
                        color: (root._hasVehicle && CompanyTelemetry.hasRcRSSI) ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                        font.pointSize: 9
                        font.bold: true
                    }
                }

                // GPS Satellites
                RowLayout {
                    spacing: 5
                    IconVector {
                        name: "gps"
                        size: 14
                        color: (root._hasVehicle && CompanyTelemetry.is3DFix) ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                    }
                    Text {
                        text: "GPS " + ((root._hasVehicle && CompanyTelemetry.gpsSatellites >= 0) ? String(CompanyTelemetry.gpsSatellites) : "--")
                        color: (root._hasVehicle && CompanyTelemetry.is3DFix) ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                        font.pointSize: 9
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }
                }

                // Quick Settings Shortcut Button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: settingsBtnMouse.containsMouse ? CompanyTheme.bgCardHover : "transparent"

                    IconVector {
                        anchors.centerIn: parent
                        name: "settings"
                        size: 15
                        color: CompanyTheme.textPrimary
                    }

                    MouseArea {
                        id: settingsBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openSettingsRequested()
                    }
                }

                // ------------------------------------------------------------
                // Desktop / Tablet Frameless Window Controls (Minimize, Maximize, Close / Cut)
                // ------------------------------------------------------------
                RowLayout {
                    spacing: 2
                    Layout.fillHeight: true
                    visible: true

                    // Vertical Divider
                    Rectangle {
                        width: 1
                        height: 14
                        color: CompanyTheme.borderCard
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 6
                        Layout.rightMargin: 6
                    }

                    // Minimize Button
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 30
                        radius: CompanyTheme.radiusSm
                        color: minMouse.containsMouse ? CompanyTheme.bgCardHover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "—"
                            color: minMouse.containsMouse ? CompanyTheme.textPrimary : CompanyTheme.textSecondary
                            font.pointSize: 10
                            font.bold: true
                        }

                        MouseArea {
                            id: minMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof mainWindow !== "undefined") {
                                    mainWindow.showMinimized()
                                }
                            }
                        }
                    }

                    // Maximize / Restore Button
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 30
                        radius: CompanyTheme.radiusSm
                        color: maxMouse.containsMouse ? CompanyTheme.bgCardHover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: (typeof mainWindow !== "undefined" && mainWindow.visibility === Window.Maximized) ? "❐" : "□"
                            color: maxMouse.containsMouse ? CompanyTheme.textPrimary : CompanyTheme.textSecondary
                            font.pointSize: 10
                            font.bold: true
                        }

                        MouseArea {
                            id: maxMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof mainWindow !== "undefined") {
                                    if (mainWindow.visibility === Window.Maximized) {
                                        mainWindow.showNormal()
                                    } else {
                                        mainWindow.showMaximized()
                                    }
                                }
                            }
                        }
                    }

                    // Close / Cut Button
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 30
                        radius: CompanyTheme.radiusSm
                        color: closeMouse.containsMouse ? CompanyTheme.danger : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeMouse.containsMouse ? CompanyTheme.textLight : CompanyTheme.textSecondary
                            font.pointSize: 11
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

    // ------------------------------------------------------------------------
    // 3. MAIN WORKSPACE: 6 NAVIGATION CARDS & RIGHT HERO BRANDING
    // ------------------------------------------------------------------------
    Item {
        id: mainWorkspace
        anchors.top: headerBar.bottom
        anchors.bottom: bottomTelemetryStrip.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: CompanyTheme.spacingLg

        RowLayout {
            anchors.fill: parent
            spacing: CompanyTheme.spacingXl

            // Left Side: 2 Columns x 3 Rows Matrix of Touch Cards
            Item {
                Layout.fillHeight: true
                Layout.preferredWidth: root._isNarrow ? parent.width : Math.min(500, parent.width * 0.48)

                GridLayout {
                    id: cardsGrid
                    anchors.centerIn: parent
                    columns: root._isNarrow ? 1 : 2
                    columnSpacing: CompanyTheme.spacingMd
                    rowSpacing: CompanyTheme.spacingMd
                    width: parent.width

                    // CARD 1: FLY (Live Flight & Control)
                    Rectangle {
                        id: flyCard
                        readonly property bool isSelected: root.activeCard === "fly"
                        readonly property bool isHighlighted: isSelected || flyMouse.containsMouse || flyMouse.pressed

                        Layout.fillWidth: true
                        Layout.preferredHeight: 84
                        radius: CompanyTheme.radiusSm + 2
                        color: isHighlighted ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                        border.color: isHighlighted ? CompanyTheme.primary : CompanyTheme.borderCard
                        border.width: isSelected ? 1.5 : (isHighlighted ? 1.5 : 1.0)

                        // Subtle green ambient glow when active or pressed/hovered
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.color: CompanyTheme.primary
                            border.width: 1
                            opacity: 0.35
                            scale: 1.01
                            visible: parent.isHighlighted
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            IconVector {
                                name: "drone"
                                size: 26
                                color: "#FFFFFF"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: qsTr("Fly")
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: 13
                                    font.bold: true
                                }
                                Text {
                                    text: qsTr("Live flight & control")
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: 8.5
                                }
                            }

                            Text {
                                text: "›"
                                color: CompanyTheme.textSecondary
                                font.pointSize: 18
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        MouseArea {
                            id: flyMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeCard = "fly"
                                root.navigateToWorkspace(1, "CAM")
                            }
                        }
                    }

                    // CARD 2: PLAN (Create & Edit Missions)
                    Rectangle {
                        id: planCard
                        readonly property bool isSelected: root.activeCard === "plan"
                        readonly property bool isHighlighted: isSelected || planMouse.containsMouse || planMouse.pressed

                        Layout.fillWidth: true
                        Layout.preferredHeight: 84
                        radius: CompanyTheme.radiusSm + 2
                        color: isHighlighted ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                        border.color: isHighlighted ? CompanyTheme.primary : CompanyTheme.borderCard
                        border.width: isSelected ? 1.5 : (isHighlighted ? 1.5 : 1.0)

                        // Subtle green ambient glow when active or pressed/hovered
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.color: CompanyTheme.primary
                            border.width: 1
                            opacity: 0.35
                            scale: 1.01
                            visible: parent.isHighlighted
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            IconVector {
                                name: "plan"
                                size: 26
                                color: "#FFFFFF"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: qsTr("Plan")
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: 13
                                    font.bold: true
                                }
                                Text {
                                    text: qsTr("Create & edit missions")
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: 8.5
                                }
                            }

                            Text {
                                text: "›"
                                color: CompanyTheme.textSecondary
                                font.pointSize: 18
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        MouseArea {
                            id: planMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeCard = "plan"
                                root.navigateToWorkspace(2, "")
                            }
                        }
                    }

                    // CARD 3: ANALYZE (Flight Data & Logs)
                    Rectangle {
                        id: analyzeCard
                        readonly property bool isSelected: root.activeCard === "analyze"
                        readonly property bool isHighlighted: isSelected || analyzeMouse.containsMouse || analyzeMouse.pressed

                        Layout.fillWidth: true
                        Layout.preferredHeight: 84
                        radius: CompanyTheme.radiusSm + 2
                        color: isHighlighted ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                        border.color: isHighlighted ? CompanyTheme.primary : CompanyTheme.borderCard
                        border.width: isSelected ? 1.5 : (isHighlighted ? 1.5 : 1.0)

                        // Subtle green ambient glow when active or pressed/hovered
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.color: CompanyTheme.primary
                            border.width: 1
                            opacity: 0.35
                            scale: 1.01
                            visible: parent.isHighlighted
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            IconVector {
                                name: "chart"
                                size: 26
                                color: "#FFFFFF"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: qsTr("Analyze")
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: 13
                                    font.bold: true
                                }
                                Text {
                                    text: qsTr("Flight data & logs")
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: 8.5
                                }
                            }

                            Text {
                                text: "›"
                                color: CompanyTheme.textSecondary
                                font.pointSize: 18
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        MouseArea {
                            id: analyzeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeCard = "analyze"
                                root.navigateToWorkspace(4, "")
                            }
                        }
                    }

                    // CARD 4: CONFIGURE (Vehicle & Payload)
                    Rectangle {
                        id: configureCard
                        readonly property bool isSelected: root.activeCard === "configure"
                        readonly property bool isHighlighted: isSelected || configureMouse.containsMouse || configureMouse.pressed

                        Layout.fillWidth: true
                        Layout.preferredHeight: 84
                        radius: CompanyTheme.radiusSm + 2
                        color: isHighlighted ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                        border.color: isHighlighted ? CompanyTheme.primary : CompanyTheme.borderCard
                        border.width: isSelected ? 1.5 : (isHighlighted ? 1.5 : 1.0)

                        // Subtle green ambient glow when active or pressed/hovered
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.color: CompanyTheme.primary
                            border.width: 1
                            opacity: 0.35
                            scale: 1.01
                            visible: parent.isHighlighted
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            IconVector {
                                name: "sliders"
                                size: 26
                                color: "#FFFFFF"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: qsTr("Configure")
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: 13
                                    font.bold: true
                                }
                                Text {
                                    text: qsTr("Vehicle & payload")
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: 8.5
                                }
                            }

                            Text {
                                text: "›"
                                color: CompanyTheme.textSecondary
                                font.pointSize: 18
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        MouseArea {
                            id: configureMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeCard = "configure"
                                root.navigateToWorkspace(7, "")
                            }
                        }
                    }

                    // CARD 5: FLEET (Manage Vehicles)
                    Rectangle {
                        id: fleetCard
                        readonly property bool isSelected: root.activeCard === "fleet"
                        readonly property bool isHighlighted: isSelected || fleetMouse.containsMouse || fleetMouse.pressed

                        Layout.fillWidth: true
                        Layout.preferredHeight: 84
                        radius: CompanyTheme.radiusSm + 2
                        color: isHighlighted ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                        border.color: isHighlighted ? CompanyTheme.primary : CompanyTheme.borderCard
                        border.width: isSelected ? 1.5 : (isHighlighted ? 1.5 : 1.0)

                        // Subtle green ambient glow when active or pressed/hovered
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.color: CompanyTheme.primary
                            border.width: 1
                            opacity: 0.35
                            scale: 1.01
                            visible: parent.isHighlighted
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            IconVector {
                                name: "layers"
                                size: 26
                                color: "#FFFFFF"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: qsTr("Fleet")
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: 13
                                    font.bold: true
                                }
                                Text {
                                    text: qsTr("Manage vehicles")
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: 8.5
                                }
                            }

                            Text {
                                text: "›"
                                color: CompanyTheme.textSecondary
                                font.pointSize: 18
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        MouseArea {
                            id: fleetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeCard = "fleet"
                                root.navigateToWorkspace(3, "")
                            }
                        }
                    }

                    // CARD 6: SETTINGS (System & Preferences)
                    Rectangle {
                        id: settingsCard
                        readonly property bool isSelected: root.activeCard === "settings"
                        readonly property bool isHighlighted: isSelected || settingsMouse.containsMouse || settingsMouse.pressed

                        Layout.fillWidth: true
                        Layout.preferredHeight: 84
                        radius: CompanyTheme.radiusSm + 2
                        color: isHighlighted ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                        border.color: isHighlighted ? CompanyTheme.primary : CompanyTheme.borderCard
                        border.width: isSelected ? 1.5 : (isHighlighted ? 1.5 : 1.0)

                        // Subtle green ambient glow when active or pressed/hovered
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.color: CompanyTheme.primary
                            border.width: 1
                            opacity: 0.35
                            scale: 1.01
                            visible: parent.isHighlighted
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            IconVector {
                                name: "settings"
                                size: 26
                                color: "#FFFFFF"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: qsTr("Settings")
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: 13
                                    font.bold: true
                                }
                                Text {
                                    text: qsTr("System & preferences")
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: 8.5
                                }
                            }

                            Text {
                                text: "›"
                                color: CompanyTheme.textSecondary
                                font.pointSize: 18
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        MouseArea {
                            id: settingsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeCard = "settings"
                                root.navigateToWorkspace(5, "")
                            }
                        }
                    }
                }
            }

            // Right Side: Clean Aerospace Brand Hero Display
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root._isNarrow

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 16

                    // Official IZI Aerospace Brand Mark
                    IziLogo {
                        Layout.preferredWidth: 161
                        Layout.preferredHeight: 120
                        color: "#FFFFFF"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // Subtitle: GROUND CONTROL STATION
                    Text {
                        text: qsTr("GROUND CONTROL STATION")
                        color: CompanyTheme.textPrimary
                        font.pointSize: 11
                        font.bold: true
                        font.letterSpacing: 4.0
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    // 4. BOTTOM REAL-TIME TELEMETRY STRIP
    // ------------------------------------------------------------------------
    Rectangle {
        id: bottomTelemetryStrip
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: CompanyTheme.spacingMd
        height: 52
        radius: CompanyTheme.radiusSm + 2
        color: CompanyTheme.bgCard
        border.color: CompanyTheme.borderCard
        border.width: 1
        z: 20

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: CompanyTheme.spacingMd
            anchors.rightMargin: CompanyTheme.spacingMd
            spacing: CompanyTheme.spacingLg

            // Left Drone Selector Well
            RowLayout {
                spacing: 10
                Layout.alignment: Qt.AlignVCenter

                IconVector {
                    name: "drone"
                    size: 20
                    color: root._hasVehicle ? CompanyTheme.success : CompanyTheme.textMuted
                }

                ColumnLayout {
                    spacing: 1

                    RowLayout {
                        spacing: 4
                        Text {
                            text: {
                                if (root._hasVehicle && root._activeVehicle) {
                                    return root._activeVehicle.id ? ("UAS #" + root._activeVehicle.id) : qsTr("VEHICLE CONNECTED")
                                }
                                return qsTr("NO VEHICLE CONNECTED")
                            }
                            color: root._hasVehicle ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                            font.pointSize: 10.5
                            font.bold: true
                        }
                        Text {
                            text: "▾"
                            color: root._hasVehicle ? CompanyTheme.textSecondary : CompanyTheme.textMuted
                            font.pointSize: 9
                            visible: root._hasVehicle
                        }
                    }

                    Text {
                        text: {
                            if (root._hasVehicle && root._activeVehicle) {
                                var vType = root._activeVehicle.vehicleTypeString || "UAS"
                                var aType = root._activeVehicle.autopilotTypeName || "Autopilot"
                                return vType + " • " + aType
                            }
                            return qsTr("Awaiting Telemetry Link")
                        }
                        color: CompanyTheme.textSecondary
                        font.pointSize: 7.5
                    }
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: CompanyTheme.borderCard
                Layout.alignment: Qt.AlignVCenter
            }

            // Real-Time Telemetry Gauges
            RowLayout {
                Layout.fillWidth: true
                spacing: root._isNarrow ? CompanyTheme.spacingSm : CompanyTheme.spacingLg
                Layout.alignment: Qt.AlignVCenter

                // Alt
                RowLayout {
                    spacing: 6
                    IconVector {
                        name: "altitude"
                        size: 14
                        color: root._hasVehicle ? CompanyTheme.textSecondary : CompanyTheme.textMuted
                    }
                    ColumnLayout {
                        spacing: 1
                        Text { text: qsTr("Alt"); color: CompanyTheme.textSecondary; font.pointSize: 7 }
                        Text {
                            text: (root._hasVehicle && CompanyTelemetry.altitudeRelativeStr !== "--") ? CompanyTelemetry.altitudeRelativeStr : "-- m"
                            color: root._hasVehicle ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                            font.pointSize: 9.5
                            font.bold: true
                            font.family: CompanyTheme.fontMono
                        }
                    }
                }

                // Speed
                RowLayout {
                    spacing: 6
                    IconVector {
                        name: "speedometer"
                        size: 14
                        color: root._hasVehicle ? CompanyTheme.textSecondary : CompanyTheme.textMuted
                    }
                    ColumnLayout {
                        spacing: 1
                        Text { text: qsTr("Speed"); color: CompanyTheme.textSecondary; font.pointSize: 7 }
                        Text {
                            text: (root._hasVehicle && CompanyTelemetry.groundSpeedStr !== "--") ? CompanyTelemetry.groundSpeedStr : "-- m/s"
                            color: root._hasVehicle ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                            font.pointSize: 9.5
                            font.bold: true
                            font.family: CompanyTheme.fontMono
                        }
                    }
                }

                // V.Speed
                RowLayout {
                    spacing: 6
                    IconVector {
                        name: "vspeed"
                        size: 14
                        color: root._hasVehicle ? CompanyTheme.textSecondary : CompanyTheme.textMuted
                    }
                    ColumnLayout {
                        spacing: 1
                        Text { text: qsTr("V.Speed"); color: CompanyTheme.textSecondary; font.pointSize: 7 }
                        Text {
                            text: (root._hasVehicle && CompanyTelemetry.climbRateStr !== "--") ? CompanyTelemetry.climbRateStr : "-- m/s"
                            color: root._hasVehicle ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                            font.pointSize: 9.5
                            font.bold: true
                            font.family: CompanyTheme.fontMono
                        }
                    }
                }

                // Battery
                RowLayout {
                    spacing: 6
                    IconVector {
                        name: "battery"
                        size: 15
                        color: (root._hasVehicle && CompanyTelemetry.hasBattery) ? CompanyTheme.success : CompanyTheme.textMuted
                    }
                    ColumnLayout {
                        spacing: 1
                        Text { text: qsTr("Battery"); color: CompanyTheme.textSecondary; font.pointSize: 7 }
                        Text {
                            text: (root._hasVehicle && CompanyTelemetry.hasBattery) ? CompanyTelemetry.batteryPercentStr : "--"
                            color: (root._hasVehicle && CompanyTelemetry.hasBattery) ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                            font.pointSize: 9.5
                            font.bold: true
                            font.family: CompanyTheme.fontMono
                        }
                    }
                }

                // GPS
                RowLayout {
                    spacing: 6
                    IconVector {
                        name: "gps"
                        size: 14
                        color: root._hasVehicle ? CompanyTheme.textSecondary : CompanyTheme.textMuted
                    }
                    ColumnLayout {
                        spacing: 1
                        Text { text: qsTr("GPS"); color: CompanyTheme.textSecondary; font.pointSize: 7 }
                        Text {
                            text: (root._hasVehicle && CompanyTelemetry.gpsSatellites >= 0) ? String(CompanyTelemetry.gpsSatellites) : "--"
                            color: root._hasVehicle ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                            font.pointSize: 9.5
                            font.bold: true
                            font.family: CompanyTheme.fontMono
                        }
                    }
                }

                // RC
                RowLayout {
                    spacing: 6
                    IconVector {
                        name: "signal"
                        size: 14
                        color: (root._hasVehicle && CompanyTelemetry.hasRcRSSI) ? CompanyTheme.success : CompanyTheme.textMuted
                    }
                    ColumnLayout {
                        spacing: 1
                        Text { text: qsTr("RC"); color: CompanyTheme.textSecondary; font.pointSize: 7 }
                        Text {
                            text: (root._hasVehicle && CompanyTelemetry.hasRcRSSI) ? CompanyTelemetry.rcRSSIStr : (root._hasVehicle ? qsTr("Good") : "--")
                            color: (root._hasVehicle && CompanyTelemetry.hasRcRSSI) ? CompanyTheme.success : CompanyTheme.textMuted
                            font.pointSize: 9.5
                            font.bold: true
                        }
                    }
                }
            }

            // Readiness Action Button (Right)
            Rectangle {
                Layout.preferredHeight: 30
                implicitWidth: readyRow.implicitWidth + 24
                radius: 15
                color: {
                    if (root._hasVehicle && root._activeVehicle && root._activeVehicle.armed) {
                        return Qt.rgba(0.937, 0.267, 0.267, 0.20)
                    }
                    if (root._hasVehicle) {
                        return Qt.rgba(0.545, 0.918, 0.408, 0.16)
                    }
                    return Qt.rgba(0.2, 0.24, 0.28, 0.35)
                }
                border.color: {
                    if (root._hasVehicle && root._activeVehicle && root._activeVehicle.armed) {
                        return CompanyTheme.danger
                    }
                    if (root._hasVehicle) {
                        return CompanyTheme.primary
                    }
                    return CompanyTheme.borderCard
                }
                border.width: 1

                RowLayout {
                    id: readyRow
                    anchors.centerIn: parent
                    spacing: 6

                    IconVector {
                        name: {
                            if (root._hasVehicle && root._activeVehicle && root._activeVehicle.armed) return "alert-triangle"
                            if (root._hasVehicle) return "check_circle"
                            return "radio"
                        }
                        size: 14
                        color: {
                            if (root._hasVehicle && root._activeVehicle && root._activeVehicle.armed) return CompanyTheme.danger
                            if (root._hasVehicle) return CompanyTheme.primary
                            return CompanyTheme.textMuted
                        }
                    }

                    Text {
                        text: {
                            if (root._hasVehicle && root._activeVehicle) {
                                if (root._activeVehicle.armed) return qsTr("Armed (In Flight)")
                                if (root._activeVehicle.readyToFlyAvailable && root._activeVehicle.readyToFly) return qsTr("Ready to Fly")
                                return qsTr("Standby (Ready)")
                            }
                            return qsTr("Disconnected")
                        }
                        color: {
                            if (root._hasVehicle && root._activeVehicle && root._activeVehicle.armed) return CompanyTheme.danger
                            if (root._hasVehicle) return CompanyTheme.primary
                            return CompanyTheme.textMuted
                        }
                        font.pointSize: 9
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root._hasVehicle) {
                            root.openPreFlightChecklistRequested()
                        } else {
                            root.navigateToWorkspace(1, "CAM")
                        }
                    }
                }
            }
        }
    }
}
