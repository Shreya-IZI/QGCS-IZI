pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Layouts
import QGroundControl
import Company.UI

Item {
    id: root

    readonly property var  _activeVehicle:      CompanyTelemetry.activeVehicle
    readonly property bool _hasVehicle:         CompanyTelemetry.hasVehicle
    readonly property bool _isArmed:            CompanyTelemetry.armed
    readonly property string _flightMode:       CompanyTelemetry.flightMode

    // ------------------------------------------------------------------------
    // Attitude Telemetry (Degrees)
    // ------------------------------------------------------------------------
    readonly property real _roll:               CompanyTelemetry.roll
    readonly property real _pitch:              CompanyTelemetry.pitch
    readonly property real _heading:            CompanyTelemetry.heading

    // ------------------------------------------------------------------------
    // Altitude Telemetry
    // ------------------------------------------------------------------------
    readonly property string _altAMSLStr:       CompanyTelemetry.altitudeAMSLStr
    readonly property string _altAMSLUnits:     CompanyTelemetry.altitudeAMSLUnits
    readonly property string _altRelStr:        CompanyTelemetry.altitudeRelativeStr
    readonly property string _altRelUnits:      CompanyTelemetry.altitudeRelativeUnits
    readonly property real   _altRelRaw:        CompanyTelemetry.altitudeRelative

    // ------------------------------------------------------------------------
    // Speed Telemetry
    // ------------------------------------------------------------------------
    readonly property real   _groundSpeedRaw:   CompanyTelemetry.groundSpeed
    readonly property string _groundSpeedStr:   CompanyTelemetry.groundSpeedStr
    readonly property string _groundSpeedUnits: CompanyTelemetry.groundSpeedUnits
    readonly property real   _airSpeedRaw:      CompanyTelemetry.airSpeed
    readonly property bool   _hasAirspeed:      CompanyTelemetry.hasAirSpeed
    readonly property string _airSpeedStr:      CompanyTelemetry.airSpeedStr
    readonly property string _airSpeedUnits:    CompanyTelemetry.airSpeedUnits

    // ------------------------------------------------------------------------
    // Vertical Speed Telemetry (VSI)
    // ------------------------------------------------------------------------
    readonly property real   _climbRateRaw:     CompanyTelemetry.climbRate
    readonly property string _climbRateStr:     CompanyTelemetry.climbRateStr
    readonly property string _climbRateUnits:   CompanyTelemetry.climbRateUnits

    // ------------------------------------------------------------------------
    // GPS & Position Telemetry
    // ------------------------------------------------------------------------
    readonly property string _gpsLockStr:       CompanyTelemetry.gpsLockString
    readonly property int    _gpsLockVal:       CompanyTelemetry.gpsLock
    readonly property string _gpsCountStr:      CompanyTelemetry.gpsCountStr
    readonly property real   _lat:              CompanyTelemetry.latitude
    readonly property real   _lon:              CompanyTelemetry.longitude

    // ------------------------------------------------------------------------
    // Home Position Telemetry
    // ------------------------------------------------------------------------
    readonly property string _distToHomeStr:    CompanyTelemetry.distToHomeStr
    readonly property string _hdgToHomeStr:     CompanyTelemetry.headingToHomeStr

    // Background Container
    Rectangle {
        anchors.fill: parent
        color: CompanyTheme.bgInput
        radius: CompanyTheme.radiusSm
        border.color: CompanyTheme.borderCard
        border.width: 1
        clip: true

        // ====================================================================
        // 1. CENTER AREA: ARTIFICIAL HORIZON & ATTITUDE INDICATOR
        // ====================================================================
        Item {
            id: horizonViewport
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: headingRibbon.bottom
            anchors.bottom: statusBar.top
            clip: true

            // Declarative Rotating & Translating Sky/Ground and Pitch Ladder Item
            Item {
                id: horizonContainer
                anchors.centerIn: parent
                width: Math.max(horizonViewport.width, horizonViewport.height) * 3
                height: width

                readonly property real pitchScale: 4.5
                readonly property real rollAngle:  root._roll
                readonly property real pitchAngle: root._pitch

                // ------------------------------------------------------------
                // 1. Sky Half (Top)
                // ------------------------------------------------------------
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.height / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: CompanyTheme.pfdSkyGradientStart }
                        GradientStop { position: 1.0; color: CompanyTheme.pfdSkyGradientEnd }
                    }
                }

                // ------------------------------------------------------------
                // 2. Ground Half (Bottom)
                // ------------------------------------------------------------
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.height / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: CompanyTheme.pfdGroundGradientStart }
                        GradientStop { position: 1.0; color: CompanyTheme.pfdGroundGradientEnd }
                    }
                }

                // ------------------------------------------------------------
                // 3. Crisp Horizon Line
                // ------------------------------------------------------------
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height / 2 - 1
                    width: parent.width
                    height: 2
                    color: CompanyTheme.pfdHorizonLine
                }

                // ------------------------------------------------------------
                // 4. Declarative Pitch Ladder
                // ------------------------------------------------------------
                Item {
                    id: pitchLadder
                    anchors.fill: parent

                    // Positive Pitch Rungs (Sky - Solid rungs with downward tabs)
                    Repeater {
                        model: [10, 20, 30, 40, 50]

                        Item {
                            id: posRung
                            required property int modelData
                            required property int index

                            width: (posRung.modelData % 20 === 0) ? 68 : 46
                            height: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height / 2 - (posRung.modelData * horizonContainer.pitchScale) - 1

                            // Left bar
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                width: (parent.width / 2) - 10
                                height: 1.5
                                color: CompanyTheme.pfdTapeText
                            }

                            // Left downward tab (points toward horizon line)
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                width: 1.5
                                height: 5
                                color: CompanyTheme.pfdTapeText
                            }

                            // Right bar
                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                width: (parent.width / 2) - 10
                                height: 1.5
                                color: CompanyTheme.pfdTapeText
                            }

                            // Right downward tab (points toward horizon line)
                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                width: 1.5
                                height: 5
                                color: CompanyTheme.pfdTapeText
                            }

                            // Left degree label
                            Text {
                                anchors.right: parent.left
                                anchors.rightMargin: 5
                                anchors.verticalCenter: parent.top
                                text: posRung.modelData.toString()
                                color: CompanyTheme.pfdTapeText
                                font.pointSize: CompanyTheme.fontTiny
                                font.family: CompanyTheme.fontMono
                                font.bold: true
                            }

                            // Right degree label
                            Text {
                                anchors.left: parent.right
                                anchors.leftMargin: 5
                                anchors.verticalCenter: parent.top
                                text: posRung.modelData.toString()
                                color: CompanyTheme.pfdTapeText
                                font.pointSize: CompanyTheme.fontTiny
                                font.family: CompanyTheme.fontMono
                                font.bold: true
                            }
                        }
                    }

                    // Negative Pitch Rungs (Ground - Dashed rungs with upward tabs)
                    Repeater {
                        model: [10, 20, 30, 40, 50]

                        Item {
                            id: negRung
                            required property int modelData
                            required property int index

                            width: (negRung.modelData % 20 === 0) ? 68 : 46
                            height: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height / 2 + (negRung.modelData * horizonContainer.pitchScale) - 1

                            // Left dashed bar
                            Row {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                spacing: 3

                                Rectangle {
                                    width: Math.floor(((negRung.width / 2) - 13) / 2)
                                    height: 1.5
                                    color: CompanyTheme.warning
                                }
                                Rectangle {
                                    width: Math.floor(((negRung.width / 2) - 13) / 2)
                                    height: 1.5
                                    color: CompanyTheme.warning
                                }
                            }

                            // Left upward tab (points toward horizon line)
                            Rectangle {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                width: 1.5
                                height: 5
                                color: CompanyTheme.warning
                            }

                            // Right dashed bar
                            Row {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                spacing: 3

                                Rectangle {
                                    width: Math.floor(((negRung.width / 2) - 13) / 2)
                                    height: 1.5
                                    color: CompanyTheme.warning
                                }
                                Rectangle {
                                    width: Math.floor(((negRung.width / 2) - 13) / 2)
                                    height: 1.5
                                    color: CompanyTheme.warning
                                }
                            }

                            // Right upward tab (points toward horizon line)
                            Rectangle {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                width: 1.5
                                height: 5
                                color: CompanyTheme.warning
                            }

                            // Left degree label
                            Text {
                                anchors.right: parent.left
                                anchors.rightMargin: 5
                                anchors.verticalCenter: parent.bottom
                                text: "-" + negRung.modelData.toString()
                                color: CompanyTheme.warning
                                font.pointSize: CompanyTheme.fontTiny
                                font.family: CompanyTheme.fontMono
                                font.bold: true
                            }

                            // Right degree label
                            Text {
                                anchors.left: parent.right
                                anchors.leftMargin: 5
                                anchors.verticalCenter: parent.bottom
                                text: "-" + negRung.modelData.toString()
                                color: CompanyTheme.warning
                                font.pointSize: CompanyTheme.fontTiny
                                font.family: CompanyTheme.fontMono
                                font.bold: true
                            }
                        }
                    }
                }

                // ------------------------------------------------------------
                // 5. Pitch & Roll Transforms
                // ------------------------------------------------------------
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

            // Fixed Roll Arc & Pointer (Top of horizon viewport)
            Canvas {
                id: rollScaleCanvas
                anchors.top: parent.top
                anchors.topMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: 180
                height: 50

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var cx = width / 2
                    var cy = 46
                    var radius = 40

                    // Draw fixed roll index ticks (0°, ±10°, ±20°, ±30°, ±45°, ±60°)
                    var angles = [-60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60]
                    ctx.strokeStyle = "rgba(255, 255, 255, 0.75)"
                    ctx.lineWidth = 1.5

                    for (var i = 0; i < angles.length; i++) {
                        var a = (angles[i] - 90) * Math.PI / 180
                        var tickLen = (angles[i] === 0 || Math.abs(angles[i]) === 30 || Math.abs(angles[i]) === 60) ? 8 : 4
                        var x1 = cx + (radius) * Math.cos(a)
                        var y1 = cy + (radius) * Math.sin(a)
                        var x2 = cx + (radius - tickLen) * Math.cos(a)
                        var y2 = cy + (radius - tickLen) * Math.sin(a)

                        ctx.beginPath()
                        ctx.moveTo(x1, y1)
                        ctx.lineTo(x2, y2)
                        ctx.stroke()
                    }

                    // Draw center top triangle marker
                    ctx.fillStyle = "#38BDF8"
                    ctx.beginPath()
                    ctx.moveTo(cx, cy - radius - 2)
                    ctx.lineTo(cx - 4, cy - radius - 9)
                    ctx.lineTo(cx + 4, cy - radius - 9)
                    ctx.closePath()
                    ctx.fill()
                }
            }

            // Rotating Roll Sky Pointer
            Item {
                anchors.top: parent.top
                anchors.topMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: 180
                height: 50
                transformOrigin: Item.Bottom

                transform: Rotation {
                    origin.x: 90
                    origin.y: 46
                    angle: -root._roll
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 46 - 40 + 1
                    width: 0
                    height: 0
                    border.width: 0

                    Canvas {
                        width: 10
                        height: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.fillStyle = "#FFFFFF"
                            ctx.beginPath()
                            ctx.moveTo(5, 8)
                            ctx.lineTo(0, 0)
                            ctx.lineTo(10, 0)
                            ctx.closePath()
                            ctx.fill()
                        }
                    }
                }
            }

            // Roll angle numeric pill (when bank angle > 1°)
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 46
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: rollText.implicitWidth + 8
                implicitHeight: 16
                radius: 3
                color: Qt.rgba(0.07, 0.11, 0.16, 0.75)
                border.color: CompanyTheme.borderCard
                border.width: 1
                visible: Math.abs(root._roll) >= 1.0

                Text {
                    id: rollText
                    anchors.centerIn: parent
                    text: Math.abs(root._roll).toFixed(0) + "°"
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontTiny
                    font.bold: true
                    font.family: CompanyTheme.fontMono
                }
            }

            // Fixed Center Aircraft Symbol (Waterline / Crosshair Reference)
            Item {
                anchors.centerIn: parent
                width: 90
                height: 24

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var cx = width / 2
                        var cy = height / 2

                        ctx.strokeStyle = "#F1F5F9"
                        ctx.fillStyle = "#F1F5F9"
                        ctx.lineWidth = 2.5
                        ctx.shadowColor = "#000000"
                        ctx.shadowBlur = 3

                        // Center Reference Dot
                        ctx.beginPath()
                        ctx.arc(cx, cy, 2.5, 0, 2 * Math.PI)
                        ctx.fill()

                        // Left Wing Bar with downward tab
                        ctx.beginPath()
                        ctx.moveTo(cx - 38, cy)
                        ctx.lineTo(cx - 14, cy)
                        ctx.lineTo(cx - 14, cy + 6)
                        ctx.stroke()

                        // Right Wing Bar with downward tab
                        ctx.beginPath()
                        ctx.moveTo(cx + 14, cy + 6)
                        ctx.lineTo(cx + 14, cy)
                        ctx.lineTo(cx + 38, cy)
                        ctx.stroke()
                    }
                }
            }
        }

        // ====================================================================
        // 2. TOP: HORIZONTAL HEADING TAPE (COMPASS RIBBON)
        // ====================================================================
        Rectangle {
            id: headingRibbon
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 38
            color: CompanyTheme.pfdTapeBg
            border.color: CompanyTheme.borderCard
            border.width: 1
            clip: true

            // Declarative Horizontally Scrolling Heading Scale Track
            Item {
                id: headingTrack
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter

                readonly property real pixelsPerDeg: 3.6
                readonly property real normHeading: (root._hasVehicle && !isNaN(root._heading)) ? ((root._heading % 360 + 360) % 360) : 0

                // Position track so normHeading is centered at headingRibbon.width / 2
                x: (headingRibbon.width / 2) - ((360 + normHeading) * pixelsPerDeg)
                width: 1080 * pixelsPerDeg

                Repeater {
                    model: 217 // Indices 0 to 216 covering degrees -360 to +720 in 5° steps

                    Item {
                        id: tickItem
                        required property int index

                        readonly property int deg: -360 + index * 5
                        readonly property int normDeg: (deg % 360 + 360) % 360
                        readonly property bool isMajor: (deg % 30 === 0)
                        readonly property bool isIntermediate: (!isMajor && deg % 10 === 0)

                        x: (deg + 360) * headingTrack.pixelsPerDeg - (width / 2)
                        y: 0
                        width: tickItem.isMajor ? 36 : 2
                        height: headingRibbon.height

                        // Top Tick Mark
                        Rectangle {
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tickItem.isMajor ? 1.5 : 1.0
                            height: tickItem.isMajor ? 9 : (tickItem.isIntermediate ? 6 : 4)
                            color: tickItem.isMajor ? CompanyTheme.pfdTapeText : CompanyTheme.pfdTapeTick
                            opacity: tickItem.isMajor ? 1.0 : (tickItem.isIntermediate ? 0.8 : 0.45)
                        }

                        // Cardinal / Degree Text Label for Major 30° Ticks
                        Text {
                            visible: tickItem.isMajor
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            text: {
                                if (tickItem.normDeg === 0) return "N"
                                if (tickItem.normDeg === 90) return "E"
                                if (tickItem.normDeg === 180) return "S"
                                if (tickItem.normDeg === 270) return "W"
                                var s = tickItem.normDeg.toString()
                                while (s.length < 3) s = "0" + s
                                return s
                            }
                            color: (tickItem.normDeg === 0) ? CompanyTheme.danger : CompanyTheme.pfdTapeText
                            font.pointSize: 9
                            font.bold: true
                            font.family: CompanyTheme.fontMono
                        }
                    }
                }
            }

            // Center Lubber Index Window & Readout
            Rectangle {
                anchors.centerIn: parent
                implicitWidth: 60
                implicitHeight: 22
                radius: 3
                color: CompanyTheme.pfdPointerBox
                border.color: CompanyTheme.pfdPointerBorder
                border.width: 1.5

                Text {
                    anchors.centerIn: parent
                    text: root._hasVehicle ? (root._heading.toFixed(0) + "°") : "---°"
                    color: CompanyTheme.pfdTapeText
                    font.pointSize: CompanyTheme.fontSmall
                    font.bold: true
                    font.family: CompanyTheme.fontMono
                }
            }

            // Center Lubber Pointer Indicator
            Canvas {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 8
                height: 5

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = CompanyTheme.pfdPointerBorder
                    ctx.beginPath()
                    ctx.moveTo(4, 0)
                    ctx.lineTo(0, 5)
                    ctx.lineTo(8, 5)
                    ctx.closePath()
                    ctx.fill()
                }
            }
        }

        // ====================================================================
        // 3. LEFT COLUMN: SPEED TAPE & READOUT (GS / AIRSPEED)
        // ====================================================================
        Rectangle {
            id: speedPanel
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.top: headingRibbon.bottom
            anchors.topMargin: 8
            anchors.bottom: statusBar.top
            anchors.bottomMargin: 8
            width: 86
            radius: CompanyTheme.radiusSm
            color: CompanyTheme.pfdTapeBg
            border.color: CompanyTheme.borderCard
            border.width: 1
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                // Speed Mode Title Badge (GS / IAS)
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 18
                    radius: 2
                    color: CompanyTheme.primaryDim
                    implicitWidth: speedBadgeText.implicitWidth + 8

                    Text {
                        id: speedBadgeText
                        anchors.centerIn: parent
                        text: root._hasAirspeed ? "IAS SPEED" : "GS SPEED"
                        color: CompanyTheme.primary
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.letterSpacing: 0.4
                    }
                }

                // Vertical Speed Ladder Viewport
                Item {
                    id: speedLadderViewport
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    // Declarative Scrolling Speed Scale Track
                    Item {
                        id: speedTrack
                        anchors.right: parent.right
                        width: parent.width

                        readonly property real maxSpeed: 80.0
                        readonly property real pixelsPerUnit: 12.0
                        readonly property real currentSpeed: Math.max(0, (root._hasVehicle && !isNaN(root._groundSpeedRaw)) ? root._groundSpeedRaw : 0)

                        // Position scale so currentSpeed is aligned with viewport vertical center
                        y: (speedLadderViewport.height / 2) - ((maxSpeed - currentSpeed) * pixelsPerUnit)
                        height: (maxSpeed + 1) * pixelsPerUnit

                        Repeater {
                            model: 81 // Indices 0 to 80 (0 to 80 m/s in 1 m/s intervals)

                            Item {
                                id: speedTickItem
                                required property int index

                                readonly property int spdVal: index
                                readonly property bool isMajor: (spdVal % 5 === 0)

                                width: speedTrack.width
                                height: 14
                                anchors.right: parent.right
                                y: (speedTrack.maxSpeed - spdVal) * speedTrack.pixelsPerUnit - 7

                                // Major / Minor Horizontal Tick Line
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: speedTickItem.isMajor ? 14 : 7
                                    height: speedTickItem.isMajor ? 1.5 : 1.0
                                    color: speedTickItem.isMajor ? CompanyTheme.pfdTapeText : CompanyTheme.pfdTapeTick
                                    opacity: speedTickItem.isMajor ? 1.0 : 0.6
                                }

                                // Numeric Label for Major 5-unit Ticks
                                Text {
                                    visible: speedTickItem.isMajor
                                    anchors.right: parent.right
                                    anchors.rightMargin: 22
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: speedTickItem.spdVal.toString()
                                    color: CompanyTheme.pfdTapeText
                                    font.pointSize: 9
                                    font.bold: true
                                    font.family: CompanyTheme.fontMono
                                }
                            }
                        }
                    }

                    // Center Pointer Readout Box (Overlay fixed at center)
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 1
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: parent.width - 6
                        implicitHeight: 28
                        radius: 3
                        color: CompanyTheme.pfdPointerBox
                        border.color: CompanyTheme.pfdPointerBorder
                        border.width: 1.5

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root._hasVehicle ? root._groundSpeedStr : "--"
                                color: CompanyTheme.pfdTapeText
                                font.pointSize: CompanyTheme.fontH3
                                font.bold: true
                                font.family: CompanyTheme.fontMono
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root._groundSpeedUnits
                                color: CompanyTheme.textSecondary
                                font.pointSize: 7.5
                            }
                        }
                    }
                }

                // Bottom Secondary Speed Readout
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root._hasAirspeed ? ("GS: " + root._groundSpeedStr + " " + root._groundSpeedUnits) : "AUTO DETECT"
                    color: CompanyTheme.textMuted
                    font.pointSize: 7.5
                    font.family: CompanyTheme.fontMono
                }
            }
        }

        // ====================================================================
        // 4. RIGHT COLUMN: ALTITUDE TAPE & VSI (ALT / REL / CLIMB)
        // ====================================================================
        Rectangle {
            id: altPanel
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.top: headingRibbon.bottom
            anchors.topMargin: 8
            anchors.bottom: statusBar.top
            anchors.bottomMargin: 8
            width: 106
            radius: CompanyTheme.radiusSm
            color: CompanyTheme.pfdTapeBg
            border.color: CompanyTheme.borderCard
            border.width: 1
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                // Altitude Title Badge (REL / AGL)
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 18
                    radius: 2
                    color: CompanyTheme.primaryDim
                    implicitWidth: altBadgeText.implicitWidth + 8

                    Text {
                        id: altBadgeText
                        anchors.centerIn: parent
                        text: "ALTITUDE REL"
                        color: CompanyTheme.primary
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.letterSpacing: 0.4
                    }
                }

                // Vertical Altitude Ladder Viewport
                Item {
                    id: altLadderViewport
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    // Declarative Scrolling Altitude Scale Track
                    Item {
                        id: altTrack
                        anchors.left: parent.left
                        anchors.right: vsiStrip.left
                        anchors.rightMargin: 3

                        readonly property real minAlt: -20.0
                        readonly property real maxAlt: 180.0
                        readonly property real pixelsPerUnit: 8.0
                        readonly property real currentAlt: (root._hasVehicle && !isNaN(root._altRelRaw)) ? root._altRelRaw : 0

                        // Position scale so currentAlt is aligned with viewport vertical center
                        y: (altLadderViewport.height / 2) - ((maxAlt - currentAlt) * pixelsPerUnit)
                        height: (maxAlt - minAlt + 1) * pixelsPerUnit

                        Repeater {
                            model: 201 // Indices 0 to 200 (-20 to +180m in 1m intervals)

                            Item {
                                id: altTickItem
                                required property int index

                                readonly property int altVal: Math.round(altTrack.minAlt + index)
                                readonly property bool isMajor: (altVal % 5 === 0)

                                width: altTrack.width
                                height: 14
                                anchors.left: parent.left
                                y: (altTrack.maxAlt - altVal) * altTrack.pixelsPerUnit - 7

                                // Major / Minor Horizontal Tick Line
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: altTickItem.isMajor ? 12 : 6
                                    height: altTickItem.isMajor ? 1.5 : 1.0
                                    color: altTickItem.isMajor ? CompanyTheme.pfdTapeText : CompanyTheme.pfdTapeTick
                                    opacity: altTickItem.isMajor ? 1.0 : 0.5
                                }

                                // Numeric Label for Major 5-meter Ticks
                                Text {
                                    visible: altTickItem.isMajor
                                    anchors.left: parent.left
                                    anchors.leftMargin: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: altTickItem.altVal.toString()
                                    color: CompanyTheme.pfdTapeText
                                    font.pointSize: 9
                                    font.bold: true
                                    font.family: CompanyTheme.fontMono
                                }
                            }
                        }
                    }

                    // Center Prominent Altitude Readout Window
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 1
                        anchors.right: vsiStrip.left
                        anchors.rightMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: 28
                        radius: 3
                        color: CompanyTheme.pfdPointerBox
                        border.color: CompanyTheme.pfdPointerBorder
                        border.width: 1.5

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root._hasVehicle ? root._altRelStr : "--"
                                color: CompanyTheme.pfdTapeText
                                font.pointSize: CompanyTheme.fontH3
                                font.bold: true
                                font.family: CompanyTheme.fontMono
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root._altRelUnits + " AGL"
                                color: CompanyTheme.textSecondary
                                font.pointSize: 7.5
                            }
                        }
                    }

                    // Right Edge: Vertical Speed Indicator (VSI) Scale & Pointer
                    Rectangle {
                        id: vsiStrip
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 20
                        radius: 2
                        color: CompanyTheme.pfdPointerBox
                        border.color: CompanyTheme.borderCard
                        border.width: 1
                        clip: true

                        readonly property real halfH: (height - 18) / 2
                        readonly property real cy: height / 2
                        readonly property real rawClimb: (root._hasVehicle && !isNaN(root._climbRateRaw)) ? root._climbRateRaw : 0

                        function climbOffset(climb) {
                            var c = Math.max(-5.0, Math.min(5.0, climb))
                            var abs = Math.abs(c)
                            var ratio = 0
                            if (abs <= 1.0) {
                                ratio = abs * 0.30
                            } else if (abs <= 2.0) {
                                ratio = 0.30 + (abs - 1.0) * 0.30
                            } else {
                                ratio = 0.60 + ((abs - 2.0) / 3.0) * 0.35
                            }
                            return (c >= 0 ? -1 : 1) * ratio * vsiStrip.halfH
                        }

                        // Digital VSI Numeric Readout (at top of VSI strip)
                        Text {
                            anchors.top: parent.top
                            anchors.topMargin: 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root._hasVehicle ? root._climbRateStr : "--"
                            color: {
                                if (vsiStrip.rawClimb > 0.05) return CompanyTheme.success
                                if (vsiStrip.rawClimb < -2.0) return CompanyTheme.warning
                                return CompanyTheme.pfdTapeTick
                            }
                            font.pointSize: 6.5
                            font.bold: true
                            font.family: CompanyTheme.fontMono
                        }

                        // Fixed Scale Ticks & Labels: +5, +2, +1, 0, -1, -2, -5
                        // Tick +5
                        Rectangle {
                            x: 0; y: Math.round(vsiStrip.cy - 0.95 * vsiStrip.halfH)
                            width: 4; height: 1; color: CompanyTheme.pfdTapeTick
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 1
                            anchors.verticalCenter: parent.top
                            anchors.verticalCenterOffset: Math.round(vsiStrip.cy - 0.95 * vsiStrip.halfH)
                            text: "5"; color: CompanyTheme.pfdTapeTick; font.pointSize: 6; font.family: CompanyTheme.fontMono
                        }

                        // Tick +2
                        Rectangle {
                            x: 0; y: Math.round(vsiStrip.cy - 0.60 * vsiStrip.halfH)
                            width: 3; height: 1; color: CompanyTheme.pfdTapeTick
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 1
                            anchors.verticalCenter: parent.top
                            anchors.verticalCenterOffset: Math.round(vsiStrip.cy - 0.60 * vsiStrip.halfH)
                            text: "2"; color: CompanyTheme.pfdTapeTick; font.pointSize: 6; font.family: CompanyTheme.fontMono
                        }

                        // Tick +1
                        Rectangle {
                            x: 0; y: Math.round(vsiStrip.cy - 0.30 * vsiStrip.halfH)
                            width: 3; height: 1; color: CompanyTheme.pfdTapeTick
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 1
                            anchors.verticalCenter: parent.top
                            anchors.verticalCenterOffset: Math.round(vsiStrip.cy - 0.30 * vsiStrip.halfH)
                            text: "1"; color: CompanyTheme.pfdTapeTick; font.pointSize: 6; font.family: CompanyTheme.fontMono
                        }

                        // Center 0 Line
                        Rectangle {
                            x: 0; y: Math.round(vsiStrip.cy)
                            width: parent.width; height: 1; color: CompanyTheme.pfdTapeText
                        }

                        // Tick -1
                        Rectangle {
                            x: 0; y: Math.round(vsiStrip.cy + 0.30 * vsiStrip.halfH)
                            width: 3; height: 1; color: CompanyTheme.pfdTapeTick
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 1
                            anchors.verticalCenter: parent.top
                            anchors.verticalCenterOffset: Math.round(vsiStrip.cy + 0.30 * vsiStrip.halfH)
                            text: "1"; color: CompanyTheme.pfdTapeTick; font.pointSize: 6; font.family: CompanyTheme.fontMono
                        }

                        // Tick -2
                        Rectangle {
                            x: 0; y: Math.round(vsiStrip.cy + 0.60 * vsiStrip.halfH)
                            width: 3; height: 1; color: CompanyTheme.pfdTapeTick
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 1
                            anchors.verticalCenter: parent.top
                            anchors.verticalCenterOffset: Math.round(vsiStrip.cy + 0.60 * vsiStrip.halfH)
                            text: "2"; color: CompanyTheme.pfdTapeTick; font.pointSize: 6; font.family: CompanyTheme.fontMono
                        }

                        // Tick -5
                        Rectangle {
                            x: 0; y: Math.round(vsiStrip.cy + 0.95 * vsiStrip.halfH)
                            width: 4; height: 1; color: CompanyTheme.pfdTapeTick
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 1
                            anchors.verticalCenter: parent.top
                            anchors.verticalCenterOffset: Math.round(vsiStrip.cy + 0.95 * vsiStrip.halfH)
                            text: "5"; color: CompanyTheme.pfdTapeTick; font.pointSize: 6; font.family: CompanyTheme.fontMono
                        }

                        // Dynamic VSI Fill Bar
                        Rectangle {
                            x: 1
                            width: 4
                            radius: 1
                            y: vsiStrip.rawClimb >= 0 ? (vsiStrip.cy + vsiStrip.climbOffset(vsiStrip.rawClimb)) : vsiStrip.cy
                            height: Math.abs(vsiStrip.climbOffset(vsiStrip.rawClimb))
                            color: {
                                if (vsiStrip.rawClimb > 0.05) return CompanyTheme.success
                                if (vsiStrip.rawClimb < -2.0) return CompanyTheme.warning
                                return CompanyTheme.pfdTapeTick
                            }
                            visible: root._hasVehicle && Math.abs(vsiStrip.rawClimb) > 0.05
                        }

                        // Dynamic VSI Pointer Needle
                        Rectangle {
                            x: 0
                            width: 5
                            height: 2
                            y: Math.round(vsiStrip.cy + vsiStrip.climbOffset(vsiStrip.rawClimb) - 1)
                            color: {
                                if (vsiStrip.rawClimb > 0.05) return CompanyTheme.success
                                if (vsiStrip.rawClimb < -2.0) return CompanyTheme.warning
                                return CompanyTheme.pfdTapeText
                            }
                            visible: root._hasVehicle
                        }
                    }
                }

                // Bottom Secondary Altitude (AMSL)
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "MSL " + root._altAMSLStr + " " + root._altAMSLUnits
                    color: CompanyTheme.textMuted
                    font.pointSize: 7.5
                    font.family: CompanyTheme.fontMono
                }
            }
        }

        // ====================================================================
        // 5. BOTTOM STATUS BAR (GPS, TELEMETRY, HOME, NAVIGATION)
        // ====================================================================
        Rectangle {
            id: statusBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 48
            color: Qt.rgba(0.07, 0.11, 0.16, 0.95)
            border.color: CompanyTheme.borderCard
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: CompanyTheme.spacingMd
                anchors.rightMargin: CompanyTheme.spacingMd
                spacing: CompanyTheme.spacingMd

                // Block 1: GPS Status & Coordinates
                ColumnLayout {
                    spacing: 1
                    Layout.preferredWidth: 200

                    RowLayout {
                        spacing: 5
                        Rectangle {
                            Layout.preferredWidth: 6
                            Layout.preferredHeight: 6
                            radius: 3
                            color: {
                                if (!root._hasVehicle) return CompanyTheme.textMuted
                                if (root._gpsLockVal >= 3) return CompanyTheme.success
                                if (root._gpsLockVal >= 2) return CompanyTheme.warning
                                return CompanyTheme.danger
                            }
                        }
                        Text {
                            text: (root._gpsLockStr.toUpperCase()) + " • " + root._gpsCountStr
                            color: CompanyTheme.textPrimary
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                        }
                    }

                    Text {
                        text: {
                            if (!root._hasVehicle || isNaN(root._lat) || isNaN(root._lon)) return "LAT -- • LON --"
                            return "LAT " + root._lat.toFixed(6) + "°  LON " + root._lon.toFixed(6) + "°"
                        }
                        color: CompanyTheme.textSecondary
                        font.pointSize: CompanyTheme.fontTiny
                        font.family: CompanyTheme.fontMono
                    }
                }

                // Spacer
                Item { Layout.fillWidth: true }

                // Block 2: Flight State & Home Reference
                ColumnLayout {
                    spacing: 1
                    Layout.alignment: Qt.AlignHCenter

                    RowLayout {
                        spacing: 6
                        Layout.alignment: Qt.AlignHCenter

                        Text {
                            text: {
                                if (!root._hasVehicle) return "STANDBY"
                                var s = "UAS #" + root._activeVehicle.id
                                if (root._flightMode !== "") s += " • " + root._flightMode.toUpperCase()
                                s += " • " + (root._isArmed ? "ARMED" : "DISARMED")
                                return s
                            }
                            color: root._isArmed ? CompanyTheme.danger : (root._hasVehicle ? CompanyTheme.success : CompanyTheme.warning)
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "HOME: " + root._distToHomeStr + "  BRG " + root._hdgToHomeStr
                        color: CompanyTheme.textMuted
                        font.pointSize: CompanyTheme.fontTiny
                        font.family: CompanyTheme.fontMono
                    }
                }

                // Spacer
                Item { Layout.fillWidth: true }

                // Block 3: VSI Readout & Telemetry Health
                ColumnLayout {
                    spacing: 1
                    Layout.preferredWidth: 150
                    Layout.alignment: Qt.AlignRight

                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "VSI " + root._climbRateStr + " " + root._climbRateUnits
                        color: Math.abs(root._climbRateRaw) > 0.2 ? (root._climbRateRaw > 0 ? CompanyTheme.success : CompanyTheme.warning) : CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }

                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: {
                            if (!root._hasVehicle) return "LINK --"
                            if (CompanyTelemetry.communicationLost) return "LINK LOST"
                            return "LINK " + CompanyTelemetry.linkQualityPercent + "%"
                        }
                        color: {
                            if (!root._hasVehicle) return CompanyTheme.textMuted
                            if (CompanyTelemetry.communicationLost) return CompanyTheme.danger
                            return CompanyTheme.textSecondary
                        }
                        font.pointSize: CompanyTheme.fontTiny
                        font.family: CompanyTheme.fontMono
                    }
                }
            }
        }

        // ====================================================================
        // 6. DISCONNECTED / STANDBY OVERLAY
        // ====================================================================
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.04, 0.07, 0.10, 0.75)
            visible: !root._hasVehicle

            ColumnLayout {
                anchors.centerIn: parent
                spacing: CompanyTheme.spacingSm

                IconVector {
                    Layout.alignment: Qt.AlignHCenter
                    name: "uas"
                    size: 32
                    color: CompanyTheme.textMuted
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "STANDBY • NO ACTIVE VEHICLE"
                    color: CompanyTheme.textSecondary
                    font.pointSize: CompanyTheme.fontH2
                    font.bold: true
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Connect vehicle to stream live attitude, navigation, and flight instruments."
                    color: CompanyTheme.textMuted
                    font.pointSize: CompanyTheme.fontBody
                }
            }
        }
    }
}
