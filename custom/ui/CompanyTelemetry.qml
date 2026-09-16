pragma Singleton
pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QGroundControl

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

    // ========================================================================
    // 2. Core Vehicle State
    // ========================================================================
    readonly property int    vehicleId:  hasVehicle ? activeVehicle.id : 0
    readonly property bool   armed:      hasVehicle && activeVehicle.armed
    readonly property bool   flying:     hasVehicle && activeVehicle.flying
    readonly property string flightMode: hasVehicle ? activeVehicle.flightMode : ""

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
}
