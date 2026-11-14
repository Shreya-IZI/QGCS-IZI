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

            Row {
                id:         motorButtons
                enabled:    safetySwitch.checked
                spacing:    ScreenTools.defaultFontPixelWidth * 2

                property int  activeMotorIndex:   -1
                property bool isSequenceRunning:  false
                property bool isSyncRunning:      false

                function stopAllMotors() {
                    seqTimer.stop()
                    syncStaggerTimer.stop()
                    syncDurationTimer.stop()
                    isSequenceRunning = false
                    isSyncRunning = false
                    activeMotorIndex = -1
                    for (var i = 0; i < buttonRepeater.count; i++) {
                        controller.vehicle.motorTest(i + 1, 0, 0, false)
                    }
                }

                function startSequenceTest() {
                    stopAllMotors()
                    if (buttonRepeater.count <= 0 || sliderThrottle.value <= 0) return
                    isSequenceRunning = true
                    activeMotorIndex = 0
                    // Send native MAV_CMD_DO_MOTOR_TEST with motorCount parameter
                    controller.vehicle.motorTest(1, sliderThrottle.value, _motorTimeoutSecs, false, buttonRepeater.count)
                    seqTimer.start()
                }

                function startSyncTest() {
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
                            motorButtons.stopAllMotors()
                        }
                    }
                }

                Timer {
                    id: syncStaggerTimer
                    property int targetIndex: 0
                    interval: 25
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
                        motorButtons.stopAllMotors()
                    }
                }

                Repeater {
                    id:         buttonRepeater
                    model:      controller.vehicle.motorCount === -1 ? 8 : controller.vehicle.motorCount

                    QGCButton {
                        id:         button
                        anchors.verticalCenter:     parent.verticalCenter
                        text:       motorIndexToString(index)
                        highlighted: motorButtons.activeMotorIndex === index || motorButtons.isSyncRunning
                        onClicked:  {
                            motorButtons.stopAllMotors()
                            motorButtons.activeMotorIndex = index
                            controller.vehicle.motorTest(index + 1, sliderThrottle.value, sliderThrottle.value === 0 ? 0 : _motorTimeoutSecs, true)
                        }
                    }
                } // Repeater

                QGCButton {
                    id:         allSeqButton
                    text:       qsTr("All (Sequence)")
                    highlighted: motorButtons.isSequenceRunning
                    onClicked:  {
                        motorButtons.startSequenceTest()
                    }
                }

                QGCButton {
                    id:         syncButton
                    text:       qsTr("All (Sync)")
                    highlighted: motorButtons.isSyncRunning
                    onClicked:  {
                        motorButtons.startSyncTest()
                    }
                }

                QGCButton {
                    id:         allStopButton
                    text:       qsTr("Stop")
                    onClicked:  {
                        motorButtons.stopAllMotors()
                    }
                }
            } // Row

            // Status label for active motor testing
            QGCLabel {
                font.pointSize: ScreenTools.smallFontPointSize
                color:  motorButtons.isSequenceRunning || motorButtons.isSyncRunning ? qgcPal.colorGreen : qgcPal.text
                text: {
                    if (motorButtons.isSequenceRunning) {
                        return qsTr("Sequence Testing: Motor %1 (%2 of %3)...").arg(motorIndexToString(motorButtons.activeMotorIndex)).arg(motorButtons.activeMotorIndex + 1).arg(buttonRepeater.count)
                    }
                    if (motorButtons.isSyncRunning) {
                        return qsTr("Synchronous Testing: All %1 Motors Active (%2%)...").arg(buttonRepeater.count).arg(sliderThrottle.value)
                    }
                    if (motorButtons.activeMotorIndex >= 0) {
                        return qsTr("Testing Motor %1...").arg(motorIndexToString(motorButtons.activeMotorIndex))
                    }
                    return qsTr("Motors idle. Click a single motor, All (Sequence), or All (Sync).")
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
