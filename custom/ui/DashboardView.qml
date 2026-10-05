pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import Company.UI

Item {
    id: root

    property string currentSubView: "MAP" // "MAP", "PFD", "CAM", "SYSTEM"
    signal navigateToTab(int tabIndex)

    readonly property bool _hasVehicle:         CompanyTelemetry.hasVehicle
    readonly property bool _isArmed:            CompanyTelemetry.armed
    readonly property bool _isFlying:           CompanyTelemetry.flying
    readonly property string _flightMode:       CompanyTelemetry.flightMode
    readonly property real _heading:            CompanyTelemetry.heading
    readonly property bool _isNarrow:           width < 1024 || ScreenTools.isMobile

    // ------------------------------------------------------------------------
    // Safety Confirmation Interlock State & Handlers
    // ------------------------------------------------------------------------
    property bool   _confirmDialogOpen: false
    property string _confirmActionType: "" // "ARM", "DISARM", "HOLD", "RTL", "LAND", "START_MISSION"
    property string _confirmTitle:      ""
    property string _confirmMessage:    ""
    property color  _confirmColor:      CompanyTheme.warning
    property string _confirmIcon:       ""
    property bool   _isExecutingAction: false

    // Safety Feedback / Abort Notification Toast
    property string _safetyNotificationText:    ""
    property color  _safetyNotificationColor:   CompanyTheme.danger
    property bool   _safetyNotificationVisible: false

    function showSafetyNotification(message, isError) {
        _safetyNotificationText = message
        _safetyNotificationColor = (isError === undefined || isError) ? CompanyTheme.danger : CompanyTheme.warning
        _safetyNotificationVisible = true
        safetyNotificationTimer.restart()
    }

    Timer {
        id: safetyNotificationTimer
        interval: 4500
        repeat: false
        onTriggered: root._safetyNotificationVisible = false
    }

    function invalidateConfirmation(reasonMessage) {
        if (!_confirmDialogOpen) return
        _confirmDialogOpen = false
        _confirmActionType = ""
        if (reasonMessage && reasonMessage !== "") {
            showSafetyNotification(reasonMessage, true)
        }
    }

    // Reactive invalidation connections
    Connections {
        target: CompanyTelemetry
        function onHasVehicleChanged() {
            if (root._confirmDialogOpen && !CompanyTelemetry.hasVehicle) {
                root.invalidateConfirmation(qsTr("Command cancelled — vehicle disconnected."))
            }
        }
        function onCommunicationLostChanged() {
            if (root._confirmDialogOpen && CompanyTelemetry.communicationLost) {
                root.invalidateConfirmation(qsTr("Command cancelled — telemetry link lost."))
            }
        }
        function onIsAirborneChanged() {
            if (root._confirmDialogOpen) {
                if (root._confirmActionType === "DISARM" && CompanyTelemetry.isAirborne) {
                    root.invalidateConfirmation(qsTr("DISARM ABORTED — UAS IS AIRBORNE"))
                } else if (root._confirmActionType === "ARM" && CompanyTelemetry.isAirborne) {
                    root.invalidateConfirmation(qsTr("ARM ABORTED — UAS IS AIRBORNE"))
                }
            }
        }
        function onIsGroundedChanged() {
            if (root._confirmDialogOpen && (root._confirmActionType === "ARM" || root._confirmActionType === "DISARM")) {
                if (!CompanyTelemetry.isGrounded) {
                    root.invalidateConfirmation(qsTr("Command cancelled — vehicle no longer grounded."))
                }
            }
        }
    }

    function requestActionConfirmation(actionType) {
        if (_isExecutingAction) return

        // 1. Connection & Comms Pre-check
        if (!CompanyTelemetry.hasVehicle || !CompanyTelemetry.activeVehicle) {
            showSafetyNotification(qsTr("Command unavailable — no vehicle connected."))
            return
        }
        if (CompanyTelemetry.communicationLost || !CompanyTelemetry.communicationValid) {
            showSafetyNotification(qsTr("Command unavailable — telemetry link lost."))
            return
        }

        _confirmActionType = actionType
        switch (actionType) {
        case "ARM":
            if (CompanyTelemetry.isAirborne) {
                showSafetyNotification(qsTr("ARM ABORTED — UAS is airborne."))
                return
            }
            if (CompanyTelemetry.armed) {
                showSafetyNotification(qsTr("Vehicle is already armed."))
                return
            }
            _confirmTitle = qsTr("Confirm Vehicle Arming")
            _confirmMessage = qsTr("Are you sure you want to ARM UAS #%1? Motors will spin if armed.").arg(CompanyTelemetry.vehicleId)
            _confirmColor = CompanyTheme.danger
            _confirmIcon = "arm"
            break

        case "DISARM":
            // STRICT SAFETY INVARIANT: Standard DISARM is strictly ground-only!
            if (CompanyTelemetry.isAirborne || !CompanyTelemetry.isGrounded) {
                showSafetyNotification(qsTr("DISARM ABORTED — UAS IS AIRBORNE"))
                return
            }
            if (!CompanyTelemetry.armed) {
                showSafetyNotification(qsTr("Vehicle is already disarmed."))
                return
            }
            _confirmTitle = qsTr("Confirm Vehicle Disarm")
            _confirmMessage = qsTr("Are you sure you want to DISARM UAS #%1?").arg(CompanyTelemetry.vehicleId)
            _confirmColor = CompanyTheme.danger
            _confirmIcon = "arm"
            break

        case "HOLD":
        case "PAUSE":
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

        case "START_MISSION":
            _confirmTitle = qsTr("Confirm Mission Start")
            _confirmMessage = qsTr("Start the uploaded mission for UAS #%1?\nThe vehicle may begin autonomous flight.").arg(CompanyTelemetry.vehicleId)
            _confirmColor = CompanyTheme.primary
            _confirmIcon = "flight"
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

        // 1. Connection & Comms Validation Immediately Before Execution
        if (!CompanyTelemetry.hasVehicle || !CompanyTelemetry.activeVehicle) {
            showSafetyNotification(qsTr("Command aborted — no active vehicle connected."))
            _isExecutingAction = false
            return
        }

        if (CompanyTelemetry.communicationLost || !CompanyTelemetry.communicationValid) {
            showSafetyNotification(qsTr("Command cancelled — telemetry link lost."))
            _isExecutingAction = false
            return
        }

        var vehicle = CompanyTelemetry.activeVehicle

        // 2. Action-Specific Live Revalidation Immediately Before Execution
        switch (action) {
        case "ARM":
            if (CompanyTelemetry.isAirborne || !CompanyTelemetry.isGrounded) {
                showSafetyNotification(qsTr("ARM ABORTED — UAS is airborne or not grounded."))
                _isExecutingAction = false
                return
            }
            if (CompanyTelemetry.armed) {
                showSafetyNotification(qsTr("ARM ABORTED — Vehicle is already armed."))
                _isExecutingAction = false
                return
            }
            vehicle.armed = true
            break

        case "DISARM":
            // STRICT SAFETY INVARIANT: Standard DISARM must never execute while airborne!
            if (CompanyTelemetry.isAirborne || !CompanyTelemetry.isGrounded) {
                showSafetyNotification(qsTr("DISARM ABORTED — UAS IS AIRBORNE"))
                _isExecutingAction = false
                return
            }
            if (!CompanyTelemetry.armed) {
                showSafetyNotification(qsTr("DISARM ABORTED — Vehicle is already disarmed."))
                _isExecutingAction = false
                return
            }
            vehicle.armed = false
            break

        case "HOLD":
        case "PAUSE":
            if (!CompanyTelemetry.armed) {
                showSafetyNotification(qsTr("HOLD ABORTED — Vehicle is disarmed."))
                _isExecutingAction = false
                return
            }
            vehicle.pauseVehicle()
            break

        case "RTL":
            if (!CompanyTelemetry.armed) {
                showSafetyNotification(qsTr("RTL ABORTED — Vehicle is disarmed."))
                _isExecutingAction = false
                return
            }
            vehicle.guidedModeRTL(false)
            break

        case "LAND":
            if (!CompanyTelemetry.armed) {
                showSafetyNotification(qsTr("LAND ABORTED — Vehicle is disarmed."))
                _isExecutingAction = false
                return
            }
            vehicle.guidedModeLand()
            break

        case "START_MISSION":
            if (!CompanyTelemetry.hasVehicle || !CompanyTelemetry.communicationValid) {
                showSafetyNotification(qsTr("MISSION START ABORTED — Telemetry link lost."))
                _isExecutingAction = false
                return
            }
            vehicle.startMission()
            break

        default:
            break
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

        // Viewport 4: Dual-Camera Surveillance Workspace (RGB & Thermal)
        CameraView {
            anchors.fill: parent
            visible: root.currentSubView === "CAM"
        }
    }

    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------
    // 2. Floating View Switcher Pill (Top Left)
    // ------------------------------------------------------------------------
    Rectangle {
        id: viewSwitcherPill
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: CompanyTheme.spacingMd
        z: 10
        height: 28
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
                    { id: "CAM",    label: qsTr("CAM"),    icon: "video" },
                    { id: "SYSTEM", label: qsTr("SYSTEM"), icon: "settings" }
                ]

                delegate: Rectangle {
                    id: switchBtn
                    required property var modelData

                    readonly property bool isSelected: root.currentSubView === switchBtn.modelData.id
                    readonly property bool isHovered: switchMouseArea.containsMouse

                    Layout.preferredWidth: 64
                    Layout.fillHeight: true
                    radius: CompanyTheme.radiusSm - 1
                    color: {
                        if (switchBtn.isSelected) return CompanyTheme.primaryDim
                        if (switchBtn.isHovered) return CompanyTheme.bgCardHover
                        return "transparent"
                    }
                    border.color: switchBtn.isSelected ? CompanyTheme.borderActive : "transparent"
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        IconVector {
                            name: switchBtn.modelData.icon
                            size: 11
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
    // 3. Floating Bottom Operational Telemetry Strip (Professional Aviation HUD)
    // ------------------------------------------------------------------------
    Rectangle {
        id: bottomTelemetryStrip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: CompanyTheme.spacingMd
        z: 10
        height: 38
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgOverlayDark
        border.color: CompanyTheme.borderCard
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: CompanyTheme.spacingMd
            anchors.rightMargin: CompanyTheme.spacingMd
            spacing: CompanyTheme.spacingMd

            // Column 1: ALT
            RowLayout {
                spacing: 5
                Text { text: "ALT"; color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny; font.bold: true }
                Text {
                    text: CompanyTelemetry.altitudeRelativeStr
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 14; color: CompanyTheme.borderCard }

            // Column 2: GS
            RowLayout {
                spacing: 5
                Text { text: "GS"; color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny; font.bold: true }
                Text {
                    text: CompanyTelemetry.groundSpeedStr
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }
            }

            Rectangle { visible: !root._isNarrow; Layout.preferredWidth: 1; Layout.preferredHeight: 14; color: CompanyTheme.borderCard }

            // Column 3: VS
            RowLayout {
                visible: !root._isNarrow
                spacing: 5
                Text { text: "VS"; color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny; font.bold: true }
                Text {
                    text: CompanyTelemetry.climbRateStr
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }
            }

            Rectangle { visible: !root._isNarrow; Layout.preferredWidth: 1; Layout.preferredHeight: 14; color: CompanyTheme.borderCard }

            // Column 4: HDG
            RowLayout {
                visible: !root._isNarrow
                spacing: 5
                Text { text: "HDG"; color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny; font.bold: true }
                Text {
                    text: CompanyTelemetry.headingStr
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 14; color: CompanyTheme.borderCard }

            // Column 5: MODE
            RowLayout {
                spacing: 5
                Text { text: "MODE"; color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny; font.bold: true }
                Text {
                    text: root._hasVehicle && root._flightMode !== "" ? root._flightMode.toUpperCase() : "STANDBY"
                    color: CompanyTheme.primary
                    font.pointSize: CompanyTheme.fontSmall
                    font.bold: true
                }
            }

            Item { Layout.fillWidth: true }

            // Column 6: LINK
            RowLayout {
                visible: !root._isNarrow
                spacing: 5
                IconVector {
                    name: "signal"
                    size: 13
                    color: {
                        if (!root._hasVehicle) return CompanyTheme.textMuted
                        return CompanyTelemetry.communicationLost ? CompanyTheme.danger : CompanyTheme.success
                    }
                }
                Text { text: "LINK"; color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny; font.bold: true }
                Text {
                    text: {
                        if (!root._hasVehicle) return "--%"
                        if (CompanyTelemetry.communicationLost) return "LOST"
                        return CompanyTelemetry.linkQualityPercent + "%"
                    }
                    color: {
                        if (!root._hasVehicle) return CompanyTheme.textMuted
                        if (CompanyTelemetry.communicationLost) return CompanyTheme.danger
                        return CompanyTheme.textPrimary
                    }
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }
            }

            Rectangle { visible: !root._isNarrow; Layout.preferredWidth: 1; Layout.preferredHeight: 14; color: CompanyTheme.borderCard }

            // Column 7: SATS
            RowLayout {
                visible: !root._isNarrow
                spacing: 5
                IconVector {
                    name: "satellite"
                    size: 13
                    color: {
                        if (!root._hasVehicle) return CompanyTheme.textMuted
                        if (CompanyTelemetry.gpsLock >= 3) return CompanyTheme.success
                        if (CompanyTelemetry.gpsLock >= 2) return CompanyTheme.warning
                        return CompanyTheme.danger
                    }
                }
                Text { text: "SATS"; color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny; font.bold: true }
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

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 14; color: CompanyTheme.borderCard }

            // Column 8: BAT
            RowLayout {
                spacing: 5
                IconVector {
                    name: "battery"
                    size: 13
                    color: {
                        if (!CompanyTelemetry.hasBattery) return CompanyTheme.textMuted
                        var pct = CompanyTelemetry.batteryPercent
                        if (pct > 30) return CompanyTheme.success
                        if (pct > 15) return CompanyTheme.warning
                        return CompanyTheme.danger
                    }
                }
                Text { text: "BAT"; color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny; font.bold: true }
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
                        text: root._confirmActionType === "START_MISSION" ? qsTr("Confirm Mission Start") : qsTr("Confirm %1").arg(root._confirmActionType)
                        isDanger: root._confirmActionType === "ARM" || root._confirmActionType === "DISARM"
                        isPrimary: root._confirmActionType !== "ARM" && root._confirmActionType !== "DISARM"
                        customColor: root._confirmColor
                        onClicked: root.executeConfirmedAction()
                    }
                }
            }
        }
    }

    // ========================================================================
    // Transient Safety Feedback / Abort Notification Toast Banner
    // ========================================================================
    Rectangle {
        id: safetyToast
        anchors.top: parent.top
        anchors.topMargin: CompanyTheme.spacingLg
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 40, toastRow.implicitWidth + 32)
        height: 42
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgCardElevated
        border.color: root._safetyNotificationColor
        border.width: 1.5
        z: 99999
        visible: root._safetyNotificationVisible

        RowLayout {
            id: toastRow
            anchors.centerIn: parent
            spacing: CompanyTheme.spacingSm

            IconVector {
                name: "warning"
                size: 16
                color: root._safetyNotificationColor
            }

            Text {
                text: root._safetyNotificationText
                color: CompanyTheme.textPrimary
                font.pointSize: CompanyTheme.fontSmall
                font.bold: true
            }
        }
    }
}

