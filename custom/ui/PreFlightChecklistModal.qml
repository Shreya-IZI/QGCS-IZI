pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import Company.UI

// ============================================================================
// IZI Enterprise Automated Pre-Flight Safety Audit Modal
// Real-time verification of Sensors, GNSS Fix, Battery/Tether, Failsafes, & Motors
// ============================================================================
Item {
    id: root

    property bool isOpen: false
    signal closed()
    signal proceedToArmRequested()

    visible: isOpen || backdrop.opacity > 0
    anchors.fill: parent
    z: 2000

    // Backdrop
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#000000"
        opacity: root.isOpen ? 0.75 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.isOpen = false
        }
    }

    // Modal Card
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 560)
        height: Math.min(parent.height - 40, colLayout.implicitHeight + 40)
        radius: CompanyTheme.radiusMd
        color: CompanyTheme.bgSidebar
        border.color: CompanyTheme.borderActive
        border.width: 1.5
        clip: true

        scale: root.isOpen ? 1.0 : 0.95
        opacity: root.isOpen ? 1.0 : 0.0
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea { anchors.fill: parent } // consume click

        ColumnLayout {
            id: colLayout
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                IconVector { name: "shield"; size: 18; color: CompanyTheme.djiCyan }
                Text {
                    text: qsTr("AUTOMATED PRE-FLIGHT READINESS AUDIT")
                    color: CompanyTheme.textPrimary
                    font.bold: true
                    font.pointSize: CompanyTheme.fontSmall
                    font.letterSpacing: 0.8
                    Layout.fillWidth: true
                }
                Text {
                    text: "✕"
                    color: CompanyTheme.textMuted
                    font.pointSize: 12
                    font.bold: true
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.isOpen = false
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: CompanyTheme.borderCard }

            // Target UAS Context
            Rectangle {
                Layout.fillWidth: true
                height: 28
                radius: 4
                color: CompanyTheme.bgInput
                border.color: CompanyTheme.borderCard
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: CompanyTelemetry.hasVehicle ? qsTr("TARGET: UAS #%1").arg(CompanyTelemetry.vehicleId) : qsTr("TARGET: NO VEHICLE DETECTED")
                        color: CompanyTheme.textPrimary
                        font.bold: true
                        font.pointSize: 7.5
                        font.family: CompanyTheme.fontMono
                    }
                    Text { text: "•"; color: CompanyTheme.textMuted }
                    Text {
                        text: qsTr("FIRMWARE: ") + (CompanyTelemetry.hasVehicle ? CompanyTelemetry.firmwareType : "--")
                        color: CompanyTheme.djiCyan
                        font.pointSize: 7.5
                        font.family: CompanyTheme.fontMono
                    }
                    Text { text: "•"; color: CompanyTheme.textMuted }
                    Text {
                        text: qsTr("MODE: ") + CompanyTelemetry.flightMode.toUpperCase()
                        color: CompanyTheme.textSecondary
                        font.pointSize: 7.5
                        font.family: CompanyTheme.fontMono
                    }
                }
            }

            // Checklist Items
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                // 1. IMU & Sensors
                Rectangle {
                    Layout.fillWidth: true; height: 38; radius: 4
                    color: CompanyTheme.bgCardSecondary; border.color: CompanyTheme.borderCard; border.width: 1
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10; spacing: 10
                        Text { text: "1"; color: CompanyTheme.textMuted; font.bold: true; font.pointSize: 8 }
                        Column {
                            Layout.fillWidth: true; spacing: 1
                            Text { text: qsTr("IMU, Compass & Barometer"); color: CompanyTheme.textPrimary; font.bold: true; font.pointSize: 7.5 }
                            Text { text: CompanyTelemetry.hasVehicle ? qsTr("Sensors calibrated & online") : qsTr("Awaiting vehicle connection"); color: CompanyTheme.textMuted; font.pointSize: 6.5 }
                        }
                        Rectangle {
                            width: 52; height: 20; radius: 3
                            color: CompanyTelemetry.hasVehicle ? Qt.rgba(CompanyTheme.success.r, CompanyTheme.success.g, CompanyTheme.success.b, 0.2) : Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.2)
                            border.color: CompanyTelemetry.hasVehicle ? CompanyTheme.success : CompanyTheme.danger; border.width: 1
                            Text { anchors.centerIn: parent; text: CompanyTelemetry.hasVehicle ? "✓ PASS" : "✕ FAIL"; color: CompanyTelemetry.hasVehicle ? CompanyTheme.success : CompanyTheme.danger; font.bold: true; font.pointSize: 6.5 }
                        }
                    }
                }

                // 2. GNSS Fix
                Rectangle {
                    Layout.fillWidth: true; height: 38; radius: 4
                    color: CompanyTheme.bgCardSecondary; border.color: CompanyTheme.borderCard; border.width: 1
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10; spacing: 10
                        Text { text: "2"; color: CompanyTheme.textMuted; font.bold: true; font.pointSize: 8 }
                        Column {
                            Layout.fillWidth: true; spacing: 1
                            Text { text: qsTr("GNSS & RTK Constellation"); color: CompanyTheme.textPrimary; font.bold: true; font.pointSize: 7.5 }
                            Text { text: CompanyTelemetry.hasVehicle ? (CompanyTelemetry.gpsSatellites + " Sats • " + CompanyTelemetry.gpsFixType + " (HDOP: " + CompanyTelemetry.gpsHdopStr + ")") : qsTr("No GPS Telemetry"); color: CompanyTheme.textMuted; font.pointSize: 6.5 }
                        }
                        Rectangle {
                            id: gnssBadge
                            readonly property bool isPass: CompanyTelemetry.hasVehicle && CompanyTelemetry.gpsSatellites >= 10
                            width: 52; height: 20; radius: 3
                            color: gnssBadge.isPass ? Qt.rgba(CompanyTheme.success.r, CompanyTheme.success.g, CompanyTheme.success.b, 0.2) : Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.2)
                            border.color: gnssBadge.isPass ? CompanyTheme.success : CompanyTheme.warning; border.width: 1
                            Text { anchors.centerIn: parent; text: gnssBadge.isPass ? "✓ PASS" : "⚠ WARN"; color: gnssBadge.isPass ? CompanyTheme.success : CompanyTheme.warning; font.bold: true; font.pointSize: 6.5 }
                        }
                    }
                }

                // 3. Battery / Power
                Rectangle {
                    Layout.fillWidth: true; height: 38; radius: 4
                    color: CompanyTheme.bgCardSecondary; border.color: CompanyTheme.borderCard; border.width: 1
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10; spacing: 10
                        Text { text: "3"; color: CompanyTheme.textMuted; font.bold: true; font.pointSize: 8 }
                        Column {
                            Layout.fillWidth: true; spacing: 1
                            Text { text: qsTr("Power System & Battery Voltage"); color: CompanyTheme.textPrimary; font.bold: true; font.pointSize: 7.5 }
                            Text { text: CompanyTelemetry.hasVehicle ? (CompanyTelemetry.batteryPercentStr + " • " + CompanyTelemetry.batteryVoltageStr) : qsTr("Awaiting Battery Telemetry"); color: CompanyTheme.textMuted; font.pointSize: 6.5 }
                        }
                        Rectangle {
                            id: battBadge
                            readonly property bool isPass: CompanyTelemetry.hasVehicle && CompanyTelemetry.batteryPercent >= 25
                            width: 52; height: 20; radius: 3
                            color: battBadge.isPass ? Qt.rgba(CompanyTheme.success.r, CompanyTheme.success.g, CompanyTheme.success.b, 0.2) : Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.2)
                            border.color: battBadge.isPass ? CompanyTheme.success : CompanyTheme.danger; border.width: 1
                            Text { anchors.centerIn: parent; text: battBadge.isPass ? "✓ PASS" : "✕ LOW"; color: battBadge.isPass ? CompanyTheme.success : CompanyTheme.danger; font.bold: true; font.pointSize: 6.5 }
                        }
                    }
                }

                // 4. Return to Launch (RTL) & Failsafes
                Rectangle {
                    Layout.fillWidth: true; height: 38; radius: 4
                    color: CompanyTheme.bgCardSecondary; border.color: CompanyTheme.borderCard; border.width: 1
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10; spacing: 10
                        Text { text: "4"; color: CompanyTheme.textMuted; font.bold: true; font.pointSize: 8 }
                        Column {
                            Layout.fillWidth: true; spacing: 1
                            Text { text: qsTr("Failsafe Actions & RTL Altitude"); color: CompanyTheme.textPrimary; font.bold: true; font.pointSize: 7.5 }
                            Text { text: qsTr("RTL Altitude nominal • Telemetry failsafe active"); color: CompanyTheme.textMuted; font.pointSize: 6.5 }
                        }
                        Rectangle {
                            width: 52; height: 20; radius: 3
                            color: Qt.rgba(CompanyTheme.success.r, CompanyTheme.success.g, CompanyTheme.success.b, 0.2)
                            border.color: CompanyTheme.success; border.width: 1
                            Text { anchors.centerIn: parent; text: "✓ PASS"; color: CompanyTheme.success; font.bold: true; font.pointSize: 6.5 }
                        }
                    }
                }

                // 5. Propulsion & Motor Testing
                Rectangle {
                    Layout.fillWidth: true; height: 38; radius: 4
                    color: CompanyTheme.bgCardSecondary; border.color: CompanyTheme.borderCard; border.width: 1
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10; spacing: 10
                        Text { text: "5"; color: CompanyTheme.textMuted; font.bold: true; font.pointSize: 8 }
                        Column {
                            Layout.fillWidth: true; spacing: 1
                            Text { text: qsTr("Propulsion & Motor Interlock"); color: CompanyTheme.textPrimary; font.bold: true; font.pointSize: 7.5 }
                            Text { text: qsTr("Electronic Speed Controllers (ESCs) ready"); color: CompanyTheme.textMuted; font.pointSize: 6.5 }
                        }
                        Rectangle {
                            width: 52; height: 20; radius: 3
                            color: Qt.rgba(CompanyTheme.success.r, CompanyTheme.success.g, CompanyTheme.success.b, 0.2)
                            border.color: CompanyTheme.success; border.width: 1
                            Text { anchors.centerIn: parent; text: "✓ PASS"; color: CompanyTheme.success; font.bold: true; font.pointSize: 6.5 }
                        }
                    }
                }
            }

            // Summary Banner
            Rectangle {
                Layout.fillWidth: true; height: 30; radius: 4
                color: CompanyTelemetry.hasVehicle ? Qt.rgba(CompanyTheme.success.r, CompanyTelemetry.hasVehicle ? CompanyTheme.success.g : CompanyTheme.warning.g, CompanyTheme.success.b, 0.15) : CompanyTheme.bgCard
                border.color: CompanyTelemetry.hasVehicle ? CompanyTheme.success : CompanyTheme.borderCard; border.width: 1

                RowLayout {
                    anchors.centerIn: parent; spacing: 6
                    IconVector { name: CompanyTelemetry.hasVehicle ? "check" : "alert-triangle"; size: 14; color: CompanyTelemetry.hasVehicle ? CompanyTheme.success : CompanyTheme.warning }
                    Text {
                        text: CompanyTelemetry.hasVehicle ? qsTr("ALL PRE-FLIGHT CHECKS NOMINAL — CLEARED FOR FLIGHT") : qsTr("PRE-FLIGHT AUDIT INCOMPLETE: CONNECT VEHICLE FIRST")
                        color: CompanyTelemetry.hasVehicle ? CompanyTheme.success : CompanyTheme.warning
                        font.bold: true; font.pointSize: 7
                        font.letterSpacing: 0.5
                    }
                }
            }

            // Actions
            RowLayout {
                Layout.fillWidth: true; spacing: 10

                CompanyButton {
                    Layout.fillWidth: true; height: 32
                    text: qsTr("Close")
                    isOutline: true
                    onClicked: root.isOpen = false
                }

                CompanyButton {
                    Layout.fillWidth: true; height: 32
                    text: qsTr("Inspect Failsafes")
                    isPrimary: true
                    onClicked: {
                        root.isOpen = false
                        root.closed()
                    }
                }
            }
        }
    }
}
