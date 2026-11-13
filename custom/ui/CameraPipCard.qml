pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Layouts
import QGroundControl
import Company.UI

Item {
    id: root

    // Standard 16:9 aspect ratio card matching DJI FlightHub 2
    implicitWidth: collapsed ? 36 : 300
    implicitHeight: collapsed ? 36 : 180

    property bool collapsed: false
    property string activeSensor: "RGB" // "RGB" or "IR"

    signal swapRequested(string targetSubView)

    readonly property bool _isRgbActive: QGroundControl.videoManager.decoding
    readonly property bool _hasVehicle: CompanyTelemetry.hasVehicle
    readonly property real _heading: CompanyTelemetry.heading

    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    // Collapsed Pill Tab
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
                name: "video"
                size: 14
                color: CompanyTheme.djiCyan
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "CAM"
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

    // Expanded Floating Live Stream Card
    Rectangle {
        id: pipCard
        anchors.fill: parent
        visible: !root.collapsed
        radius: CompanyTheme.radiusMd
        color: CompanyTheme.bgGlass
        border.color: CompanyTheme.borderGlass
        border.width: 1
        clip: true

        // Top Control Ribbon (DJI Enterprise Frosted Header)
        Rectangle {
            id: cardHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 28
            color: Qt.rgba(0.04, 0.06, 0.09, 0.94)
            border.color: CompanyTheme.borderGlass
            border.width: 1
            z: 10

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 6
                spacing: 6

                // Live Stream Indicator Dot
                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: root._isRgbActive ? CompanyTheme.success : CompanyTheme.warning

                    SequentialAnimation on opacity {
                        running: root._isRgbActive
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                    }
                }

                // Title
                Text {
                    text: root.activeSensor === "RGB" ? qsTr("DAYLIGHT CAM") : qsTr("THERMAL IR")
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontTiny
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                // Sensor Selector Pill (RGB / IR)
                Row {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        width: 32
                        height: 18
                        radius: 3
                        color: root.activeSensor === "RGB" ? CompanyTheme.djiBlue : CompanyTheme.bgCard
                        Text {
                            anchors.centerIn: parent
                            text: "RGB"
                            color: root.activeSensor === "RGB" ? "#FFFFFF" : CompanyTheme.textSecondary
                            font.pointSize: 7
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeSensor = "RGB"
                        }
                    }

                    Rectangle {
                        width: 32
                        height: 18
                        radius: 3
                        color: root.activeSensor === "IR" ? CompanyTheme.djiBlue : CompanyTheme.bgCard
                        Text {
                            anchors.centerIn: parent
                            text: "IR"
                            color: root.activeSensor === "IR" ? "#FFFFFF" : CompanyTheme.textSecondary
                            font.pointSize: 7
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeSensor = "IR"
                        }
                    }
                }

                // 1-Click Viewport SWAP Button
                Rectangle {
                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 18
                    radius: 3
                    color: swapMouse.containsMouse ? CompanyTheme.djiBlueHover : CompanyTheme.djiBlueDim
                    border.color: CompanyTheme.djiCyan
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            text: "⛶"
                            color: CompanyTheme.djiCyan
                            font.pointSize: 8
                        }
                        Text {
                            text: "SWAP"
                            color: CompanyTheme.djiCyan
                            font.pointSize: 7
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: swapMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.swapRequested(root.activeSensor === "RGB" ? "RGB_CAM" : "IR_CAM")
                        }
                    }
                }

                // Collapse Button
                Rectangle {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    radius: 3
                    color: minMouse.containsMouse ? CompanyTheme.bgCardHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "—"
                        color: CompanyTheme.textSecondary
                        font.pointSize: 9
                        font.bold: true
                    }

                    MouseArea {
                        id: minMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.collapsed = true
                    }
                }
            }
        }

        // Camera Video Viewport Surface
        Rectangle {
            id: videoSurface
            anchors.top: cardHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            color: "#0A0D14"

            // Crosshair overlay
            Item {
                anchors.centerIn: parent
                width: 30
                height: 30
                opacity: 0.6

                Rectangle { anchors.centerIn: parent; width: 30; height: 1; color: CompanyTheme.djiCyan }
                Rectangle { anchors.centerIn: parent; width: 1; height: 30; color: CompanyTheme.djiCyan }
                Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: "transparent"; border.color: CompanyTheme.djiCyan; border.width: 1 }
            }

            // Sensor Placeholder / Status Graphic when no stream
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4
                visible: !root._isRgbActive

                IconVector {
                    name: "video"
                    size: 24
                    color: CompanyTheme.textMuted
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: root.activeSensor === "RGB" ? qsTr("OPTICAL SENSOR STANDBY") : qsTr("THERMAL SENSOR STANDBY")
                    color: CompanyTheme.textSecondary
                    font.pointSize: 7
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: qsTr("Tap to open full workspace")
                    color: CompanyTheme.textMuted
                    font.pointSize: 6
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // Stream Telemetry HUD Chips
            RowLayout {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 6
                spacing: 4
                z: 5

                Rectangle {
                    Layout.preferredHeight: 14
                    implicitWidth: resText.implicitWidth + 8
                    radius: 2
                    color: Qt.rgba(0.0, 0.0, 0.0, 0.6)
                    Text {
                        id: resText
                        anchors.centerIn: parent
                        text: "1080P"
                        color: CompanyTheme.textSecondary
                        font.pointSize: 6
                        font.family: CompanyTheme.fontMono
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 14
                    implicitWidth: fpsText.implicitWidth + 8
                    radius: 2
                    color: Qt.rgba(0.0, 0.0, 0.0, 0.6)
                    Text {
                        id: fpsText
                        anchors.centerIn: parent
                        text: "60 FPS"
                        color: CompanyTheme.textSecondary
                        font.pointSize: 6
                        font.family: CompanyTheme.fontMono
                        font.bold: true
                    }
                }
            }

            // Click anywhere on video surface to swap to full camera workspace
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.swapRequested(root.activeSensor === "RGB" ? "RGB_CAM" : "IR_CAM")
                }
            }
        }
    }
}
