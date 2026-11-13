pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Layouts
import QGroundControl
import Company.UI

Item {
    id: root

    // Ergonomic aerospace HUD dimensions
    implicitWidth: collapsed ? 36 : 280
    implicitHeight: collapsed ? 36 : 220

    property bool collapsed: false

    readonly property real _roll:        CompanyTelemetry.roll
    readonly property real _pitch:       CompanyTelemetry.pitch
    readonly property real _heading:     CompanyTelemetry.heading
    readonly property real _altRel:      CompanyTelemetry.altitudeRelative
    readonly property real _groundSpeed: CompanyTelemetry.groundSpeed
    readonly property string _flightMode: CompanyTelemetry.flightMode
    readonly property bool _hasVehicle:  CompanyTelemetry.hasVehicle
    readonly property bool _isArmed:     CompanyTelemetry.armed

    // Smooth transition animations
    Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

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
                text: "PFD"
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

    // Expanded Aerospace PFD HUD Card
    Rectangle {
        id: hudCard
        anchors.fill: parent
        visible: !root.collapsed
        radius: CompanyTheme.radiusMd
        color: CompanyTheme.bgGlass
        border.color: CompanyTheme.borderGlass
        border.width: 1
        clip: true

        // Top Status Header (Flight Mode & Telemetry Header)
        Rectangle {
            id: topHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 24
            color: Qt.rgba(0.04, 0.06, 0.09, 0.94)
            border.color: CompanyTheme.borderGlass
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: root._hasVehicle ? (root._isArmed ? CompanyTheme.success : CompanyTheme.warning) : CompanyTheme.textMuted
                }

                Text {
                    text: root._hasVehicle ? (root._flightMode !== "" ? root._flightMode.toUpperCase() : "STANDBY") : "NO LINK"
                    color: CompanyTheme.djiCyan
                    font.pointSize: CompanyTheme.fontTiny
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                // Heading degrees
                Text {
                    text: isNaN(root._heading) ? "--°" : Math.round(root._heading).toString() + "° HDG"
                    color: CompanyTheme.textPrimary
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
                width: Math.max(hudViewport.width, hudViewport.height) * 2.6
                height: width

                readonly property real pitchScale: 2.8
                readonly property real rollAngle:  root._roll
                readonly property real pitchAngle: root._pitch

                // Deep Aerospace Sky Gradient
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.height / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#0B192C" }
                        GradientStop { position: 1.0; color: "#1E3E62" }
                    }
                }

                // Deep Terrain Earth Gradient
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.height / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#2B1B10" }
                        GradientStop { position: 1.0; color: "#140D08" }
                    }
                }

                // Illuminated Horizon Line
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height / 2 - 1
                    width: parent.width
                    height: 2
                    color: "#00E5FF"
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
                            width: 44
                            height: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height / 2 - (posPitchItem.modelData * horizonContainer.pitchScale) - 1

                            Rectangle { anchors.left: parent.left; width: 14; height: 1.5; color: "#E0F2FE" }
                            Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 1.5; height: 4; color: "#E0F2FE" }
                            Rectangle { anchors.right: parent.right; width: 14; height: 1.5; color: "#E0F2FE" }
                            Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 1.5; height: 4; color: "#E0F2FE" }

                            Text {
                                anchors.right: parent.left; anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: posPitchItem.modelData.toString()
                                color: "#E0F2FE"
                                font.pointSize: 7
                                font.family: CompanyTheme.fontMono
                            }
                            Text {
                                anchors.left: parent.right; anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: posPitchItem.modelData.toString()
                                color: "#E0F2FE"
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
                            width: 44
                            height: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height / 2 + (negPitchItem.modelData * horizonContainer.pitchScale) - 1

                            Rectangle { anchors.left: parent.left; width: 14; height: 1.5; color: "#FED7AA" }
                            Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 1.5; height: 4; color: "#FED7AA" }
                            Rectangle { anchors.right: parent.right; width: 14; height: 1.5; color: "#FED7AA" }
                            Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 1.5; height: 4; color: "#FED7AA" }

                            Text {
                                anchors.right: parent.left; anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: "-" + negPitchItem.modelData.toString()
                                color: "#FED7AA"
                                font.pointSize: 7
                                font.family: CompanyTheme.fontMono
                            }
                            Text {
                                anchors.left: parent.right; anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: "-" + negPitchItem.modelData.toString()
                                color: "#FED7AA"
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
                width: 64
                height: 20
                z: 5

                // Center Target Dot
                Rectangle {
                    anchors.centerIn: parent
                    width: 4
                    height: 4
                    radius: 2
                    color: "#FFB300"
                }

                // Left Wing Bar with Drop
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 2
                    color: "#FFB300"
                }
                Rectangle {
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 3
                    width: 2
                    height: 6
                    color: "#FFB300"
                }

                // Right Wing Bar with Drop
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 2
                    color: "#FFB300"
                }
                Rectangle {
                    x: parent.width - 22
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 3
                    width: 2
                    height: 6
                    color: "#FFB300"
                }
            }

            // Left Airspeed Tape (m/s)
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 46
                color: Qt.rgba(0.04, 0.07, 0.10, 0.85)
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
                        font.pointSize: 6
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item { Layout.fillHeight: true }

                    // Speed Readout Pointer Box
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20
                        radius: 3
                        color: CompanyTheme.djiBlue
                        border.color: CompanyTheme.djiCyan
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: isNaN(root._groundSpeed) ? "0.0" : root._groundSpeed.toFixed(1)
                            color: "#FFFFFF"
                            font.pointSize: CompanyTheme.fontTiny
                            font.family: CompanyTheme.fontMono
                            font.bold: true
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // Right Relative Altitude Tape (m)
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 46
                color: Qt.rgba(0.04, 0.07, 0.10, 0.85)
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
                        font.pointSize: 6
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item { Layout.fillHeight: true }

                    // Altitude Readout Pointer Box
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20
                        radius: 3
                        color: CompanyTheme.djiBlue
                        border.color: CompanyTheme.djiCyan
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: isNaN(root._altRel) ? "0.0" : root._altRel.toFixed(1)
                            color: "#FFFFFF"
                            font.pointSize: CompanyTheme.fontTiny
                            font.family: CompanyTheme.fontMono
                            font.bold: true
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }

        // Bottom Compass Arc
        Rectangle {
            id: compassBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 22
            color: Qt.rgba(0.04, 0.06, 0.09, 0.94)
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
                    Layout.preferredWidth: 32
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
