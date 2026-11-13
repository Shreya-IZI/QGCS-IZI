pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Layouts
import QtLocation
import QtPositioning
import QGroundControl
import QGroundControl.FlightMap
import Company.UI

Item {
    id: root

    implicitWidth: collapsed ? 36 : 280
    implicitHeight: collapsed ? 36 : 180

    property bool collapsed: false
    signal swapRequested()

    readonly property var  _activeVehicle:   CompanyTelemetry.activeVehicle
    readonly property bool _hasVehicle:      CompanyTelemetry.hasVehicle
    readonly property var  _vehicleCoord:    CompanyTelemetry.coordinate
    readonly property bool _hasValidCoord:   CompanyTelemetry.hasValidCoord
    readonly property var  _homeCoord:       CompanyTelemetry.homeCoordinate
    readonly property bool _hasHomeCoord:    CompanyTelemetry.hasHomeCoord
    readonly property real _heading:         CompanyTelemetry.heading

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
                name: "flight"
                size: 14
                color: CompanyTheme.djiCyan
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "MAP"
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

    // Expanded Floating Mini Map Card
    Rectangle {
        id: pipCard
        anchors.fill: parent
        visible: !root.collapsed
        radius: CompanyTheme.radiusMd
        color: CompanyTheme.bgGlass
        border.color: CompanyTheme.borderGlass
        border.width: 1
        clip: true

        // Top Control Ribbon
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

                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: root._hasValidCoord ? CompanyTheme.success : CompanyTheme.warning
                }

                Text {
                    text: qsTr("TACTICAL MAP")
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontTiny
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
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
                        onClicked: root.swapRequested()
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

        // Mini Map Surface
        Rectangle {
            id: mapSurface
            anchors.top: cardHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            color: "#0B111A"
            clip: true

            FlightMap {
                id: miniFlightMap
                anchors.fill: parent
                mapName: "CompanyMiniMap"
                allowGCSLocationCenter: false
                allowVehicleLocationCenter: true
                zoomLevel: 16

                Connections {
                    target: root._activeVehicle
                    function onCoordinateChanged() {
                        if (root._hasValidCoord) {
                            miniFlightMap.center = root._activeVehicle.coordinate
                        }
                    }
                }

                // Aircraft position marker
                MapQuickItem {
                    coordinate: root._hasValidCoord ? root._vehicleCoord : QtPositioning.coordinate()
                    visible: root._hasValidCoord
                    anchorPoint.x: 12
                    anchorPoint.y: 12
                    z: 20

                    sourceItem: Item {
                        width: 24
                        height: 24
                        rotation: isNaN(root._heading) ? 0 : root._heading

                        // Aircraft Chevron
                        Canvas {
                            anchors.fill: parent
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.beginPath()
                                ctx.moveTo(12, 2)
                                ctx.lineTo(22, 20)
                                ctx.lineTo(12, 16)
                                ctx.lineTo(2, 20)
                                ctx.closePath()
                                ctx.fillStyle = "#00E5FF"
                                ctx.fill()
                                ctx.strokeStyle = "#FFFFFF"
                                ctx.lineWidth = 1.5
                                ctx.stroke()
                            }
                        }
                    }
                }
            }

            // Click anywhere to swap to full map view
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.swapRequested()
            }
        }
    }
}
