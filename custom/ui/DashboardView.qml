pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import Company.UI

Item {
    id: root

    property string currentSubView: "MAP" // "MAP", "PFD", "SYSTEM"
    signal navigateToTab(int tabIndex)

    readonly property bool _hasVehicle:         CompanyTelemetry.hasVehicle
    readonly property bool _isArmed:            CompanyTelemetry.armed
    readonly property bool _isFlying:           CompanyTelemetry.flying
    readonly property string _flightMode:       CompanyTelemetry.flightMode
    readonly property real _heading:            CompanyTelemetry.heading

    // ------------------------------------------------------------------------
    // Safety Confirmation Interlock State & Handlers
    // ------------------------------------------------------------------------
    property bool   _confirmDialogOpen: false
    property string _confirmActionType: "" // "ARM", "DISARM", "HOLD", "RTL", "LAND"
    property string _confirmTitle:      ""
    property string _confirmMessage:    ""
    property color  _confirmColor:      CompanyTheme.warning
    property string _confirmIcon:       ""
    property bool   _isExecutingAction: false

    function requestActionConfirmation(actionType) {
        if (!CompanyTelemetry.hasVehicle || !CompanyTelemetry.activeVehicle || _isExecutingAction) return

        _confirmActionType = actionType
        switch (actionType) {
        case "ARM":
            _confirmTitle = qsTr("Confirm Vehicle Arming")
            _confirmMessage = qsTr("Are you sure you want to ARM UAS #%1? Motors will spin if armed.").arg(CompanyTelemetry.vehicleId)
            _confirmColor = CompanyTheme.danger
            _confirmIcon = "arm"
            break
        case "DISARM":
            _confirmTitle = qsTr("Confirm Vehicle Disarm")
            _confirmMessage = CompanyTelemetry.flying ?
                qsTr("CRITICAL WARNING: UAS #%1 is currently airborne! Disarming in flight will cause an immediate crash!").arg(CompanyTelemetry.vehicleId) :
                qsTr("Are you sure you want to DISARM UAS #%1?").arg(CompanyTelemetry.vehicleId)
            _confirmColor = CompanyTheme.danger
            _confirmIcon = "arm"
            break
        case "HOLD":
            _confirmTitle = qsTr("Confirm Hold / Loiter")
            _confirmMessage = qsTr("Command UAS #%1 to pause flight and hold its current position?").arg(CompanyTelemetry.vehicleId)
            _confirmColor = CompanyTheme.warning
            _confirmIcon = "hold"
            break
        case "RTL":
            _confirmTitle = qsTr("Confirm Return to Launch")
            _confirmMessage = qsTr("Command UAS #%1 to return to launch location (RTL)?").arg(CompanyTelemetry.vehicleId)
            _confirmColor = CompanyTheme.warning
            _confirmIcon = "rtl"
            break
        case "LAND":
            _confirmTitle = qsTr("Confirm Land")
            _confirmMessage = qsTr("Command UAS #%1 to land immediately at its current position?").arg(CompanyTelemetry.vehicleId)
            _confirmColor = CompanyTheme.warning
            _confirmIcon = "land"
            break
        default:
            return
        }
        _confirmDialogOpen = true
    }

    function cancelActionConfirmation() {
        _confirmDialogOpen = false
        _confirmActionType = ""
    }

    function executeConfirmedAction() {
        if (_isExecutingAction) return
        _isExecutingAction = true

        var action = _confirmActionType
        _confirmDialogOpen = false
        _confirmActionType = ""

        if (CompanyTelemetry.hasVehicle && CompanyTelemetry.activeVehicle) {
            switch (action) {
            case "ARM":
                CompanyTelemetry.activeVehicle.armed = true
                break
            case "DISARM":
                CompanyTelemetry.activeVehicle.armed = false
                break
            case "HOLD":
                CompanyTelemetry.activeVehicle.pauseVehicle()
                break
            case "RTL":
                CompanyTelemetry.activeVehicle.guidedModeRTL(false)
                break
            case "LAND":
                CompanyTelemetry.activeVehicle.guidedModeLand()
                break
            }
        }

        _isExecutingAction = false
    }

    // ------------------------------------------------------------------------
    // 1. Full-Bleed Primary Visualization Canvas
    // ------------------------------------------------------------------------
    Item {
        id: visualCanvas
        anchors.fill: parent

        // Viewport 1: Moving Tactical FlightMap (Default QGC View)
        TacticalMapView {
            anchors.fill: parent
            visible: root.currentSubView === "MAP"
        }

        // Viewport 2: Glass Cockpit Primary Flight Display (PFD)
        PrimaryFlightDisplay {
            anchors.fill: parent
            visible: root.currentSubView === "PFD"
        }

        // Viewport 3: Comprehensive System Diagnostics
        SystemDiagnosticsView {
            anchors.fill: parent
            visible: root.currentSubView === "SYSTEM"
        }
    }

    // ------------------------------------------------------------------------
    // 2. Floating View Switcher Pill (Top Left, Offset from Toolstrip)
    // ------------------------------------------------------------------------
    Rectangle {
        id: viewSwitcherPill
        anchors.top: parent.top
        anchors.left: actionToolstrip.right
        anchors.leftMargin: CompanyTheme.spacingMd
        anchors.topMargin: CompanyTheme.spacingMd
        z: 10
        height: 32
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgOverlayDark
        border.color: CompanyTheme.borderCard
        border.width: 1
        implicitWidth: switcherLayout.implicitWidth + 4

        RowLayout {
            id: switcherLayout
            anchors.fill: parent
            anchors.margins: 2
            spacing: 2

            Repeater {
                model: [
                    { id: "MAP",    label: qsTr("MAP"),    icon: "flight" },
                    { id: "PFD",    label: qsTr("PFD"),    icon: "dashboard" },
                    { id: "SYSTEM", label: qsTr("SYSTEM"), icon: "settings" }
                ]

                delegate: Rectangle {
                    id: switchBtn
                    required property var modelData

                    readonly property bool isSelected: root.currentSubView === switchBtn.modelData.id
                    readonly property bool isHovered: switchMouseArea.containsMouse

                    Layout.preferredWidth: 68
                    Layout.fillHeight: true
                    radius: CompanyTheme.radiusSm - 1
                    color: {
                        if (switchBtn.isSelected) return CompanyTheme.primaryDim
                        if (switchBtn.isHovered) return CompanyTheme.bgCardHover
                        return "transparent"
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        IconVector {
                            name: switchBtn.modelData.icon
                            size: 12
                            color: switchBtn.isSelected ? CompanyTheme.primary : (switchBtn.isHovered ? CompanyTheme.textPrimary : CompanyTheme.textSecondary)
                        }

                        Text {
                            text: switchBtn.modelData.label
                            color: switchBtn.isSelected ? CompanyTheme.primary : (switchBtn.isHovered ? CompanyTheme.textPrimary : CompanyTheme.textSecondary)
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: switchBtn.isSelected
                            font.letterSpacing: 0.5
                        }
                    }

                    MouseArea {
                        id: switchMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentSubView = switchBtn.modelData.id
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    // 3. Floating Left Operational Action Toolstrip (QGC Style)
    // ------------------------------------------------------------------------
    Rectangle {
        id: actionToolstrip
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: CompanyTheme.spacingMd
        z: 10
        width: 52
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgOverlayDark
        border.color: CompanyTheme.borderCard
        border.width: 1
        implicitHeight: toolstripColumn.implicitHeight + CompanyTheme.spacingSm * 2

        ColumnLayout {
            id: toolstripColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: CompanyTheme.spacingXs
            spacing: CompanyTheme.spacingXs

            // Tool 1: ARM / DISARM
            Rectangle {
                id: armToolBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: CompanyTheme.radiusSm
                color: {
                    if (!root._hasVehicle) return "transparent"
                    if (armMouseArea.containsMouse) return CompanyTheme.bgCardHover
                    return root._isArmed ? Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.2) : "transparent"
                }
                border.color: {
                    if (!root._hasVehicle) return "transparent"
                    if (root._isArmed) return CompanyTheme.danger
                    return armMouseArea.containsMouse ? CompanyTheme.primary : CompanyTheme.borderSubtle
                }
                border.width: 1
                opacity: root._hasVehicle ? 1.0 : 0.4

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    IconVector {
                        Layout.alignment: Qt.AlignHCenter
                        name: "arm"
                        size: 15
                        color: {
                            if (!root._hasVehicle) return CompanyTheme.textMuted
                            return root._isArmed ? CompanyTheme.danger : CompanyTheme.primary
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root._isArmed ? qsTr("DISARM") : qsTr("ARM")
                        color: {
                            if (!root._hasVehicle) return CompanyTheme.textMuted
                            return root._isArmed ? CompanyTheme.danger : CompanyTheme.textPrimary
                        }
                        font.pointSize: CompanyTheme.fontTiny - 1
                        font.bold: true
                    }
                }

                MouseArea {
                    id: armMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root._hasVehicle
                    cursorShape: root._hasVehicle ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (CompanyTelemetry.hasVehicle) {
                            root.requestActionConfirmation(root._isArmed ? "DISARM" : "ARM")
                        }
                    }
                }

                ToolTip.visible: armMouseArea.containsMouse
                ToolTip.delay: 300
                ToolTip.text: root._hasVehicle ? (root._isArmed ? qsTr("Disarm Vehicle") : qsTr("Arm Vehicle")) : qsTr("No Vehicle Connected")
            }

            // Tool 2: HOLD / PAUSE
            Rectangle {
                id: holdToolBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: CompanyTheme.radiusSm
                color: (holdMouseArea.containsMouse && holdToolBtn.enabled) ? CompanyTheme.bgCardHover : "transparent"
                border.color: (holdMouseArea.containsMouse && holdToolBtn.enabled) ? CompanyTheme.borderActive : "transparent"
                border.width: 1
                enabled: root._hasVehicle && root._isArmed
                opacity: enabled ? 1.0 : 0.35

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    IconVector {
                        Layout.alignment: Qt.AlignHCenter
                        name: "hold"
                        size: 15
                        color: holdToolBtn.enabled ? CompanyTheme.warning : CompanyTheme.textMuted
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("HOLD")
                        color: holdToolBtn.enabled ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                        font.pointSize: CompanyTheme.fontTiny - 1
                        font.bold: true
                    }
                }

                MouseArea {
                    id: holdMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: holdToolBtn.enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (CompanyTelemetry.hasVehicle && root._isArmed) {
                            root.requestActionConfirmation("HOLD")
                        }
                    }
                }

                ToolTip.visible: holdMouseArea.containsMouse
                ToolTip.delay: 300
                ToolTip.text: qsTr("Hold / Loiter in Place")
            }

            // Tool 3: RTL (Return To Launch)
            Rectangle {
                id: rtlToolBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: CompanyTheme.radiusSm
                color: (rtlMouseArea.containsMouse && rtlToolBtn.enabled) ? CompanyTheme.bgCardHover : "transparent"
                border.color: (rtlMouseArea.containsMouse && rtlToolBtn.enabled) ? CompanyTheme.borderActive : "transparent"
                border.width: 1
                enabled: root._hasVehicle && root._isArmed
                opacity: enabled ? 1.0 : 0.35

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    IconVector {
                        Layout.alignment: Qt.AlignHCenter
                        name: "rtl"
                        size: 15
                        color: rtlToolBtn.enabled ? CompanyTheme.warning : CompanyTheme.textMuted
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("RTL")
                        color: rtlToolBtn.enabled ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                        font.pointSize: CompanyTheme.fontTiny - 1
                        font.bold: true
                    }
                }

                MouseArea {
                    id: rtlMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: rtlToolBtn.enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (CompanyTelemetry.hasVehicle && root._isArmed) {
                            root.requestActionConfirmation("RTL")
                        }
                    }
                }

                ToolTip.visible: rtlMouseArea.containsMouse
                ToolTip.delay: 300
                ToolTip.text: qsTr("Return to Launch (RTL)")
            }

            // Tool 4: LAND
            Rectangle {
                id: landToolBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: CompanyTheme.radiusSm
                color: (landMouseArea.containsMouse && landToolBtn.enabled) ? CompanyTheme.bgCardHover : "transparent"
                border.color: (landMouseArea.containsMouse && landToolBtn.enabled) ? CompanyTheme.borderActive : "transparent"
                border.width: 1
                enabled: root._hasVehicle && root._isArmed
                opacity: enabled ? 1.0 : 0.35

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    IconVector {
                        Layout.alignment: Qt.AlignHCenter
                        name: "land"
                        size: 15
                        color: landToolBtn.enabled ? CompanyTheme.textSecondary : CompanyTheme.textMuted
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("LAND")
                        color: landToolBtn.enabled ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                        font.pointSize: CompanyTheme.fontTiny - 1
                        font.bold: true
                    }
                }

                MouseArea {
                    id: landMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: landToolBtn.enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (CompanyTelemetry.hasVehicle && root._isArmed) {
                            root.requestActionConfirmation("LAND")
                        }
                    }
                }

                ToolTip.visible: landMouseArea.containsMouse
                ToolTip.delay: 300
                ToolTip.text: qsTr("Land at Current Position")
            }

            // Toolstrip Divider
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 1
                Layout.alignment: Qt.AlignHCenter
                color: CompanyTheme.borderCard
            }

            // Tool 5: JUMP TO MISSIONS (PLAN)
            Rectangle {
                id: planToolBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: CompanyTheme.radiusSm
                color: planMouseArea.containsMouse ? CompanyTheme.bgCardHover : "transparent"
                border.color: planMouseArea.containsMouse ? CompanyTheme.borderActive : "transparent"
                border.width: 1

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    IconVector {
                        Layout.alignment: Qt.AlignHCenter
                        name: "missions"
                        size: 15
                        color: planMouseArea.containsMouse ? CompanyTheme.primary : CompanyTheme.textSecondary
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("PLAN")
                        color: planMouseArea.containsMouse ? CompanyTheme.textPrimary : CompanyTheme.textSecondary
                        font.pointSize: CompanyTheme.fontTiny - 1
                        font.bold: true
                    }
                }

                MouseArea {
                    id: planMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.navigateToTab(2) // Jump to Missions Planner
                }

                ToolTip.visible: planMouseArea.containsMouse
                ToolTip.delay: 300
                ToolTip.text: qsTr("Switch to Mission Planner")
            }
        }
    }

    // ------------------------------------------------------------------------
    // 4. Floating Bottom Operational Telemetry Strip (QGC HUD Bar)
    // ------------------------------------------------------------------------
    Rectangle {
        id: bottomTelemetryStrip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: CompanyTheme.spacingMd
        z: 10
        height: 44
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgOverlayDark
        border.color: CompanyTheme.borderCard
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: CompanyTheme.spacingMd
            anchors.rightMargin: CompanyTheme.spacingMd
            spacing: CompanyTheme.spacingLg

            // Telemetry Item 1: Altitude (Relative)
            RowLayout {
                spacing: 6
                Text { text: qsTr("ALT:"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny; font.bold: true }
                Text {
                    text: CompanyTelemetry.altitudeRelativeStr
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }
            }

            // Telemetry Item 2: Ground Speed
            RowLayout {
                spacing: 6
                Text { text: qsTr("GS:"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny; font.bold: true }
                Text {
                    text: CompanyTelemetry.groundSpeedStr
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }
            }

            // Telemetry Item 3: Climb Rate (VSI)
            RowLayout {
                spacing: 6
                Text { text: qsTr("VSI:"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny; font.bold: true }
                Text {
                    text: CompanyTelemetry.climbRateStr
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }
            }

            // Telemetry Item 4: Heading
            RowLayout {
                spacing: 6
                Text { text: qsTr("HDG:"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny; font.bold: true }
                Text {
                    text: CompanyTelemetry.headingStr
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }
            }

            // Telemetry Item 5: Flight Mode
            RowLayout {
                spacing: 6
                Text { text: qsTr("MODE:"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny; font.bold: true }
                Text {
                    text: root._hasVehicle && root._flightMode !== "" ? root._flightMode.toUpperCase() : "--"
                    color: CompanyTheme.primary
                    font.pointSize: CompanyTheme.fontSmall
                    font.bold: true
                }
            }

            // Spacer to push right-hand status indicators
            Item { Layout.fillWidth: true }

            // Telemetry Item 6: Battery
            RowLayout {
                spacing: 6
                IconVector { name: "battery"; size: 14; color: CompanyTheme.textSecondary }
                Text {
                    text: CompanyTelemetry.batteryPercentStr
                    color: {
                        if (!CompanyTelemetry.hasBattery) return CompanyTheme.textMuted
                        var pct = CompanyTelemetry.batteryPercent
                        if (pct > 30) return CompanyTheme.success
                        if (pct > 15) return CompanyTheme.warning
                        return CompanyTheme.danger
                    }
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }
            }

            // Telemetry Item 7: GPS Satellites
            RowLayout {
                spacing: 6
                IconVector { name: "satellite"; size: 14; color: CompanyTheme.textSecondary }
                Text {
                    text: {
                        if (!CompanyTelemetry.hasVehicle) return "--"
                        var countStr = CompanyTelemetry.gpsCountStr
                        if (CompanyTelemetry.gpsLockString !== "" && CompanyTelemetry.gpsLockString !== "No Fix" && CompanyTelemetry.gpsLockString !== "--") {
                            countStr += " (" + CompanyTelemetry.gpsLockString + ")"
                        }
                        return countStr
                    }
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                }
            }

            // Telemetry Item 8: Link Quality
            RowLayout {
                spacing: 6
                IconVector { name: "signal"; size: 14; color: CompanyTheme.textSecondary }
                Text {
                    text: {
                        if (!CompanyTelemetry.hasVehicle) return "--%"
                        if (CompanyTelemetry.communicationLost) return "LOST"
                        return CompanyTelemetry.linkQualityPercent + "%"
                    }
                    color: {
                        if (!CompanyTelemetry.hasVehicle) return CompanyTheme.textMuted
                        if (CompanyTelemetry.communicationLost) return CompanyTheme.danger
                        return CompanyTheme.success
                    }
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    // 5. Flight-Critical Safety Confirmation Modal Overlay
    // ------------------------------------------------------------------------
    Rectangle {
        id: confirmModalOverlay
        anchors.fill: parent
        z: 100
        visible: root._confirmDialogOpen
        color: Qt.rgba(0.04, 0.07, 0.10, 0.75)

        // Block all pointer events from reaching underlying dashboard views
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            onClicked: root.cancelActionConfirmation()
        }

        Rectangle {
            id: confirmModalCard
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 420)
            implicitHeight: modalColumn.implicitHeight + CompanyTheme.spacingLg * 2
            radius: CompanyTheme.radiusMd
            color: CompanyTheme.bgCardElevated
            border.color: root._confirmColor
            border.width: 1

            // Prevent clicks inside modal card from dismissing it
            MouseArea {
                anchors.fill: parent
                onClicked: { } // consume click
            }

            ColumnLayout {
                id: modalColumn
                anchors.fill: parent
                anchors.margins: CompanyTheme.spacingLg
                spacing: CompanyTheme.spacingMd

                // Header with icon, title, and action badge
                RowLayout {
                    Layout.fillWidth: true
                    spacing: CompanyTheme.spacingSm

                    IconVector {
                        name: root._confirmIcon !== "" ? root._confirmIcon : "warning"
                        size: 20
                        color: root._confirmColor
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root._confirmTitle
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontH3
                        font.bold: true
                    }

                    StatusBadge {
                        text: root._confirmActionType
                        badgeColor: root._confirmColor
                        showDot: true
                    }
                }

                // Divider line
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: CompanyTheme.borderCard
                }

                // Description / Warning message
                Text {
                    Layout.fillWidth: true
                    text: root._confirmMessage
                    color: CompanyTheme.textSecondary
                    font.pointSize: CompanyTheme.fontBody
                    wrapMode: Text.WordWrap
                    lineHeight: 1.2
                }

                // Vehicle Status Context Pill
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: CompanyTheme.radiusSm
                    color: CompanyTheme.bgInput
                    border.color: CompanyTheme.borderSubtle
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: CompanyTheme.spacingSm
                        anchors.rightMargin: CompanyTheme.spacingSm

                        Text {
                            text: qsTr("Target: UAS #%1").arg(CompanyTelemetry.vehicleId)
                            color: CompanyTheme.textPrimary
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: CompanyTelemetry.armed ? (CompanyTelemetry.flying ? qsTr("AIRBORNE") : qsTr("ARMED")) : qsTr("DISARMED")
                            color: CompanyTelemetry.armed ? CompanyTheme.danger : CompanyTheme.warning
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                        }

                        Text {
                            text: "•"
                            color: CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontSmall
                        }

                        Text {
                            text: CompanyTelemetry.flightMode.toUpperCase()
                            color: CompanyTheme.primary
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                        }
                    }
                }

                // Action buttons: Cancel and Confirm
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: CompanyTheme.spacingSm
                    spacing: CompanyTheme.spacingMd

                    CompanyButton {
                        Layout.fillWidth: true
                        text: qsTr("Cancel")
                        isOutline: true
                        onClicked: root.cancelActionConfirmation()
                    }

                    CompanyButton {
                        Layout.fillWidth: true
                        text: qsTr("Confirm %1").arg(root._confirmActionType)
                        isDanger: root._confirmActionType === "ARM" || root._confirmActionType === "DISARM"
                        isPrimary: root._confirmActionType !== "ARM" && root._confirmActionType !== "DISARM"
                        customColor: root._confirmColor
                        onClicked: root.executeConfirmedAction()
                    }
                }
            }
        }
    }
}

