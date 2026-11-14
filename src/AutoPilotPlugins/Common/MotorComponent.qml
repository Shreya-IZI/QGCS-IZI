import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

SetupPage {
    id:             motorPage
    pageComponent:  pageComponent

    property bool userLetterMotorIndices: false

    readonly property int _barHeight:           10
    readonly property int _barWidth:            5
    readonly property int _sliderWidth:         15
    readonly property int _motorTimeoutSecs:    3

    function motorIndexToString(motorIndex) {
        let asciiA = 65;
        if (userLetterMotorIndices) {
            return String.fromCharCode(asciiA + motorIndex);
        } else {
            return motorIndex + 1;
        }
    }

    FactPanelController {
        id: controller
    }

    Component {
        id: pageComponent

        Column {
            spacing: ScreenTools.defaultFontPixelHeight

            QGCLabel {
                text:       qsTr("Warning: Unable to determine motor count")
                color:      qgcPal.warningText
                visible:    controller.vehicle.motorCount == -1
            }

            Row {
                id:         motorSlider
                enabled:    safetySwitch.checked
                spacing:    ScreenTools.defaultFontPixelWidth * 4

                ValueSlider {
                    id:                 sliderThrottle
                    width:              motorButtons.width
                    label:              qsTr("Throttle")
                    from:               0
                    to:                 100
                    majorTickStepSize:  5
                    decimalPlaces: 0
                    unitsString: qsTr("%")
                }
            } // Row

            QGCLabel {
                anchors.left:   parent.left
                anchors.right:  parent.right
                wrapMode:       Text.WordWrap
                text:           qsTr("Make sure you remove all props.")
            }

            // ----------------------------------------------------------------
            // Section 1: Individual Motor Testing
            // ----------------------------------------------------------------
            QGCLabel {
                text: qsTr("Individual Motor Testing:")
                font.bold: true
                font.pointSize: ScreenTools.smallFontPointSize
            }

            Row {
                id:         motorButtons
                enabled:    safetySwitch.checked
                spacing:    ScreenTools.defaultFontPixelWidth * 2

                property int    activeMotorIndex:      -1
                property bool   isSequenceRunning:     false
                property bool   isSyncRunning:         false
                property string completionStatusText:  ""
                property bool   isCompletedSuccess:    false

                function stopAllMotors() {
                    seqTimer.stop()
                    syncStaggerTimer.stop()
                    syncDurationTimer.stop()
                    var wasRunning = isSequenceRunning || isSyncRunning || activeMotorIndex >= 0
                    isSequenceRunning = false
                    isSyncRunning = false
                    activeMotorIndex = -1
                    for (var i = 0; i < buttonRepeater.count; i++) {
                        controller.vehicle.motorTest(i + 1, 0, 0, false)
                    }
                    if (wasRunning && !isCompletedSuccess) {
                        completionStatusText = qsTr("Motor test stopped.")
                    }
                }

                function startSequenceTest() {
                    isCompletedSuccess = false
                    completionStatusText = ""
                    stopAllMotors()
                    if (buttonRepeater.count <= 0 || sliderThrottle.value <= 0) return
                    isSequenceRunning = true
                    activeMotorIndex = 0
                    // Send native MAV_CMD_DO_MOTOR_TEST with motorCount parameter
                    controller.vehicle.motorTest(1, sliderThrottle.value, _motorTimeoutSecs, false, buttonRepeater.count)
                    seqTimer.start()
                }

                function startSyncTest() {
                    isCompletedSuccess = false
                    completionStatusText = ""
                    stopAllMotors()
                    if (buttonRepeater.count <= 0 || sliderThrottle.value <= 0) return
                    isSyncRunning = true
                    activeMotorIndex = -2
                    syncStaggerTimer.targetIndex = 0
                    syncStaggerTimer.start()
                    syncDurationTimer.start()
                }

                Timer {
                    id: seqTimer
                    interval: (_motorTimeoutSecs * 1000) + 300
                    repeat: true
                    onTriggered: {
                        motorButtons.activeMotorIndex++
                        if (motorButtons.activeMotorIndex < buttonRepeater.count) {
                            controller.vehicle.motorTest(motorButtons.activeMotorIndex + 1, sliderThrottle.value, _motorTimeoutSecs, false)
                        } else {
                            motorButtons.isCompletedSuccess = true
                            motorButtons.completionStatusText = qsTr("✓ Test Complete: All %1 motors tested successfully in sequence.").arg(buttonRepeater.count)
                            motorButtons.stopAllMotors()
                        }
                    }
                }

                Timer {
                    id: syncStaggerTimer
                    property int targetIndex: 0
                    interval: 30
                    repeat: true
                    onTriggered: {
                        if (targetIndex < buttonRepeater.count) {
                            controller.vehicle.motorTest(targetIndex + 1, sliderThrottle.value, _motorTimeoutSecs, false)
                            targetIndex++
                        } else {
                            stop()
                        }
                    }
                }

                Timer {
                    id: syncDurationTimer
                    interval: (_motorTimeoutSecs * 1000)
                    repeat: false
                    onTriggered: {
                        motorButtons.isCompletedSuccess = true
                        motorButtons.completionStatusText = qsTr("✓ Test Complete: All %1 motors spun simultaneously (%2% throttle).").arg(buttonRepeater.count).arg(sliderThrottle.value)
                        motorButtons.stopAllMotors()
                    }
                }

                Repeater {
                    id:         buttonRepeater
                    model:      controller.vehicle.motorCount === -1 ? 8 : controller.vehicle.motorCount

                    QGCButton {
                        id:         button
                        anchors.verticalCenter:     parent.verticalCenter
                        text:       qsTr("Motor %1").arg(motorIndexToString(index))
                        highlighted: motorButtons.activeMotorIndex === index || motorButtons.isSyncRunning
                        onClicked:  {
                            motorButtons.isCompletedSuccess = false
                            motorButtons.completionStatusText = ""
                            motorButtons.stopAllMotors()
                            motorButtons.activeMotorIndex = index
                            controller.vehicle.motorTest(index + 1, sliderThrottle.value, sliderThrottle.value === 0 ? 0 : _motorTimeoutSecs, true)
                        }
                    }
                } // Repeater
            } // Row

            // ----------------------------------------------------------------
            // Section 2: Automated Multi-Motor Actions
            // ----------------------------------------------------------------
            QGCLabel {
                text: qsTr("Multi-Motor Testing Options:")
                font.bold: true
                font.pointSize: ScreenTools.smallFontPointSize
            }

            Row {
                enabled:    safetySwitch.checked
                spacing:    ScreenTools.defaultFontPixelWidth * 2

                QGCButton {
                    id:         allSeqButton
                    text:       qsTr("Test All Motors (Sequence)")
                    highlighted: motorButtons.isSequenceRunning
                    onClicked:  {
                        motorButtons.startSequenceTest()
                    }
                }

                QGCButton {
                    id:         syncButton
                    text:       qsTr("Test All Motors (Simultaneous)")
                    highlighted: motorButtons.isSyncRunning
                    onClicked:  {
                        motorButtons.startSyncTest()
                    }
                }

                QGCButton {
                    id:         allStopButton
                    text:       qsTr("STOP ALL MOTORS")
                    onClicked:  {
                        motorButtons.isCompletedSuccess = false
                        motorButtons.completionStatusText = qsTr("Motor test stopped by user.")
                        motorButtons.stopAllMotors()
                    }
                }
            } // Row

            // ----------------------------------------------------------------
            // Section 3: Real-Time Motor Testing Status & Completion Banner
            // ----------------------------------------------------------------
            Rectangle {
                anchors.left:   parent.left
                anchors.right:  parent.right
                height:         ScreenTools.defaultFontPixelHeight * 2.5
                radius:         4
                color: {
                    if (motorButtons.isCompletedSuccess) return "#103820"
                    if (motorButtons.isSequenceRunning || motorButtons.isSyncRunning || motorButtons.activeMotorIndex >= 0) return "#1A2E44"
                    return "#1E2229"
                }
                border.color: {
                    if (motorButtons.isCompletedSuccess) return qgcPal.colorGreen
                    if (motorButtons.isSequenceRunning || motorButtons.isSyncRunning || motorButtons.activeMotorIndex >= 0) return "#0082FA"
                    return qgcPal.windowShade
                }
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: ScreenTools.defaultFontPixelWidth * 2

                    QGCLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        font.bold: true
                        font.pointSize: ScreenTools.defaultFontPointSize
                        color: {
                            if (motorButtons.isCompletedSuccess) return qgcPal.colorGreen
                            if (motorButtons.isSequenceRunning || motorButtons.isSyncRunning || motorButtons.activeMotorIndex >= 0) return "#00D2FF"
                            return qgcPal.text
                        }
                        text: {
                            if (motorButtons.isCompletedSuccess && motorButtons.completionStatusText !== "") {
                                return motorButtons.completionStatusText
                            }
                            if (motorButtons.isSequenceRunning) {
                                return qsTr("▶ Sequence Testing Active: Motor %1 (%2 of %3) at %4% throttle...")
                                    .arg(motorIndexToString(motorButtons.activeMotorIndex))
                                    .arg(motorButtons.activeMotorIndex + 1)
                                    .arg(buttonRepeater.count)
                                    .arg(sliderThrottle.value)
                            }
                            if (motorButtons.isSyncRunning) {
                                return qsTr("▶ Simultaneous Testing Active: All %1 Motors Spinning (%2% throttle)...")
                                    .arg(buttonRepeater.count)
                                    .arg(sliderThrottle.value)
                            }
                            if (motorButtons.activeMotorIndex >= 0) {
                                return qsTr("▶ Single Motor Testing: Motor %1 active at %2% throttle...")
                                    .arg(motorIndexToString(motorButtons.activeMotorIndex))
                                    .arg(sliderThrottle.value)
                            }
                            if (motorButtons.completionStatusText !== "") {
                                return motorButtons.completionStatusText
                            }
                            return qsTr("Motors Idle. Click an individual motor, 'Test All Motors (Sequence)', or 'Test All Motors (Simultaneous)'.")
                        }
                    }
                }
            }

            Row {
                spacing: ScreenTools.defaultFontPixelWidth

                Switch {
                    id: safetySwitch
                    onClicked: {
                        if (!checked) {
                            sliderThrottle.setValue(0);
                            motorButtons.stopAllMotors();
                        }
                    }
                }

                QGCLabel {
                    anchors.verticalCenter:     parent.verticalCenter
                    color:  qgcPal.warningText
                    text:   safetySwitch.checked ? qsTr("Careful : Motors are enabled") : qsTr("Propellers are removed - Enable slider and motors")
                }
            } // Row
        } // Column
    } // Component
} // SetupPage
