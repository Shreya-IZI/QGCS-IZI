pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Company.UI

// First-Run Onboarding Guide Overlay
// Shows a step-by-step walkthrough the first time IZI GCS is launched.
// Emits dismissed() when the user completes or skips the guide.
Item {
    id: root

    signal dismissed()

    // Steps definition
    readonly property var steps: [
        {
            icon: "☰",
            title: "NAVIGATION",
            subtitle: "Open the Menu",
            body: "Tap the three-line menu icon (☰) in the top-left corner to open the navigation drawer.\n\nFrom there you can access:\n• Flight Operations (Map, PFD, Camera, System)\n• Mission Planner & Waypoints\n• Vehicle Setup & Parameters\n• Flight Logs & Settings",
            highlight: "top-left"
        },
        {
            icon: "📡",
            title: "CONNECT VEHICLE",
            subtitle: "Link to Your Drone",
            body: "Tap the CONNECT VEHICLE button in the top-right corner of the screen.\n\nIZI GCS connects via MAVLink over:\n• UDP (default port 14550)\n• TCP\n• Serial (USB OTG)\n• High-Speed Ethernet\n\nOnce connected, telemetry will display in real time.",
            highlight: "top-right"
        },
        {
            icon: "🗺",
            title: "MAP VIEW",
            subtitle: "Tactical Flight Operations",
            body: "The Map View is your primary tactical operations canvas.\n\nYou will see:\n• Live aircraft position and heading on satellite map\n• Speed, altitude, and battery telemetry overlay\n• Waypoint progress and flight tracks\n\nSwipe or pinch to zoom and pan the map.",
            highlight: "center"
        },
        {
            icon: "📊",
            title: "PFD HUD",
            subtitle: "Primary Flight Display",
            body: "The PFD (Primary Flight Display) provides aviation-grade instruments:\n\n• Artificial Horizon (pitch & roll attitude)\n• Airspeed & Groundspeed tapes\n• Altitude tape & Variometer\n• Compass heading rose\n• Flight mode & arm status",
            highlight: "center"
        },
        {
            icon: "📷",
            title: "CAMERA",
            subtitle: "RGB, Thermal & Multi-Spectral",
            body: "The Camera View displays live video feeds from your payload:\n\n• RGB — daylight optical camera\n• THERMAL — FLIR / LWIR infrared stream\n• SPLIT — side-by-side synchronized view\n• PIP — picture-in-picture mode\n\nUse the tactical controls to capture snapshots and record video with millisecond timestamps.",
            highlight: "center"
        },
        {
            icon: "✈",
            title: "FLIGHT CONTROL",
            subtitle: "ARM, HOLD, RTL, LAND",
            body: "Flight commands are located in the navigation drawer:\n\n• ARM / DISARM — motor arming interlock\n• HOLD — command the drone to loiter in place\n• RTL — Return To Launch (home coordinates)\n• LAND — automated landing routine\n\n⚠ Critical commands require confirmation to prevent accidental triggering.",
            highlight: "left-sidebar"
        },
        {
            icon: "📝",
            title: "MISSION PLANNER",
            subtitle: "Autonomous Waypoint Missions",
            body: "Plan autonomous flight paths easily:\n\n1. Open Navigation → Mission / Plan\n2. Tap the map to create waypoints\n3. Adjust speed, altitude, and actions per point\n4. Tap UPLOAD to transmit to the flight controller\n5. Switch to AUTO mode to execute",
            highlight: "center"
        },
        {
            icon: "⚙",
            title: "PARAMETERS",
            subtitle: "Flight Controller Tuning",
            body: "Access the complete MAVLink parameter database:\n\nNavigation → Vehicle → Parameters\n\n• Search across all flight parameters\n• Tune PID gains, RC channels, and failsafes\n• Changes take effect immediately or on reboot\n\n⚠ Only modify parameters you understand.",
            highlight: "center"
        }
    ]

    property int currentStep: 0

    // Fullscreen dimmed backdrop
    Rectangle {
        anchors.fill: parent
        color: "#E8080A0D"

        MouseArea {
            anchors.fill: parent
        }
    }

    // -------------------------------------------------------------------------
    // Responsive central card (fits phones in landscape and desktop)
    // -------------------------------------------------------------------------
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, 460)
        height: Math.min(parent.height - 20, 380)
        radius: 3
        color: CompanyTheme.bgCard
        border.color: CompanyTheme.borderActive
        border.width: 1
        clip: true

        // Thin top accent line
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: CompanyTheme.primary
            z: 10
        }

        // ---------------------------------------------------------------------
        // Pinned Header
        // ---------------------------------------------------------------------
        Rectangle {
            id: headerArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 48
            color: CompanyTheme.bgCard
            z: 5

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: "IZI GCS — OPERATOR GUIDE"
                    color: CompanyTheme.textMuted
                    font.pointSize: 8
                    font.bold: true
                    font.letterSpacing: 1.2
                    Layout.fillWidth: true
                }

                Text {
                    text: (root.currentStep + 1) + " / " + root.steps.length
                    color: CompanyTheme.primary
                    font.pointSize: 9
                    font.bold: true
                }

                // Instant close "✕" button
                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 2
                    color: closeMouse.containsMouse ? CompanyTheme.bgCardHover : "transparent"
                    border.color: closeMouse.containsMouse ? CompanyTheme.borderActive : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeMouse.containsMouse ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                        font.pointSize: 9
                        font.bold: true
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissed()
                    }
                }
            }

            // Progress bar line
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 2
                color: CompanyTheme.borderCard

                Rectangle {
                    width: parent.width * (root.currentStep + 1) / root.steps.length
                    height: parent.height
                    color: CompanyTheme.primary

                    Behavior on width {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // Scrollable Body Content
        // ---------------------------------------------------------------------
        Flickable {
            id: bodyFlickable
            anchors.top: headerArea.bottom
            anchors.bottom: footerArea.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            contentWidth: width
            contentHeight: stepContentCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: stepContentCol
                width: parent.width
                spacing: 10

                // Icon + Title Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 2
                        color: CompanyTheme.bgCardSecondary
                        border.color: CompanyTheme.borderCard
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.steps[root.currentStep].icon
                            font.pointSize: 18
                        }
                    }

                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true

                        Text {
                            text: root.steps[root.currentStep].title
                            color: CompanyTheme.primary
                            font.pointSize: CompanyTheme.fontH2
                            font.bold: true
                            font.letterSpacing: 0.8
                        }
                        Text {
                            text: root.steps[root.currentStep].subtitle
                            color: CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontSmall
                        }
                    }
                }

                // Description Box
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: descText.implicitHeight + 16
                    radius: 2
                    color: CompanyTheme.bgCardSecondary
                    border.color: CompanyTheme.borderSubtle
                    border.width: 1

                    Text {
                        id: descText
                        anchors.fill: parent
                        anchors.margins: 10
                        text: root.steps[root.currentStep].body
                        color: CompanyTheme.textSecondary
                        font.pointSize: CompanyTheme.fontSmall
                        wrapMode: Text.WordWrap
                        lineHeight: 1.4
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // Pinned Footer (Action Buttons — ALWAYS visible and reachable)
        // ---------------------------------------------------------------------
        Rectangle {
            id: footerArea
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 48
            color: CompanyTheme.bgCardSecondary
            border.color: CompanyTheme.borderCard
            border.width: 1
            z: 5

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                // Skip All button
                Rectangle {
                    Layout.preferredHeight: 32
                    implicitWidth: skipText.implicitWidth + 16
                    radius: 2
                    color: skipMouseArea.containsMouse ? CompanyTheme.bgCardHover : "transparent"
                    border.color: skipMouseArea.containsMouse ? CompanyTheme.borderCard : "transparent"
                    border.width: 1

                    Text {
                        id: skipText
                        anchors.centerIn: parent
                        text: qsTr("SKIP")
                        color: CompanyTheme.textMuted
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        font.letterSpacing: 0.8
                    }

                    MouseArea {
                        id: skipMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissed()
                    }
                }

                Item { Layout.fillWidth: true }

                // Back button
                Rectangle {
                    Layout.preferredHeight: 32
                    implicitWidth: backText.implicitWidth + 18
                    radius: 2
                    visible: root.currentStep > 0
                    color: backMouseArea.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                    border.color: CompanyTheme.borderCard
                    border.width: 1

                    Text {
                        id: backText
                        anchors.centerIn: parent
                        text: "← BACK"
                        color: CompanyTheme.textSecondary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                    }

                    MouseArea {
                        id: backMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.currentStep > 0) root.currentStep--
                        }
                    }
                }

                // Next / Done button
                Rectangle {
                    id: nextBtn
                    Layout.preferredHeight: 32
                    implicitWidth: nextText.implicitWidth + 20
                    radius: 2
                    color: nextMouseArea.containsMouse ? CompanyTheme.primaryHover : CompanyTheme.primary
                    border.color: CompanyTheme.borderActive
                    border.width: 1

                    Text {
                        id: nextText
                        anchors.centerIn: parent
                        text: root.currentStep < root.steps.length - 1 ? qsTr("NEXT →") : qsTr("LET'S FLY  ✓")
                        color: CompanyTheme.bgApp
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        font.letterSpacing: 0.6
                    }

                    MouseArea {
                        id: nextMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.currentStep < root.steps.length - 1) {
                                root.currentStep++
                            } else {
                                root.dismissed()
                            }
                        }
                    }
                }
            }
        }
    }
}
