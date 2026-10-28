pragma Singleton
pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QGroundControl
import Company.UI

Item {
    id: root
    visible: false

    // ========================================================================
    // 1. Authoritative Vehicle Reference
    // ========================================================================
    readonly property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool hasVehicle:   activeVehicle !== null

    // Internal FactGroup and Link helpers (null-guarded)
    readonly property var _battery:      (hasVehicle && activeVehicle.batteries && activeVehicle.batteries.count > 0) ? activeVehicle.batteries.get(0) : null
    readonly property var _gps:          (hasVehicle && activeVehicle.gps) ? activeVehicle.gps : null
    readonly property var _linkMgr:      (hasVehicle && activeVehicle.vehicleLinkManager) ? activeVehicle.vehicleLinkManager : null
    readonly property var _gimbalMgr:    (hasVehicle && activeVehicle.gimbalController) ? activeVehicle.gimbalController : null
    readonly property var _activeGimbal: (_gimbalMgr && _gimbalMgr.activeGimbal) ? _gimbalMgr.activeGimbal : null
    readonly property var _cameraMgr:    (hasVehicle && activeVehicle.cameraManager) ? activeVehicle.cameraManager : null
    readonly property var _activeCamera: (_cameraMgr && _cameraMgr.currentCameraInstance) ? _cameraMgr.currentCameraInstance : null

    // ========================================================================
    // 2. Core Vehicle State
    // ========================================================================
    readonly property int    vehicleId:          hasVehicle ? activeVehicle.id : 0
    readonly property bool   armed:              hasVehicle && activeVehicle.armed
    readonly property bool   flying:             hasVehicle && activeVehicle.flying
    readonly property bool   isAirborne:         hasVehicle && activeVehicle.flying
    readonly property bool   isGrounded:         hasVehicle && !activeVehicle.flying && !activeVehicle.landing
    readonly property string flightMode:         hasVehicle ? activeVehicle.flightMode : ""

    // ========================================================================
    // 3. Battery Telemetry
    // ========================================================================
    readonly property bool   hasBattery:         _battery !== null && _battery.percentRemaining && !isNaN(_battery.percentRemaining.value)
    readonly property real   batteryPercent:     hasBattery ? _battery.percentRemaining.value : NaN
    readonly property string batteryPercentStr:  hasBattery ? (Math.round(batteryPercent) + "%") : "--%"
    readonly property real   batteryVoltage:     (_battery && _battery.voltage && !isNaN(_battery.voltage.value)) ? _battery.voltage.value : NaN
    readonly property string batteryVoltageStr:  !isNaN(batteryVoltage) ? (batteryVoltage.toFixed(1) + "V") : "--"
    readonly property real   batteryCurrent:     (_battery && _battery.current && !isNaN(_battery.current.value)) ? _battery.current.value : NaN
    readonly property string batteryCurrentStr:  !isNaN(batteryCurrent) ? (batteryCurrent.toFixed(1) + "A") : "--"
    readonly property bool   hasBatteryConsumed: (_battery && _battery.mahConsumed && !isNaN(_battery.mahConsumed.rawValue) && _battery.mahConsumed.rawValue >= 0)
    readonly property real   batteryConsumedMah: hasBatteryConsumed ? Number(_battery.mahConsumed.rawValue) : NaN
    readonly property string batteryConsumedMahStr: hasBatteryConsumed ? (Math.round(batteryConsumedMah) + " mAh") : "-- mAh"

    // Battery Pack Temperature
    readonly property real   batteryTemperature: (_battery && _battery.temperature && !isNaN(_battery.temperature.value)) ? _battery.temperature.value : NaN
    readonly property bool   hasBatteryTemperature: !isNaN(batteryTemperature) && batteryTemperature > -40 && batteryTemperature < 120
    readonly property string batteryTemperatureStr: hasBatteryTemperature ? (Math.round(batteryTemperature) + "°C") : "--°C"

    // Real-Time Estimated Flight Time Remaining (Endurance)
    readonly property real   batteryTimeRemainingSec: {
        if (_battery && _battery.timeRemaining && !isNaN(_battery.timeRemaining.rawValue) && _battery.timeRemaining.rawValue > 0) {
            return Number(_battery.timeRemaining.rawValue)
        }
        if (hasBattery && !isNaN(batteryCurrent) && batteryCurrent > 0.5 && !isNaN(batteryPercent) && batteryPercent > 0) {
            if (hasBatteryConsumed && batteryConsumedMah > 20 && batteryPercent < 98) {
                var estTotalMah = batteryConsumedMah / (1.0 - (batteryPercent / 100.0))
                var estRemainingMah = estTotalMah * (batteryPercent / 100.0)
                var estSec = (estRemainingMah / (batteryCurrent * 1000.0)) * 3600.0
                if (estSec > 0 && estSec < 86400) {
                    return estSec
                }
            }
        }
        return NaN
    }
    readonly property bool   hasBatteryTimeRemaining: !isNaN(batteryTimeRemainingSec) && batteryTimeRemainingSec > 0
    readonly property string batteryTimeRemainingStr: {
        if (!hasBatteryTimeRemaining) return "--:--"
        var totalSec = Math.round(batteryTimeRemainingSec)
        var m = Math.floor(totalSec / 60)
        var s = totalSec % 60
        if (m >= 60) {
            var h = Math.floor(m / 60)
            m = m % 60
            return h + "h " + m + "m"
        }
        return m + "m " + (s < 10 ? "0" : "") + s + "s"
    }
    readonly property string batteryEnduranceShortStr: {
        if (!hasBatteryTimeRemaining) return ""
        var mins = Math.round(batteryTimeRemainingSec / 60)
        return mins + " min"
    }
    readonly property bool   isLowEndurance: hasBatteryTimeRemaining && batteryTimeRemainingSec <= 300
    readonly property bool   isCriticalEndurance: hasBatteryTimeRemaining && batteryTimeRemainingSec <= 120

    // ========================================================================
    // 4. GPS & Positioning Telemetry
    // ========================================================================
    readonly property int    gpsLock:            (_gps && _gps.lock && !isNaN(_gps.lock.rawValue)) ? Number(_gps.lock.rawValue) : 0
    readonly property string gpsLockString:      (_gps && _gps.lock && _gps.lock.enumStringValue !== "") ? _gps.lock.enumStringValue : (hasVehicle ? "No Fix" : "--")
    readonly property int    gpsSatellites:      (_gps && _gps.count && !isNaN(_gps.count.rawValue) && _gps.count.rawValue >= 0) ? Number(_gps.count.rawValue) : 0
    readonly property string gpsCountStr:        (hasVehicle && _gps && _gps.count && !isNaN(_gps.count.value) && _gps.count.value >= 0) ? (_gps.count.valueString + " Sats") : "-- Sats"

    readonly property bool   isRtkFixed:         gpsLock === 6
    readonly property bool   isRtkFloat:         gpsLock === 5
    readonly property bool   isRtkActive:        isRtkFixed || isRtkFloat
    readonly property bool   isDgps:             gpsLock === 4
    readonly property bool   is3DFix:            gpsLock >= 3

    readonly property string gpsFixType: {
        if (!hasVehicle) return "--"
        if (isRtkFixed) return "RTK FIXED"
        if (isRtkFloat) return "RTK FLOAT"
        if (isDgps) return "DGPS"
        if (gpsLock === 3) return "3D FIX"
        if (gpsLock === 2) return "2D FIX"
        return "NO FIX"
    }

    readonly property real   gpsHdop:            (_gps && _gps.hdop && !isNaN(_gps.hdop.value)) ? _gps.hdop.value : NaN
    readonly property string gpsHdopStr:         !isNaN(gpsHdop) ? gpsHdop.toFixed(2) : "--"
    readonly property real   gpsVdop:            (_gps && _gps.vdop && !isNaN(_gps.vdop.value)) ? _gps.vdop.value : NaN
    readonly property string gpsVdopStr:         !isNaN(gpsVdop) ? gpsVdop.toFixed(2) : "--"

    // Ground Station RTK Base Receiver Facts (QGroundControl.gpsRtk)
    readonly property var    _gpsRtk:            QGroundControl.gpsRtk
    readonly property bool   hasRtkBase:         _gpsRtk !== null && _gpsRtk.connected && _gpsRtk.connected.value === true
    readonly property bool   isRtkBaseSurveying: _gpsRtk !== null && _gpsRtk.active && _gpsRtk.active.value === true
    readonly property bool   isRtkBaseValid:     _gpsRtk !== null && _gpsRtk.valid && _gpsRtk.valid.value === true
    readonly property real   rtkBaseAccuracy:    (_gpsRtk && _gpsRtk.currentAccuracy && !isNaN(_gpsRtk.currentAccuracy.value)) ? _gpsRtk.currentAccuracy.value : NaN
    readonly property string rtkBaseAccuracyStr: !isNaN(rtkBaseAccuracy) ? (rtkBaseAccuracy.toFixed(2) + " m") : "--"
    readonly property int    rtkBaseDuration:    (_gpsRtk && _gpsRtk.currentDuration && !isNaN(_gpsRtk.currentDuration.value)) ? Math.round(_gpsRtk.currentDuration.value) : 0

    readonly property var    coordinate:         (hasVehicle && activeVehicle.coordinate && activeVehicle.coordinate.isValid) ? activeVehicle.coordinate : null
    readonly property bool   hasValidCoord:      coordinate !== null && !isNaN(coordinate.latitude) && !isNaN(coordinate.longitude) && (coordinate.latitude !== 0 || coordinate.longitude !== 0)
    readonly property real   latitude:           hasValidCoord ? coordinate.latitude : NaN
    readonly property real   longitude:          hasValidCoord ? coordinate.longitude : NaN
    readonly property string coordString:        hasValidCoord ? (coordinate.latitude.toFixed(6) + "°, " + coordinate.longitude.toFixed(6) + "°") : (hasVehicle ? qsTr("Awaiting GPS Fix...") : qsTr("Standby for Telemetry"))

    readonly property var    homeCoordinate:     (hasVehicle && activeVehicle.homePosition && activeVehicle.homePosition.isValid) ? activeVehicle.homePosition : null
    readonly property bool   hasHomeCoord:       homeCoordinate !== null && !isNaN(homeCoordinate.latitude) && !isNaN(homeCoordinate.longitude) && (homeCoordinate.latitude !== 0 || homeCoordinate.longitude !== 0)

    // ========================================================================
    // 5. Altitudes & Speeds
    // ========================================================================
    readonly property real   altitudeRelative:      (hasVehicle && activeVehicle.altitudeRelative && !isNaN(activeVehicle.altitudeRelative.rawValue)) ? activeVehicle.altitudeRelative.rawValue : 0
    readonly property string altitudeRelativeStr:   (hasVehicle && activeVehicle.altitudeRelative && !isNaN(activeVehicle.altitudeRelative.rawValue)) ? (activeVehicle.altitudeRelative.valueString + " " + activeVehicle.altitudeRelative.units) : "--"
    readonly property string altitudeRelativeUnits: (hasVehicle && activeVehicle.altitudeRelative && activeVehicle.altitudeRelative.units !== "") ? activeVehicle.altitudeRelative.units : "m"

    readonly property real   altitudeAMSL:          (hasVehicle && activeVehicle.altitudeAMSL && !isNaN(activeVehicle.altitudeAMSL.rawValue)) ? activeVehicle.altitudeAMSL.rawValue : 0
    readonly property string altitudeAMSLStr:       (hasVehicle && activeVehicle.altitudeAMSL && !isNaN(activeVehicle.altitudeAMSL.rawValue)) ? (activeVehicle.altitudeAMSL.valueString + " " + activeVehicle.altitudeAMSL.units) : "--"
    readonly property string altitudeAMSLUnits:     (hasVehicle && activeVehicle.altitudeAMSL && activeVehicle.altitudeAMSL.units !== "") ? activeVehicle.altitudeAMSL.units : "m"

    readonly property real   groundSpeed:           (hasVehicle && activeVehicle.groundSpeed && !isNaN(activeVehicle.groundSpeed.rawValue)) ? activeVehicle.groundSpeed.rawValue : 0
    readonly property string groundSpeedStr:        (hasVehicle && activeVehicle.groundSpeed && !isNaN(activeVehicle.groundSpeed.rawValue)) ? (activeVehicle.groundSpeed.valueString + " " + activeVehicle.groundSpeed.units) : "--"
    readonly property string groundSpeedUnits:      (hasVehicle && activeVehicle.groundSpeed && activeVehicle.groundSpeed.units !== "") ? activeVehicle.groundSpeed.units : "m/s"

    readonly property real   airSpeed:              (hasVehicle && activeVehicle.airSpeed && !isNaN(activeVehicle.airSpeed.rawValue)) ? activeVehicle.airSpeed.rawValue : 0
    readonly property bool   hasAirSpeed:           hasVehicle && !isNaN(airSpeed) && airSpeed > 0.5
    readonly property string airSpeedStr:           (hasVehicle && activeVehicle.airSpeed && !isNaN(activeVehicle.airSpeed.rawValue)) ? (activeVehicle.airSpeed.valueString + " " + activeVehicle.airSpeed.units) : "--"
    readonly property string airSpeedUnits:         (hasVehicle && activeVehicle.airSpeed && activeVehicle.airSpeed.units !== "") ? activeVehicle.airSpeed.units : "m/s"

    readonly property real   climbRate:             (hasVehicle && activeVehicle.climbRate && !isNaN(activeVehicle.climbRate.rawValue)) ? activeVehicle.climbRate.rawValue : 0
    readonly property string climbRateStr:          (hasVehicle && activeVehicle.climbRate && !isNaN(activeVehicle.climbRate.rawValue)) ? (((climbRate >= 0) ? "+" : "") + activeVehicle.climbRate.valueString + " " + activeVehicle.climbRate.units) : "--"
    readonly property string climbRateUnits:        (hasVehicle && activeVehicle.climbRate && activeVehicle.climbRate.units !== "") ? activeVehicle.climbRate.units : "m/s"

    readonly property real   heading:               (hasVehicle && activeVehicle.heading && !isNaN(activeVehicle.heading.rawValue)) ? activeVehicle.heading.rawValue : 0
    readonly property string headingStr:            hasVehicle ? (heading.toFixed(0) + "°") : "--°"

    // ========================================================================
    // 6. Attitude (Roll / Pitch)
    // ========================================================================
    readonly property real   roll:                  (hasVehicle && activeVehicle.roll && !isNaN(activeVehicle.roll.rawValue)) ? activeVehicle.roll.rawValue : 0
    readonly property real   pitch:                 (hasVehicle && activeVehicle.pitch && !isNaN(activeVehicle.pitch.rawValue)) ? activeVehicle.pitch.rawValue : 0

    // ========================================================================
    // 7. Home Navigation Facts
    // ========================================================================
    readonly property string distToHomeStr:         (hasVehicle && activeVehicle.distanceToHome && !isNaN(activeVehicle.distanceToHome.rawValue)) ? (activeVehicle.distanceToHome.valueString + " " + activeVehicle.distanceToHome.units) : "--"
    readonly property string headingToHomeStr:      (hasVehicle && activeVehicle.headingToHome && !isNaN(activeVehicle.headingToHome.rawValue)) ? (activeVehicle.headingToHome.valueString + "°") : "--"

    // ========================================================================
    // 8. Communications & MAVLink Loss
    // ========================================================================
    readonly property real   mavlinkLossPercent:    (hasVehicle && !isNaN(activeVehicle.mavlinkLossPercent)) ? activeVehicle.mavlinkLossPercent : 0
    readonly property int    linkQualityPercent:    hasVehicle ? Math.max(0, Math.min(100, Math.round(100 - mavlinkLossPercent))) : 0

    // Network jitter buffer (Ethernet UDP resilience against transient drops during video streaming)
    property bool _commGraceActive: false
    Timer {
        id: commGraceTimer
        interval: 3000 // 3.0s grace window before declaring hard communication loss
        repeat: false
        onTriggered: {
            root._commGraceActive = false
        }
    }

    onHasVehicleChanged: {
        _commGraceActive = false
        commGraceTimer.stop()
    }

    readonly property bool _rawCommLost: hasVehicle && _linkMgr ? _linkMgr.communicationLost : false
    on_RawCommLostChanged: {
        if (_rawCommLost) {
            _commGraceActive = true
            commGraceTimer.restart()
        } else {
            _commGraceActive = false
            commGraceTimer.stop()
        }
    }

    readonly property bool   communicationLost:     hasVehicle ? (_rawCommLost && !_commGraceActive) : false
    readonly property bool   communicationValid:    hasVehicle ? (!_rawCommLost || _commGraceActive) : false

    // Radio & RSSI Telemetry (SiK / RFD / Microhard / RC)
    readonly property var    _radioStatus:          (hasVehicle && activeVehicle.radioStatus) ? activeVehicle.radioStatus : null
    readonly property bool   hasRadioStatus:        _radioStatus !== null && _radioStatus.lrssi && _radioStatus.lrssi.rawValue !== 0
    readonly property real   radioLrssi:            hasRadioStatus ? Number(_radioStatus.lrssi.rawValue) : NaN
    readonly property real   radioRrssi:            (hasRadioStatus && _radioStatus.rrssi) ? Number(_radioStatus.rrssi.rawValue) : NaN
    readonly property string radioLrssiStr:         !isNaN(radioLrssi) ? (radioLrssi + " dBm") : "-- dBm"
    readonly property string radioRrssiStr:         !isNaN(radioRrssi) ? (radioRrssi + " dBm") : "-- dBm"

    readonly property bool   hasRcRSSI:             hasVehicle && activeVehicle.rcRSSI && !isNaN(activeVehicle.rcRSSI.rawValue) && activeVehicle.rcRSSI.rawValue > 0 && activeVehicle.rcRSSI.rawValue <= 100
    readonly property real   rcRSSI:                hasRcRSSI ? Number(activeVehicle.rcRSSI.rawValue) : NaN
    readonly property string rcRSSIStr:             hasRcRSSI ? (Math.round(rcRSSI) + "%") : "--%"

    readonly property string rssiDisplayStr: {
        if (hasRadioStatus) return radioLrssiStr
        if (hasRcRSSI) return rcRSSIStr
        if (hasVehicle) return linkQualityPercent + "%"
        return "--"
    }

    readonly property bool   isSignalWeak:          (hasRadioStatus && radioLrssi < -95) || (hasRcRSSI && rcRSSI < 25) || (hasVehicle && linkQualityPercent < 60)
    readonly property bool   isSignalCritical:      communicationLost || (hasRadioStatus && radioLrssi < -105) || (hasRcRSSI && rcRSSI < 15) || (hasVehicle && linkQualityPercent < 30)

    // ========================================================================
    // 9. Gimbal Telemetry (Pitch / Yaw / Roll) & Movement Controls
    // ========================================================================
    readonly property bool   hasGimbal:             _activeGimbal !== null || (typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface !== null)
    readonly property real   gimbalPitch:           (_activeGimbal && _activeGimbal.absolutePitch && !isNaN(_activeGimbal.absolutePitch.rawValue)) ? _activeGimbal.absolutePitch.rawValue : ((typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface) ? CompanyPayloadInterface.pitch : NaN)
    readonly property string gimbalPitchStr:        !isNaN(gimbalPitch) ? (gimbalPitch.toFixed(1) + "°") : "--"
    readonly property real   gimbalYaw:             (_activeGimbal && _activeGimbal.absoluteYaw && !isNaN(_activeGimbal.absoluteYaw.rawValue)) ? _activeGimbal.absoluteYaw.rawValue : ((typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface) ? CompanyPayloadInterface.yaw : NaN)
    readonly property string gimbalYawStr:          !isNaN(gimbalYaw) ? (gimbalYaw.toFixed(1) + "°") : "--"
    readonly property real   gimbalRoll:            (_activeGimbal && _activeGimbal.absoluteRoll && !isNaN(_activeGimbal.absoluteRoll.rawValue)) ? _activeGimbal.absoluteRoll.rawValue : ((typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface) ? CompanyPayloadInterface.roll : NaN)
    readonly property string gimbalRollStr:         !isNaN(gimbalRoll) ? (gimbalRoll.toFixed(1) + "°") : "--"

    // Detailed Gimbal Movement & State
    readonly property real   gimbalBodyYaw:         (_activeGimbal && _activeGimbal.bodyYaw && !isNaN(_activeGimbal.bodyYaw.rawValue)) ? _activeGimbal.bodyYaw.rawValue : 0.0
    readonly property string gimbalBodyYawStr:      gimbalBodyYaw.toFixed(1) + "°"
    readonly property real   gimbalPitchRate:       _activeGimbal ? _activeGimbal.pitchRate : 0.0
    readonly property real   gimbalYawRate:         _activeGimbal ? _activeGimbal.yawRate : 0.0
    readonly property bool   gimbalYawLock:         _activeGimbal ? _activeGimbal.yawLock : false
    readonly property bool   gimbalRetracted:       _activeGimbal ? _activeGimbal.retracted : false
    readonly property bool   gimbalHaveControl:     _activeGimbal ? _activeGimbal.gimbalHaveControl : false
    readonly property string gimbalMotionState: {
        if (!_activeGimbal) return "OFFLINE"
        if (_activeGimbal.retracted) return "RETRACTED"
        if (Math.abs(_activeGimbal.pitchRate) > 0.5 || Math.abs(_activeGimbal.yawRate) > 0.5) return "SLEWING"
        if (_activeGimbal.yawLock) return "YAW LOCK"
        return "STABILIZED"
    }

    function centerGimbal() {
        if (_gimbalMgr && _gimbalMgr.centerGimbal) {
            _gimbalMgr.centerGimbal()
        }
    }

    function pointGimbalNadir() {
        if (_gimbalMgr && _gimbalMgr.sendPitchBodyYaw) {
            _gimbalMgr.sendPitchBodyYaw(-90.0, 0.0)
        }
    }

    function pointGimbalHorizon() {
        if (_gimbalMgr && _gimbalMgr.sendPitchBodyYaw) {
            _gimbalMgr.sendPitchBodyYaw(0.0, 0.0)
        }
    }

    // ========================================================================
    // 10. Camera & Sensor FOV Telemetry
    // ========================================================================
    readonly property real   rgbHfov:               (QGroundControl.videoManager.hfov > 1.0) ? QGroundControl.videoManager.hfov : (_activeCamera && _activeCamera.currentStreamInstance && _activeCamera.currentStreamInstance.hfov > 0 ? _activeCamera.currentStreamInstance.hfov : ((typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface && CompanyPayloadInterface.fov > 0.1) ? CompanyPayloadInterface.fov : NaN))
    readonly property bool   hasRgbHfov:            !isNaN(rgbHfov) && rgbHfov > 1.0
    readonly property string rgbHfovStr:            hasRgbHfov ? (rgbHfov.toFixed(1) + "°") : "N/A"

    readonly property real   thermalHfov:           (QGroundControl.videoManager.thermalHfov > 1.0) ? QGroundControl.videoManager.thermalHfov : NaN
    readonly property bool   hasThermalHfov:        !isNaN(thermalHfov) && thermalHfov > 1.0
    readonly property string thermalHfovStr:         hasThermalHfov ? (thermalHfov.toFixed(1) + "°") : "N/A"

    readonly property bool   canZoom:               (_activeCamera !== null && _activeCamera.hasZoom) || (typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface !== null) || (typeof companyPayload !== "undefined" && companyPayload !== null)
    readonly property real   zoomLevel:             (_activeCamera !== null && _activeCamera.hasZoom) ? _activeCamera.zoomLevel : ((typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface) ? CompanyPayloadInterface.zoom : ((typeof companyPayload !== "undefined" && companyPayload) ? companyPayload.zoom : NaN))
    readonly property string zoomLevelStr:          canZoom ? (!isNaN(zoomLevel) ? (zoomLevel.toFixed(1) + "x") : "--") : "--"

    readonly property bool   canCapturePhoto:       _activeCamera !== null ? _activeCamera.capturesPhotos : ((typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface) ? CompanyPayloadInterface.capturesPhotos : ((typeof companyPayload !== "undefined" && companyPayload) ? companyPayload.capturesPhotos : QGroundControl.videoManager.decoding))
    readonly property bool   canRecordVideo:        _activeCamera !== null ? _activeCamera.capturesVideo : ((typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface) ? CompanyPayloadInterface.capturesVideo : ((typeof companyPayload !== "undefined" && companyPayload) ? companyPayload.capturesVideo : QGroundControl.videoManager.decoding))

    // ========================================================================
    // 10B. Laser Rangefinder (LRF) Telemetry
    // ========================================================================
    readonly property var    _distSensors:          (hasVehicle && activeVehicle.distanceSensors) ? activeVehicle.distanceSensors : null
    readonly property real   _mavlinkLrfDist: {
        if (!_distSensors) return NaN
        if (_distSensors.rotationNone && !isNaN(_distSensors.rotationNone.rawValue) && _distSensors.rotationNone.rawValue > 0.05) {
            return _distSensors.rotationNone.rawValue
        }
        if (_distSensors.rotationPitch270 && !isNaN(_distSensors.rotationPitch270.rawValue) && _distSensors.rotationPitch270.rawValue > 0.05) {
            return _distSensors.rotationPitch270.rawValue
        }
        return NaN
    }
    readonly property bool   isMavlinkLrf:          !isNaN(_mavlinkLrfDist)
    readonly property real   lrfDistance:           isMavlinkLrf ? _mavlinkLrfDist : ((typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface && CompanyPayloadInterface.lrfValid) ? CompanyPayloadInterface.lrfDistance : NaN)
    readonly property bool   hasLrfDistance:        !isNaN(lrfDistance) && lrfDistance > 0.01
    readonly property string lrfDistanceStr:        hasLrfDistance ? (lrfDistance.toFixed(1) + " m") : "N/A"

    // ========================================================================
    // 11. Authoritative Time Reference
    // ========================================================================
    // Synchronized to drone GPS epoch via MAVLink SYSTEM_TIME & GPS_RAW_INT.
    // Seamlessly falls back to local GCS UTC when vehicle GPS time is not yet established.
    readonly property bool   hasDroneGpsTime:       (typeof CompanyCsvLogger !== "undefined" && CompanyCsvLogger !== null) ? CompanyCsvLogger.hasDroneGpsTime : false
    readonly property string timeSourceLabel:       hasDroneGpsTime ? "DRONE GPS UTC" : "LOCAL GCS UTC"
    readonly property real   currentDroneTimeMs:    (typeof CompanyCsvLogger !== "undefined" && CompanyCsvLogger !== null) ? CompanyCsvLogger.currentDroneTimeMs : Date.now()
    readonly property string droneTimestampHmsMs:   (typeof CompanyCsvLogger !== "undefined" && CompanyCsvLogger !== null) ? CompanyCsvLogger.formattedHmsMs : ""
    readonly property string droneTimestampFull:    (typeof CompanyCsvLogger !== "undefined" && CompanyCsvLogger !== null) ? CompanyCsvLogger.droneUtcTimestamp : ""

    // ========================================================================
    // 12. Voice & Audio Annunciator (Speech Synthesis)
    // ========================================================================
    property bool voiceMuted: (QGroundControl.settingsManager && QGroundControl.settingsManager.appSettings && QGroundControl.settingsManager.appSettings.audioMuted) ? QGroundControl.settingsManager.appSettings.audioMuted.rawValue : false

    function toggleVoiceMute() {
        if (QGroundControl.settingsManager && QGroundControl.settingsManager.appSettings && QGroundControl.settingsManager.appSettings.audioMuted) {
            var newVal = !QGroundControl.settingsManager.appSettings.audioMuted.rawValue
            QGroundControl.settingsManager.appSettings.audioMuted.rawValue = newVal
            voiceMuted = newVal
        } else {
            voiceMuted = !voiceMuted
        }
    }

    function say(text) {
        if (voiceMuted) return
        if (typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface && CompanyPayloadInterface.say) {
            CompanyPayloadInterface.say(text)
        }
    }

    // Startup settling timer to avoid spurious announcements during application launch
    property bool _systemInitialized: false
    Timer {
        id: startupTimer
        interval: 3500
        running: true
        repeat: false
        onTriggered: root._systemInitialized = true
    }

    // 1. Armed State Announcements
    property bool _prevArmed: false
    onArmedChanged: {
        if (_systemInitialized && hasVehicle) {
            if (armed && !_prevArmed) {
                say("Vehicle armed")
            } else if (!armed && _prevArmed) {
                say("Vehicle disarmed")
            }
        }
        _prevArmed = armed
    }

    // 2. Flight Mode Announcements
    property string _prevFlightMode: ""
    onFlightModeChanged: {
        if (_systemInitialized && hasVehicle && flightMode !== "" && flightMode !== _prevFlightMode) {
            say("Flight mode, " + flightMode)
        }
        _prevFlightMode = flightMode
    }

    // 3. Battery Percentage Threshold Announcements
    property int _lastAnnouncedBatThresh: 100
    onBatteryPercentChanged: {
        if (!_systemInitialized || !hasBattery || isNaN(batteryPercent)) return
        if (batteryPercent <= 10 && _lastAnnouncedBatThresh > 10) {
            _lastAnnouncedBatThresh = 10
            say("Emergency, battery 10 percent, land immediately")
        } else if (batteryPercent <= 15 && _lastAnnouncedBatThresh > 15) {
            _lastAnnouncedBatThresh = 15
            say("Alert, battery critical, 15 percent")
        } else if (batteryPercent <= 25 && _lastAnnouncedBatThresh > 25) {
            _lastAnnouncedBatThresh = 25
            say("Warning, battery 25 percent")
        } else if (batteryPercent > 30) {
            _lastAnnouncedBatThresh = 100
        }
    }

    // 4. Battery Endurance Time Remaining Announcements
    property int _lastAnnouncedEnduranceThresh: 9999
    onBatteryTimeRemainingSecChanged: {
        if (!_systemInitialized || !hasBatteryTimeRemaining || isNaN(batteryTimeRemainingSec)) return
        if (batteryTimeRemainingSec <= 120 && _lastAnnouncedEnduranceThresh > 120) {
            _lastAnnouncedEnduranceThresh = 120
            say("Alert, 2 minutes flight time remaining")
        } else if (batteryTimeRemainingSec <= 300 && _lastAnnouncedEnduranceThresh > 300) {
            _lastAnnouncedEnduranceThresh = 300
            say("Warning, 5 minutes flight time remaining")
        } else if (batteryTimeRemainingSec > 360) {
            _lastAnnouncedEnduranceThresh = 9999
        }
    }

    // 5. GPS 3D Fix & RTK Acquisition Announcements
    property int _prevGpsLock: 0
    onGpsLockChanged: {
        if (_systemInitialized && hasVehicle) {
            if (gpsLock === 6 && _prevGpsLock !== 6) {
                say("RTK Fixed lock acquired, sub-centimeter precision")
            } else if (gpsLock === 5 && _prevGpsLock < 5) {
                say("RTK Float precision active")
            } else if (gpsLock >= 3 && _prevGpsLock < 3) {
                say("GPS 3D Fix acquired, " + gpsSatellites + " satellites")
            }
        }
        _prevGpsLock = gpsLock
    }

    // 6. Telemetry Link Lost / Restored Announcements
    property bool _prevCommLost: false
    onCommunicationLostChanged: {
        if (_systemInitialized && hasVehicle) {
            if (communicationLost && !_prevCommLost) {
                say("Warning, telemetry link lost")
            } else if (!communicationLost && _prevCommLost) {
                say("Telemetry link restored")
            }
        }
        _prevCommLost = communicationLost
    }

    // ========================================================================
    // 12. Warning Messages & System StatusText Alerts
    // ========================================================================
    readonly property bool   messageTypeWarning:    hasVehicle && activeVehicle.messageTypeWarning
    readonly property bool   messageTypeError:      hasVehicle && activeVehicle.messageTypeError
    readonly property bool   messageTypeNormal:     hasVehicle && activeVehicle.messageTypeNormal
    readonly property string formattedMessages:     hasVehicle ? activeVehicle.formattedMessages : ""

    property string latestWarningText: ""
    property string latestWarningSeverity: "" // "ERROR", "WARNING", "INFO"
    property int warningCount: 0
    property int errorCount: 0
    property var messageHistory: []

    function resetMessages() {
        if (hasVehicle && activeVehicle.resetAllMessages) {
            activeVehicle.resetAllMessages()
        }
        warningCount = 0
        errorCount = 0
    }

    Connections {
        target: root.activeVehicle
        ignoreUnknownSignals: true
        function onNewFormattedMessage(formattedMessage) {
            var plain = formattedMessage.replace(/<[^>]*>/g, "").trim()
            if (plain.length > 0) {
                root.latestWarningText = plain
                var isErr = root.activeVehicle ? root.activeVehicle.messageTypeError : false
                var isWarn = root.activeVehicle ? root.activeVehicle.messageTypeWarning : false
                if (isErr) {
                    root.latestWarningSeverity = "ERROR"
                    root.errorCount++
                } else if (isWarn) {
                    root.latestWarningSeverity = "WARNING"
                    root.warningCount++
                } else {
                    root.latestWarningSeverity = "INFO"
                }

                var list = root.messageHistory.slice(0, 49)
                list.unshift({
                    text: plain,
                    timestamp: Qt.formatDateTime(new Date(), "hh:mm:ss"),
                    severity: root.latestWarningSeverity
                })
                root.messageHistory = list
            }
        }
    }
}
