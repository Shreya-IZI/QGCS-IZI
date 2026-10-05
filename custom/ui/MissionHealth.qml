import QtQuick
import QGroundControl
import Company.UI

Item {
    id: root

    // ============================================================
    // IZI MISSION HEALTH VALIDATION LAYER
    // ============================================================

    property var activeVehicle: CompanyTelemetry.activeVehicle
    property bool hasVehicle: CompanyTelemetry.hasVehicle

    property var missionController: null
    property var visualItems: null

    readonly property int itemCount: visualItems ? visualItems.count : 0

    // ------------------------------------------------------------
    // Individual checks
    // ------------------------------------------------------------

    // 1. Telemetry Link Check
    readonly property bool vehicleConnected:
        hasVehicle

    // 2. GPS Navigation Fix Check (3D Fix or better required for autonomous navigation)
    readonly property bool gpsReady:
        hasVehicle && CompanyTelemetry.gpsLock >= 3

    // 3. Home Position Check (Vehicle home or explicit mission planned home)
    readonly property bool homeReady: {
        if (hasVehicle && CompanyTelemetry.hasHomeCoord) {
            return true
        }
        if (missionController && missionController.plannedHomePosition && missionController.plannedHomePosition.isValid) {
            return true
        }
        return false
    }

    // 4. Battery Level Check (>= 20% safe pre-flight threshold)
    readonly property bool batteryReady:
        hasVehicle &&
        CompanyTelemetry.hasBattery &&
        CompanyTelemetry.batteryPercent >= 20

    // 5. Mission Route Exists Check (QGC visualItems[0] is always MissionSettingsItem)
    readonly property bool missionReady:
        missionController ? missionController.containsItems : (itemCount > 1)

    // 6. Coordinates & Item Integrity Validation
    readonly property bool coordinatesReady: {
        if (!visualItems || !missionReady) {
            return false
        }

        for (var i = 0; i < itemCount; i++) {
            var item = visualItems.get(i)
            if (!item) {
                return false
            }

            // Skip index 0 (MissionSettingsItem / Home position special case)
            if (item.homePosition) {
                continue
            }

            // Spatial items (Waypoints, Takeoff, Land, Loiter) MUST have valid coordinates
            if (item.specifiesCoordinate) {
                if (!item.coordinate || !item.coordinate.isValid) {
                    return false
                }
            }

            // Complex items (e.g. Survey, Corridor Scan) must have complete patterns
            if (item.isIncomplete !== undefined && item.isIncomplete) {
                return false
            }

            // Terrain and Data readiness check (0 = VisualMissionItem.ReadyForSave)
            if (item.readyForSaveState !== undefined && item.readyForSaveState !== 0) {
                return false
            }

            // Reject if terrain collision is flagged
            if (item.terrainCollision !== undefined && item.terrainCollision) {
                return false
            }
        }

        return true
    }

    // ------------------------------------------------------------
    // Overall readiness
    // ------------------------------------------------------------

    readonly property bool ready:
        vehicleConnected &&
        gpsReady &&
        homeReady &&
        batteryReady &&
        missionReady &&
        coordinatesReady

    readonly property string status:
        ready ? qsTr("MISSION READY") :
        !vehicleConnected ? qsTr("VEHICLE NOT CONNECTED") :
        !batteryReady ? qsTr("BATTERY TOO LOW") :
        !gpsReady ? qsTr("GPS NOT READY") :
        !homeReady ? qsTr("HOME POSITION NOT SET") :
        !missionReady ? qsTr("NO MISSION") :
        !coordinatesReady ? qsTr("INVALID MISSION") :
        qsTr("CHECK REQUIRED")

    readonly property string statusDetail:
        ready
            ? qsTr("All pre-flight mission readiness checks passed.")
            : !vehicleConnected
                ? qsTr("Connect vehicle via telemetry link before mission upload.")
                : !batteryReady
                    ? qsTr("Vehicle battery is below the safe 20% pre-flight threshold.")
                    : !gpsReady
                        ? qsTr("Waiting for 3D GPS satellite navigation lock (3D Fix or better).")
                        : !homeReady
                            ? qsTr("Vehicle home location has not been acquired or set.")
                            : !missionReady
                                ? qsTr("Add waypoints to the mission plan before flight.")
                                : !coordinatesReady
                                    ? qsTr("Mission contains incomplete patterns or invalid waypoint coordinates.")
                                    : qsTr("One or more pre-flight checks require operator attention.")

    // ------------------------------------------------------------
    // Check count and metrics
    // ------------------------------------------------------------

    readonly property int passedChecks: {
        var count = 0
        if (vehicleConnected) count++
        if (gpsReady) count++
        if (homeReady) count++
        if (batteryReady) count++
        if (missionReady) count++
        if (coordinatesReady) count++
        return count
    }

    readonly property int totalChecks: 6

    readonly property real healthPercent:
        (passedChecks / totalChecks) * 100

    // Structured check list for UI rendering
    readonly property var checkItems: [
        {
            name: qsTr("Vehicle Link"),
            passed: vehicleConnected,
            detail: vehicleConnected ? qsTr("Connected") : qsTr("No Link")
        },
        {
            name: qsTr("Battery Level"),
            passed: batteryReady,
            detail: CompanyTelemetry.hasBattery ? CompanyTelemetry.batteryPercentStr : qsTr("No Data")
        },
        {
            name: qsTr("GPS 3D Fix"),
            passed: gpsReady,
            detail: CompanyTelemetry.gpsLockString
        },
        {
            name: qsTr("Home Position"),
            passed: homeReady,
            detail: homeReady ? qsTr("Acquired") : qsTr("Not Set")
        },
        {
            name: qsTr("Mission Route"),
            passed: missionReady,
            detail: missionReady ? qsTr("%1 items").arg(Math.max(0, itemCount - 1)) : qsTr("Empty")
        },
        {
            name: qsTr("Waypoint Integrity"),
            passed: coordinatesReady,
            detail: coordinatesReady ? qsTr("Valid") : qsTr("Incomplete")
        }
    ]

    visible: false
}
