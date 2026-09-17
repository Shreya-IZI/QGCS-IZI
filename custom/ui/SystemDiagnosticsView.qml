pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import Company.UI

Item {
    id: root

    // ------------------------------------------------------------------------
    // Vehicle & Telemetry Bindings (Strictly Real Vehicle Data - Zero Fake Values)
    // ------------------------------------------------------------------------
    readonly property var  _activeVehicle:      CompanyTelemetry.activeVehicle
    readonly property bool _hasVehicle:         CompanyTelemetry.hasVehicle
    readonly property var  _linkMgr:            _hasVehicle ? _activeVehicle.vehicleLinkManager : null
    readonly property var  _gps:                _hasVehicle ? _activeVehicle.gps : null
    readonly property var  _estimator:          _hasVehicle ? _activeVehicle.estimatorStatus : null
    readonly property var  _vibration:          _hasVehicle ? _activeVehicle.vibration : null
    readonly property var  _sensorInfo:         _hasVehicle ? _activeVehicle.sysStatusSensorInfo : null
    readonly property var  _batteries:          _hasVehicle ? _activeVehicle.batteries : null
    readonly property var  _radioStatus:        _hasVehicle ? _activeVehicle.radioStatus : null

    // Multi-Battery Selection
    property int selectedBatteryIndex:          0
    readonly property var _currentBattery: {
        if (!_batteries || _batteries.count === 0) return null
        if (selectedBatteryIndex >= 0 && selectedBatteryIndex < _batteries.count) {
            return _batteries.get(selectedBatteryIndex)
        }
        return _batteries.get(0)
    }

    // ------------------------------------------------------------------------
    // Real Sensor Degradation Tracer (Genuinely Reported by PX4/ArduPilot SYS_STATUS)
    // ------------------------------------------------------------------------
    readonly property var _unhealthySensorsList: {
        if (!root._hasVehicle) return []
        var result = []
        if (root._sensorInfo && root._sensorInfo.sensorNames && root._sensorInfo.sensorStatus) {
            var names = root._sensorInfo.sensorNames
            var statuses = root._sensorInfo.sensorStatus
            for (var i = 0; i < names.length && i < statuses.length; i++) {
                if (statuses[i] === "Error" || statuses[i] === qsTr("Error")) {
                    result.push(names[i])
                }
            }
        }
        // Fallback cross-check with sensorsUnhealthyBits bitmask if sysStatusSensorInfo is initializing
        if (result.length === 0 && root._activeVehicle && root._activeVehicle.sensorsUnhealthyBits) {
            var bits = root._activeVehicle.sensorsUnhealthyBits
            if (bits & MAVLinkEnums.MAV_SYS_STATUS_SENSOR_3D_MAG) result.push(qsTr("Magnetometer"))
            if (bits & MAVLinkEnums.MAV_SYS_STATUS_SENSOR_3D_ACCEL) result.push(qsTr("Accelerometer"))
            if (bits & MAVLinkEnums.MAV_SYS_STATUS_SENSOR_3D_GYRO) result.push(qsTr("Gyroscope"))
            if (bits & MAVLinkEnums.MAV_SYS_STATUS_SENSOR_ABSOLUTE_PRESSURE) result.push(qsTr("Barometer"))
            if (bits & MAVLinkEnums.MAV_SYS_STATUS_SENSOR_DIFFERENTIAL_PRESSURE) result.push(qsTr("Airspeed"))
            if (bits & MAVLinkEnums.MAV_SYS_STATUS_SENSOR_GPS) result.push(qsTr("GPS"))
            if (bits & MAVLinkEnums.MAV_SYS_STATUS_AHRS) result.push(qsTr("AHRS"))
            if (bits & MAVLinkEnums.MAV_SYS_STATUS_SENSOR_RC_RECEIVER) result.push(qsTr("RC Receiver"))
            if (bits & MAVLinkEnums.MAV_SYS_STATUS_PREARM_CHECK) result.push(qsTr("Pre-Arm Check"))
            if (bits & MAVLinkEnums.MAV_SYS_STATUS_SENSOR_BATTERY) result.push(qsTr("Battery"))
            if (bits & MAVLinkEnums.MAV_SYS_STATUS_SENSOR_MOTOR_OUTPUTS) result.push(qsTr("Motor Outputs"))
            if (bits & MAVLinkEnums.MAV_SYS_STATUS_LOGGING) result.push(qsTr("Logging"))
        }
        return result
    }

    clip: true

    // ========================================================================
    // 1. FIXED MASTER SYSTEM HEALTH HERO BANNER (Always Visible While Scrolling)
    // ========================================================================
    Rectangle {
        id: heroBanner
        anchors.top: parent.top
        anchors.topMargin: 52
        anchors.left: parent.left
        anchors.leftMargin: 72
        anchors.right: parent.right
        anchors.rightMargin: CompanyTheme.spacingMd
        z: 20
        radius: CompanyTheme.radiusMd
        color: CompanyTheme.bgCardElevated
        border.color: {
            if (!root._hasVehicle) return CompanyTheme.borderCard
            if (root._activeVehicle.prearmError !== "") return Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.6)
            if (root._linkMgr && root._linkMgr.communicationLost) return Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.6)
            if (!root._activeVehicle.allSensorsHealthy) return Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.6)
            return Qt.rgba(CompanyTheme.success.r, CompanyTheme.success.g, CompanyTheme.success.b, 0.3)
        }
        border.width: 1
        implicitHeight: heroColumn.implicitHeight + CompanyTheme.spacingMd * 2

        ColumnLayout {
            id: heroColumn
            anchors.fill: parent
            anchors.margins: CompanyTheme.spacingMd
            spacing: CompanyTheme.spacingSm

            // Top Status Bar: Master Badge + Armed State + Mode + Quick Chips
            RowLayout {
                Layout.fillWidth: true
                spacing: CompanyTheme.spacingMd

                // Master Flight Readiness Badge
                StatusBadge {
                    text: {
                        if (!CompanyTelemetry.hasVehicle) return qsTr("Disconnected")
                        if (CompanyTelemetry.communicationLost) return qsTr("Comms Lost")
                        if (CompanyTelemetry.armed) return qsTr("Armed")
                        if (root._activeVehicle && (root._activeVehicle.readyToFly || (root._activeVehicle.healthAndArmingCheckReport && root._activeVehicle.healthAndArmingCheckReport.canArm))) return qsTr("Ready To Fly")
                        if (CompanyTelemetry.flying) return qsTr("Airborne")
                        return qsTr("Standby")
                    }
                    badgeColor: {
                        if (!CompanyTelemetry.hasVehicle) return CompanyTheme.textMuted
                        if (CompanyTelemetry.communicationLost) return CompanyTheme.danger
                        if (CompanyTelemetry.armed) return CompanyTheme.danger
                        if (root._activeVehicle && (root._activeVehicle.readyToFly || (root._activeVehicle.healthAndArmingCheckReport && root._activeVehicle.healthAndArmingCheckReport.canArm))) return CompanyTheme.success
                        if (CompanyTelemetry.flying) return CompanyTheme.info
                        return CompanyTheme.warning
                    }
                    pulse: CompanyTelemetry.hasVehicle && CompanyTelemetry.communicationLost
                }

                // Subsystem Sensor Health Indicator Badge (shown whenever sensors are degraded)
                StatusBadge {
                    visible: root._hasVehicle && root._activeVehicle && !root._activeVehicle.allSensorsHealthy
                    text: root._unhealthySensorsList.length > 0 ? (qsTr("Sensors: %1").arg(root._unhealthySensorsList.join(", "))) : qsTr("Sensors Degraded")
                    badgeColor: CompanyTheme.warning
                    showDot: true
                }

                // Armed State Badge
                StatusBadge {
                    visible: CompanyTelemetry.hasVehicle
                    text: CompanyTelemetry.armed ? qsTr("Armed") : qsTr("Disarmed")
                    badgeColor: CompanyTelemetry.armed ? CompanyTheme.danger : CompanyTheme.warning
                    showDot: true
                }

                // Flight Mode Pill
                Rectangle {
                    visible: CompanyTelemetry.hasVehicle && CompanyTelemetry.flightMode !== ""
                    Layout.preferredHeight: 22
                    radius: CompanyTheme.radiusSm
                    color: CompanyTheme.primaryDim
                    implicitWidth: modeLabel.implicitWidth + 12

                    Text {
                        id: modeLabel
                        anchors.centerIn: parent
                        text: CompanyTelemetry.flightMode.toUpperCase()
                        color: CompanyTheme.primary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                    }
                }

                Item { Layout.fillWidth: true }

                // Quick Telemetry Chips
                RowLayout {
                    spacing: CompanyTheme.spacingLg

                    // Link Chip
                    RowLayout {
                        spacing: 4
                        IconVector { name: "comms"; size: 13; color: CompanyTheme.textSecondary }
                        Text {
                            text: root._linkMgr ? root._linkMgr.primaryLinkName : "--"
                            color: CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontSmall
                            font.family: CompanyTheme.fontMono
                        }
                    }

                    // Loss Rate Chip
                    RowLayout {
                        spacing: 4
                        Text { text: qsTr("Loss:"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontSmall }
                        Text {
                            text: root._hasVehicle ? root._activeVehicle.mavlinkLossPercent.toFixed(1) + "%" : "--"
                            color: (root._hasVehicle && root._activeVehicle.mavlinkLossPercent > 5) ? CompanyTheme.warning : CompanyTheme.textPrimary
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                            font.family: CompanyTheme.fontMono
                        }
                    }

                    // GPS Chip
                    RowLayout {
                        spacing: 4
                        IconVector { name: "gps"; size: 13; color: CompanyTheme.textSecondary }
                        Text {
                            text: root._gps ? (root._gps.lock.enumStringValue + " (" + root._gps.count.valueString + ")") : "--"
                            color: (root._gps && root._gps.lock.rawValue >= 3) ? CompanyTheme.success : CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                        }
                    }
                }
            }

            // Pre-arm Error Warning Strip (Visible when prearm error is reported)
            Rectangle {
                Layout.fillWidth: true
                visible: root._hasVehicle && root._activeVehicle.prearmError !== ""
                radius: CompanyTheme.radiusSm
                color: Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.15)
                border.color: CompanyTheme.danger
                border.width: 1
                implicitHeight: prearmRow.implicitHeight + 8

                RowLayout {
                    id: prearmRow
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    IconVector { name: "warning"; size: 16; color: CompanyTheme.danger }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("PRE-ARM REJECTED: ") + (root._activeVehicle ? root._activeVehicle.prearmError : "")
                        color: CompanyTheme.danger
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Degraded Sensors Warning Strip (Visible when prearm is ok but sensors are degraded)
            Rectangle {
                Layout.fillWidth: true
                visible: root._hasVehicle && root._activeVehicle.prearmError === "" && !root._activeVehicle.allSensorsHealthy && root._unhealthySensorsList.length > 0
                radius: CompanyTheme.radiusSm
                color: Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.15)
                border.color: CompanyTheme.warning
                border.width: 1
                implicitHeight: sensorWarnRow.implicitHeight + 8

                RowLayout {
                    id: sensorWarnRow
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    IconVector { name: "warning"; size: 16; color: CompanyTheme.warning }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("ATTENTION: Degraded sensor(s) reported by vehicle SYS_STATUS: ") + root._unhealthySensorsList.join(", ")
                        color: CompanyTheme.warning
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    // ========================================================================
    // 2. SCROLLABLE DIAGNOSTICS VIEWPORT (Independent Vertical Scrolling)
    // ========================================================================
    Flickable {
        id: flickable
        anchors.top: heroBanner.bottom
        anchors.topMargin: CompanyTheme.spacingMd
        anchors.left: parent.left
        anchors.leftMargin: 72
        anchors.right: parent.right
        anchors.rightMargin: CompanyTheme.spacingMd
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 68
        clip: true
        contentWidth: width
        contentHeight: cardsContainer.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        // Elegant CompanyTheme Vertical Scrollbar
        ScrollBar.vertical: ScrollBar {
            id: vScrollBar
            parent: flickable
            anchors.top: flickable.top
            anchors.right: flickable.right
            anchors.bottom: flickable.bottom
            anchors.rightMargin: 2
            policy: flickable.contentHeight > flickable.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
            width: 6

            contentItem: Rectangle {
                implicitWidth: 6
                radius: 3
                color: vScrollBar.pressed ? CompanyTheme.accent : (vScrollBar.hovered ? CompanyTheme.borderActive : Qt.rgba(CompanyTheme.textSecondary.r, CompanyTheme.textSecondary.g, CompanyTheme.textSecondary.b, 0.35))
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            background: Rectangle {
                implicitWidth: 6
                color: Qt.rgba(0, 0, 0, 0.15)
                radius: 3
            }
        }

        Item {
            id: cardsContainer
            width: flickable.width - (vScrollBar.visible ? 10 : 0)
            implicitHeight: diagGrid.implicitHeight + CompanyTheme.spacingLg

            GridLayout {
                id: diagGrid
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                columns: root.width > 1280 ? 3 : (root.width > 760 ? 2 : 1)
                columnSpacing: CompanyTheme.spacingMd
                rowSpacing: CompanyTheme.spacingMd

                // ============================================================
                // CARD 1: Vehicle Identity & Firmware
                // ============================================================
                CompanyCard {
                    Layout.fillWidth: true
                    title: qsTr("Vehicle Identity & Firmware")
                    subtitle: qsTr("Hardware platform & autopilot build")
                    headerAccent: CompanyTheme.primary

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 7

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("System ID"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._hasVehicle ? qsTr("SYS ID %1").arg(root._activeVehicle.id) : "--"
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.bold: true
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Airframe Type"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._hasVehicle ? root._activeVehicle.vehicleTypeString : "--"
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Motors / Actuators"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._hasVehicle ? qsTr("%1 Motors").arg(root._activeVehicle.motorCount) : "--"
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Autopilot Stack"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._hasVehicle ? root._activeVehicle.firmwareTypeString : "--"
                                color: CompanyTheme.primary
                                font.pointSize: CompanyTheme.fontSmall
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Firmware Version"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: {
                                    if (!root._hasVehicle || root._activeVehicle.firmwareMajorVersion <= 0) return "--"
                                    var v = root._activeVehicle.firmwareMajorVersion + "." + root._activeVehicle.firmwareMinorVersion + "." + root._activeVehicle.firmwarePatchVersion
                                    if (root._activeVehicle.firmwareVersionTypeString !== "") {
                                        v += " (" + root._activeVehicle.firmwareVersionTypeString + ")"
                                    }
                                    return v
                                }
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Git Commit SHA"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (root._hasVehicle && root._activeVehicle.gitHash !== "") ? root._activeVehicle.gitHash.substring(0, 8) : "--"
                                color: CompanyTheme.textMuted
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Hardware UID"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (root._hasVehicle && root._activeVehicle.vehicleUIDStr !== "") ? root._activeVehicle.vehicleUIDStr : "--"
                                color: CompanyTheme.textMuted
                                font.pointSize: CompanyTheme.fontTiny
                                font.family: CompanyTheme.fontMono
                                elide: Text.ElideMiddle
                                Layout.maximumWidth: 150
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Hobbs Operating Meter"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (root._hasVehicle && root._activeVehicle.hobbsMeter !== "") ? root._activeVehicle.hobbsMeter : "--"
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                                font.bold: true
                            }
                        }
                    }
                }

                // ============================================================
                // CARD 2: Communications & MAVLink Telemetry
                // ============================================================
                CompanyCard {
                    Layout.fillWidth: true
                    title: qsTr("Communications & Telemetry")
                    subtitle: qsTr("MAVLink link health & packet stats")
                    headerAccent: (!root._hasVehicle || (root._linkMgr && root._linkMgr.communicationLost)) ? CompanyTheme.danger : CompanyTheme.info

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 7

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Active Primary Link"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._linkMgr ? root._linkMgr.primaryLinkName : "--"
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Link Status"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            StatusBadge {
                                text: (!root._hasVehicle || (root._linkMgr && root._linkMgr.communicationLost)) ? qsTr("Lost") : qsTr("Connected")
                                badgeColor: (!root._hasVehicle || (root._linkMgr && root._linkMgr.communicationLost)) ? CompanyTheme.danger : CompanyTheme.success
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Packet Loss Rate"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._hasVehicle ? root._activeVehicle.mavlinkLossPercent.toFixed(1) + "%" : "--"
                                color: (root._hasVehicle && root._activeVehicle.mavlinkLossPercent > 5) ? CompanyTheme.warning : CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Lost Packet Count"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._hasVehicle ? root._activeVehicle.mavlinkLossCount.toLocaleString() : "--"
                                color: (root._hasVehicle && root._activeVehicle.mavlinkLossCount > 0) ? CompanyTheme.warning : CompanyTheme.textSecondary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Packets Transmitted"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._hasVehicle ? root._activeVehicle.mavlinkSentCount.toLocaleString() : "--"
                                color: CompanyTheme.textSecondary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Packets Received"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._hasVehicle ? root._activeVehicle.mavlinkReceivedCount.toLocaleString() : "--"
                                color: CompanyTheme.textSecondary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("RC Receiver Signal"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                readonly property bool isValidRSSI: root._hasVehicle && root._activeVehicle.rcRSSI && !isNaN(root._activeVehicle.rcRSSI.rawValue) && root._activeVehicle.rcRSSI.rawValue >= 0 && root._activeVehicle.rcRSSI.rawValue <= 100
                                text: isValidRSSI ? (root._activeVehicle.rcRSSI.valueString + "%") : qsTr("Unavailable")
                                color: isValidRSSI ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                                font.bold: isValidRSSI
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Telemetry Radio (L/R)"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (root._radioStatus && !isNaN(root._radioStatus.lrssi.rawValue)) ? (root._radioStatus.lrssi.valueString + " / " + root._radioStatus.rrssi.valueString + " dBm") : "N/A"
                                color: CompanyTheme.textMuted
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }
                    }
                }

                // ============================================================
                // CARD 3: GNSS & Navigation Subsystem
                // ============================================================
                CompanyCard {
                    Layout.fillWidth: true
                    title: qsTr("GNSS & Navigation")
                    subtitle: qsTr("Constellation tracking & dilution of precision")
                    headerAccent: (root._gps && root._gps.lock.rawValue >= 3) ? CompanyTheme.success : CompanyTheme.warning

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 7

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Fix Lock State"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            StatusBadge {
                                text: root._gps ? root._gps.lock.enumStringValue : "--"
                                badgeColor: (root._gps && root._gps.lock.rawValue >= 3) ? CompanyTheme.success : CompanyTheme.warning
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Satellites Tracked"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._gps ? root._gps.count.valueString : "--"
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Horizontal DOP (HDOP)"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._gps ? root._gps.hdop.valueString : "--"
                                color: (root._gps && root._gps.hdop.rawValue > 2.0) ? CompanyTheme.warning : CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Vertical DOP (VDOP)"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._gps ? root._gps.vdop.valueString : "--"
                                color: CompanyTheme.textSecondary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Latitude"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (root._gps && !isNaN(root._gps.lat.rawValue)) ? (root._gps.lat.value.toFixed(6) + "°") : "--"
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Longitude"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (root._gps && !isNaN(root._gps.lon.rawValue)) ? (root._gps.lon.value.toFixed(6) + "°") : "--"
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Jamming Status"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                readonly property int jamVal: (root._gps && !isNaN(root._gps.jammingState.rawValue)) ? root._gps.jammingState.rawValue : 255
                                text: {
                                    if (jamVal === 255) return qsTr("N/A")
                                    if (jamVal === 0) return qsTr("Unknown")
                                    if (jamVal === 1) return qsTr("Not Jammed")
                                    if (jamVal === 2) return qsTr("Mitigated")
                                    if (jamVal === 3) return qsTr("DETECTED")
                                    return (root._gps && root._gps.jammingState.enumStringValue) ? root._gps.jammingState.enumStringValue : qsTr("N/A")
                                }
                                color: {
                                    if (jamVal === 255 || jamVal === 0) return CompanyTheme.textMuted
                                    if (jamVal === 1) return CompanyTheme.success
                                    if (jamVal === 2) return CompanyTheme.warning
                                    return CompanyTheme.danger
                                }
                                font.pointSize: CompanyTheme.fontSmall
                                font.bold: jamVal > 1 && jamVal < 255
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Spoofing Status"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                readonly property int spoofVal: (root._gps && !isNaN(root._gps.spoofingState.rawValue)) ? root._gps.spoofingState.rawValue : 255
                                text: {
                                    if (spoofVal === 255) return qsTr("N/A")
                                    if (spoofVal === 0) return qsTr("Unknown")
                                    if (spoofVal === 1) return qsTr("Not Spoofed")
                                    if (spoofVal === 2) return qsTr("Mitigated")
                                    if (spoofVal === 3) return qsTr("DETECTED")
                                    return (root._gps && root._gps.spoofingState.enumStringValue) ? root._gps.spoofingState.enumStringValue : qsTr("N/A")
                                }
                                color: {
                                    if (spoofVal === 255 || spoofVal === 0) return CompanyTheme.textMuted
                                    if (spoofVal === 1) return CompanyTheme.success
                                    if (spoofVal === 2) return CompanyTheme.warning
                                    return CompanyTheme.danger
                                }
                                font.pointSize: CompanyTheme.fontSmall
                                font.bold: spoofVal > 1 && spoofVal < 255
                            }
                        }
                    }
                }

                // ============================================================
                // CARD 4: Power & Battery Subsystem
                // ============================================================
                CompanyCard {
                    Layout.fillWidth: true
                    title: qsTr("Power & Batteries")
                    subtitle: (root._batteries && root._batteries.count > 1) ? qsTr("Pack %1 of %2").arg(root.selectedBatteryIndex + 1).arg(root._batteries.count) : qsTr("Primary power bus")
                    headerAccent: (root._currentBattery && root._currentBattery.percentRemaining.rawValue < 20) ? CompanyTheme.danger : CompanyTheme.accent

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 7

                        // Multi-battery selector tabs
                        RowLayout {
                            Layout.fillWidth: true
                            visible: root._batteries && root._batteries.count > 1
                            spacing: 4

                            Repeater {
                                model: root._batteries ? root._batteries.count : 0
                                delegate: Rectangle {
                                    id: batTab
                                    required property int index

                                    Layout.preferredHeight: 22
                                    Layout.preferredWidth: 60
                                    radius: CompanyTheme.radiusSm
                                    color: root.selectedBatteryIndex === batTab.index ? CompanyTheme.primaryDim : CompanyTheme.bgInput
                                    border.color: root.selectedBatteryIndex === batTab.index ? CompanyTheme.primary : CompanyTheme.borderCard

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("BAT %1").arg(batTab.index + 1)
                                        color: root.selectedBatteryIndex === batTab.index ? CompanyTheme.primary : CompanyTheme.textSecondary
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectedBatteryIndex = batTab.index
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Remaining Charge"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._currentBattery ? (root._currentBattery.percentRemaining.valueString + "%") : "--"
                                color: {
                                    if (!root._currentBattery || isNaN(root._currentBattery.percentRemaining.rawValue)) return CompanyTheme.textMuted
                                    if (root._currentBattery.percentRemaining.rawValue <= 15) return CompanyTheme.danger
                                    if (root._currentBattery.percentRemaining.rawValue <= 25) return CompanyTheme.warning
                                    return CompanyTheme.success
                                }
                                font.pointSize: CompanyTheme.fontH3
                                font.family: CompanyTheme.fontMono
                                font.bold: true
                            }
                        }

                        // Battery Capacity Meter
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: CompanyTheme.bgInput

                            Rectangle {
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                width: (root._currentBattery && !isNaN(root._currentBattery.percentRemaining.rawValue)) ? (parent.width * Math.max(0, Math.min(100, root._currentBattery.percentRemaining.rawValue)) / 100) : 0
                                radius: 3
                                color: {
                                    if (!root._currentBattery || isNaN(root._currentBattery.percentRemaining.rawValue)) return CompanyTheme.textMuted
                                    if (root._currentBattery.percentRemaining.rawValue <= 15) return CompanyTheme.danger
                                    if (root._currentBattery.percentRemaining.rawValue <= 25) return CompanyTheme.warning
                                    return CompanyTheme.success
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Bus Voltage"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._currentBattery ? (root._currentBattery.voltage.valueString + " " + root._currentBattery.voltage.units) : "--"
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Current Draw"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                readonly property bool hasCurrent: root._currentBattery && !isNaN(root._currentBattery.current.rawValue)
                                text: hasCurrent ? (root._currentBattery.current.valueString + " " + root._currentBattery.current.units) : qsTr("N/A")
                                color: hasCurrent ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Consumed Capacity"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                readonly property bool hasMah: root._currentBattery && !isNaN(root._currentBattery.mahConsumed.rawValue)
                                text: hasMah ? (root._currentBattery.mahConsumed.valueString + " mAh") : qsTr("N/A")
                                color: hasMah ? CompanyTheme.textSecondary : CompanyTheme.textMuted
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Instantaneous Power"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                readonly property bool hasPower: root._currentBattery && !isNaN(root._currentBattery.instantPower.rawValue)
                                text: hasPower ? (root._currentBattery.instantPower.valueString + " W") : qsTr("N/A")
                                color: hasPower ? CompanyTheme.textSecondary : CompanyTheme.textMuted
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Pack Temperature"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                readonly property bool hasTemp: root._currentBattery && !isNaN(root._currentBattery.temperature.rawValue)
                                text: hasTemp ? (root._currentBattery.temperature.valueString + " °C") : qsTr("N/A")
                                color: hasTemp ? CompanyTheme.textSecondary : CompanyTheme.textMuted
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Estimated Flight Time"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                readonly property bool hasTime: root._currentBattery && !isNaN(root._currentBattery.timeRemaining.rawValue) && root._currentBattery.timeRemainingStr.value !== "––:––:––" && root._currentBattery.timeRemainingStr.value !== ""
                                text: hasTime ? root._currentBattery.timeRemainingStr.value : qsTr("N/A")
                                color: hasTime ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                                font.bold: hasTime
                            }
                        }
                    }
                }

                // ============================================================
                // CARD 5: Sensors & Subsystems Health (Genuinely Traces Degraded Sensor)
                // ============================================================
                CompanyCard {
                    Layout.fillWidth: true
                    title: qsTr("Sensors & Subsystems")
                    subtitle: qsTr("SYS_STATUS avionics health monitors")
                    headerAccent: (root._hasVehicle && root._activeVehicle.allSensorsHealthy) ? CompanyTheme.success : CompanyTheme.warning

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 7

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Overall Sensor Health"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            StatusBadge {
                                text: (root._hasVehicle && root._activeVehicle.allSensorsHealthy) ? qsTr("All Healthy") : (root._hasVehicle ? qsTr("Attention Required") : "--")
                                badgeColor: (root._hasVehicle && root._activeVehicle.allSensorsHealthy) ? CompanyTheme.success : (root._hasVehicle ? CompanyTheme.warning : CompanyTheme.textMuted)
                            }
                        }

                        // Explicit Degraded Sensors Alert Box
                        Rectangle {
                            Layout.fillWidth: true
                            visible: root._hasVehicle && !root._activeVehicle.allSensorsHealthy && root._unhealthySensorsList.length > 0
                            radius: CompanyTheme.radiusSm
                            color: Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.12)
                            border.color: CompanyTheme.warning
                            border.width: 1
                            implicitHeight: unhCol.implicitHeight + 10

                            ColumnLayout {
                                id: unhCol
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 2

                                Text {
                                    text: qsTr("AFFECTED SENSORS / SUBSYSTEMS:")
                                    color: CompanyTheme.warning
                                    font.pointSize: CompanyTheme.fontTiny
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root._unhealthySensorsList.join(" • ")
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: CompanyTheme.fontSmall
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        // Dynamic Sensor Items from SysStatusSensorInfo (Unhealthy sensors appear at the top)
                        Repeater {
                            model: (root._sensorInfo && root._sensorInfo.sensorNames) ? root._sensorInfo.sensorNames.length : 0
                            delegate: RowLayout {
                                id: sensorRow
                                required property int index

                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: root._sensorInfo.sensorNames[sensorRow.index]
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: CompanyTheme.fontSmall
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                StatusBadge {
                                    readonly property string statusStr: root._sensorInfo.sensorStatus[sensorRow.index]
                                    text: statusStr
                                    badgeColor: statusStr === "Normal" ? CompanyTheme.success : (statusStr === "Error" ? CompanyTheme.danger : CompanyTheme.textMuted)
                                    showDot: false
                                }
                            }
                        }

                        // Fallback static checklist when sensorInfo is initializing
                        ColumnLayout {
                            visible: !root._sensorInfo || !root._sensorInfo.sensorNames || root._sensorInfo.sensorNames.length === 0
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: [
                                    { name: "3D Accelerometer", bit: MAVLinkEnums.MAV_SYS_STATUS_SENSOR_3D_ACCEL },
                                    { name: "3D Gyroscope",     bit: MAVLinkEnums.MAV_SYS_STATUS_SENSOR_3D_GYRO },
                                    { name: "3D Magnetometer",  bit: MAVLinkEnums.MAV_SYS_STATUS_SENSOR_3D_MAG },
                                    { name: "Barometer",        bit: MAVLinkEnums.MAV_SYS_STATUS_SENSOR_ABSOLUTE_PRESSURE },
                                    { name: "AHRS Subsystem",   bit: MAVLinkEnums.MAV_SYS_STATUS_AHRS }
                                ]

                                delegate: RowLayout {
                                    id: defaultSensorRow
                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: defaultSensorRow.modelData.name
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontSmall
                                        Layout.fillWidth: true
                                    }

                                    StatusBadge {
                                        readonly property bool isUnhealthy: root._hasVehicle && (root._activeVehicle.sensorsUnhealthyBits & defaultSensorRow.modelData.bit)
                                        text: !root._hasVehicle ? "--" : (isUnhealthy ? qsTr("Error") : qsTr("Normal"))
                                        badgeColor: !root._hasVehicle ? CompanyTheme.textMuted : (isUnhealthy ? CompanyTheme.danger : CompanyTheme.success)
                                        showDot: false
                                    }
                                }
                            }
                        }
                    }
                }

                // ============================================================
                // CARD 6: EKF & State Estimation Metrics
                // ============================================================
                CompanyCard {
                    Layout.fillWidth: true
                    title: qsTr("EKF / State Estimator")
                    subtitle: qsTr("Kalman filter solution integrity")
                    headerAccent: CompanyTheme.primary

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 7

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Attitude Estimate"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            StatusBadge {
                                text: (root._estimator && root._estimator.goodAttitudeEstimate.value) ? qsTr("Valid") : (root._hasVehicle ? qsTr("Degraded") : "--")
                                badgeColor: (root._estimator && root._estimator.goodAttitudeEstimate.value) ? CompanyTheme.success : CompanyTheme.warning
                                showDot: false
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Horizontal Velocity"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            StatusBadge {
                                text: (root._estimator && root._estimator.goodHorizVelEstimate.value) ? qsTr("Valid") : (root._hasVehicle ? qsTr("Degraded") : "--")
                                badgeColor: (root._estimator && root._estimator.goodHorizVelEstimate.value) ? CompanyTheme.success : CompanyTheme.warning
                                showDot: false
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Vertical Velocity"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            StatusBadge {
                                text: (root._estimator && root._estimator.goodVertVelEstimate.value) ? qsTr("Valid") : (root._hasVehicle ? qsTr("Degraded") : "--")
                                badgeColor: (root._estimator && root._estimator.goodVertVelEstimate.value) ? CompanyTheme.success : CompanyTheme.warning
                                showDot: false
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Absolute Position (Horiz)"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            StatusBadge {
                                text: (root._estimator && root._estimator.goodHorizPosAbsEstimate.value) ? qsTr("Valid") : (root._hasVehicle ? qsTr("Degraded") : "--")
                                badgeColor: (root._estimator && root._estimator.goodHorizPosAbsEstimate.value) ? CompanyTheme.success : CompanyTheme.warning
                                showDot: false
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Absolute Position (Vert)"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            StatusBadge {
                                text: (root._estimator && root._estimator.goodVertPosAbsEstimate.value) ? qsTr("Valid") : (root._hasVehicle ? qsTr("Degraded") : "--")
                                badgeColor: (root._estimator && root._estimator.goodVertPosAbsEstimate.value) ? CompanyTheme.success : CompanyTheme.warning
                                showDot: false
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("GPS Glitch Flag"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (root._estimator && root._estimator.gpsGlitch.value) ? qsTr("DETECTED") : qsTr("None")
                                color: (root._estimator && root._estimator.gpsGlitch.value) ? CompanyTheme.danger : CompanyTheme.success
                                font.pointSize: CompanyTheme.fontSmall
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Accel Fault Flag"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (root._estimator && root._estimator.accelError.value) ? qsTr("FAULT") : qsTr("None")
                                color: (root._estimator && root._estimator.accelError.value) ? CompanyTheme.danger : CompanyTheme.success
                                font.pointSize: CompanyTheme.fontSmall
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Position Accuracy (1σ)"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._estimator ? ("H: ±" + root._estimator.horizPosAccuracy.valueString + "m  V: ±" + root._estimator.vertPosAccuracy.valueString + "m") : "--"
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }
                    }
                }

                // ============================================================
                // CARD 7: Dynamics & Thermal Monitors
                // ============================================================
                CompanyCard {
                    Layout.fillWidth: true
                    title: qsTr("Dynamics & Thermal")
                    subtitle: qsTr("Vibration levels, clips & temperature")
                    headerAccent: CompanyTheme.primary

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 7

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("X-Axis Vibration"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._vibration ? (root._vibration.xAxis.valueString + " m/s²") : "--"
                                color: (root._vibration && root._vibration.xAxis.rawValue > 15.0) ? CompanyTheme.warning : CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Y-Axis Vibration"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._vibration ? (root._vibration.yAxis.valueString + " m/s²") : "--"
                                color: (root._vibration && root._vibration.yAxis.rawValue > 15.0) ? CompanyTheme.warning : CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Z-Axis Vibration"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._vibration ? (root._vibration.zAxis.valueString + " m/s²") : "--"
                                color: (root._vibration && root._vibration.zAxis.rawValue > 20.0) ? CompanyTheme.warning : CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                                font.bold: true
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Accel Clip Count 1"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._vibration ? root._vibration.clipCount1.valueString : "--"
                                color: (root._vibration && root._vibration.clipCount1.rawValue > 0) ? CompanyTheme.warning : CompanyTheme.textSecondary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Accel Clip Count 2"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._vibration ? root._vibration.clipCount2.valueString : "--"
                                color: (root._vibration && root._vibration.clipCount2.rawValue > 0) ? CompanyTheme.warning : CompanyTheme.textSecondary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Accel Clip Count 3"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root._vibration ? root._vibration.clipCount3.valueString : "--"
                                color: (root._vibration && root._vibration.clipCount3.rawValue > 0) ? CompanyTheme.warning : CompanyTheme.textSecondary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("IMU Core Temp"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (root._hasVehicle && !isNaN(root._activeVehicle.imuTemp.rawValue)) ? (root._activeVehicle.imuTemp.valueString + " °C") : "--"
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Barometer Temp"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (root._hasVehicle && root._activeVehicle.temperature && !isNaN(root._activeVehicle.temperature.temperature1.rawValue)) ? (root._activeVehicle.temperature.temperature1.valueString + " °C") : "--"
                                color: CompanyTheme.textSecondary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }
                    }
                }

                // ============================================================
                // CARD 8: Link Details & Vehicle Capabilities (Sections 9 & 10)
                // ============================================================
                CompanyCard {
                    Layout.fillWidth: true
                    title: qsTr("Link Details & Capabilities")
                    subtitle: qsTr("Connected interfaces & autopilot features")
                    headerAccent: CompanyTheme.info

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 7

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Flight Readiness"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: qsTr("See System Health")
                                color: CompanyTheme.textMuted
                                font.pointSize: CompanyTheme.fontSmall
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("GCS Walkaround Checklist"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            StatusBadge {
                                text: {
                                    if (!root._hasVehicle) return "--"
                                    if (root._activeVehicle.checkListState === 1) return qsTr("Completed")
                                    if (root._activeVehicle.checkListState === 2) return qsTr("Failed")
                                    return qsTr("NOT SET UP")
                                }
                                badgeColor: {
                                    if (!root._hasVehicle) return CompanyTheme.textMuted
                                    if (root._activeVehicle.checkListState === 1) return CompanyTheme.success
                                    if (root._activeVehicle.checkListState === 2) return CompanyTheme.danger
                                    return CompanyTheme.textMuted
                                }
                                showDot: false
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Guided Mode Control"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            StatusBadge {
                                text: (root._hasVehicle && root._activeVehicle.guidedMode) ? qsTr("ENGAGED") : (root._hasVehicle ? qsTr("AVAILABLE") : "--")
                                badgeColor: (root._hasVehicle && root._activeVehicle.guidedMode) ? CompanyTheme.primary : CompanyTheme.textMuted
                                showDot: false
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Flight Mode"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (root._hasVehicle && root._activeVehicle.flightMode !== "") ? root._activeVehicle.flightMode.toUpperCase() : "--"
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                                font.bold: true
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Radio TX Buffer"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (root._radioStatus && !isNaN(root._radioStatus.txBuffer.rawValue)) ? (root._radioStatus.txBuffer.valueString + "%") : "N/A"
                                color: CompanyTheme.textSecondary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Radio Noise (L/R)"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (root._radioStatus && !isNaN(root._radioStatus.lNoise.rawValue)) ? (root._radioStatus.lNoise.valueString + " / " + root._radioStatus.rNoise.valueString + " dBm") : "N/A"
                                color: CompanyTheme.textMuted
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }
                        }

                        // Attached Links List
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: root._linkMgr && root._linkMgr.linkNames && root._linkMgr.linkNames.length > 0

                            Text {
                                text: qsTr("Attached Interface Links:")
                                color: CompanyTheme.textSecondary
                                font.pointSize: CompanyTheme.fontTiny
                                font.bold: true
                            }

                            Repeater {
                                model: root._linkMgr ? root._linkMgr.linkNames.length : 0
                                delegate: RowLayout {
                                    id: linkRow
                                    required property int index

                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: "• " + root._linkMgr.linkNames[linkRow.index]
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.family: CompanyTheme.fontMono
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: (root._linkMgr.linkStatuses && root._linkMgr.linkStatuses.length > linkRow.index) ? root._linkMgr.linkStatuses[linkRow.index] : ""
                                        color: CompanyTheme.textMuted
                                        font.pointSize: CompanyTheme.fontTiny
                                    }
                                }
                            }
                        }
                    }
                }

                // ============================================================
                // CARD 9: Vehicle Event & Warning Log (Section 11)
                // ============================================================
                CompanyCard {
                    Layout.fillWidth: true
                    Layout.columnSpan: diagGrid.columns
                    title: qsTr("Recent Vehicle Events & System Log")
                    subtitle: qsTr("Autopilot STATUSTEXT message stream")
                    headerAccent: (root._hasVehicle && root._activeVehicle.messageTypeError) ? CompanyTheme.danger : ((root._hasVehicle && root._activeVehicle.messageTypeWarning) ? CompanyTheme.warning : CompanyTheme.primary)

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 8

                        // Log Control Toolbar
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: qsTr("Logged Messages: %1").arg(root._hasVehicle ? root._activeVehicle.messageCount : 0)
                                color: CompanyTheme.textSecondary
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                            }

                            StatusBadge {
                                visible: root._hasVehicle && root._activeVehicle.messageTypeError
                                text: qsTr("Errors Present")
                                badgeColor: CompanyTheme.danger
                                pulse: true
                            }

                            StatusBadge {
                                visible: root._hasVehicle && !root._activeVehicle.messageTypeError && root._activeVehicle.messageTypeWarning
                                text: qsTr("Warnings Present")
                                badgeColor: CompanyTheme.warning
                            }

                            Item { Layout.fillWidth: true }

                            CompanyButton {
                                text: qsTr("Clear Log")
                                Layout.preferredHeight: 26
                                isOutline: true
                                enabled: root._hasVehicle
                                onClicked: {
                                    if (root._hasVehicle) {
                                        root._activeVehicle.clearMessages()
                                        logTextArea.text = ""
                                    }
                                }
                            }
                        }

                        // Message Box
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 220
                            radius: CompanyTheme.radiusSm
                            color: CompanyTheme.bgInput
                            border.color: CompanyTheme.borderCard
                            border.width: 1
                            clip: true

                            ScrollView {
                                anchors.fill: parent
                                anchors.margins: 8
                                clip: true
                                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                TextArea {
                                    id: logTextArea
                                    readOnly: true
                                    textFormat: TextEdit.RichText
                                    wrapMode: TextEdit.Wrap
                                    color: CompanyTheme.textPrimary
                                    font.family: CompanyTheme.fontMono
                                    font.pointSize: CompanyTheme.fontSmall
                                    placeholderText: qsTr("No system messages logged.")
                                    placeholderTextColor: CompanyTheme.textMuted
                                    background: null
                                    padding: 0

                                    function formatLogMessage(msg) {
                                        if (!msg) return ""
                                        msg = msg.replace(new RegExp("<#E>", "g"), "<span style='color: #EF4444; font-weight: bold;'>[ERROR] </span>")
                                        msg = msg.replace(new RegExp("<#I>", "g"), "<span style='color: #F59E0B; font-weight: bold;'>[WARN] </span>")
                                        msg = msg.replace(new RegExp("<#N>", "g"), "<span style='color: #94A3B8;'>[INFO] </span>")
                                        return msg
                                    }

                                    Component.onCompleted: {
                                        if (root._hasVehicle && root._activeVehicle.formattedMessages !== "") {
                                            logTextArea.text = formatLogMessage(root._activeVehicle.formattedMessages)
                                            root._activeVehicle.resetAllMessages()
                                        }
                                    }

                                    Connections {
                                        target: root._activeVehicle
                                        function onNewFormattedMessage(formattedMessage) {
                                            logTextArea.insert(0, logTextArea.formatLogMessage(formattedMessage) + "<br/>")
                                        }
                                        function onFormattedMessagesChanged() {
                                            if (root._hasVehicle) {
                                                logTextArea.text = logTextArea.formatLogMessage(root._activeVehicle.formattedMessages)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
