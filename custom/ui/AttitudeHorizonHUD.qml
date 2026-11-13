pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Layouts
import QGroundControl
import Company.UI

Item {
    id: root

    // Dimension specifications for DJI Pilot 2 HUD widget
    implicitWidth: collapsed ? 36 : 280
    implicitHeight: collapsed ? 36 : 240

    property bool collapsed: false

    readonly property real _roll:        CompanyTelemetry.roll
    readonly property real _pitch:       CompanyTelemetry.pitch
    readonly property real _heading:     CompanyTelemetry.heading
    readonly property real _altRel:      CompanyTelemetry.altitudeRelative
    readonly property real _groundSpeed: CompanyTelemetry.groundSpeed
    readonly property string _flightMode: CompanyTelemetry.flightMode
    readonly property bool _hasVehicle:  CompanyTelemetry.hasVehicle
    readonly property bool _isArmed:     CompanyTelemetry.armed

    // Smooth width/height animation on collapse
    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    // Collapsed Toggle Tab
    Rectangle {
        id: collapsedTab
        anchors.fill: parent
        visible: root.collapsed
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgGlass
        border.color: CompanyTheme.borderGlass
        border.width: 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            IconVector {
                name: "dashboard"
                size: 14
                color: CompanyTheme.djiCyan
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "HUD"
                color: CompanyTheme.textPrimary
                font.pointSize: 7
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.collapsed = false
        }
    }

    // Expanded HUD Card
    Rectangle {
        id: hudCard
        anchors.fill: parent
        visible: !root.collapsed
        radius: CompanyTheme.radiusMd
        color: CompanyTheme.bgGlass
        border.color: CompanyTheme.borderGlass
        border.width: 1
        clip: true

        // Top Status Header
        Rectangle {
            id: topHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 24
            color: Qt.rgba(0.04, 0.06, 0.09, 0.92)
            border.color: CompanyTheme.borderGlass
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                // Aircraft Icon & Mode
                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: root._hasVehicle ? (root._isArmed ? CompanyTheme.success : CompanyTheme.warning) : CompanyTheme.textMuted
                }

                Text {
                    text: root._hasVehicle ? (root._flightMode !== "" ? root._flightMode.toUpperCase() : "STANDBY") : "NO VEHICLE"
                    color: CompanyTheme.djiCyan
                    font.pointSize: CompanyTheme.fontTiny
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                // Heading degrees
                Text {
                    text: isNaN(root._heading) ? "--°" : Math.round(root._heading).toString() + "°"
                    color: CompanyTheme.textLight
                    font.pointSize: CompanyTheme.fontTiny
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }

                // Collapse Button
                Rectangle {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    radius: 3
                    color: collapseMouse.containsMouse ? CompanyTheme.bgCardHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "◀"
                        color: CompanyTheme.textSecondary
                        font.pointSize: 8
                    }

                    MouseArea {
                        id: collapseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.collapsed = true
                    }
                }
            }
        }

        // Center Viewport: Horizon, Pitch Ladder, Speed Tape, Altitude Tape
        Item {
            id: hudViewport
            anchors.top: topHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: compassBar.top
            clip: true

            // Rotating & Translating Artificial Horizon
            Item {
                id: horizonContainer
                anchors.centerIn: parent
                width: Math.max(hudViewport.width, hudViewport.height) * 2.5
                height: width

                readonly property real pitchScale: 3.0
                readonly property real rollAngle:  root._roll
                readonly property real pitchAngle: root._pitch

                // Sky Half
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.height / 2
                    color: "#0066CC"
                }

                // Ground Half
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.height / 2
                    color: "#7A431D"
                }

                // Crisp Horizon Line
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height / 2 - 1
                    width: parent.width
                    height: 2
                    color: "#FFFFFF"
                }

                // Pitch Ladder Lines
                Item {
                    id: pitchLadder
                    anchors.fill: parent

                    // Positive Pitch (Sky)
                    Repeater {
                        model: [10, 20, 30]
                        Item {
                            id: posPitchItem
                            required property int modelData
                            width: 40
                            height: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height / 2 - (posPitchItem.modelData * horizonContainer.pitchScale) - 1

                            Rectangle { anchors.left: parent.left; width: 14; height: 1.5; color: "#FFFFFF" }
                            Rectangle { anchors.right: parent.right; width: 14; height: 1.5; color: "#FFFFFF" }

                            Text {
                                anchors.right: parent.left; anchors.rightMargin: 3
                                anchors.verticalCenter: parent.verticalCenter
                                text: posPitchItem.modelData.toString()
                                color: "#FFFFFF"
                                font.pointSize: 7
                                font.family: CompanyTheme.fontMono
                            }
                            Text {
                                anchors.left: parent.right; anchors.leftMargin: 3
                                anchors.verticalCenter: parent.verticalCenter
                                text: posPitchItem.modelData.toString()
                                color: "#FFFFFF"
                                font.pointSize: 7
                                font.family: CompanyTheme.fontMono
                            }
                        }
                    }

                    // Negative Pitch (Ground)
                    Repeater {
                        model: [10, 20, 30]
                        Item {
                            id: negPitchItem
                            required property int modelData
                            width: 40
                            height: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height / 2 + (negPitchItem.modelData * horizonContainer.pitchScale) - 1

                            Rectangle { anchors.left: parent.left; width: 14; height: 1.5; color: "#FFFFFF" }
                            Rectangle { anchors.right: parent.right; width: 14; height: 1.5; color: "#FFFFFF" }

                            Text {
                                anchors.right: parent.left; anchors.rightMargin: 3
                                anchors.verticalCenter: parent.verticalCenter
                                text: "-" + negPitchItem.modelData.toString()
                                color: "#FFFFFF"
                                font.pointSize: 7
                                font.family: CompanyTheme.fontMono
                            }
                            Text {
                                anchors.left: parent.right; anchors.leftMargin: 3
                                anchors.verticalCenter: parent.verticalCenter
                                text: "-" + negPitchItem.modelData.toString()
                                color: "#FFFFFF"
                                font.pointSize: 7
                                font.family: CompanyTheme.fontMono
                            }
                        }
                    }
                }

                transform: [
                    Translate {
                        y: horizonContainer.pitchAngle * horizonContainer.pitchScale
                    },
                    Rotation {
                        origin.x: horizonContainer.width / 2
                        origin.y: horizonContainer.height / 2
                        angle: -horizonContainer.rollAngle
                    }
                ]
            }

            // Fixed Center Reticle / Aircraft Reference Symbol
            Item {
                anchors.centerIn: parent
                width: 60
                height: 20
                z: 5

                // Center Dot
                Rectangle {
                    anchors.centerIn: parent
                    width: 4
                    height: 4
                    radius: 2
                    color: "#FFD700"
                }

                // Left Wing Bar
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 2.5
                    color: "#FFD700"
                }

                // Right Wing Bar
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 2.5
                    color: "#FFD700"
                }
            }

            // Left Speed Tape (m/s)
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 48
                color: Qt.rgba(0.06, 0.08, 0.12, 0.75)
                border.color: CompanyTheme.borderGlass
                border.width: 1
                z: 6

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 2

                    Text {
                        text: "SPD m/s"
                        color: CompanyTheme.textMuted
                        font.pointSize: 7
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item { Layout.fillHeight: true }

                    // Speed Readout Box
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        radius: 3
                        color: CompanyTheme.djiBlue
                        border.color: "#FFFFFF"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: isNaN(root._groundSpeed) ? "0.0" : root._groundSpeed.toFixed(1)
                            color: "#FFFFFF"
                            font.pointSize: CompanyTheme.fontSmall
                            font.family: CompanyTheme.fontMono
                            font.bold: true
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // Right Altitude Tape (m)
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 48
                color: Qt.rgba(0.06, 0.08, 0.12, 0.75)
                border.color: CompanyTheme.borderGlass
                border.width: 1
                z: 6

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 2

                    Text {
                        text: "ALT m"
                        color: CompanyTheme.textMuted
                        font.pointSize: 7
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item { Layout.fillHeight: true }

                    // Altitude Readout Box
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        radius: 3
                        color: CompanyTheme.djiBlue
                        border.color: "#FFFFFF"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: isNaN(root._altRel) ? "0.0" : root._altRel.toFixed(1)
                            color: "#FFFFFF"
                            font.pointSize: CompanyTheme.fontSmall
                            font.family: CompanyTheme.fontMono
                            font.bold: true
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }

        // Bottom Compass Tape
        Rectangle {
            id: compassBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 22
            color: Qt.rgba(0.04, 0.06, 0.09, 0.92)
            border.color: CompanyTheme.borderGlass
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 4

                Text { text: "W"; color: CompanyTheme.textMuted; font.pointSize: 7 }
                Item { Layout.fillWidth: true }
                Text { text: "NW"; color: CompanyTheme.textMuted; font.pointSize: 7 }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 14
                    radius: 2
                    color: CompanyTheme.djiBlueDim
                    border.color: CompanyTheme.djiCyan
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: isNaN(root._heading) ? "N" : Math.round(root._heading).toString() + "°"
                        color: CompanyTheme.djiCyan
                        font.pointSize: 7
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }
                }
                Item { Layout.fillWidth: true }
                Text { text: "NE"; color: CompanyTheme.textMuted; font.pointSize: 7 }
                Item { Layout.fillWidth: true }
                Text { text: "E"; color: CompanyTheme.textMuted; font.pointSize: 7 }
            }
        }
    }
}
