pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Company.UI

Rectangle {
    id: root

    property int    currentTab: 1 // Backward-compatible tab index (0/1: Dashboard, 2: Missions, 3: Fleet, 4: Logs, 5: Settings, 6: Parameters, 7: Vehicle Setup)
    property string activeSection: "OPERATIONS" // "OPERATIONS", "VEHICLE", "TOOLS"
    property string activeSubView: "MAP"        // "MAP", "PFD", "CAM", "SYSTEM"
    property int    activeTool: -1              // 2: Missions, 3: Fleet, 4: Logs, 5: Settings
    property int    activeVehicleItem: -1       // 6: Parameters, 7: Vehicle Setup
    property bool   isExpanded: false

    signal tabSelected(int index)
    signal subViewSelected(string viewId)
    signal flightActionRequested(string actionType)
    signal toolSelected(int tabIndex)
    signal vehicleItemSelected(int tabIndex)
    signal closeRequested()

    readonly property bool _hasVehicle:         CompanyTelemetry.hasVehicle
    readonly property bool _isArmed:            CompanyTelemetry.armed
    readonly property bool _isAirborne:         CompanyTelemetry.isAirborne
    readonly property bool _isGrounded:         CompanyTelemetry.isGrounded
    readonly property bool _communicationValid: CompanyTelemetry.communicationValid

    width: isExpanded ? CompanyTheme.sidebarWidthExpanded : CompanyTheme.sidebarWidthCompact
    implicitWidth: width
    color: CompanyTheme.bgSidebar
    clip: true

    Behavior on width {
        NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
    }

    // Right border line
    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 1
        color: CompanyTheme.borderCard
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: CompanyTheme.spacingSm
        anchors.bottomMargin: CompanyTheme.spacingSm
        anchors.leftMargin: root.isExpanded ? CompanyTheme.spacingSm : 4
        anchors.rightMargin: root.isExpanded ? CompanyTheme.spacingSm : 4
        spacing: 4

        // --------------------------------------------------------------------
        // Rail Header: Expand / Collapse Hamburger Toggle
        // --------------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            implicitHeight: 32
            radius: CompanyTheme.radiusSm
            color: toggleMouseArea.containsMouse ? CompanyTheme.bgCard : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                anchors.rightMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                spacing: CompanyTheme.spacingSm

                Item {
                    Layout.preferredWidth: root.isExpanded ? 22 : parent.width
                    Layout.fillHeight: true

                    // Hamburger lines icon
                    Column {
                        anchors.centerIn: parent
                        spacing: 3
                        Rectangle { width: 14; height: 2; radius: 1; color: toggleMouseArea.containsMouse ? CompanyTheme.textPrimary : CompanyTheme.textSecondary }
                        Rectangle { width: 14; height: 2; radius: 1; color: toggleMouseArea.containsMouse ? CompanyTheme.textPrimary : CompanyTheme.textSecondary }
                        Rectangle { width: 14; height: 2; radius: 1; color: toggleMouseArea.containsMouse ? CompanyTheme.textPrimary : CompanyTheme.textSecondary }
                    }
                }

                Text {
                    visible: root.isExpanded
                    text: qsTr("NAVIGATION")
                    color: CompanyTheme.textMuted
                    font.pointSize: CompanyTheme.fontTiny
                    font.bold: true
                    font.letterSpacing: 1.0
                    Layout.fillWidth: true
                }

                Rectangle {
                    visible: root.isExpanded
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 2
                    color: closeBtnMouse.containsMouse ? CompanyTheme.bgCardHover : "transparent"
                    border.color: closeBtnMouse.containsMouse ? CompanyTheme.borderActive : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeBtnMouse.containsMouse ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                        font.pointSize: 9
                        font.bold: true
                    }

                    MouseArea {
                        id: closeBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.closeRequested()
                            root.isExpanded = false
                        }
                    }
                }
            }

            MouseArea {
                id: toggleMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Only toggle if not clicking the close button area
                onClicked: (mouse) => {
                    if (root.isExpanded && mouse.x > width - 36) {
                        root.closeRequested()
                        root.isExpanded = false
                    } else {
                        root.isExpanded = !root.isExpanded
                    }
                }
            }

            ToolTip.visible: toggleMouseArea.containsMouse && !root.isExpanded
            ToolTip.delay: 400
            ToolTip.text: qsTr("Toggle Sidebar")
        }

        // Section Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: CompanyTheme.borderCard
        }

        // --------------------------------------------------------------------
        // Scrollable Navigation Rail Body
        // --------------------------------------------------------------------
        Flickable {
            id: railFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: railContentCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: railContentCol
                width: parent.width
                spacing: 3

                // ============================================================
                // 1. OPERATIONS (MAP, PFD, CAM, SYSTEM)
                // ============================================================
                Text {
                    visible: root.isExpanded
                    Layout.leftMargin: CompanyTheme.spacingSm
                    Layout.topMargin: 2
                    Layout.bottomMargin: 1
                    text: qsTr("OPERATIONS")
                    color: CompanyTheme.textMuted
                    font.pointSize: 8
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Repeater {
                    model: [
                        { id: "MAP",    title: qsTr("Map View"), icon: "flight" },
                        { id: "PFD",    title: qsTr("PFD HUD"),  icon: "dashboard" },
                        { id: "CAM",    title: qsTr("Camera"),   icon: "video" },
                        { id: "SYSTEM", title: qsTr("System"),   icon: "settings" }
                    ]

                    delegate: Rectangle {
                        id: opItem
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        implicitHeight: 32
                        radius: CompanyTheme.radiusSm

                        readonly property bool isSelected: root.activeSection === "OPERATIONS" && root.activeSubView === opItem.modelData.id
                        readonly property bool isHovered: opMouseArea.containsMouse

                        color: {
                            if (isSelected) return CompanyTheme.primaryDim
                            if (isHovered) return CompanyTheme.bgCard
                            return "transparent"
                        }

                        // Left active indicator
                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 18
                            radius: 1.5
                            color: CompanyTheme.primary
                            visible: opItem.isSelected
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                            anchors.rightMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                            spacing: CompanyTheme.spacingSm

                            Item {
                                Layout.preferredWidth: root.isExpanded ? 20 : parent.width
                                Layout.fillHeight: true

                                IconVector {
                                    anchors.centerIn: parent
                                    name: opItem.modelData.icon
                                    size: 15
                                    color: opItem.isSelected ? CompanyTheme.primary : (opItem.isHovered ? CompanyTheme.textPrimary : CompanyTheme.textSecondary)
                                }
                            }

                            Text {
                                visible: root.isExpanded
                                text: opItem.modelData.title
                                color: opItem.isSelected ? CompanyTheme.textPrimary : (opItem.isHovered ? CompanyTheme.textPrimary : CompanyTheme.textSecondary)
                                font.pointSize: CompanyTheme.fontSmall
                                font.bold: opItem.isSelected
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: opMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeSection = "OPERATIONS"
                                root.activeSubView = opItem.modelData.id
                                root.activeTool = -1
                                root.activeVehicleItem = -1
                                root.subViewSelected(opItem.modelData.id)
                            }
                        }

                        ToolTip.visible: opMouseArea.containsMouse && !root.isExpanded
                        ToolTip.delay: 300
                        ToolTip.text: opItem.modelData.title
                    }
                }

                // Section Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 4
                    Layout.bottomMargin: 2
                    color: CompanyTheme.borderCard
                }

                // ============================================================
                // 2. FLIGHT CONTROL (ARM/DISARM, HOLD, RTL, LAND)
                // ============================================================
                Text {
                    visible: root.isExpanded
                    Layout.leftMargin: CompanyTheme.spacingSm
                    Layout.topMargin: 2
                    Layout.bottomMargin: 1
                    text: qsTr("FLIGHT CONTROL")
                    color: CompanyTheme.textMuted
                    font.pointSize: 8
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                // Control 1: ARM / DISARM
                Rectangle {
                    id: armCtrl
                    readonly property bool canArm:    root._hasVehicle && root._communicationValid && !root._isArmed && root._isGrounded
                    readonly property bool canDisarm: root._hasVehicle && root._communicationValid && root._isArmed && !root._isAirborne && root._isGrounded
                    readonly property bool isActionAvailable: root._isArmed ? canDisarm : canArm

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    implicitHeight: 32
                    radius: CompanyTheme.radiusSm
                    color: {
                        if (armMouseArea.containsMouse && isActionAvailable) return CompanyTheme.bgCardHover
                        return root._isArmed ? Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.16) : "transparent"
                    }
                    border.color: {
                        if (root._isArmed) return CompanyTheme.danger
                        return (armMouseArea.containsMouse && isActionAvailable) ? CompanyTheme.borderActive : "transparent"
                    }
                    border.width: 1
                    opacity: isActionAvailable ? 1.0 : 0.4

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                        anchors.rightMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                        spacing: CompanyTheme.spacingSm

                        Item {
                            Layout.preferredWidth: root.isExpanded ? 20 : parent.width
                            Layout.fillHeight: true

                            IconVector {
                                anchors.centerIn: parent
                                name: "arm"
                                size: 15
                                color: {
                                    if (!root._hasVehicle || !root._communicationValid) return CompanyTheme.textMuted
                                    return root._isArmed ? CompanyTheme.danger : CompanyTheme.warning
                                }
                            }
                        }

                        Text {
                            visible: root.isExpanded
                            text: {
                                if (root._isArmed) {
                                    return root._isAirborne ? qsTr("AIRBORNE") : qsTr("DISARM")
                                }
                                return qsTr("ARM")
                            }
                            color: {
                                if (!armCtrl.isActionAvailable && !root._isArmed) return CompanyTheme.textMuted
                                return root._isArmed ? CompanyTheme.danger : CompanyTheme.textPrimary
                            }
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: armMouseArea
                        anchors.fill: parent
                        hoverEnabled: armCtrl.isActionAvailable
                        cursorShape: armCtrl.isActionAvailable ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!armCtrl.isActionAvailable) return
                            root.flightActionRequested(root._isArmed ? "DISARM" : "ARM")
                        }
                    }

                    ToolTip.visible: armMouseArea.containsMouse && (!root.isExpanded || !armCtrl.isActionAvailable)
                    ToolTip.delay: 300
                    ToolTip.text: {
                        if (!root._hasVehicle) return qsTr("No vehicle connected")
                        if (!root._communicationValid) return qsTr("Telemetry lost — flight controls disabled")
                        if (root._isArmed && root._isAirborne) return qsTr("Standard DISARM unavailable while airborne")
                        return root._isArmed ? qsTr("Disarm Vehicle (Requires Confirmation)") : qsTr("Arm Vehicle (Requires Confirmation)")
                    }
                }

                // Control 2: HOLD / PAUSE
                Rectangle {
                    id: holdCtrl
                    readonly property bool isActionAvailable: root._hasVehicle && root._communicationValid && root._isArmed

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    implicitHeight: 32
                    radius: CompanyTheme.radiusSm
                    color: (holdMouseArea.containsMouse && isActionAvailable) ? CompanyTheme.bgCardHover : "transparent"
                    border.color: (holdMouseArea.containsMouse && isActionAvailable) ? CompanyTheme.borderActive : "transparent"
                    border.width: 1
                    opacity: isActionAvailable ? 1.0 : 0.4

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                        anchors.rightMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                        spacing: CompanyTheme.spacingSm

                        Item {
                            Layout.preferredWidth: root.isExpanded ? 20 : parent.width
                            Layout.fillHeight: true

                            IconVector {
                                anchors.centerIn: parent
                                name: "hold"
                                size: 15
                                color: holdCtrl.isActionAvailable ? CompanyTheme.warning : CompanyTheme.textMuted
                            }
                        }

                        Text {
                            visible: root.isExpanded
                            text: qsTr("HOLD")
                            color: holdCtrl.isActionAvailable ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: holdMouseArea
                        anchors.fill: parent
                        hoverEnabled: holdCtrl.isActionAvailable
                        cursorShape: holdCtrl.isActionAvailable ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (holdCtrl.isActionAvailable) {
                                root.flightActionRequested("HOLD")
                            }
                        }
                    }

                    ToolTip.visible: holdMouseArea.containsMouse && (!root.isExpanded || !holdCtrl.isActionAvailable)
                    ToolTip.delay: 300
                    ToolTip.text: {
                        if (!root._hasVehicle) return qsTr("No vehicle connected")
                        if (!root._communicationValid) return qsTr("Telemetry lost — flight controls disabled")
                        if (!root._isArmed) return qsTr("Vehicle is disarmed")
                        return qsTr("Hold / Loiter Position (Requires Confirmation)")
                    }
                }

                // Control 3: RTL (Return to Launch)
                Rectangle {
                    id: rtlCtrl
                    readonly property bool isActionAvailable: root._hasVehicle && root._communicationValid && root._isArmed

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    implicitHeight: 32
                    radius: CompanyTheme.radiusSm
                    color: (rtlMouseArea.containsMouse && isActionAvailable) ? CompanyTheme.bgCardHover : "transparent"
                    border.color: (rtlMouseArea.containsMouse && isActionAvailable) ? CompanyTheme.borderActive : "transparent"
                    border.width: 1
                    opacity: isActionAvailable ? 1.0 : 0.4

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                        anchors.rightMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                        spacing: CompanyTheme.spacingSm

                        Item {
                            Layout.preferredWidth: root.isExpanded ? 20 : parent.width
                            Layout.fillHeight: true

                            IconVector {
                                anchors.centerIn: parent
                                name: "rtl"
                                size: 15
                                color: rtlCtrl.isActionAvailable ? CompanyTheme.warning : CompanyTheme.textMuted
                            }
                        }

                        Text {
                            visible: root.isExpanded
                            text: qsTr("RTL")
                            color: rtlCtrl.isActionAvailable ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: rtlMouseArea
                        anchors.fill: parent
                        hoverEnabled: rtlCtrl.isActionAvailable
                        cursorShape: rtlCtrl.isActionAvailable ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (rtlCtrl.isActionAvailable) {
                                root.flightActionRequested("RTL")
                            }
                        }
                    }

                    ToolTip.visible: rtlMouseArea.containsMouse && (!root.isExpanded || !rtlCtrl.isActionAvailable)
                    ToolTip.delay: 300
                    ToolTip.text: {
                        if (!root._hasVehicle) return qsTr("No vehicle connected")
                        if (!root._communicationValid) return qsTr("Telemetry lost — flight controls disabled")
                        if (!root._isArmed) return qsTr("Vehicle is disarmed")
                        return qsTr("Return to Launch (Requires Confirmation)")
                    }
                }

                // Control 4: LAND
                Rectangle {
                    id: landCtrl
                    readonly property bool isActionAvailable: root._hasVehicle && root._communicationValid && root._isArmed

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    implicitHeight: 32
                    radius: CompanyTheme.radiusSm
                    color: (landMouseArea.containsMouse && isActionAvailable) ? CompanyTheme.bgCardHover : "transparent"
                    border.color: (landMouseArea.containsMouse && isActionAvailable) ? CompanyTheme.borderActive : "transparent"
                    border.width: 1
                    opacity: isActionAvailable ? 1.0 : 0.4

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                        anchors.rightMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                        spacing: CompanyTheme.spacingSm

                        Item {
                            Layout.preferredWidth: root.isExpanded ? 20 : parent.width
                            Layout.fillHeight: true

                            IconVector {
                                anchors.centerIn: parent
                                name: "land"
                                size: 15
                                color: landCtrl.isActionAvailable ? CompanyTheme.textSecondary : CompanyTheme.textMuted
                            }
                        }

                        Text {
                            visible: root.isExpanded
                            text: qsTr("LAND")
                            color: landCtrl.isActionAvailable ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: landMouseArea
                        anchors.fill: parent
                        hoverEnabled: landCtrl.isActionAvailable
                        cursorShape: landCtrl.isActionAvailable ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (landCtrl.isActionAvailable) {
                                root.flightActionRequested("LAND")
                            }
                        }
                    }

                    ToolTip.visible: landMouseArea.containsMouse && (!root.isExpanded || !landCtrl.isActionAvailable)
                    ToolTip.delay: 300
                    ToolTip.text: {
                        if (!root._hasVehicle) return qsTr("No vehicle connected")
                        if (!root._communicationValid) return qsTr("Telemetry lost — flight controls disabled")
                        if (!root._isArmed) return qsTr("Vehicle is disarmed")
                        return qsTr("Land Vehicle (Requires Confirmation)")
                    }
                }

                // Section Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 4
                    Layout.bottomMargin: 2
                    color: CompanyTheme.borderCard
                }

                // ============================================================
                // 3. VEHICLE (PARAMETERS, VEHICLE SETUP)
                // ============================================================
                Text {
                    visible: root.isExpanded
                    Layout.leftMargin: CompanyTheme.spacingSm
                    Layout.topMargin: 2
                    Layout.bottomMargin: 1
                    text: qsTr("VEHICLE")
                    color: CompanyTheme.textMuted
                    font.pointSize: 8
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Repeater {
                    model: [
                        { id: 6, title: qsTr("Parameters"),    icon: "params" },
                        { id: 7, title: qsTr("Vehicle Setup"), icon: "setup" }
                    ]

                    delegate: Rectangle {
                        id: vehicleItem
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        implicitHeight: 32
                        radius: CompanyTheme.radiusSm

                        readonly property bool isSelected: root.activeSection === "VEHICLE" && root.activeVehicleItem === vehicleItem.modelData.id
                        readonly property bool isHovered: vehicleMouseArea.containsMouse

                        color: {
                            if (isSelected) return CompanyTheme.primaryDim
                            if (isHovered) return CompanyTheme.bgCard
                            return "transparent"
                        }

                        // Left active indicator
                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 18
                            radius: 1.5
                            color: CompanyTheme.primary
                            visible: vehicleItem.isSelected
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                            anchors.rightMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                            spacing: CompanyTheme.spacingSm

                            Item {
                                Layout.preferredWidth: root.isExpanded ? 20 : parent.width
                                Layout.fillHeight: true

                                IconVector {
                                    anchors.centerIn: parent
                                    name: vehicleItem.modelData.icon
                                    size: 15
                                    color: vehicleItem.isSelected ? CompanyTheme.primary : (vehicleItem.isHovered ? CompanyTheme.textPrimary : CompanyTheme.textSecondary)
                                }
                            }

                            Text {
                                visible: root.isExpanded
                                text: vehicleItem.modelData.title
                                color: vehicleItem.isSelected ? CompanyTheme.textPrimary : (vehicleItem.isHovered ? CompanyTheme.textPrimary : CompanyTheme.textSecondary)
                                font.pointSize: CompanyTheme.fontSmall
                                font.bold: vehicleItem.isSelected
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: vehicleMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeSection = "VEHICLE"
                                root.activeVehicleItem = vehicleItem.modelData.id
                                root.activeTool = -1
                                root.currentTab = vehicleItem.modelData.id
                                root.vehicleItemSelected(vehicleItem.modelData.id)
                                root.tabSelected(vehicleItem.modelData.id)
                            }
                        }

                        ToolTip.visible: vehicleMouseArea.containsMouse && !root.isExpanded
                        ToolTip.delay: 300
                        ToolTip.text: vehicleItem.modelData.title
                    }
                }

                // Section Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 4
                    Layout.bottomMargin: 2
                    color: CompanyTheme.borderCard
                }

                // ============================================================
                // 4. TOOLS (MISSION/PLAN, ANALYSIS/FLEET, LOGS, SETTINGS)
                // ============================================================
                Text {
                    visible: root.isExpanded
                    Layout.leftMargin: CompanyTheme.spacingSm
                    Layout.topMargin: 2
                    Layout.bottomMargin: 1
                    text: qsTr("TOOLS")
                    color: CompanyTheme.textMuted
                    font.pointSize: 8
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Repeater {
                    model: [
                        { id: 2, title: qsTr("Mission / Plan"), icon: "missions" },
                        { id: 3, title: qsTr("Analysis / Fleet"), icon: "fleet" },
                        { id: 4, title: qsTr("Logs"),            icon: "logs" },
                        { id: 5, title: qsTr("Settings"),        icon: "settings" }
                    ]

                    delegate: Rectangle {
                        id: toolItem
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        implicitHeight: 32
                        radius: CompanyTheme.radiusSm

                        readonly property bool isSelected: root.activeSection === "TOOLS" && root.activeTool === toolItem.modelData.id
                        readonly property bool isHovered: toolMouseArea.containsMouse

                        color: {
                            if (isSelected) return CompanyTheme.primaryDim
                            if (isHovered) return CompanyTheme.bgCard
                            return "transparent"
                        }

                        // Left active indicator
                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 18
                            radius: 1.5
                            color: CompanyTheme.primary
                            visible: toolItem.isSelected
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                            anchors.rightMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                            spacing: CompanyTheme.spacingSm

                            Item {
                                Layout.preferredWidth: root.isExpanded ? 20 : parent.width
                                Layout.fillHeight: true

                                IconVector {
                                    anchors.centerIn: parent
                                    name: toolItem.modelData.icon
                                    size: 15
                                    color: toolItem.isSelected ? CompanyTheme.primary : (toolItem.isHovered ? CompanyTheme.textPrimary : CompanyTheme.textSecondary)
                                }
                            }

                            Text {
                                visible: root.isExpanded
                                text: toolItem.modelData.title
                                color: toolItem.isSelected ? CompanyTheme.textPrimary : (toolItem.isHovered ? CompanyTheme.textPrimary : CompanyTheme.textSecondary)
                                font.pointSize: CompanyTheme.fontSmall
                                font.bold: toolItem.isSelected
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: toolMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeSection = "TOOLS"
                                root.activeTool = toolItem.modelData.id
                                root.activeVehicleItem = -1
                                root.currentTab = toolItem.modelData.id
                                root.toolSelected(toolItem.modelData.id)
                                root.tabSelected(toolItem.modelData.id)
                            }
                        }

                        ToolTip.visible: toolMouseArea.containsMouse && !root.isExpanded
                        ToolTip.delay: 300
                        ToolTip.text: toolItem.modelData.title
                    }
                }
            }
        }

        // Section Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: CompanyTheme.borderCard
        }

        // --------------------------------------------------------------------
        // Bottom System Status (Compact Dot or Full Card)
        // --------------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.isExpanded ? 46 : 30
            implicitHeight: root.isExpanded ? 46 : 30
            color: CompanyTheme.bgCard
            radius: CompanyTheme.radiusSm
            border.color: CompanyTheme.borderCard
            border.width: 1

            // Compact status display (single dot centered)
            Item {
                anchors.fill: parent
                visible: !root.isExpanded

                Rectangle {
                    anchors.centerIn: parent
                    width: 7
                    height: 7
                    radius: 3.5
                    color: CompanyTheme.success
                }

                MouseArea {
                    id: statusCompactHover
                    anchors.fill: parent
                    hoverEnabled: true
                }

                ToolTip.visible: statusCompactHover.containsMouse
                ToolTip.delay: 300
                ToolTip.text: qsTr("IZI GCS Engine Online • v5.0.3")
            }

            // Expanded status display
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2
                visible: root.isExpanded

                RowLayout {
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: CompanyTheme.success
                    }

                    Text {
                        text: qsTr("IZI ENGINE ONLINE")
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.letterSpacing: 0.4
                    }
                }

                Text {
                    Layout.leftMargin: 12
                    text: qsTr("Core v5.0.3  •  COMM OK")
                    color: CompanyTheme.textMuted
                    font.pointSize: 7
                }
            }
        }
    }
}
