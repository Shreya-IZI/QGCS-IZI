pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap
import QGroundControl.PlanView
import Company.UI
import "controls"

Item {
    id: root

    // ------------------------------------------------------------------------
    // Vehicle & Telemetry Bindings
    // ------------------------------------------------------------------------
    readonly property var  _activeVehicle:   CompanyTelemetry.activeVehicle
    readonly property bool _hasVehicle:      CompanyTelemetry.hasVehicle
    readonly property var  _vehicleCoord:    CompanyTelemetry.coordinate
    readonly property bool _hasValidCoord:   CompanyTelemetry.hasValidCoord
    readonly property bool _isArmed:         CompanyTelemetry.armed
    readonly property bool _isFlying:        CompanyTelemetry.flying
    readonly property string _flightMode:    CompanyTelemetry.flightMode
    readonly property bool _isMissionExecuting: _hasVehicle && _isArmed && _isFlying && (_flightMode !== "") && (_flightMode === _activeVehicle.missionFlightMode)
    readonly property bool _inMissionMode:   _isMissionExecuting
    readonly property bool _isMissionPaused: _hasVehicle && _isArmed && _isFlying && (_flightMode !== "") && (_flightMode === _activeVehicle.pauseFlightMode) && _wasExecutingMission && !_missionCompleted
    readonly property bool _isMissionActive: (_isMissionExecuting || _isMissionPaused) && !_missionCompleted
    readonly property int  _currentMissionIndex: (_hasVehicle && _activeVehicle.missionItemIndex) ? Number(_activeVehicle.missionItemIndex.rawValue) : 0
    readonly property int  _flightItemCount: Math.max(0, root._itemCount - 1)
    readonly property bool _hasMissionItems: root._flightItemCount > 0 && ((root._missionController && root._missionController.containsItems) || planMasterController.containsItems || root._itemCount > 1)

    // Interactive Mode Controls
    property bool addWaypointMode:           true
    property bool followVehicle:             false

    // Mission Execution Lifecycle & Progress Tracking
    property bool _missionCompleted:         false
    property bool _wasExecutingMission:      false
    property var  _takeoffCoordinate:        null

    readonly property real _missionExecutionPct: {
        if (!root._hasVehicle || root._flightItemCount <= 0) return 0.0
        if (root._missionCompleted) return 1.0
        // When disarmed, progress is strictly 0%
        if (!root._isArmed) return 0.0
        // When armed on ground prior to flight, progress is strictly 0%
        if (!root._isFlying && !root._inMissionMode) return 0.0

        var current = root._currentMissionIndex
        var total = root._flightItemCount
        if (total <= 0 || current <= 0) return 0.0

        // Completed flight waypoints prior to current active item
        var completedWps = Math.max(0, Math.min(total - 1, current - 1))
        var wpFraction = 0.0

        // Target waypoint coordinate (flight items start at visual item 1)
        var targetCoord = null
        if (root._visualItems && current < root._itemCount) {
            var currItem = root._visualItems.get(current)
            if (currItem && currItem.coordinate && currItem.coordinate.isValid) {
                targetCoord = currItem.coordinate
            }
        }

        // Live vehicle GPS coordinate
        var vehiclePos = (root._hasVehicle && root._activeVehicle.coordinate && root._activeVehicle.coordinate.isValid) ? root._activeVehicle.coordinate : null

        // Segment start coordinate: home position / takeoff anchor for item 1, previous waypoint for subsequent items
        var startCoord = null
        if (current === 1) {
            if (root._hasVehicle && root._activeVehicle.homePosition && root._activeVehicle.homePosition.isValid) {
                startCoord = root._activeVehicle.homePosition
            } else if (root._visualItems && root._itemCount > 0) {
                var item0 = root._visualItems.get(0)
                if (item0 && item0.coordinate && item0.coordinate.isValid) {
                    startCoord = item0.coordinate
                }
            }
            if (!startCoord) {
                if (root._takeoffCoordinate && root._takeoffCoordinate.isValid) {
                    startCoord = root._takeoffCoordinate
                } else if (vehiclePos && vehiclePos.isValid) {
                    root._takeoffCoordinate = vehiclePos
                    startCoord = vehiclePos
                }
            }
        } else if (current > 1 && root._visualItems && (current - 1) < root._itemCount) {
            var prevItem = root._visualItems.get(current - 1)
            if (prevItem && prevItem.coordinate && prevItem.coordinate.isValid) {
                startCoord = prevItem.coordinate
            }
        }

        if (targetCoord && startCoord && vehiclePos &&
            !isNaN(targetCoord.latitude) && !isNaN(targetCoord.longitude) &&
            !isNaN(startCoord.latitude) && !isNaN(startCoord.longitude) &&
            !isNaN(vehiclePos.latitude) && !isNaN(vehiclePos.longitude)) {

            var segmentDistance = startCoord.distanceTo(targetCoord)
            var remainingDistance = vehiclePos.distanceTo(targetCoord)

            if (!isNaN(segmentDistance) && segmentDistance > 1.0 && !isNaN(remainingDistance) && remainingDistance >= 0) {
                var fraction = 1.0 - (remainingDistance / segmentDistance)
                wpFraction = Math.max(0.05, Math.min(0.95, fraction))
            }
        }

        // Bounded strictly below 1.0 during flight; true 100% requires _missionCompleted
        var progress = (completedWps + wpFraction) / total
        return Math.max(0.05, Math.min(0.99, progress))
    }

    Connections {
        target: root._activeVehicle

        function onTextMessageReceived(sysid, componentid, severity, text, description) {
            var lower = text.toLowerCase()
            if (lower.indexOf("mission finished") !== -1 || lower.indexOf("mission complete") !== -1 || lower.indexOf("flight plan complete") !== -1) {
                if (root._wasExecutingMission || root._inMissionMode) {
                    root._missionCompleted = true
                    root._wasExecutingMission = false
                }
            }
        }
    }

    on_InMissionModeChanged: {
        if (_inMissionMode) {
            _wasExecutingMission = true
            _missionCompleted = false
            if (!_takeoffCoordinate && _activeVehicle && _activeVehicle.coordinate && _activeVehicle.coordinate.isValid) {
                _takeoffCoordinate = _activeVehicle.coordinate
            }
        }
    }

    on_CurrentMissionIndexChanged: {
        if ((_wasExecutingMission || _inMissionMode) && _flightItemCount > 0 && _currentMissionIndex > _flightItemCount) {
            _missionCompleted = true
            _wasExecutingMission = false
        }
    }

    on_IsArmedChanged: {
        if (!_isArmed) {
            _missionCompleted = false
            _wasExecutingMission = false
            _takeoffCoordinate = null
        }
    }

    on_ItemCountChanged: {
        _missionCompleted = false
        _wasExecutingMission = false
        _takeoffCoordinate = null
    }

    on_ActiveVehicleChanged: {
        _missionCompleted = false
        _wasExecutingMission = false
        _takeoffCoordinate = null
    }

    clip: true

    // ------------------------------------------------------------------------
    // Core QGC PlanMasterController (Zero Backend Modification - 100% Reuse)
    // ------------------------------------------------------------------------
    PlanMasterController {
        id: planMasterController
        flyView: false

        Component.onCompleted: {
            start()
            missionController.setCurrentPlanViewSeqNum(0, true)
        }
    }

    readonly property var  _missionController: planMasterController.missionController
    readonly property var  _visualItems:       _missionController ? _missionController.visualItems : null
    readonly property int  _itemCount:         _visualItems ? _visualItems.count : 0
    readonly property var  _selectedItem:      _missionController ? _missionController.currentPlanViewItem : null
    readonly property int  _selectedSeqNum:    _missionController ? _missionController.currentPlanViewSeqNum : 0
    readonly property int  _selectedVIIndex:   _missionController ? _missionController.currentPlanViewVIIndex : -1
    readonly property bool _syncInProgress:    planMasterController.syncInProgress
    readonly property bool _dirtyForUpload:    planMasterController.dirtyForUpload
    readonly property bool _dirtyForSave:      planMasterController.dirtyForSave

    // Fit Viewport helper
    MapFitFunctions {
        id: mapFitFunctions
        map: editorMap
        usePlannedHomePosition: true
        planMasterController: planMasterController
    }

    // Plan File Dialog
    QGCFileDialog {
        id: planFileDialog
        folder: QGroundControl.settingsManager.appSettings.missionSavePath
        nameFilters: planMasterController.loadNameFilters
        title: qsTr("Select Plan File")

        onAcceptedForSave: (file) => {
            planMasterController.saveToFile(file)
            close()
        }
        onAcceptedForLoad: (file) => {
            planMasterController.loadFromFile(file)
            mapFitFunctions.fitMapViewportToMissionItems()
            _missionController.setCurrentPlanViewSeqNum(0, true)
            root._missionCompleted = false
            root._wasExecutingMission = false
            close()
        }
    }

    // ====================================================================
    // 1. TOP COMMAND & SYNC STRIP (Floating QGC Style)
    // ====================================================================
    Rectangle {
        id: topCommandStrip
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: CompanyTheme.spacingSm
        z: 10
        height: 48
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgOverlayDark
        border.color: CompanyTheme.borderCard
        border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: CompanyTheme.spacingMd
                anchors.rightMargin: CompanyTheme.spacingMd
                spacing: CompanyTheme.spacingMd

                // Mission Badge & Name
                RowLayout {
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: CompanyTheme.radiusSm
                        color: CompanyTheme.primaryDim
                        IconVector {
                            anchors.centerIn: parent
                            name: "missions"
                            size: 16
                            color: CompanyTheme.primary
                        }
                    }

                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: planMasterController.currentPlanFileName !== "" ? planMasterController.currentPlanFileName : qsTr("Active Flight Plan")
                            color: CompanyTheme.textPrimary
                            font.pointSize: CompanyTheme.fontBody
                            font.bold: true
                        }
                        Text {
                            text: qsTr("Waypoint Navigation • %1 items").arg(root._flightItemCount)
                            color: CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontTiny
                        }
                    }
                }

                // Vertical Divider
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 24
                    color: CompanyTheme.borderCard
                }

                // Route Distance Chip
                RowLayout {
                    spacing: 4
                    Text { text: qsTr("Distance:"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontSmall }
                    Text {
                        text: {
                            var distMeters = root._missionController ? root._missionController.missionTotalDistance : 0
                            if (distMeters >= 1000) return (distMeters / 1000).toFixed(2) + " km"
                            return Math.round(distMeters) + " m"
                        }
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }
                }

                // Route Flight Time Chip
                RowLayout {
                    spacing: 4
                    Text { text: qsTr("Est. Time:"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontSmall }
                    Text {
                        text: {
                            var sec = root._missionController ? root._missionController.missionTime : 0
                            if (isNaN(sec) || sec <= 0) return "--:--"
                            var m = Math.floor(sec / 60)
                            var s = Math.floor(sec % 60)
                            return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
                        }
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }
                }

                // Sync Status Pill
                StatusBadge {
                    text: {
                        if (root._syncInProgress) return qsTr("SYNCING...")
                        if (root._dirtyForUpload) return qsTr("UNSAVED TO VEHICLE")
                        return qsTr("SYNCED")
                    }
                    badgeColor: {
                        if (root._syncInProgress) return CompanyTheme.warning
                        if (root._dirtyForUpload) return CompanyTheme.accent
                        return CompanyTheme.success
                    }
                    pulse: root._syncInProgress
                }

                Item { Layout.fillWidth: true }

                // Actions: Mode Toggle
                Rectangle {
                    Layout.preferredHeight: 32
                    radius: CompanyTheme.radiusSm
                    color: root.addWaypointMode ? CompanyTheme.primaryDim : CompanyTheme.bgInput
                    border.color: root.addWaypointMode ? CompanyTheme.primary : CompanyTheme.borderCard
                    border.width: 1
                    implicitWidth: addWpRow.implicitWidth + 16

                    RowLayout {
                        id: addWpRow
                        anchors.centerIn: parent
                        spacing: 6
                        IconVector {
                            name: "target"
                            size: 13
                            color: root.addWaypointMode ? CompanyTheme.primary : CompanyTheme.textSecondary
                        }
                        Text {
                            text: root.addWaypointMode ? qsTr("ADD WAYPOINT: ON") : qsTr("ADD WAYPOINT: OFF")
                            color: root.addWaypointMode ? CompanyTheme.primary : CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.addWaypointMode = !root.addWaypointMode
                    }
                }

                // Action: Fit Viewport
                Button {
                    Layout.preferredHeight: 32
                    implicitWidth: fitText.implicitWidth + 20
                    contentItem: Text {
                        id: fitText
                        text: qsTr("Fit Map")
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                    }
                    background: Rectangle {
                        radius: CompanyTheme.radiusSm
                        color: parent.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                        border.color: CompanyTheme.borderCard
                    }
                    onClicked: mapFitFunctions.fitMapViewportToMissionItems()
                }

                // Action: Download from Vehicle
                Button {
                    Layout.preferredHeight: 32
                    enabled: root._hasVehicle && !root._syncInProgress
                    implicitWidth: dlText.implicitWidth + 20
                    contentItem: Text {
                        id: dlText
                        text: qsTr("Download")
                        color: parent.enabled ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                    }
                    background: Rectangle {
                        radius: CompanyTheme.radiusSm
                        color: parent.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                        border.color: CompanyTheme.borderCard
                    }
                    onClicked: planMasterController.loadFromVehicle()
                }

                // Action: Upload to Vehicle
                Button {
                    id: uploadBtn
                    Layout.preferredHeight: 32
                    enabled: root._hasVehicle && !root._syncInProgress && root._itemCount > 0 && !root._isMissionActive
                    implicitWidth: upText.implicitWidth + 20
                    contentItem: Text {
                        id: upText
                        text: qsTr("Upload to Drone")
                        color: uploadBtn.enabled ? CompanyTheme.textLight : CompanyTheme.textMuted
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                    }
                    background: Rectangle {
                        radius: CompanyTheme.radiusSm
                        color: {
                            if (!uploadBtn.enabled) return CompanyTheme.bgInput
                            if (uploadBtn.pressed) return Qt.darker(CompanyTheme.primary, 1.2)
                            return uploadBtn.hovered ? CompanyTheme.primaryHover : CompanyTheme.primary
                        }
                    }
                    onClicked: {
                        if (root._isMissionActive) return
                        if (planMasterController.readyForSaveState() === 0) {
                            root._missionCompleted = false
                            root._wasExecutingMission = false
                            planMasterController.sendToVehicle()
                        }
                    }
                }

                // Action: Open / Save Dropdown Menu
                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: 32
                    radius: CompanyTheme.radiusSm
                    color: fileMenuArea.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                    border.color: CompanyTheme.borderCard
                    border.width: 1

                    IconVector {
                        anchors.centerIn: parent
                        name: "config"
                        size: 14
                        color: CompanyTheme.textSecondary
                    }

                    MouseArea {
                        id: fileMenuArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: planMenu.open()
                    }

                    Menu {
                        id: planMenu
                        y: parent.height + 4

                        MenuItem {
                            text: qsTr("Open Plan File...")
                            onTriggered: {
                                planFileDialog.title = qsTr("Open Plan File")
                                planFileDialog.openForLoad()
                            }
                        }
                        MenuItem {
                            text: qsTr("Save Plan File...")
                            enabled: root._itemCount > 0
                            onTriggered: {
                                planFileDialog.title = qsTr("Save Plan File")
                                planFileDialog.openForSave()
                            }
                        }
                        MenuItem {
                            text: qsTr("Insert Takeoff Item")
                            onTriggered: {
                                var nextIdx = root._selectedVIIndex >= 0 ? (root._selectedVIIndex + 1) : root._itemCount
                                root._missionController.insertTakeoffItem(editorMap.center, nextIdx, true)
                            }
                        }
                        MenuItem {
                            text: qsTr("Insert Land Item")
                            onTriggered: {
                                var nextIdx = root._selectedVIIndex >= 0 ? (root._selectedVIIndex + 1) : root._itemCount
                                root._missionController.insertLandItem(editorMap.center, nextIdx, true)
                            }
                        }
                        MenuSeparator {}
                        MenuItem {
                            text: qsTr("Clear All Waypoints")
                            enabled: root._itemCount > 0
                            onTriggered: planMasterController.removeAll()
                        }
                    }
                }
            }
        }

    // ====================================================================
    // 2. FULL-BLEED INTERACTIVE MISSION FLIGHTMAP (QGC PlanView Canvas)
    // ====================================================================
    FlightMap {
                    id: editorMap
                    objectName: "companyMissionEditorMap"
                    anchors.fill: parent
                    mapName: "CompanyMissionEditor"
                    allowGCSLocationCenter: true
                    allowVehicleLocationCenter: root.followVehicle
                    planView: true

                    zoomLevel: QGroundControl.flightMapZoom
                    center: QGroundControl.flightMapPosition

                    onZoomLevelChanged: QGroundControl.flightMapZoom = editorMap.zoomLevel
                    onCenterChanged: QGroundControl.flightMapPosition = editorMap.center

                    // Interactive Waypoint Placement on Map Click
                    onMapClicked: (mouse) => {
                        var coord = editorMap.toCoordinate(Qt.point(mouse.x, mouse.y), false)
                        coord.latitude = Number(coord.latitude.toFixed(8))
                        coord.longitude = Number(coord.longitude.toFixed(8))
                        coord.altitude = Number(coord.altitude.toFixed(2))

                        if (root.addWaypointMode) {
                            var nextIndex = root._selectedVIIndex >= 0 ? (root._selectedVIIndex + 1) : root._itemCount
                            root._missionController.insertSimpleMissionItem(coord, nextIndex, true)
                        }
                    }

                    // 1. Waypoint Visual Markers (Native QGC PlanView component)
                    Repeater {
                        model: root._visualItems
                        delegate: MissionItemMapVisual {
                            id: mapVisual
                            required property var object
                            required property int index

                            map: editorMap
                            interactive: true
                            vehicle: planMasterController.controllerVehicle
                            onClicked: (sequenceNumber) => {
                                root._missionController.setCurrentPlanViewSeqNum(sequenceNumber, false)
                            }
                        }
                    }

                    // 2. Geodesic Flight Path Lines Connecting Waypoints
                    MissionLineView {
                        model: root._missionController ? root._missionController.simpleFlightPathSegments : null
                    }

                    // 3. Direction Arrows along Segments
                    MapItemView {
                        model: root._missionController ? root._missionController.directionArrows : null
                        delegate: MapLineArrow {
                            id: dirArrow
                            required property var object
                            fromCoord: dirArrow.object ? dirArrow.object.coordinate1 : undefined
                            toCoord: dirArrow.object ? dirArrow.object.coordinate2 : undefined
                            arrowPosition: 3
                            z: QGroundControl.zOrderWaypointLines + 1
                        }
                    }

                    // 4. Vehicles on Map
                    MapItemView {
                        model: QGroundControl.multiVehicleManager.vehicles
                        delegate: VehicleMapItem {
                            id: vItem
                            required property var object
                            vehicle: vItem.object
                            coordinate: vItem.object.coordinate
                            map: editorMap
                            size: ScreenTools.defaultFontPixelHeight * 2.8
                            z: QGroundControl.zOrderVehicles
                        }
                    }

                    // 5. Planned Home Position Marker
                    MapQuickItem {
                        id: plannedHomeMarker
                        readonly property var homeCoord: root._missionController ? root._missionController.plannedHomePosition : QtPositioning.coordinate()
                        coordinate: homeCoord && homeCoord.isValid ? homeCoord : QtPositioning.coordinate()
                        visible: homeCoord && homeCoord.isValid
                        z: QGroundControl.zOrderMapItems
                        anchorPoint.x: homeIcon.width / 2
                        anchorPoint.y: homeIcon.height / 2

                        sourceItem: Rectangle {
                            id: homeIcon
                            width: 26
                            height: 26
                            radius: 13
                            color: Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.25)
                            border.color: CompanyTheme.warning
                            border.width: 1.5

                            Image {
                                anchors.centerIn: parent
                                source: "/qmlimages/MapHome.svg"
                                width: 14
                                height: 14
                                sourceSize.width: 14
                                sourceSize.height: 14
                                fillMode: Image.PreserveAspectFit
                            }
                        }
                    }
                }

    // Floating Map Controls (Zoom In/Out + Recenter)
    ColumnLayout {
        id: mapZoomTools
        anchors.right: queuePanel.left
        anchors.bottom: bottomExecutionStrip.top
        anchors.margins: CompanyTheme.spacingSm
        spacing: CompanyTheme.spacingXs
        z: 15

        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: CompanyTheme.radiusSm
            color: CompanyTheme.bgCardElevated
            border.color: CompanyTheme.borderCard
            border.width: 1
            Text { anchors.centerIn: parent; text: "+"; color: CompanyTheme.textPrimary; font.pointSize: CompanyTheme.fontTitle; font.bold: true }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: editorMap.zoomLevel = Math.min(21, editorMap.zoomLevel + 1)
            }
        }

        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: CompanyTheme.radiusSm
            color: CompanyTheme.bgCardElevated
            border.color: CompanyTheme.borderCard
            border.width: 1
            Text { anchors.centerIn: parent; text: "−"; color: CompanyTheme.textPrimary; font.pointSize: CompanyTheme.fontTitle; font.bold: true }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: editorMap.zoomLevel = Math.max(2, editorMap.zoomLevel - 1)
            }
        }

        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: CompanyTheme.radiusSm
            color: CompanyTheme.bgCardElevated
            border.color: CompanyTheme.borderCard
            border.width: 1
            IconVector { anchors.centerIn: parent; name: "location"; size: 14; color: CompanyTheme.primary }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root._hasValidCoord) {
                        editorMap.center = root._vehicleCoord
                    } else {
                        mapFitFunctions.fitMapViewportToMissionItems()
                    }
                }
            }
        }
    }

    // ====================================================================
    // 3. FLOATING WAYPOINT QUEUE & SELECTED ITEM INSPECTOR (Right Overlay)
    // ====================================================================
    Rectangle {
        id: queuePanel
        anchors.top: topCommandStrip.bottom
        anchors.bottom: bottomExecutionStrip.top
        anchors.right: parent.right
        anchors.topMargin: CompanyTheme.spacingSm
        anchors.bottomMargin: CompanyTheme.spacingSm
        anchors.rightMargin: CompanyTheme.spacingSm
        z: 10
        width: 340
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgOverlayDark
        border.color: CompanyTheme.borderCard
        border.width: 1
        clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: CompanyTheme.spacingMd
                    spacing: CompanyTheme.spacingSm

                    // Queue Header
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("MISSION QUEUE")
                            color: CompanyTheme.textPrimary
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                            font.letterSpacing: 0.8
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: qsTr("%1 items").arg(root._itemCount)
                            color: CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontSmall
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: CompanyTheme.borderCard
                    }

                    // Waypoint List View
                    ListView {
                        id: queueList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4
                        clip: true
                        model: root._visualItems

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        delegate: Rectangle {
                            id: itemDelegate
                            required property var object
                            required property int index

                            readonly property bool isSelected: root._selectedVIIndex === itemDelegate.index
                            readonly property bool isCurrentExec: itemDelegate.object ? itemDelegate.object.isCurrentItem : false

                            Layout.fillWidth: true
                            width: queueList.width
                            height: 48
                            radius: CompanyTheme.radiusSm
                            color: {
                                if (itemDelegate.isCurrentExec) return Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.18)
                                if (itemDelegate.isSelected) return CompanyTheme.primaryDim
                                return queueMouse.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCardElevated
                            }
                            border.color: {
                                if (itemDelegate.isCurrentExec) return CompanyTheme.warning
                                if (itemDelegate.isSelected) return CompanyTheme.primary
                                return CompanyTheme.borderCard
                            }
                            border.width: (itemDelegate.isSelected || itemDelegate.isCurrentExec) ? 1.5 : 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                // Sequence Number Badge
                                Rectangle {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    radius: 12
                                    color: itemDelegate.isSelected ? CompanyTheme.primary : CompanyTheme.bgInput

                                    Text {
                                        anchors.centerIn: parent
                                        text: itemDelegate.object ? itemDelegate.object.sequenceNumber : (itemDelegate.index + 1)
                                        color: itemDelegate.isSelected ? CompanyTheme.textLight : CompanyTheme.textSecondary
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.bold: true
                                    }
                                }

                                // Command Name & Coordinates
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: itemDelegate.object ? itemDelegate.object.commandName : qsTr("Waypoint")
                                        color: itemDelegate.isSelected ? CompanyTheme.primary : CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontSmall
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: {
                                            if (!itemDelegate.object) return "--"
                                            if (itemDelegate.object.specifiesCoordinate) {
                                                var c = itemDelegate.object.coordinate
                                                return c.latitude.toFixed(4) + "°, " + c.longitude.toFixed(4) + "°"
                                            }
                                            return itemDelegate.object.commandDescription || ""
                                        }
                                        color: CompanyTheme.textMuted
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.family: CompanyTheme.fontMono
                                        elide: Text.ElideRight
                                    }
                                }

                                // Altitude
                                Text {
                                    text: {
                                        if (itemDelegate.object && itemDelegate.object.isSimpleItem && itemDelegate.object.altitude) {
                                            return itemDelegate.object.altitude.valueString + " " + itemDelegate.object.altitude.units
                                        }
                                        return ""
                                    }
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: CompanyTheme.fontSmall
                                    font.family: CompanyTheme.fontMono
                                }
                            }

                            MouseArea {
                                id: queueMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (itemDelegate.object) {
                                        root._missionController.setCurrentPlanViewSeqNum(itemDelegate.object.sequenceNumber, true)
                                    }
                                }
                            }
                        }
                    }

                    // Selected Waypoint Parameter Inspector
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 140
                        radius: CompanyTheme.radiusSm
                        color: CompanyTheme.bgCardElevated
                        border.color: CompanyTheme.borderCard
                        border.width: 1
                        visible: root._selectedItem !== null

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: qsTr("WAYPOINT %1 PARAMETERS").arg(root._selectedItem ? root._selectedItem.sequenceNumber : 0)
                                    color: CompanyTheme.primary
                                    font.pointSize: CompanyTheme.fontTiny
                                    font.bold: true
                                }
                                Item { Layout.fillWidth: true }
                                // Delete Waypoint Button
                                Button {
                                    Layout.preferredHeight: 22
                                    implicitWidth: 60
                                    contentItem: Text {
                                        text: qsTr("Delete")
                                        color: CompanyTheme.danger
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    background: Rectangle {
                                        radius: CompanyTheme.radiusSm
                                        color: parent.hovered ? Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.2) : "transparent"
                                        border.color: CompanyTheme.danger
                                    }
                                    onClicked: {
                                        if (root._selectedVIIndex >= 0) {
                                            root._missionController.removeVisualItem(root._selectedVIIndex)
                                        }
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderCard }

                            // Altitude Input (Fact-driven)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text { text: qsTr("Altitude:"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall; Layout.preferredWidth: 70 }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: CompanyTheme.borderCard

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8

                                        TextInput {
                                            id: altInput
                                            Layout.fillWidth: true
                                            text: (root._selectedItem && root._selectedItem.isSimpleItem && root._selectedItem.altitude) ? root._selectedItem.altitude.valueString : "50"
                                            color: CompanyTheme.textPrimary
                                            font.pointSize: CompanyTheme.fontSmall
                                            font.family: CompanyTheme.fontMono
                                            selectByMouse: true
                                            onEditingFinished: {
                                                if (root._selectedItem && root._selectedItem.isSimpleItem && root._selectedItem.altitude) {
                                                    var num = parseFloat(altInput.text)
                                                    if (!isNaN(num)) {
                                                        root._selectedItem.altitude.value = num
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: (root._selectedItem && root._selectedItem.isSimpleItem && root._selectedItem.altitude) ? root._selectedItem.altitude.units : "m"
                                            color: CompanyTheme.textMuted
                                            font.pointSize: CompanyTheme.fontTiny
                                        }
                                    }
                                }
                            }

                            // Coordinate Display
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text { text: qsTr("Position:"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall; Layout.preferredWidth: 70 }
                                Text {
                                    text: {
                                        if (root._selectedItem && root._selectedItem.specifiesCoordinate) {
                                            var coord = root._selectedItem.coordinate
                                            return coord.latitude.toFixed(6) + "°, " + coord.longitude.toFixed(6) + "°"
                                        }
                                        return "--"
                                    }
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: CompanyTheme.fontSmall
                                    font.family: CompanyTheme.fontMono
                                }
                            }
                        }
                    }
                }
            }

    // ====================================================================
    // 4. FLOATING BOTTOM MISSION EXECUTION & PROGRESS BAR (QGC Style)
    // ====================================================================
    Rectangle {
        id: bottomExecutionStrip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: CompanyTheme.spacingSm
        z: 10
        height: 56
        radius: CompanyTheme.radiusSm
        color: CompanyTheme.bgOverlayDark
        border.color: CompanyTheme.borderCard
        border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: CompanyTheme.spacingMd
                anchors.rightMargin: CompanyTheme.spacingMd
                spacing: CompanyTheme.spacingLg

                // Execution Status Icon & Heading
                RowLayout {
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: CompanyTheme.radiusSm
                        color: {
                            if (root._missionCompleted) return Qt.rgba(CompanyTheme.success.r, CompanyTheme.success.g, CompanyTheme.success.b, 0.2)
                            if (root._inMissionMode || (root._isArmed && root._isFlying)) return Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.2)
                            return CompanyTheme.bgInput
                        }
                        border.color: {
                            if (root._missionCompleted) return CompanyTheme.success
                            if (root._inMissionMode || (root._isArmed && root._isFlying)) return CompanyTheme.warning
                            return CompanyTheme.borderCard
                        }
                        IconVector {
                            anchors.centerIn: parent
                            name: "flight"
                            size: 16
                            color: {
                                if (root._missionCompleted) return CompanyTheme.success
                                if (root._inMissionMode || (root._isArmed && root._isFlying)) return CompanyTheme.warning
                                return CompanyTheme.textSecondary
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: qsTr("MISSION PROGRESS")
                            color: CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                        }
                        Text {
                            text: {
                                if (!root._hasVehicle) return qsTr("No Vehicle")
                                if (root._missionCompleted) return qsTr("Mission Complete")
                                if (root._inMissionMode) {
                                    var currentFlightWP = Math.max(1, Math.min(root._flightItemCount, root._currentMissionIndex))
                                    return qsTr("Tracking Waypoint %1 of %2").arg(currentFlightWP).arg(root._flightItemCount)
                                }
                                if (root._isArmed && root._isFlying) {
                                    if (root._hasVehicle && root._flightMode === root._activeVehicle.pauseFlightMode) {
                                        return qsTr("Mission Paused")
                                    }
                                    return qsTr("Standby (In Flight)")
                                }
                                if (root._isArmed) return qsTr("Armed (Standby)")
                                return qsTr("Vehicle Disarmed")
                            }
                            color: {
                                if (root._missionCompleted) return CompanyTheme.success
                                if (root._inMissionMode || (root._isArmed && root._isFlying)) return CompanyTheme.warning
                                return CompanyTheme.textPrimary
                            }
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                        }
                    }
                }

                // Progress Bar
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: qsTr("Completion"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Math.round(root._missionExecutionPct * 100) + "%"
                            color: CompanyTheme.textPrimary
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                            font.family: CompanyTheme.fontMono
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        radius: 3
                        color: CompanyTheme.bgInput

                        Rectangle {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            width: parent.width * Math.max(0, Math.min(1.0, root._missionExecutionPct))
                            radius: 3
                            color: root._missionCompleted ? CompanyTheme.success : CompanyTheme.primary
                        }
                    }
                }

                // Execution Controls: Start, Pause, Resume, RTL
                RowLayout {
                    spacing: CompanyTheme.spacingSm

                    // Start Mission Button
                    Button {
                        id: startMissionBtn
                        Layout.preferredHeight: 34
                        implicitWidth: 120
                        enabled: root._hasVehicle && root._hasMissionItems && !root._inMissionMode
                        contentItem: Text {
                            text: qsTr("Start Mission")
                            color: startMissionBtn.enabled ? CompanyTheme.textLight : CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: CompanyTheme.radiusSm
                            color: {
                                if (!startMissionBtn.enabled) return CompanyTheme.bgInput
                                return startMissionBtn.hovered ? CompanyTheme.primaryHover : CompanyTheme.primary
                            }
                        }
                        onClicked: {
                            if (root._hasVehicle) {
                                root._missionCompleted = false
                                root._wasExecutingMission = false
                                root._activeVehicle.startMission()
                            }
                        }
                    }

                    // Pause / Hold Button
                    Button {
                        id: pauseBtn
                        Layout.preferredHeight: 34
                        implicitWidth: 80
                        enabled: root._hasVehicle && root._isArmed
                        contentItem: Text {
                            text: qsTr("Pause")
                            color: pauseBtn.enabled ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: CompanyTheme.radiusSm
                            color: pauseBtn.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCardElevated
                            border.color: CompanyTheme.borderCard
                        }
                        onClicked: {
                            if (root._hasVehicle) {
                                root._activeVehicle.pauseVehicle()
                            }
                        }
                    }

                    // Return To Launch (RTL) Button
                    Button {
                        id: rtlMissionBtn
                        Layout.preferredHeight: 34
                        implicitWidth: 70
                        enabled: root._hasVehicle && root._isArmed
                        contentItem: Text {
                            text: qsTr("RTL")
                            color: rtlMissionBtn.enabled ? CompanyTheme.textSecondary : CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: CompanyTheme.radiusSm
                            color: rtlMissionBtn.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCardElevated
                            border.color: CompanyTheme.borderCard
                        }
                        onClicked: {
                            if (root._hasVehicle) {
                                root._activeVehicle.guidedModeRTL(false)
                            }
                        }
                    }
                }
            }
        }
    }
