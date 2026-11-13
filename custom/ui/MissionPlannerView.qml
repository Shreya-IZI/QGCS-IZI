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

Item {
    id: root

    // ------------------------------------------------------------------------
    // Vehicle & Telemetry Bindings
    // ------------------------------------------------------------------------
    readonly property var  _activeVehicle:   CompanyTelemetry.activeVehicle
    readonly property bool _hasVehicle:      CompanyTelemetry.hasVehicle && _activeVehicle !== null
    readonly property var  _vehicleCoord:    CompanyTelemetry.coordinate
    readonly property bool _hasValidCoord:   CompanyTelemetry.hasValidCoord
    readonly property bool _isArmed:         CompanyTelemetry.armed
    readonly property bool _isFlying:        CompanyTelemetry.flying
    readonly property string _flightMode:    CompanyTelemetry.flightMode
    readonly property bool _isMissionExecuting: _hasVehicle && _isArmed && _isFlying && (_flightMode !== "") && (_activeVehicle ? (_flightMode === _activeVehicle.missionFlightMode) : false)
    readonly property bool _inMissionMode:   _isMissionExecuting
    readonly property bool _isMissionPaused: _hasVehicle && _isArmed && _isFlying && (_flightMode !== "") && (_activeVehicle ? (_flightMode === _activeVehicle.pauseFlightMode) : false) && _wasExecutingMission && !_missionCompleted
    readonly property bool _isMissionActive: (_isMissionExecuting || _isMissionPaused) && !_missionCompleted
    readonly property int  _currentMissionIndex: (_hasVehicle && _activeVehicle && _activeVehicle.missionItemIndex) ? Number(_activeVehicle.missionItemIndex.rawValue) : 0
    readonly property int  _flightItemCount: Math.max(0, root._itemCount - 1)
    readonly property bool _hasMissionItems: root._flightItemCount > 0 && ((root._missionController && root._missionController.containsItems) || planMasterController.containsItems || root._itemCount > 1)

    signal flightActionRequested(string actionType)

    // Interactive Mode Controls
    property bool addWaypointMode:           true
    property bool followVehicle:             false

    // DJI Flight Task Configuration
    property string positioningAccuracy:     "RTK" // "RTK" or "GNSS"
    property string planTimer:               "Immediate" // "Immediate", "Timed", "Recurring"
    property real   defaultAltitude:         50.0

    function stepAltitude(delta) {
        if (root._selectedItem && root._selectedItem.isSimpleItem && root._selectedItem.altitude) {
            var cur = Number(root._selectedItem.altitude.rawValue)
            if (isNaN(cur)) cur = 50.0
            root._selectedItem.altitude.value = Math.max(5.0, cur + delta)
        } else {
            defaultAltitude = Math.max(5.0, defaultAltitude + delta)
            if (root._visualItems && root._itemCount > 0) {
                for (var i = 1; i < root._itemCount; ++i) {
                    var itm = root._visualItems.get(i)
                    if (itm && itm.isSimpleItem && itm.altitude) {
                        var c = Number(itm.altitude.rawValue)
                        if (!isNaN(c)) itm.altitude.value = Math.max(5.0, c + delta)
                    }
                }
            }
        }
    }

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
        var vehiclePos = (root._hasVehicle && root._activeVehicle && root._activeVehicle.coordinate && root._activeVehicle.coordinate.isValid) ? root._activeVehicle.coordinate : null

        // Segment start coordinate: home position / takeoff anchor for item 1, previous waypoint for subsequent items
        var startCoord = null
        if (current === 1) {
            if (root._hasVehicle && root._activeVehicle && root._activeVehicle.homePosition && root._activeVehicle.homePosition.isValid) {
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

    // ============================================================
    // IZI MISSION HEALTH
    // ============================================================

    MissionHealth {
        id: missionHealth

        missionController: root._missionController
        visualItems: root._visualItems
    }
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
    // Mission Upload & Pre-Flight Validation Helper
    // ====================================================================
    function _executeUpload() {
        if (root._missionController && root._missionController.sendToVehiclePreCheck() === MissionController.SendToVehiclePreCheckStateFirwmareVehicleMismatch) {
            QGroundControl.showMessageDialog(
                root,
                qsTr("Plan Upload Mismatch"),
                qsTr("This Plan was created for a different firmware or vehicle type than the vehicle you are uploading to.\n\nClick 'Ok' to upload the Plan anyway."),
                Dialog.Ok | Dialog.Cancel,
                function() {
                    root._missionCompleted = false
                    root._wasExecutingMission = false
                    planMasterController.sendToVehicle()
                }
            )
            return
        }

        root._missionCompleted = false
        root._wasExecutingMission = false
        planMasterController.sendToVehicle()
    }

    function initiateMissionUpload() {
        if (root._isMissionActive) {
            return
        }

        // 1. QGC Structural Save/Upload Gate (Incomplete data or waiting on terrain elevation)
        var saveState = planMasterController.readyForSaveState()
        if (saveState === 1 /* VisualMissionItem.NotReadyForSaveTerrain */) {
            QGroundControl.showMessageDialog(
                root,
                qsTr("Unable to Upload"),
                qsTr("Plan is waiting on terrain elevation data from the server for correct altitude values.")
            )
            return
        } else if (saveState === 2 /* VisualMissionItem.NotReadyForSaveData */) {
            QGroundControl.showMessageDialog(
                root,
                qsTr("Unable to Upload"),
                qsTr("Plan has incomplete items. Complete all mission parameters and attempt upload again.")
            )
            return
        }

        // 2. QGC Active Mission Check
        if (root._missionController) {
            var preCheck = root._missionController.sendToVehiclePreCheck()
            if (preCheck === MissionController.SendToVehiclePreCheckStateActiveMission) {
                QGroundControl.showMessageDialog(
                    root,
                    qsTr("Send To Vehicle"),
                    qsTr("Current mission must be paused prior to uploading a new Plan.")
                )
                return
            }
        }

        // 3. IZI Mission Health Advisory Validation
        if (!missionHealth.ready) {
            var failedList = []
            for (var i = 0; i < missionHealth.checkItems.length; i++) {
                var check = missionHealth.checkItems[i]
                if (!check.passed) {
                    failedList.push("• " + check.name + ": " + check.detail)
                }
            }
            var failedSummary = failedList.join("\n")
            var warningMsg = qsTr("One or more pre-flight health checks require attention:\n\n%1\n\nDetail: %2\n\nDo you want to proceed with uploading this plan to the vehicle anyway?").arg(failedSummary).arg(missionHealth.statusDetail)

            QGroundControl.showMessageDialog(
                root,
                qsTr("Pre-Flight Health Notice"),
                warningMsg,
                Dialog.Ok | Dialog.Cancel,
                function() {
                    root._executeUpload()
                }
            )
            return
        }

        // 4. All checks passed: proceed directly with upload
        root._executeUpload()
    }

    // ====================================================================
    // 1. TOP COMMAND & SYNC STRIP (DJI Glass Architecture)
    // ====================================================================
    Rectangle {
        id: topCommandStrip
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: CompanyTheme.spacingSm
        z: 10
        height: 48
        radius: CompanyTheme.radiusMd
        color: CompanyTheme.bgGlass
        border.color: CompanyTheme.borderGlass
        border.width: 1
        clip: true

        Flickable {
            id: missionToolbarFlickable
            anchors.fill: parent
            contentWidth: Math.max(width, missionToolbarLayout.x + missionToolbarLayout.implicitWidth + CompanyTheme.spacingMd)
            contentHeight: height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick
            clip: true

            RowLayout {
                id: missionToolbarLayout
                x: CompanyTheme.spacingMd
                anchors.verticalCenter: parent.verticalCenter
                spacing: CompanyTheme.spacingMd
                width: Math.max(missionToolbarFlickable.width - CompanyTheme.spacingMd * 2, implicitWidth)

                // Mission Badge & Name
                RowLayout {
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        implicitWidth: 30
                        implicitHeight: 30
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
                    visible: topCommandStrip.width >= 1050
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 24
                    implicitWidth: visible ? 1 : 0
                    implicitHeight: 24
                    color: CompanyTheme.borderCard
                }

                // Route Distance Chip
                RowLayout {
                    visible: topCommandStrip.width >= 1050
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
                    visible: topCommandStrip.width >= 1050
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
                    visible: topCommandStrip.width >= 820
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

                // Mission Pre-Flight Health Pill
                StatusBadge {
                    visible: topCommandStrip.width >= 1200
                    text: missionHealth.status
                    badgeColor: {
                        if (missionHealth.ready) return CompanyTheme.success
                        if (missionHealth.passedChecks >= 4) return CompanyTheme.warning
                        return CompanyTheme.danger
                    }
                    pulse: !missionHealth.ready && root._hasVehicle
                }

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: CompanyTheme.spacingSm
                    implicitWidth: 0
                }

                // Actions: Mode Toggle
                Rectangle {
                    Layout.preferredHeight: 32
                    implicitHeight: 32
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
                    implicitHeight: 32
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
                    implicitHeight: 32
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
                    implicitHeight: 32
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
                    ToolTip.visible: uploadBtn.hovered
                    ToolTip.delay: 400
                    ToolTip.text: {
                        if (!root._hasVehicle) return qsTr("No vehicle connected")
                        if (root._isMissionActive) return qsTr("Mission is currently executing or paused")
                        if (root._itemCount <= 0) return qsTr("No mission items to upload")
                        if (root._syncInProgress) return qsTr("Sync already in progress")
                        if (!missionHealth.ready) return qsTr("Pre-flight Health Notice: %1").arg(missionHealth.status)
                        return qsTr("Upload mission plan to vehicle")
                    }
                    onClicked: root.initiateMissionUpload()
                }

                // Action: Open / Save Dropdown Menu
                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: 32
                    implicitWidth: 32
                    implicitHeight: 32
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

            ScrollBar.horizontal: ScrollBar {
                id: hScrollBar
                policy: (missionToolbarFlickable.contentWidth > missionToolbarFlickable.width) ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                height: 2
                anchors.bottom: parent.bottom
                contentItem: Rectangle {
                    implicitHeight: 2
                    radius: 1
                    color: hScrollBar.pressed ? CompanyTheme.primary : (hScrollBar.hovered ? CompanyTheme.borderActive : CompanyTheme.borderCard)
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    var delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y
                    var maxContentX = Math.max(0, missionToolbarFlickable.contentWidth - missionToolbarFlickable.width)
                    missionToolbarFlickable.contentX = Math.max(0, Math.min(maxContentX, missionToolbarFlickable.contentX - delta))
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

    // Floating Map Controls (Zoom In/Out + Recenter - Right Side)
    ColumnLayout {
        id: mapZoomTools
        anchors.right: parent.right
        anchors.bottom: bottomExecutionStrip.top
        anchors.margins: CompanyTheme.spacingMd
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
    // 3. DJI FLIGHT TASK & CREATE PLAN DRAWER (Left Overlay - FlightHub 2)
    // ====================================================================
    Rectangle {
        id: queuePanel
        anchors.top: topCommandStrip.bottom
        anchors.bottom: bottomExecutionStrip.top
        anchors.left: parent.left
        anchors.topMargin: CompanyTheme.spacingSm
        anchors.bottomMargin: CompanyTheme.spacingSm
        anchors.leftMargin: CompanyTheme.spacingSm
        z: 10
        width: 360
        radius: CompanyTheme.radiusMd
        color: CompanyTheme.bgGlass
        border.color: CompanyTheme.borderGlass
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: CompanyTheme.spacingMd
            spacing: CompanyTheme.spacingSm

            // 1. Task Header / Breadcrumb
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "❮"
                    color: CompanyTheme.djiCyan
                    font.pointSize: CompanyTheme.fontSmall
                    font.bold: true
                }

                Text {
                    text: qsTr("CREATE FLIGHT PLAN")
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: qsTr("%1 Waypoints").arg(root._flightItemCount)
                    color: CompanyTheme.djiCyan
                    font.pointSize: CompanyTheme.fontTiny
                    font.bold: true
                }
            }

            // 2. Device & RTK Status Banner
            Rectangle {
                Layout.fillWidth: true
                height: 38
                radius: CompanyTheme.radiusSm
                color: Qt.rgba(0.04, 0.06, 0.09, 0.85)
                border.color: CompanyTheme.borderGlass
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: root._hasVehicle ? CompanyTheme.success : CompanyTheme.warning
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: root._hasVehicle ? qsTr("UAS #%1 Online").arg(CompanyTelemetry.vehicleId) : qsTr("No Vehicle Linked")
                            color: CompanyTheme.textPrimary
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                        }
                        Text {
                            text: root._hasVehicle ? (CompanyTelemetry.gpsCountStr + " sats • " + CompanyTelemetry.gpsLockString) : qsTr("Simulated Editor")
                            color: CompanyTheme.textMuted
                            font.pointSize: 6
                        }
                    }

                    Rectangle {
                        Layout.preferredHeight: 18
                        implicitWidth: 50
                        radius: 3
                        color: root.positioningAccuracy === "RTK" ? CompanyTheme.djiBlue : CompanyTheme.bgCard
                        Text {
                            anchors.centerIn: parent
                            text: root.positioningAccuracy
                            color: "#FFFFFF"
                            font.pointSize: 7
                            font.bold: true
                        }
                    }
                }
            }

            // 3. Positioning Accuracy Pill Selector
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: qsTr("Positioning:")
                    color: CompanyTheme.textSecondary
                    font.pointSize: CompanyTheme.fontTiny
                    Layout.preferredWidth: 70
                }

                Row {
                    spacing: 4
                    Layout.fillWidth: true

                    Rectangle {
                        width: 60
                        height: 22
                        radius: CompanyTheme.radiusSm
                        color: root.positioningAccuracy === "RTK" ? CompanyTheme.djiBlue : CompanyTheme.bgCard
                        border.color: root.positioningAccuracy === "RTK" ? CompanyTheme.djiCyan : CompanyTheme.borderCard
                        Text {
                            anchors.centerIn: parent
                            text: "RTK"
                            color: root.positioningAccuracy === "RTK" ? "#FFFFFF" : CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.positioningAccuracy = "RTK"
                        }
                    }

                    Rectangle {
                        width: 60
                        height: 22
                        radius: CompanyTheme.radiusSm
                        color: root.positioningAccuracy === "GNSS" ? CompanyTheme.djiBlue : CompanyTheme.bgCard
                        border.color: root.positioningAccuracy === "GNSS" ? CompanyTheme.djiCyan : CompanyTheme.borderCard
                        Text {
                            anchors.centerIn: parent
                            text: "GNSS"
                            color: root.positioningAccuracy === "GNSS" ? "#FFFFFF" : CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.positioningAccuracy = "GNSS"
                        }
                    }
                }
            }

            // 4. Plan Timer Pill Selector
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: qsTr("Execution:")
                    color: CompanyTheme.textSecondary
                    font.pointSize: CompanyTheme.fontTiny
                    Layout.preferredWidth: 70
                }

                Row {
                    spacing: 4
                    Layout.fillWidth: true

                    Repeater {
                        model: ["Immediate", "Timed", "Recurring"]
                        Rectangle {
                            id: timerPill
                            required property string modelData
                            width: 64
                            height: 22
                            radius: CompanyTheme.radiusSm
                            color: root.planTimer === timerPill.modelData ? CompanyTheme.djiBlue : CompanyTheme.bgCard
                            border.color: root.planTimer === timerPill.modelData ? CompanyTheme.djiCyan : CompanyTheme.borderCard
                            Text {
                                anchors.centerIn: parent
                                text: timerPill.modelData
                                color: root.planTimer === timerPill.modelData ? "#FFFFFF" : CompanyTheme.textSecondary
                                font.pointSize: 7
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.planTimer = timerPill.modelData
                            }
                        }
                    }
                }
            }

            // 5. DJI Quick Altitude Stepper Controls
            Rectangle {
                Layout.fillWidth: true
                height: 52
                radius: CompanyTheme.radiusSm
                color: Qt.rgba(0.04, 0.06, 0.09, 0.85)
                border.color: CompanyTheme.borderGlass
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 2

                    Text {
                        text: root._selectedItem ? qsTr("WAYPOINT %1 ALTITUDE").arg(root._selectedItem.sequenceNumber) : qsTr("CRUISE ALTITUDE (ALL WPS)")
                        color: CompanyTheme.djiCyan
                        font.pointSize: 7
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Layout.alignment: Qt.AlignHCenter

                        Repeater {
                            model: [-100, -10, -1]
                            Rectangle {
                                id: negStepBtn
                                required property int modelData
                                width: 34
                                height: 22
                                radius: 3
                                color: negStepMouse.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                                border.color: CompanyTheme.borderCard
                                Text {
                                    anchors.centerIn: parent
                                    text: negStepBtn.modelData.toString()
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: 7
                                    font.family: CompanyTheme.fontMono
                                    font.bold: true
                                }
                                MouseArea {
                                    id: negStepMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.stepAltitude(negStepBtn.modelData)
                                }
                            }
                        }

                        // Current Altitude Display Box
                        Rectangle {
                            Layout.fillWidth: true
                            height: 22
                            radius: 3
                            color: CompanyTheme.djiBlueDim
                            border.color: CompanyTheme.djiCyan
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (root._selectedItem && root._selectedItem.isSimpleItem && root._selectedItem.altitude) {
                                        return root._selectedItem.altitude.valueString + " m"
                                    }
                                    return Math.round(root.defaultAltitude) + " m"
                                }
                                color: "#FFFFFF"
                                font.pointSize: CompanyTheme.fontSmall
                                font.family: CompanyTheme.fontMono
                                font.bold: true
                            }
                        }

                        Repeater {
                            model: [1, 10, 100]
                            Rectangle {
                                id: posStepBtn
                                required property int modelData
                                width: 34
                                height: 22
                                radius: 3
                                color: posStepMouse.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                                border.color: CompanyTheme.borderCard
                                Text {
                                    anchors.centerIn: parent
                                    text: "+" + posStepBtn.modelData.toString()
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: 7
                                    font.family: CompanyTheme.fontMono
                                    font.bold: true
                                }
                                MouseArea {
                                    id: posStepMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.stepAltitude(posStepBtn.modelData)
                                }
                            }
                        }
                    }
                }
            }

            // 6. Pre-Flight Mission Health Overview
            Rectangle {
                Layout.fillWidth: true
                radius: CompanyTheme.radiusSm
                color: Qt.rgba(0.04, 0.06, 0.09, 0.85)
                border.color: missionHealth.ready ? Qt.rgba(CompanyTheme.success.r, CompanyTheme.success.g, CompanyTheme.success.b, 0.3) : CompanyTheme.borderCard
                border.width: 1
                implicitHeight: healthCol.implicitHeight + 12

                ColumnLayout {
                    id: healthCol
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("PRE-FLIGHT CHECKS")
                            color: CompanyTheme.textSecondary
                            font.pointSize: 7
                            font.bold: true
                            font.letterSpacing: 0.5
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: qsTr("%1/%2 Passed").arg(missionHealth.passedChecks).arg(missionHealth.totalChecks)
                            color: missionHealth.ready ? CompanyTheme.success : (missionHealth.passedChecks >= 4 ? CompanyTheme.warning : CompanyTheme.danger)
                            font.pointSize: 7
                            font.bold: true
                        }
                    }
                }
            }

            // 7. Waypoint List View
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
                    height: 42
                    radius: CompanyTheme.radiusSm
                    color: {
                        if (itemDelegate.isCurrentExec) return Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.18)
                        if (itemDelegate.isSelected) return CompanyTheme.djiBlueDim
                        return queueMouse.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCardElevated
                    }
                    border.color: {
                        if (itemDelegate.isCurrentExec) return CompanyTheme.warning
                        if (itemDelegate.isSelected) return CompanyTheme.djiCyan
                        return CompanyTheme.borderCard
                    }
                    border.width: (itemDelegate.isSelected || itemDelegate.isCurrentExec) ? 1.5 : 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        // Sequence Number Badge
                        Rectangle {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            radius: 10
                            color: itemDelegate.isSelected ? CompanyTheme.djiBlue : CompanyTheme.bgInput

                            Text {
                                anchors.centerIn: parent
                                text: itemDelegate.object ? itemDelegate.object.sequenceNumber : (itemDelegate.index + 1)
                                color: itemDelegate.isSelected ? "#FFFFFF" : CompanyTheme.textSecondary
                                font.pointSize: 7
                                font.bold: true
                            }
                        }

                        // Command Name & Coordinates
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: itemDelegate.object ? itemDelegate.object.commandName : qsTr("Waypoint")
                                color: itemDelegate.isSelected ? CompanyTheme.djiCyan : CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontTiny
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
                                font.pointSize: 6
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
                            font.pointSize: CompanyTheme.fontTiny
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

            // 8. Drawer Bottom Action Buttons (Clear & Upload)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    contentItem: Text {
                        text: qsTr("Clear All")
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
                        if (root._itemCount > 0) planMasterController.removeAll()
                    }
                }

                Button {
                    id: djiUploadBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    enabled: root._hasVehicle && !root._syncInProgress && root._itemCount > 0 && !root._isMissionActive
                    contentItem: Text {
                        text: qsTr("Upload Mission")
                        color: djiUploadBtn.enabled ? "#FFFFFF" : CompanyTheme.textMuted
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    background: Rectangle {
                        radius: CompanyTheme.radiusSm
                        color: {
                            if (!djiUploadBtn.enabled) return CompanyTheme.bgInput
                            return djiUploadBtn.hovered ? CompanyTheme.djiBlueHover : CompanyTheme.djiBlue
                        }
                        border.color: djiUploadBtn.enabled ? CompanyTheme.djiCyan : "transparent"
                        border.width: 1
                    }
                    onClicked: root.initiateMissionUpload()
                }
            }
        }
    }

    // ====================================================================
    // 4. FLOATING BOTTOM MISSION EXECUTION & PROGRESS BAR (DJI Glass HUD)
    // ====================================================================
    Rectangle {
        id: bottomExecutionStrip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: CompanyTheme.spacingSm
        z: 10
        height: 56
        radius: CompanyTheme.radiusMd
        color: CompanyTheme.bgGlass
        border.color: CompanyTheme.borderGlass
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
                                    if (root._hasVehicle && root._activeVehicle && root._flightMode === root._activeVehicle.pauseFlightMode) {
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
                        enabled: root._hasVehicle && CompanyTelemetry.communicationValid && root._hasMissionItems && !root._inMissionMode
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
                            if (root._hasVehicle && CompanyTelemetry.communicationValid && root._hasMissionItems && !root._inMissionMode) {
                                root.flightActionRequested("START_MISSION")
                            }
                        }
                    }

                    // Pause / Hold Button
                    Button {
                        id: pauseBtn
                        Layout.preferredHeight: 34
                        implicitWidth: 80
                        enabled: root._hasVehicle && CompanyTelemetry.communicationValid && root._isArmed
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
                            if (root._hasVehicle && CompanyTelemetry.communicationValid && root._isArmed) {
                                root.flightActionRequested("HOLD")
                            }
                        }
                    }

                    // Return To Launch (RTL) Button
                    Button {
                        id: rtlMissionBtn
                        Layout.preferredHeight: 34
                        implicitWidth: 70
                        enabled: root._hasVehicle && CompanyTelemetry.communicationValid && root._isArmed
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
                            if (root._hasVehicle && CompanyTelemetry.communicationValid && root._isArmed) {
                                root.flightActionRequested("RTL")
                            }
                        }
                    }
                }
            }
        }
    }
