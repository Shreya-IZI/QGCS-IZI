pragma Singleton
pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QGroundControl
import Company.UI

QtObject {
    id: root

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

    // ========================================================================
    // 4. GPS & Positioning Telemetry
    // ========================================================================
    readonly property int    gpsLock:            (_gps && _gps.lock && !isNaN(_gps.lock.rawValue)) ? Number(_gps.lock.rawValue) : 0
    readonly property string gpsLockString:      (_gps && _gps.lock && _gps.lock.enumStringValue !== "") ? _gps.lock.enumStringValue : (hasVehicle ? "No Fix" : "--")
    readonly property int    gpsSatellites:      (_gps && _gps.count && !isNaN(_gps.count.rawValue) && _gps.count.rawValue >= 0) ? Number(_gps.count.rawValue) : 0
    readonly property string gpsCountStr:        (hasVehicle && _gps && _gps.count && !isNaN(_gps.count.value) && _gps.count.value >= 0) ? (_gps.count.valueString + " Sats") : "-- Sats"

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
    readonly property bool   communicationLost:     hasVehicle && _linkMgr ? _linkMgr.communicationLost : false
    readonly property bool   communicationValid:    hasVehicle && _linkMgr ? !_linkMgr.communicationLost : false

    // ========================================================================
    // ========================================================================
    // 9. Gimbal Telemetry (Pitch / Yaw / Roll)
    // ========================================================================
    readonly property bool   hasGimbal:             _activeGimbal !== null || (typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface !== null)
    readonly property real   gimbalPitch:           (_activeGimbal && _activeGimbal.absolutePitch && !isNaN(_activeGimbal.absolutePitch.rawValue)) ? _activeGimbal.absolutePitch.rawValue : ((typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface) ? CompanyPayloadInterface.pitch : NaN)
    readonly property string gimbalPitchStr:        !isNaN(gimbalPitch) ? (gimbalPitch.toFixed(1) + "°") : "--"
    readonly property real   gimbalYaw:             (_activeGimbal && _activeGimbal.absoluteYaw && !isNaN(_activeGimbal.absoluteYaw.rawValue)) ? _activeGimbal.absoluteYaw.rawValue : ((typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface) ? CompanyPayloadInterface.yaw : NaN)
    readonly property string gimbalYawStr:          !isNaN(gimbalYaw) ? (gimbalYaw.toFixed(1) + "°") : "--"
    readonly property real   gimbalRoll:            (_activeGimbal && _activeGimbal.absoluteRoll && !isNaN(_activeGimbal.absoluteRoll.rawValue)) ? _activeGimbal.absoluteRoll.rawValue : ((typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface) ? CompanyPayloadInterface.roll : NaN)
    readonly property string gimbalRollStr:         !isNaN(gimbalRoll) ? (gimbalRoll.toFixed(1) + "°") : "--"

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
    readonly property real   lrfDistance:           (typeof CompanyPayloadInterface !== "undefined" && CompanyPayloadInterface && CompanyPayloadInterface.lrfValid) ? CompanyPayloadInterface.lrfDistance : ((typeof companyPayload !== "undefined" && companyPayload && companyPayload.lrfValid) ? companyPayload.lrfDistance : NaN)
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
}
