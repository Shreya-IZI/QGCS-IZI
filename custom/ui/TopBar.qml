pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import Company.UI
import "controls"

Rectangle {
    id: root

    height: CompanyTheme.topBarHeight
    color: CompanyTheme.bgTopBar

    readonly property bool _hasVehicle:      CompanyTelemetry.hasVehicle
    readonly property bool _isArmed:         CompanyTelemetry.armed
    readonly property string _flightMode:    CompanyTelemetry.flightMode

    // Bottom border separator line
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: CompanyTheme.borderCard
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: CompanyTheme.spacingMd
        anchors.rightMargin: CompanyTheme.spacingMd
        spacing: CompanyTheme.spacingMd

        // --------------------------------------------------------------------
        // 1. Brand & Logo Area
        // --------------------------------------------------------------------
        RowLayout {
            spacing: CompanyTheme.spacingSm

            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: CompanyTheme.radiusSm
                color: CompanyTheme.primary

                Text {
                    anchors.centerIn: parent
                    text: "◆"
                    color: CompanyTheme.textLight
                    font.pointSize: 11
                    font.bold: true
                }
            }

            Text {
                text: "COMPANY GCS"
                color: CompanyTheme.textPrimary
                font.pointSize: CompanyTheme.fontH3
                font.bold: true
                font.letterSpacing: 0.6
            }
        }

        // Vertical divider
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 18
            color: CompanyTheme.borderCard
        }

        // --------------------------------------------------------------------
        // 2. Vehicle Identification & Flight Mode (QGC Style)
        // --------------------------------------------------------------------
        RowLayout {
            spacing: CompanyTheme.spacingSm

            // Vehicle connection & ID pill
            Rectangle {
                Layout.preferredHeight: 26
                radius: CompanyTheme.radiusSm
                color: CompanyTheme.bgCard
                border.color: CompanyTheme.borderCard
                border.width: 1
                implicitWidth: vehicleIdLayout.implicitWidth + 14

                RowLayout {
                    id: vehicleIdLayout
                    anchors.centerIn: parent
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
                        text: root._hasVehicle ? qsTr("UAS #%1").arg(CompanyTelemetry.vehicleId) : qsTr("STANDBY")
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                    }
                }
            }

            // Arm State Badge
            Rectangle {
                visible: root._hasVehicle
                Layout.preferredHeight: 24
                radius: 3
                color: root._isArmed ? Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.18) : CompanyTheme.bgCard
                border.color: root._isArmed ? CompanyTheme.danger : CompanyTheme.borderCard
                border.width: 1
                implicitWidth: armText.implicitWidth + 10

                Text {
                    id: armText
                    anchors.centerIn: parent
                    text: root._isArmed ? qsTr("ARMED") : qsTr("DISARMED")
                    color: root._isArmed ? CompanyTheme.danger : CompanyTheme.textMuted
                    font.pointSize: CompanyTheme.fontTiny
                    font.bold: true
                    font.letterSpacing: 0.4
                }
            }

            // Flight Mode Badge
            Rectangle {
                visible: root._hasVehicle && root._flightMode !== ""
                Layout.preferredHeight: 24
                radius: 3
                color: CompanyTheme.primaryDim
                border.color: Qt.rgba(CompanyTheme.primary.r, CompanyTheme.primary.g, CompanyTheme.primary.b, 0.4)
                border.width: 1
                implicitWidth: modeText.implicitWidth + 12

                Text {
                    id: modeText
                    anchors.centerIn: parent
                    text: root._flightMode.toUpperCase()
                    color: CompanyTheme.primary
                    font.pointSize: CompanyTheme.fontTiny
                    font.bold: true
                    font.letterSpacing: 0.4
                }
            }
        }

        // Vertical divider
        Rectangle {
            visible: root._hasVehicle
            Layout.preferredWidth: 1
            Layout.preferredHeight: 18
            color: CompanyTheme.borderCard
        }

        // --------------------------------------------------------------------
        // 3. Operational Indicators: Battery, GPS, Link (QGC Style Header Strip)
        // --------------------------------------------------------------------
        RowLayout {
            visible: root._hasVehicle
            spacing: CompanyTheme.spacingMd

            // Battery Indicator
            RowLayout {
                spacing: 5
                IconVector {
                    name: "battery"
                    size: 14
                    color: {
                        if (!CompanyTelemetry.hasBattery) return CompanyTheme.textMuted
                        var pct = CompanyTelemetry.batteryPercent
                        if (pct > 30) return CompanyTheme.success
                        if (pct > 15) return CompanyTheme.warning
                        return CompanyTheme.danger
                    }
                }
                Text {
                    text: CompanyTelemetry.batteryPercentStr
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }
                Text {
                    visible: !isNaN(CompanyTelemetry.batteryVoltage)
                    text: CompanyTelemetry.batteryVoltageStr
                    color: CompanyTheme.textSecondary
                    font.pointSize: CompanyTheme.fontTiny
                    font.family: CompanyTheme.fontMono
                }
            }

            // GPS Indicator
            RowLayout {
                spacing: 5
                IconVector {
                    name: "satellite"
                    size: 14
                    color: {
                        if (CompanyTelemetry.gpsLock >= 3) return CompanyTheme.success
                        if (CompanyTelemetry.gpsLock >= 2) return CompanyTheme.warning
                        return CompanyTheme.danger
                    }
                }
                Text {
                    text: CompanyTelemetry.gpsCountStr
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }
                Text {
                    visible: CompanyTelemetry.gpsLockString !== "" && CompanyTelemetry.gpsLockString !== "No Fix" && CompanyTelemetry.gpsLockString !== "--"
                    text: "(" + CompanyTelemetry.gpsLockString + ")"
                    color: CompanyTheme.textSecondary
                    font.pointSize: CompanyTheme.fontTiny
                }
            }

            // MAVLink / Comm Link Indicator
            RowLayout {
                spacing: 5
                IconVector {
                    name: "signal"
                    size: 14
                    color: CompanyTelemetry.communicationLost ? CompanyTheme.danger : CompanyTheme.success
                }
                Text {
                    text: CompanyTelemetry.communicationLost ? "LOST" : (CompanyTelemetry.linkQualityPercent + "%")
                    color: CompanyTelemetry.communicationLost ? CompanyTheme.danger : CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }
            }
        }

        // Expanding spacer
        Item {
            Layout.fillWidth: true
        }

        // --------------------------------------------------------------------
        // 4. Right Controls: UTC Clock, Connect/Disconnect
        // --------------------------------------------------------------------
        RowLayout {
            spacing: CompanyTheme.spacingSm

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

            // Small vertical divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                color: CompanyTheme.borderCard
            }

            // Connection Action Button
            Button {
                id: connectBtn
                Layout.preferredHeight: 28
                implicitHeight: 28
                implicitWidth: connText.implicitWidth + 18

                contentItem: Text {
                    id: connText
                    text: root._hasVehicle ? qsTr("Disconnect") : qsTr("Connect Vehicle")
                    color: CompanyTheme.textLight
                    font.pointSize: CompanyTheme.fontSmall
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: CompanyTheme.radiusSm
                    color: {
                        if (!connectBtn.enabled) return CompanyTheme.bgInput
                        if (root._hasVehicle) {
                            return connectBtn.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCardSecondary
                        }
                        return connectBtn.pressed ? Qt.darker(CompanyTheme.primary, 1.2) : (connectBtn.hovered ? CompanyTheme.primaryHover : CompanyTheme.primary)
                    }
                    border.color: root._hasVehicle ? CompanyTheme.borderCard : "transparent"
                    border.width: 1
                }

                onClicked: {
                    if (CompanyTelemetry.hasVehicle && CompanyTelemetry.activeVehicle && CompanyTelemetry.activeVehicle.vehicleLinkManager) {
                        CompanyTelemetry.activeVehicle.vehicleLinkManager.closeVehicle()
                    } else if (QGroundControl.linkManager && QGroundControl.linkManager.linkConfigurations && QGroundControl.linkManager.linkConfigurations.count > 0) {
                        QGroundControl.linkManager.createConnectedLink(QGroundControl.linkManager.linkConfigurations.get(0))
                    }
                }
            }
        }
    }
}
