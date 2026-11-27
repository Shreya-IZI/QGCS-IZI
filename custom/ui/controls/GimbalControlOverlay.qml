pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import Company.UI

Item {
    id: root

    implicitWidth: collapsed ? 44 : 220
    implicitHeight: collapsed ? 44 : 260

    property bool collapsed: false
    property string slewMode: "NORM" // "FINE", "NORM", "FAST"

    readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property var _gimbalMgr: _activeVehicle ? _activeVehicle.gimbalController : null
    readonly property bool _hasGimbal: CompanyTelemetry.hasGimbal || _gimbalMgr !== null
    readonly property real _currentPitch: !isNaN(CompanyTelemetry.gimbalPitch) ? CompanyTelemetry.gimbalPitch : 0.0
    readonly property real _pitchSpeed: slewMode === "FINE" ? 5.0 : (slewMode === "FAST" ? 25.0 : 15.0)
    readonly property real _panSpeed:   slewMode === "FINE" ? 7.0 : (slewMode === "FAST" ? 35.0 : 20.0)

    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    function sendGimbalPitch(pitchDeg) {
        if (_gimbalMgr && _gimbalMgr.sendPitchBodyYaw) {
            _gimbalMgr.sendPitchBodyYaw(pitchDeg, 0.0, false)
        }
    }

    function sendGimbalRate(pitchRate, yawRate) {
        if (_gimbalMgr && _gimbalMgr.sendGimbalRate) {
            _gimbalMgr.sendGimbalRate(pitchRate, yawRate)
        }
    }

    // ------------------------------------------------------------------------
    // Collapsed Floating Button (When minimized)
    // ------------------------------------------------------------------------
    Rectangle {
        id: collapsedBtn
        anchors.fill: parent
        visible: root.collapsed
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgOverlayDark
        border.color: CompanyTheme.borderActive
        border.width: 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            IconVector {
                name: "sliders"
                size: 15
                color: CompanyTheme.primary
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "GIMBAL"
                color: CompanyTheme.textPrimary
                font.pointSize: 6.5
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.collapsed = false
        }
    }

    // ------------------------------------------------------------------------
    // Expanded Tactical Gimbal Control Overlay
    // ------------------------------------------------------------------------
    Rectangle {
        id: expandedCard
        anchors.fill: parent
        visible: !root.collapsed
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgOverlayDark
        border.color: CompanyTheme.borderActive
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            // Header Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                IconVector {
                    name: "sliders"
                    size: 13
                    color: CompanyTheme.primary
                }

                Text {
                    text: qsTr("GIMBAL CONTROL")
                    color: CompanyTheme.textPrimary
                    font.bold: true
                    font.pointSize: CompanyTheme.fontTiny
                    font.letterSpacing: 0.8
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 20
                    height: 20
                    radius: 3
                    color: closeArea.containsMouse ? CompanyTheme.bgCardHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "—"
                        color: CompanyTheme.textMuted
                        font.pointSize: 9
                        font.bold: true
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.collapsed = true
                    }
                }
            }

            // Live Angle Display
            Rectangle {
                Layout.fillWidth: true
                height: 22
                radius: 3
                color: CompanyTheme.bgCard
                border.color: CompanyTheme.borderCard
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "PITCH: " + CompanyTelemetry.gimbalPitchStr
                        color: CompanyTheme.primary
                        font.pointSize: 7.5
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }

                    Text {
                        text: "YAW: " + CompanyTelemetry.gimbalBodyYawStr
                        color: CompanyTheme.textSecondary
                        font.pointSize: 7.5
                        font.family: CompanyTheme.fontMono
                    }
                }
            }

            // Interactive Pitch Slider & Quick Presets Row
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // Vertical Pitch Slider Column
                ColumnLayout {
                    Layout.preferredWidth: 38
                    Layout.fillHeight: true
                    spacing: 2

                    Text {
                        text: "+20°"
                        color: CompanyTheme.textMuted
                        font.pointSize: 6
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Slider {
                        id: pitchSlider
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignHCenter
                        orientation: Qt.Vertical
                        from: -90.0
                        to: 20.0
                        stepSize: 1.0
                        value: root._currentPitch

                        background: Rectangle {
                            x: pitchSlider.leftPadding + pitchSlider.availableWidth / 2 - width / 2
                            y: pitchSlider.topPadding
                            implicitWidth: 4
                            implicitHeight: 100
                            width: implicitWidth
                            height: pitchSlider.availableHeight
                            radius: 2
                            color: CompanyTheme.bgCard

                            Rectangle {
                                width: parent.width
                                height: pitchSlider.visualPosition * parent.height
                                color: CompanyTheme.primary
                                radius: 2
                            }
                        }

                        handle: Rectangle {
                            x: pitchSlider.leftPadding + pitchSlider.availableWidth / 2 - width / 2
                            y: pitchSlider.topPadding + pitchSlider.visualPosition * (pitchSlider.availableHeight - height)
                            implicitWidth: 16
                            implicitHeight: 16
                            radius: 8
                            color: pitchSlider.pressed ? CompanyTheme.primaryHover : CompanyTheme.primary
                            border.color: "#FFFFFF"
                            border.width: 1
                        }

                        onMoved: {
                            root.sendGimbalPitch(pitchSlider.value)
                        }
                    }

                    Text {
                        text: "-90°"
                        color: CompanyTheme.textMuted
                        font.pointSize: 6
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // Quick Angle Buttons Column
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    // Horizon 0°
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        radius: 3
                        color: btnH.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                        border.color: CompanyTheme.borderCard
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("HORIZON (0°)")
                            color: CompanyTheme.textPrimary
                            font.pointSize: 7
                            font.bold: true
                        }

                        MouseArea {
                            id: btnH
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                CompanyTelemetry.pointGimbalHorizon()
                            }
                        }
                    }

                    // 45° Down
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        radius: 3
                        color: btn45.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                        border.color: CompanyTheme.borderCard
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("TILT (-45°)")
                            color: CompanyTheme.textPrimary
                            font.pointSize: 7
                            font.bold: true
                        }

                        MouseArea {
                            id: btn45
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.sendGimbalPitch(-45.0)
                            }
                        }
                    }

                    // Nadir -90°
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        radius: 3
                        color: btnN.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                        border.color: CompanyTheme.borderCard
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("NADIR (-90°)")
                            color: CompanyTheme.textPrimary
                            font.pointSize: 7
                            font.bold: true
                        }

                        MouseArea {
                            id: btnN
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                CompanyTelemetry.pointGimbalNadir()
                            }
                        }
                    }

                    // Center Gimbal
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        radius: 3
                        color: btnC.containsMouse ? CompanyTheme.primaryDim : CompanyTheme.bgCardSecondary
                        border.color: CompanyTheme.primary
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "⌖"
                                color: CompanyTheme.primary
                                font.pointSize: 9
                                font.bold: true
                            }

                            Text {
                                text: qsTr("CENTER GIMBAL")
                                color: CompanyTheme.primary
                                font.pointSize: 7
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: btnC
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                CompanyTelemetry.centerGimbal()
                            }
                        }
                    }
                }
            }

            // Slew Rate Selector Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 3

                Repeater {
                    model: [
                        { id: "FINE", label: "FINE 5°/s" },
                        { id: "NORM", label: "NORM 15°/s" },
                        { id: "FAST", label: "FAST 25°/s" }
                    ]
                    delegate: Rectangle {
                        id: slewBtn
                        required property var modelData
                        readonly property bool isCur: root.slewMode === modelData.id
                        Layout.fillWidth: true
                        height: 20
                        radius: 2
                        color: isCur ? CompanyTheme.primary : (slewMa.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCard)
                        border.color: isCur ? CompanyTheme.primary : CompanyTheme.borderCard
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: slewBtn.modelData.label
                            color: isCur ? "#000000" : CompanyTheme.textSecondary
                            font.pointSize: 6
                            font.bold: isCur
                        }

                        MouseArea {
                            id: slewMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.slewMode = slewBtn.modelData.id
                        }
                    }
                }
            }
        }
    }
}
