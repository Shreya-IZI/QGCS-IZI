pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import Company.UI
import "controls"

// ============================================================================
// Enterprise Safety & Failsafes Dashboard Modal
// Real-time inspection of RC loss, GCS telemetry loss, battery failsafe,
// and geofence breach settings, plus emergency action triggers.
// ============================================================================
Item {
    id: root

    property bool isOpen: false

    signal closed()
    signal flightActionRequested(string actionType)
    signal configureSafetyRequested()

    visible: isOpen || backdrop.opacity > 0
    anchors.fill: parent
    z: 1000

    FactPanelController {
        id: controller
    }

    // --- Safety Parameter Fact Resolvers (ArduPilot & PX4) ---
    readonly property var factFsThrEnable:   controller.getParameterFact(-1, "FS_THR_ENABLE", false)
    readonly property var factNavRclAct:     controller.getParameterFact(-1, "NAV_RCL_ACT", false)
    readonly property var factFsGcsEnable:   controller.getParameterFact(-1, "FS_GCS_ENABLE", false)
    readonly property var factNavDllAct:     controller.getParameterFact(-1, "NAV_DLL_ACT", false)
    readonly property var factBattFsLow:     controller.getParameterFact(-1, "BATT_FS_LOW_ACT", false)
    readonly property var factBattFsCrit:    controller.getParameterFact(-1, "BATT_FS_CRT_ACT", false)
    readonly property var factComLowBatAct:  controller.getParameterFact(-1, "COM_LOW_BAT_ACT", false)
    readonly property var factBattLowVolt:   controller.getParameterFact(-1, "BATT_LOW_VOLT", false)
    readonly property var factBattCrtVolt:   controller.getParameterFact(-1, "BATT_CRT_VOLT", false)
    readonly property var factFenceEnable:   controller.getParameterFact(-1, "FENCE_ENABLE", false)
    readonly property var factFenceAction:   controller.getParameterFact(-1, "FENCE_ACTION", false)
    readonly property var factGfAction:      controller.getParameterFact(-1, "GF_ACTION", false)
    readonly property var factRtlAltM:       controller.getParameterFact(-1, "RTL_ALT_M", false)
    readonly property var factRtlAlt:        controller.getParameterFact(-1, "RTL_ALT", false)
    readonly property var factRtlReturnAlt:  controller.getParameterFact(-1, "RTL_RETURN_ALT", false)

    // Formatted Failsafe Strings
    function getRcFailsafeAction() {
        if (factFsThrEnable && factFsThrEnable.value !== undefined) {
            switch (factFsThrEnable.value) {
            case 0: return qsTr("Disabled / Ignored")
            case 1: return qsTr("Always RTL (Return to Launch)")
            case 2: return qsTr("Continue in AUTO, else RTL")
            case 3: return qsTr("Always Land Immediately")
            case 4: return qsTr("SmartRTL or RTL")
            case 5: return qsTr("SmartRTL or Land")
            default: return qsTr("Configured (Code %1)").arg(factFsThrEnable.value)
            }
        }
        if (factNavRclAct && factNavRclAct.value !== undefined) {
            switch (factNavRclAct.value) {
            case 0: return qsTr("Disabled")
            case 1: return qsTr("Hold / Loiter")
            case 2: return qsTr("RTL (Return to Launch)")
            case 3: return qsTr("Land Immediately")
            case 4: return qsTr("Flight Termination")
            case 5: return qsTr("Disarm")
            default: return qsTr("PX4 Action %1").arg(factNavRclAct.value)
            }
        }
        return CompanyTelemetry.hasVehicle ? qsTr("Active (Flight Controller Managed)") : qsTr("No Vehicle Connected")
    }

    function getGcsFailsafeAction() {
        if (factFsGcsEnable && factFsGcsEnable.value !== undefined) {
            switch (factFsGcsEnable.value) {
            case 0: return qsTr("Disabled (Warning Only)")
            case 1: return qsTr("Always RTL (Return to Launch)")
            case 2: return qsTr("Continue in AUTO, else RTL")
            case 3: return qsTr("SmartRTL or RTL")
            case 4: return qsTr("SmartRTL or Land")
            case 5: return qsTr("Always Land Immediately")
            default: return qsTr("Configured (Code %1)").arg(factFsGcsEnable.value)
            }
        }
        if (factNavDllAct && factNavDllAct.value !== undefined) {
            switch (factNavDllAct.value) {
            case 0: return qsTr("Disabled")
            case 1: return qsTr("Hold / Loiter")
            case 2: return qsTr("RTL (Return to Launch)")
            case 3: return qsTr("Land Immediately")
            case 4: return qsTr("Flight Termination")
            default: return qsTr("PX4 Action %1").arg(factNavDllAct.value)
            }
        }
        return CompanyTelemetry.hasVehicle ? qsTr("Active (Heartbeat Timeout Managed)") : qsTr("No Vehicle Connected")
    }

    function getBatteryFailsafeSummary() {
        var actions = []
        if (factBattFsLow && factBattFsLow.value !== undefined) {
            var lowAct = ""
            switch (factBattFsLow.value) {
            case 0: lowAct = qsTr("Warning Only"); break
            case 1: lowAct = qsTr("Land"); break
            case 2: lowAct = qsTr("RTL"); break
            case 3: lowAct = qsTr("SmartRTL/RTL"); break
            case 4: lowAct = qsTr("SmartRTL/Land"); break
            case 5: lowAct = qsTr("Terminate"); break
            default: lowAct = qsTr("Action %1").arg(factBattFsLow.value); break
            }
            var lowVolt = (factBattLowVolt && factBattLowVolt.value > 0) ? (factBattLowVolt.value.toFixed(1) + "V") : "20%"
            actions.push(qsTr("Low: %1 (%2)").arg(lowAct, lowVolt))
        }
        if (factBattFsCrit && factBattFsCrit.value !== undefined) {
            var critAct = ""
            switch (factBattFsCrit.value) {
            case 0: critAct = qsTr("Warning Only"); break
            case 1: critAct = qsTr("Land Immediately"); break
            case 2: critAct = qsTr("RTL"); break
            case 5: critAct = qsTr("Terminate"); break
            default: critAct = qsTr("Action %1").arg(factBattFsCrit.value); break
            }
            var critVolt = (factBattCrtVolt && factBattCrtVolt.value > 0) ? (factBattCrtVolt.value.toFixed(1) + "V") : "10%"
            actions.push(qsTr("Critical: %1 (%2)").arg(critAct, critVolt))
        }
        if (factComLowBatAct && factComLowBatAct.value !== undefined) {
            switch (factComLowBatAct.value) {
            case 0: actions.push(qsTr("Warning Only")); break
            case 1: actions.push(qsTr("RTL on Low Battery")); break
            case 2: actions.push(qsTr("Land on Low Battery")); break
            default: break
            }
        }
        if (actions.length > 0) {
            return actions.join(" • ")
        }
        return CompanyTelemetry.hasVehicle ? qsTr("Smart Auto-RTL on Low Battery") : qsTr("No Vehicle Connected")
    }

    function getGeofenceSummary() {
        var enabled = false
        if (factFenceEnable && factFenceEnable.value !== undefined) {
            enabled = (factFenceEnable.value > 0)
        }
        var actStr = ""
        if (factFenceAction && factFenceAction.value !== undefined) {
            switch (factFenceAction.value) {
            case 0: actStr = qsTr("Report / Log Only"); break
            case 1: actStr = qsTr("RTL or Land"); break
            case 2: actStr = qsTr("Land"); break
            case 3: actStr = qsTr("SmartRTL / RTL"); break
            case 4: actStr = qsTr("Brake / Hold"); break
            default: actStr = qsTr("Breach Action %1").arg(factFenceAction.value); break
            }
        } else if (factGfAction && factGfAction.value !== undefined) {
            switch (factGfAction.value) {
            case 0: actStr = qsTr("None"); break
            case 1: actStr = qsTr("Warning"); break
            case 2: actStr = qsTr("Hold"); break
            case 3: actStr = qsTr("Return (RTL)"); break
            case 4: actStr = qsTr("Land"); break
            default: actStr = qsTr("PX4 GF %1").arg(factGfAction.value); break
            }
        }

        if (enabled) {
            return actStr !== "" ? qsTr("ENABLED • Action: %1").arg(actStr) : qsTr("ENABLED")
        }
        return qsTr("DISABLED (Configured via Flight Controller)")
    }

    function getRtlAltitudeSummary() {
        if (factRtlAltM && factRtlAltM.value !== undefined) {
            return factRtlAltM.value > 0 ? (factRtlAltM.value + " m AGL") : qsTr("Current Flight Altitude")
        }
        if (factRtlAlt && factRtlAlt.value !== undefined) {
            // cm to meters
            var altM = factRtlAlt.value / 100.0
            return altM > 0 ? (altM.toFixed(1) + " m AGL") : qsTr("Current Flight Altitude")
        }
        if (factRtlReturnAlt && factRtlReturnAlt.value !== undefined) {
            return factRtlReturnAlt.value + " m AGL"
        }
        return qsTr("30.0 m AGL (Default)")
    }

    // --- Dimmed Backdrop ---
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#E0000000"
        opacity: root.isOpen ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    // --- Modal Window Container ---
    Rectangle {
        id: modalCard
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 760)
        height: Math.min(parent.height - 48, 640)
        radius: CompanyTheme.radiusMd
        color: CompanyTheme.bgCardElevated
        border.color: CompanyTheme.borderActive
        border.width: 1.5
        clip: true

        scale: root.isOpen ? 1.0 : 0.95
        opacity: root.isOpen ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        // Catch clicks inside card to prevent backdrop dismiss
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: CompanyTheme.spacingLg
            spacing: CompanyTheme.spacingMd

            // 1. Header Bar: Title, Shield Icon, Status Badge, Close Button
            RowLayout {
                Layout.fillWidth: true
                spacing: CompanyTheme.spacingSm

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: CompanyTheme.radiusSm
                    color: Qt.rgba(CompanyTheme.primary.r, CompanyTheme.primary.g, CompanyTheme.primary.b, 0.15)
                    border.color: CompanyTheme.primary
                    border.width: 1

                    IconVector {
                        anchors.centerIn: parent
                        name: "shield"
                        size: 20
                        color: CompanyTheme.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: qsTr("FLIGHT SAFETY & FAILSAFE DASHBOARD")
                        color: CompanyTheme.textPrimary
                        font.pointSize: 13
                        font.bold: true
                        font.letterSpacing: 0.8
                    }

                    Text {
                        text: {
                            if (!CompanyTelemetry.hasVehicle) return qsTr("STANDBY • NO VEHICLE CONNECTED")
                            return qsTr("UAS #%1 • %2 • %3 • FIX: %4").arg(
                                CompanyTelemetry.vehicleId,
                                CompanyTelemetry.armed ? qsTr("ARMED") : qsTr("DISARMED"),
                                CompanyTelemetry.flightMode.toUpperCase(),
                                CompanyTelemetry.gpsFixType
                            )
                        }
                        color: CompanyTelemetry.hasVehicle ? (CompanyTelemetry.armed ? CompanyTheme.danger : CompanyTheme.success) : CompanyTheme.textMuted
                        font.pointSize: CompanyTheme.fontTiny
                        font.family: CompanyTheme.fontMono
                        font.bold: true
                    }
                }

                // Close Button
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: CompanyTheme.radiusSm
                    color: closeMouse.containsMouse ? CompanyTheme.bgCardHover : "transparent"
                    border.color: closeMouse.containsMouse ? CompanyTheme.borderCard : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: CompanyTheme.textSecondary
                        font.pointSize: 14
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closed()
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: CompanyTheme.borderCard
            }

            // 2. Failsafe Matrix: 4 High-Reliability Status Cards
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: CompanyTheme.spacingMd
                columnSpacing: CompanyTheme.spacingMd

                // --- Card 1: RC Link Loss Failsafe ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: CompanyTheme.radiusSm
                    color: CompanyTheme.bgCard
                    border.color: CompanyTheme.borderCard
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: CompanyTheme.spacingMd
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            IconVector {
                                name: "rc"
                                size: 16
                                color: CompanyTelemetry.hasRcRSSI ? CompanyTheme.success : CompanyTheme.warning
                            }

                            Text {
                                text: qsTr("RC CONTROLLER LOSS")
                                color: CompanyTheme.textPrimary
                                font.pointSize: 11
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredHeight: 20
                                implicitWidth: rcStatusText.implicitWidth + 12
                                radius: 10
                                color: Qt.rgba(CompanyTheme.success.r, CompanyTheme.success.g, CompanyTheme.success.b, 0.15)
                                border.color: CompanyTheme.success
                                border.width: 1

                                Text {
                                    id: rcStatusText
                                    anchors.centerIn: parent
                                    text: CompanyTelemetry.hasRcRSSI ? qsTr("CONNECTED") : qsTr("STANDBY")
                                    color: CompanyTheme.success
                                    font.pointSize: 9
                                    font.bold: true
                                }
                            }
                        }

                        Text {
                            text: qsTr("Failsafe Action:")
                            color: CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontTiny
                        }

                        Text {
                            text: root.getRcFailsafeAction()
                            color: CompanyTheme.info
                            font.pointSize: 11
                            font.bold: true
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Item { Layout.fillHeight: true }

                        Text {
                            text: CompanyTelemetry.hasRcRSSI ? qsTr("Signal: %1").arg(CompanyTelemetry.rcRSSIStr) : qsTr("Receiver: Monitored via MAVLink")
                            color: CompanyTheme.textSecondary
                            font.pointSize: 9
                            font.family: CompanyTheme.fontMono
                        }
                    }
                }

                // --- Card 2: Telemetry / Data Link Loss Failsafe ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: CompanyTheme.radiusSm
                    color: CompanyTheme.bgCard
                    border.color: CompanyTelemetry.communicationLost ? CompanyTheme.danger : CompanyTheme.borderCard
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: CompanyTheme.spacingMd
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            IconVector {
                                name: "signal"
                                size: 16
                                color: CompanyTelemetry.communicationLost ? CompanyTheme.danger : CompanyTheme.success
                            }

                            Text {
                                text: qsTr("GCS TELEMETRY LOSS")
                                color: CompanyTheme.textPrimary
                                font.pointSize: 11
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredHeight: 20
                                implicitWidth: gcsStatusText.implicitWidth + 12
                                radius: 10
                                color: CompanyTelemetry.communicationLost ? Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.18) : Qt.rgba(CompanyTheme.success.r, CompanyTheme.success.g, CompanyTheme.success.b, 0.15)
                                border.color: CompanyTelemetry.communicationLost ? CompanyTheme.danger : CompanyTheme.success
                                border.width: 1

                                Text {
                                    id: gcsStatusText
                                    anchors.centerIn: parent
                                    text: CompanyTelemetry.communicationLost ? qsTr("LINK LOST") : qsTr("ONLINE")
                                    color: CompanyTelemetry.communicationLost ? CompanyTheme.danger : CompanyTheme.success
                                    font.pointSize: 9
                                    font.bold: true
                                }
                            }
                        }

                        Text {
                            text: qsTr("Failsafe Action:")
                            color: CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontTiny
                        }

                        Text {
                            text: root.getGcsFailsafeAction()
                            color: CompanyTheme.info
                            font.pointSize: 11
                            font.bold: true
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Item { Layout.fillHeight: true }

                        Text {
                            text: qsTr("Link Quality: %1% • Loss: %2%").arg(CompanyTelemetry.linkQualityPercent).arg(Math.round(CompanyTelemetry.mavlinkLossPercent))
                            color: CompanyTelemetry.isSignalCritical ? CompanyTheme.danger : CompanyTheme.textSecondary
                            font.pointSize: 9
                            font.family: CompanyTheme.fontMono
                        }
                    }
                }

                // --- Card 3: Battery Low & Critical Failsafe ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: CompanyTheme.radiusSm
                    color: CompanyTheme.bgCard
                    border.color: CompanyTelemetry.isBatteryCritical ? CompanyTheme.danger : (CompanyTelemetry.isBatteryLow ? CompanyTheme.warning : CompanyTheme.borderCard)
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: CompanyTheme.spacingMd
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            IconVector {
                                name: "battery"
                                size: 16
                                color: CompanyTelemetry.isBatteryCritical ? CompanyTheme.danger : (CompanyTelemetry.isBatteryLow ? CompanyTheme.warning : CompanyTheme.success)
                            }

                            Text {
                                text: qsTr("BATTERY FAILSAFES")
                                color: CompanyTheme.textPrimary
                                font.pointSize: 11
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredHeight: 20
                                implicitWidth: battStatusText.implicitWidth + 12
                                radius: 10
                                color: CompanyTelemetry.isBatteryCritical ? Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.2) : Qt.rgba(CompanyTheme.success.r, CompanyTheme.success.g, CompanyTheme.success.b, 0.15)
                                border.color: CompanyTelemetry.isBatteryCritical ? CompanyTheme.danger : CompanyTheme.success
                                border.width: 1

                                Text {
                                    id: battStatusText
                                    anchors.centerIn: parent
                                    text: CompanyTelemetry.batteryPercentStr
                                    color: CompanyTelemetry.isBatteryCritical ? CompanyTheme.danger : CompanyTheme.textPrimary
                                    font.pointSize: 9
                                    font.bold: true
                                    font.family: CompanyTheme.fontMono
                                }
                            }
                        }

                        Text {
                            text: qsTr("Failsafe Actions & Triggers:")
                            color: CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontTiny
                        }

                        Text {
                            text: root.getBatteryFailsafeSummary()
                            color: CompanyTheme.info
                            font.pointSize: 11
                            font.bold: true
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Item { Layout.fillHeight: true }

                        Text {
                            text: qsTr("Pack: %1 • Endurance: %2 • Temp: %3").arg(
                                CompanyTelemetry.batteryVoltageStr,
                                CompanyTelemetry.batteryEnduranceShortStr,
                                CompanyTelemetry.batteryTemperature > 0 ? (CompanyTelemetry.batteryTemperature.toFixed(0) + "°C") : "NORM"
                            )
                            color: CompanyTheme.textSecondary
                            font.pointSize: 9
                            font.family: CompanyTheme.fontMono
                        }
                    }
                }

                // --- Card 4: Geofence & RTL Altitude Settings ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: CompanyTheme.radiusSm
                    color: CompanyTheme.bgCard
                    border.color: CompanyTheme.borderCard
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: CompanyTheme.spacingMd
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            IconVector {
                                name: "shield"
                                size: 16
                                color: CompanyTheme.primary
                            }

                            Text {
                                text: qsTr("GEOFENCE & RTL PROFILE")
                                color: CompanyTheme.textPrimary
                                font.pointSize: 11
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredHeight: 20
                                implicitWidth: gfStatusText.implicitWidth + 12
                                radius: 10
                                color: Qt.rgba(CompanyTheme.primary.r, CompanyTheme.primary.g, CompanyTheme.primary.b, 0.15)
                                border.color: CompanyTheme.primary
                                border.width: 1

                                Text {
                                    id: gfStatusText
                                    anchors.centerIn: parent
                                    text: qsTr("RTL: %1").arg(root.getRtlAltitudeSummary())
                                    color: CompanyTheme.primary
                                    font.pointSize: 9
                                    font.bold: true
                                    font.family: CompanyTheme.fontMono
                                }
                            }
                        }

                        Text {
                            text: qsTr("Geofence Containment:")
                            color: CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontTiny
                        }

                        Text {
                            text: root.getGeofenceSummary()
                            color: CompanyTheme.info
                            font.pointSize: 11
                            font.bold: true
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Item { Layout.fillHeight: true }

                        Text {
                            text: qsTr("RTL Minimum Return Climb: %1").arg(root.getRtlAltitudeSummary())
                            color: CompanyTheme.textSecondary
                            font.pointSize: 9
                            font.family: CompanyTheme.fontMono
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: CompanyTheme.borderCard
            }

            // 3. Emergency Actions Bottom Row: RTL, Land, E-Stop, Configure
            RowLayout {
                Layout.fillWidth: true
                spacing: CompanyTheme.spacingSm

                CompanyButton {
                    text: qsTr("Full Vehicle Setup...")
                    isOutline: true
                    onClicked: {
                        root.closed()
                        root.configureSafetyRequested()
                    }
                }

                Item { Layout.fillWidth: true }

                // Quick RTL
                CompanyButton {
                    text: qsTr("TRIGGER RTL")
                    enabled: CompanyTelemetry.hasVehicle && CompanyTelemetry.armed
                    customColor: CompanyTheme.warning
                    onClicked: {
                        root.closed()
                        root.flightActionRequested("RTL")
                    }
                }

                // Quick Land
                CompanyButton {
                    text: qsTr("TRIGGER LAND")
                    enabled: CompanyTelemetry.hasVehicle && CompanyTelemetry.armed
                    customColor: CompanyTheme.warning
                    onClicked: {
                        root.closed()
                        root.flightActionRequested("LAND")
                    }
                }

                // EMERGENCY MOTOR KILL
                CompanyButton {
                    text: qsTr("KILL MOTORS (E-STOP)")
                    enabled: CompanyTelemetry.hasVehicle && CompanyTelemetry.armed
                    isDanger: true
                    onClicked: {
                        root.closed()
                        root.flightActionRequested("EMERGENCY_STOP")
                    }
                }
            }
        }
    }
}
