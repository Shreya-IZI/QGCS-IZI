// qmllint disable unqualified

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Company.UI

Rectangle {
    id: root

    readonly property var _tether: (typeof SafeTManager !== "undefined" && SafeTManager) ? SafeTManager : (typeof safeTManager !== "undefined" ? safeTManager : null)
    readonly property bool _hasTether: _tether !== null && _tether.isConnected

    radius: CompanyTheme.radiusSm
    color: CompanyTheme.bgCard
    border.color: {
        if (!_hasTether) return CompanyTheme.borderCard
        if (_tether.highTensionAlarm) return CompanyTheme.danger
        if (_tether.isStale) return CompanyTheme.warning
        return CompanyTheme.borderCard
    }
    border.width: (_tether && (_tether.highTensionAlarm || _tether.isStale)) ? 1.5 : 1

    implicitWidth: 320
    implicitHeight: tetherLayout.implicitHeight + (CompanyTheme.spacingSm * 2)

    ColumnLayout {
        id: tetherLayout
        anchors.fill: parent
        anchors.margins: CompanyTheme.spacingSm
        spacing: 6

        // Header: Title & Link Badge
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            IconVector {
                name: "activity"
                size: 13
                color: root._hasTether ? (_tether.highTensionAlarm ? CompanyTheme.danger : CompanyTheme.success) : CompanyTheme.textMuted
            }

            Text {
                text: qsTr("SAFE-T TETHER SYSTEM")
                color: CompanyTheme.textPrimary
                font.pointSize: CompanyTheme.fontTiny
                font.bold: true
                font.letterSpacing: 0.6
                Layout.fillWidth: true
            }

            Rectangle {
                height: 16
                implicitWidth: statusText.implicitWidth + 8
                radius: 2
                color: {
                    if (!root._hasTether) return CompanyTheme.bgCardSecondary
                    if (_tether.highTensionAlarm) return Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.25)
                    if (_tether.isStale) return Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.25)
                    return Qt.rgba(CompanyTheme.success.r, CompanyTheme.success.g, CompanyTheme.success.b, 0.2)
                }
                border.color: {
                    if (!root._hasTether) return CompanyTheme.borderCard
                    if (_tether.highTensionAlarm) return CompanyTheme.danger
                    if (_tether.isStale) return CompanyTheme.warning
                    return CompanyTheme.success
                }

                Text {
                    id: statusText
                    anchors.centerIn: parent
                    text: root._hasTether ? (_tether.highTensionAlarm ? "HIGH TENSION" : (_tether.isStale ? "STALE" : _tether.winchStatus)) : "STANDBY"
                    color: {
                        if (!root._hasTether) return CompanyTheme.textMuted
                        if (_tether.highTensionAlarm) return CompanyTheme.danger
                        if (_tether.isStale) return CompanyTheme.warning
                        return CompanyTheme.success
                    }
                    font.pointSize: 7
                    font.bold: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: CompanyTheme.borderCard
        }

        // Metrics Grid (Tension, Length, Station Power, Drum Temp)
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 6
            columnSpacing: 8

            // 1. Line Tension (N)
            Rectangle {
                Layout.fillWidth: true
                height: 38
                radius: CompanyTheme.radiusSm - 1
                color: CompanyTheme.bgInput
                border.color: (root._hasTether && _tether.highTensionAlarm) ? CompanyTheme.danger : CompanyTheme.borderCard

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        text: qsTr("TENSION")
                        color: CompanyTheme.textMuted
                        font.pointSize: 6.5
                        font.bold: true
                    }
                    Text {
                        text: root._hasTether ? (_tether.tensionN.toFixed(1) + " N") : "-- N"
                        color: (root._hasTether && _tether.highTensionAlarm) ? CompanyTheme.danger : CompanyTheme.textPrimary
                        font.pointSize: 10
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }
                }
            }

            // 2. Tether Deployed Length (m)
            Rectangle {
                Layout.fillWidth: true
                height: 38
                radius: CompanyTheme.radiusSm - 1
                color: CompanyTheme.bgInput
                border.color: CompanyTheme.borderCard

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        text: qsTr("PAYOUT")
                        color: CompanyTheme.textMuted
                        font.pointSize: 6.5
                        font.bold: true
                    }
                    Text {
                        text: root._hasTether ? (_tether.tetherLengthM.toFixed(1) + " m") : "-- m"
                        color: CompanyTheme.primary
                        font.pointSize: 10
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }
                }
            }

            // 3. Station Voltage (V) & Current (A)
            Rectangle {
                Layout.fillWidth: true
                height: 38
                radius: CompanyTheme.radiusSm - 1
                color: CompanyTheme.bgInput
                border.color: CompanyTheme.borderCard

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        text: qsTr("STATION POWER")
                        color: CompanyTheme.textMuted
                        font.pointSize: 6.5
                        font.bold: true
                    }
                    Text {
                        text: root._hasTether ? (_tether.stationVoltageV.toFixed(0) + "V • " + _tether.stationCurrentA.toFixed(1) + "A") : "--V • --A"
                        color: CompanyTheme.textPrimary
                        font.pointSize: 9
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }
                }
            }

            // 4. Drum Temperature (°C)
            Rectangle {
                Layout.fillWidth: true
                height: 38
                radius: CompanyTheme.radiusSm - 1
                color: CompanyTheme.bgInput
                border.color: CompanyTheme.borderCard

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        text: qsTr("DRUM TEMP")
                        color: CompanyTheme.textMuted
                        font.pointSize: 6.5
                        font.bold: true
                    }
                    Text {
                        text: root._hasTether ? (_tether.drumTempC.toFixed(1) + "°C") : "--°C"
                        color: CompanyTheme.textSecondary
                        font.pointSize: 9
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }
                }
            }
        }
    }
}
