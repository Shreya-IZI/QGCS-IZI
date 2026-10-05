pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Layouts
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap
import Company.UI

Item {
    id: root

    // ------------------------------------------------------------------------
    // Vehicle & Telemetry Bindings (Strictly Real Vehicle Data - No Simulated Values)
    // ------------------------------------------------------------------------
    readonly property var  _activeVehicle:   CompanyTelemetry.activeVehicle
    readonly property bool _hasVehicle:      CompanyTelemetry.hasVehicle
    readonly property var  _vehicleCoord:    CompanyTelemetry.coordinate
    readonly property bool _hasValidCoord:   CompanyTelemetry.hasValidCoord
    readonly property var  _homeCoord:       CompanyTelemetry.homeCoordinate
    readonly property bool _hasHomeCoord:    CompanyTelemetry.hasHomeCoord
    readonly property real _heading:         CompanyTelemetry.heading
    readonly property bool _isArmed:         CompanyTelemetry.armed
    readonly property string _flightMode:    CompanyTelemetry.flightMode

    property bool followVehicle:             true

    clip: true

    // ------------------------------------------------------------------------
    // Base Map: Native QGroundControl FlightMap
    // ------------------------------------------------------------------------
    FlightMap {
        id: flightMap
        anchors.fill: parent
        mapName: "CompanyTacticalMap"
        allowGCSLocationCenter: true
        allowVehicleLocationCenter: root.followVehicle

        // Suspend follow mode when operator manually pans the map
        onMapPanStart: {
            root.followVehicle = false
        }

        // --------------------------------------------------------------------
        // Continuous Vehicle Follow
        // --------------------------------------------------------------------
        Connections {
            target: root._activeVehicle
            function onCoordinateChanged() {
                if (root.followVehicle && root._hasValidCoord) {
                    flightMap.center = root._activeVehicle.coordinate
                }
            }
        }

        // --------------------------------------------------------------------
        // Flight Trajectory Polyline
        // --------------------------------------------------------------------
        MapPolyline {
            id: trajectoryPolyline
            line.width: 2.5
            line.color: CompanyTheme.primary
            z: QGroundControl.zOrderTrajectoryLines

            Connections {
                target: QGroundControl.multiVehicleManager
                function onActiveVehicleChanged(activeVehicle) {
                    trajectoryPolyline.path = (root._hasVehicle && root._activeVehicle.trajectoryPoints) ? root._activeVehicle.trajectoryPoints.list() : []
                }
            }

            Connections {
                target: (root._hasVehicle && root._activeVehicle.trajectoryPoints) ? root._activeVehicle.trajectoryPoints : null
                function onPointAdded(coordinate) {
                    trajectoryPolyline.addCoordinate(coordinate)
                }
                function onUpdateLastPoint(coordinate) {
                    if (trajectoryPolyline.pathLength() > 0) {
                        trajectoryPolyline.replaceCoordinate(trajectoryPolyline.pathLength() - 1, coordinate)
                    } else {
                        trajectoryPolyline.addCoordinate(coordinate)
                    }
                }
                function onPointsCleared() {
                    trajectoryPolyline.path = []
                }
            }

            Component.onCompleted: {
                if (root._hasVehicle && root._activeVehicle.trajectoryPoints) {
                    trajectoryPolyline.path = root._activeVehicle.trajectoryPoints.list()
                }
            }
        }

        // --------------------------------------------------------------------
        // Vehicle Map Items (Multi-Vehicle Supported)
        // --------------------------------------------------------------------
        MapItemView {
            model: QGroundControl.multiVehicleManager.vehicles
            delegate: VehicleMapItem {
                id: vehicleMarker
                required property var object

                vehicle: vehicleMarker.object
                coordinate: vehicleMarker.object.coordinate
                map: flightMap
                size: ScreenTools.defaultFontPixelHeight * 2.8
                z: QGroundControl.zOrderVehicles
            }
        }

        // --------------------------------------------------------------------
        // Home Position Marker
        // --------------------------------------------------------------------
        MapQuickItem {
            id: homeMarker
            coordinate: root._hasHomeCoord ? root._homeCoord : QtPositioning.coordinate()
            visible: root._hasHomeCoord
            z: QGroundControl.zOrderMapItems
            anchorPoint.x: homeIconContainer.width / 2
            anchorPoint.y: homeIconContainer.height / 2

            sourceItem: Item {
                id: homeIconContainer
                width: 32
                height: 32

                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    radius: 13
                    color: Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.25)
                    border.color: CompanyTheme.warning
                    border.width: 1.5
                }

                Image {
                    anchors.centerIn: parent
                    source: "/qmlimages/MapHome.svg"
                    width: 16
                    height: 16
                    sourceSize.width: 16
                    sourceSize.height: 16
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    // Dynamic Map Scale (Metric & Imperial)
    // ------------------------------------------------------------------------
    MapScale {
        id: mapScale
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: CompanyTheme.spacingMd
        anchors.bottomMargin: 52
        mapControl: flightMap
        z: 10
    }

    // ------------------------------------------------------------------------
    // Top-Left Floating Tactical Telemetry HUD Card (Compact Modern Dark)
    // ------------------------------------------------------------------------
    Rectangle {
        id: telemetryCard
        anchors.top: parent.top
        anchors.topMargin: 48
        anchors.left: parent.left
        anchors.leftMargin: CompanyTheme.spacingMd
        z: 10
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgOverlayDark
        border.color: CompanyTheme.borderCard
        border.width: 1
        implicitWidth: telemetryLayout.implicitWidth + CompanyTheme.spacingMd * 2
        implicitHeight: telemetryLayout.implicitHeight + CompanyTheme.spacingSm * 2

        ColumnLayout {
            id: telemetryLayout
            anchors.centerIn: parent
            spacing: 4

            // Row 1: UAS #1 | DISARMED | CUSTOM: 0x0
            RowLayout {
                spacing: 6

                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: root._hasVehicle ? (root._isArmed ? CompanyTheme.danger : CompanyTheme.success) : CompanyTheme.warning
                }

                Text {
                    text: root._hasVehicle ? qsTr("UAS #%1").arg(root._activeVehicle.id) : qsTr("UAS #1")
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.bold: true
                }

                Text {
                    text: "•"
                    color: CompanyTheme.textMuted
                    font.pointSize: CompanyTheme.fontSmall
                }

                Text {
                    text: root._isArmed ? qsTr("ARMED") : qsTr("DISARMED")
                    color: root._isArmed ? CompanyTheme.danger : CompanyTheme.warning
                    font.pointSize: CompanyTheme.fontTiny
                    font.bold: true
                }

                Text {
                    text: "•"
                    color: CompanyTheme.textMuted
                    font.pointSize: CompanyTheme.fontSmall
                }

                Text {
                    text: {
                        if (!root._hasVehicle) return "CUSTOM: 0x0"
                        return root._flightMode !== "" ? root._flightMode.toUpperCase() : "CUSTOM: 0x0"
                    }
                    color: CompanyTheme.primary
                    font.pointSize: CompanyTheme.fontTiny
                    font.bold: true
                }
            }

            // Row 2: ALT 0.0m | GS 0.0m/s | HDG 0°
            RowLayout {
                spacing: 8

                Text {
                    text: "ALT " + (root._hasVehicle ? CompanyTelemetry.altitudeRelativeStr : "0.0m")
                    color: CompanyTheme.textSecondary
                    font.pointSize: CompanyTheme.fontTiny
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }

                Text {
                    text: "•"
                    color: CompanyTheme.textMuted
                    font.pointSize: CompanyTheme.fontTiny
                }

                Text {
                    text: "GS " + (root._hasVehicle ? CompanyTelemetry.groundSpeedStr : "0.0m/s")
                    color: CompanyTheme.textSecondary
                    font.pointSize: CompanyTheme.fontTiny
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }

                Text {
                    text: "•"
                    color: CompanyTheme.textMuted
                    font.pointSize: CompanyTheme.fontTiny
                }

                Text {
                    text: "HDG " + (root._hasVehicle ? CompanyTelemetry.headingStr : "0°")
                    color: CompanyTheme.textSecondary
                    font.pointSize: CompanyTheme.fontTiny
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    // Top-Left Floating Clean Connection / GPS Status Notification
    // ------------------------------------------------------------------------
    Rectangle {
        id: connectionStatusNotification
        anchors.top: telemetryCard.bottom
        anchors.left: parent.left
        anchors.leftMargin: CompanyTheme.spacingMd
        anchors.topMargin: 6
        z: 10
        visible: !root._hasVehicle || !root._hasValidCoord
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgOverlayDark
        border.color: CompanyTheme.borderCard
        border.width: 1
        implicitWidth: notifLayout.implicitWidth + CompanyTheme.spacingMd * 2
        implicitHeight: notifLayout.implicitHeight + 10

        RowLayout {
            id: notifLayout
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 6
                Layout.preferredHeight: 6
                radius: 3
                color: root._hasVehicle ? CompanyTheme.warning : CompanyTheme.secondaryBlue
            }

            ColumnLayout {
                spacing: 1
                Text {
                    text: root._hasVehicle ? qsTr("GPS: %1 Sats (No Fix)").arg(CompanyTelemetry.gpsCountStr) : qsTr("No Vehicle Connected")
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.bold: true
                }
                Text {
                    text: root._hasVehicle ? qsTr("Acquiring 3D satellite navigation lock") : qsTr("Connect telemetry link or USB to start")
                    color: CompanyTheme.textMuted
                    font.pointSize: 8
                }
            }
        }
    }


    // ------------------------------------------------------------------------
    // Top-Right Map Layer Mode Selector (Street / Satellite / Hybrid)
    // ------------------------------------------------------------------------
    Rectangle {
        id: mapTypePill
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: CompanyTheme.spacingMd
        z: 10
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgOverlayDark
        border.color: CompanyTheme.borderCard
        border.width: 1
        implicitHeight: 28
        implicitWidth: mapTypeLayout.implicitWidth + 8

        RowLayout {
            id: mapTypeLayout
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: [
                    { label: "Street",    typeName: "Street" },
                    { label: "Satellite", typeName: "Satellite" },
                    { label: "Hybrid",    typeName: "Hybrid" }
                ]

                delegate: Rectangle {
                    id: typeBtn
                    required property var modelData
                    required property int index

                    Layout.preferredWidth: 54
                    Layout.preferredHeight: 22
                    radius: CompanyTheme.radiusSm
                    color: {
                        var currentType = QGroundControl.settingsManager.flightMapSettings.mapType.rawValue
                        if (currentType.indexOf(typeBtn.modelData.typeName) >= 0) {
                            return CompanyTheme.primaryDim
                        }
                        return typeBtnMouseArea.containsMouse ? CompanyTheme.bgCardHover : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: typeBtn.modelData.label
                        color: {
                            var currentType = QGroundControl.settingsManager.flightMapSettings.mapType.rawValue
                            if (currentType.indexOf(typeBtn.modelData.typeName) >= 0) {
                                return CompanyTheme.primary
                            }
                            return CompanyTheme.textSecondary
                        }
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                    }

                    MouseArea {
                        id: typeBtnMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var mgr = QGroundControl.mapEngineManager
                            var providerFact = QGroundControl.settingsManager.flightMapSettings.mapProvider
                            var typeFact = QGroundControl.settingsManager.flightMapSettings.mapType
                            if (providerFact.rawValue !== "Google") {
                                providerFact.rawValue = "Google"
                            }
                            var types = mgr.mapTypeList("Google")
                            for (var i = 0; i < types.length; i++) {
                                if (types[i].indexOf(typeBtn.modelData.typeName) >= 0) {
                                    typeFact.rawValue = types[i]
                                    return
                                }
                            }
                            if (types.length > 0) {
                                typeFact.rawValue = types[0]
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    // Bottom-Right Tactical Navigation Tool Rail
    // ------------------------------------------------------------------------
    Rectangle {
        id: toolRail
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: CompanyTheme.spacingMd
        anchors.bottomMargin: 52
        z: 10
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgOverlayDark
        border.color: CompanyTheme.borderCard
        border.width: 1
        width: 38
        implicitHeight: toolRailColumn.implicitHeight + 12

        ColumnLayout {
            id: toolRailColumn
            anchors.centerIn: parent
            spacing: 6

            // Button 1: Zoom In (+)
            Rectangle {
                id: zoomInBtn
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: CompanyTheme.radiusSm
                color: zoomInMouseArea.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCardSecondary
                border.color: CompanyTheme.borderCard
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: CompanyTheme.textPrimary
                    font.pointSize: 15
                    font.bold: true
                }

                MouseArea {
                    id: zoomInMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        flightMap.zoomLevel = Math.min(flightMap.maximumZoomLevel, flightMap.zoomLevel + 1)
                    }
                }
            }

            // Button 2: Zoom Out (-)
            Rectangle {
                id: zoomOutBtn
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: CompanyTheme.radiusSm
                color: zoomOutMouseArea.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCardSecondary
                border.color: CompanyTheme.borderCard
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "−"
                    color: CompanyTheme.textPrimary
                    font.pointSize: 15
                    font.bold: true
                }

                MouseArea {
                    id: zoomOutMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        flightMap.zoomLevel = Math.max(flightMap.minimumZoomLevel, flightMap.zoomLevel - 1)
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 1
                Layout.alignment: Qt.AlignHCenter
                color: CompanyTheme.borderCard
            }

            // Button 3: Center on Vehicle
            Rectangle {
                id: centerVehicleBtn
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: CompanyTheme.radiusSm
                color: centerVehicleMouseArea.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCardSecondary
                border.color: root._hasValidCoord ? CompanyTheme.borderCard : CompanyTheme.borderSubtle
                border.width: 1
                opacity: root._hasValidCoord ? 1.0 : 0.4

                IconVector {
                    anchors.centerIn: parent
                    name: "flight"
                    size: 14
                    color: root._hasValidCoord ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                }

                MouseArea {
                    id: centerVehicleMouseArea
                    anchors.fill: parent
                    enabled: root._hasValidCoord
                    hoverEnabled: true
                    cursorShape: root._hasValidCoord ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root._hasValidCoord) {
                            flightMap.center = root._vehicleCoord
                            root.followVehicle = true
                        }
                    }
                }
            }

            // Button 4: Center on Home
            Rectangle {
                id: centerHomeBtn
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: CompanyTheme.radiusSm
                color: centerHomeMouseArea.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCardSecondary
                border.color: root._hasHomeCoord ? CompanyTheme.borderCard : CompanyTheme.borderSubtle
                border.width: 1
                opacity: root._hasHomeCoord ? 1.0 : 0.4

                IconVector {
                    anchors.centerIn: parent
                    name: "rtl"
                    size: 14
                    color: root._hasHomeCoord ? CompanyTheme.warning : CompanyTheme.textMuted
                }

                MouseArea {
                    id: centerHomeMouseArea
                    anchors.fill: parent
                    enabled: root._hasHomeCoord
                    hoverEnabled: true
                    cursorShape: root._hasHomeCoord ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root._hasHomeCoord) {
                            flightMap.center = root._homeCoord
                            root.followVehicle = false
                        }
                    }
                }
            }

            // Button 5: Center on GCS / Operator Location
            Rectangle {
                id: centerGcsBtn
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: CompanyTheme.radiusSm
                readonly property bool _hasGcs: flightMap.gcsPosition && flightMap.gcsPosition.isValid
                color: centerGcsMouseArea.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCardSecondary
                border.color: _hasGcs ? CompanyTheme.borderCard : CompanyTheme.borderSubtle
                border.width: 1
                opacity: _hasGcs ? 1.0 : 0.4

                IconVector {
                    anchors.centerIn: parent
                    name: "radio"
                    size: 14
                    color: centerGcsBtn._hasGcs ? CompanyTheme.primary : CompanyTheme.textMuted
                }

                MouseArea {
                    id: centerGcsMouseArea
                    anchors.fill: parent
                    enabled: centerGcsBtn._hasGcs
                    hoverEnabled: true
                    cursorShape: centerGcsBtn._hasGcs ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (centerGcsBtn._hasGcs) {
                            flightMap.center = flightMap.gcsPosition
                            flightMap.zoomLevel = QGroundControl.flightMapInitialZoom
                            root.followVehicle = false
                        }
                    }
                }
            }

            // Button 6: Toggle Follow Vehicle
            Rectangle {
                id: followToggleBtn
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: CompanyTheme.radiusSm
                color: root.followVehicle ? CompanyTheme.primaryDim : (followMouseArea.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCardSecondary)
                border.color: root.followVehicle ? CompanyTheme.primary : CompanyTheme.borderCard
                border.width: 1
                opacity: root._hasValidCoord ? 1.0 : 0.4

                IconVector {
                    anchors.centerIn: parent
                    name: "missions"
                    size: 13
                    color: root.followVehicle ? CompanyTheme.primary : (root._hasValidCoord ? CompanyTheme.textSecondary : CompanyTheme.textMuted)
                }

                MouseArea {
                    id: followMouseArea
                    anchors.fill: parent
                    enabled: root._hasValidCoord
                    hoverEnabled: true
                    cursorShape: root._hasValidCoord ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        root.followVehicle = !root.followVehicle
                        if (root.followVehicle && root._hasValidCoord) {
                            flightMap.center = root._vehicleCoord
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    // Initialization: Center to Vehicle / GCS / Last Position
    // ------------------------------------------------------------------------
    Component.onCompleted: {
        var providerFact = QGroundControl.settingsManager.flightMapSettings.mapProvider
        var typeFact = QGroundControl.settingsManager.flightMapSettings.mapType
        if (providerFact && (!providerFact.rawValue || providerFact.rawValue === "Bing")) {
            providerFact.rawValue = "Google"
            if (typeFact) {
                typeFact.rawValue = "Hybrid"
            }
        }
        if (root._hasValidCoord) {
            flightMap.center = root._vehicleCoord
            flightMap.zoomLevel = QGroundControl.flightMapInitialZoom
        } else if (flightMap.gcsPosition && flightMap.gcsPosition.isValid) {
            flightMap.center = flightMap.gcsPosition
            flightMap.zoomLevel = QGroundControl.flightMapInitialZoom
        } else {
            flightMap.center = QGroundControl.flightMapPosition
            flightMap.zoomLevel = 10.0
        }
    }
}
