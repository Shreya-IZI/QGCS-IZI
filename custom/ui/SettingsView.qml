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

    property string activeSubTab: "TELEMETRY" // "TELEMETRY", "NETWORK", "OFFLINE_MAPS"
    readonly property bool _isNarrow: width < 900 || ScreenTools.isMobile

    NumberAnimation {
        id: scrollAnim
        target: tabFlickable
        property: "contentX"
        duration: 200
        easing.type: Easing.OutQuad
    }

    function ensureTabVisible(item) {
        if (!item || typeof tabFlickable === "undefined" || !tabFlickable) return
        var itemLeft = item.x
        var itemRight = item.x + item.width
        var maxContentX = Math.max(0, tabFlickable.contentWidth - tabFlickable.width)
        var targetX = tabFlickable.contentX

        if (itemLeft < tabFlickable.contentX) {
            targetX = Math.max(0, itemLeft - 8)
        } else if (itemRight > tabFlickable.contentX + tabFlickable.width) {
            targetX = Math.min(maxContentX, itemRight - tabFlickable.width + 8)
        }

        if (targetX !== tabFlickable.contentX) {
            scrollAnim.stop()
            scrollAnim.to = targetX
            scrollAnim.start()
        }
    }

    onActiveSubTabChanged: {
        Qt.callLater(function() {
            if (activeSubTab === "TELEMETRY") ensureTabVisible(subTabLoggingBtn)
            else if (activeSubTab === "NETWORK") ensureTabVisible(subTabNetworkBtn)
            else if (activeSubTab === "OFFLINE_MAPS") ensureTabVisible(subTabOfflineMapsBtn)
        })
    }

    readonly property var _mapEngineManager: QGroundControl.mapEngineManager
    // ImportAction enum values: ActionNone = 0, ActionImporting = 1, ActionExporting = 2, ActionDone = 3
    readonly property bool _currentlyImportOrExporting: _mapEngineManager ? (_mapEngineManager.importAction === 1 || _mapEngineManager.importAction === 2) : false

    readonly property bool _hasVehicle:    CompanyTelemetry.hasVehicle
    readonly property bool _logging: {
        if (typeof CompanyCsvLogger !== "undefined" && CompanyCsvLogger) return CompanyCsvLogger.loggingActive
        if (typeof companyCsvLogger !== "undefined" && companyCsvLogger) return companyCsvLogger.loggingActive
        return false
    }
    readonly property int  _rateHz: {
        if (typeof CompanyCsvLogger !== "undefined" && CompanyCsvLogger) return CompanyCsvLogger.loggingRateHz
        if (typeof companyCsvLogger !== "undefined" && companyCsvLogger) return companyCsvLogger.loggingRateHz
        return 1
    }
    readonly property int  _sampleCount:   CompanyCsvLogger ? CompanyCsvLogger.samplesLogged : 0
    readonly property int  _eventCount:    CompanyCsvLogger ? CompanyCsvLogger.eventsLogged : 0
    readonly property string _fileName:    CompanyCsvLogger ? CompanyCsvLogger.currentLogFileName : ""
    readonly property string _savePath:    CompanyCsvLogger ? CompanyCsvLogger.logSavePath : ""

    // Native QGC Settings References
    readonly property var _autoConnectSettings: QGroundControl.settingsManager ? QGroundControl.settingsManager.autoConnectSettings : null
    readonly property var _mavlinkSettings:     QGroundControl.settingsManager ? QGroundControl.settingsManager.mavlinkSettings : null
    readonly property var _videoSettings:       QGroundControl.settingsManager ? QGroundControl.settingsManager.videoSettings : null
    readonly property var _appSettings:         QGroundControl.settingsManager ? QGroundControl.settingsManager.appSettings : null
    readonly property var _netSettings:         (typeof CompanyNetworkSettings !== "undefined" && CompanyNetworkSettings) ? CompanyNetworkSettings : (typeof companyNetworkSettings !== "undefined" ? companyNetworkSettings : null)
    readonly property var _dataOutput:          (typeof CompanyDataOutput !== "undefined" && CompanyDataOutput) ? CompanyDataOutput : (typeof companyDataOutput !== "undefined" ? companyDataOutput : null)

    Rectangle {
        anchors.fill: parent
        color: CompanyTheme.bgApp
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: CompanyTheme.spacingLg
        spacing: CompanyTheme.spacingMd

        // ================================================================
        // 1. TOP HEADER (FIXED AT TOP)
        // ================================================================
        RowLayout {
            Layout.fillWidth: true
            spacing: CompanyTheme.spacingMd

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                Text {
                    text: qsTr("SYSTEM SETTINGS & TELEMETRY")
                    color: CompanyTheme.textPrimary
                    font.pointSize: root._isNarrow ? CompanyTheme.fontH2 : CompanyTheme.fontH1
                    font.bold: true
                    font.letterSpacing: 0.6
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: qsTr("Configure telemetry data logging, vehicle comms, dual video streams and tactical data links")
                    color: CompanyTheme.textSecondary
                    font.pointSize: CompanyTheme.fontBody
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    visible: !root._isNarrow
                }
            }

            // High-Visibility Recording / Offline Status Badge
            Rectangle {
                Layout.preferredHeight: 30
                radius: CompanyTheme.radiusSm
                color: CompanyTheme.bgCard
                border.color: CompanyTheme.borderCard
                border.width: 1
                implicitWidth: statusBadgeLayout.implicitWidth + CompanyTheme.spacingMd * 2

                RowLayout {
                    id: statusBadgeLayout
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: {
                            if (root.activeSubTab === "OFFLINE_MAPS") {
                                return root._currentlyImportOrExporting ? CompanyTheme.warning : CompanyTheme.success
                            }
                            return root._logging ? CompanyTheme.success : CompanyTheme.textMuted
                        }
                    }

                    Text {
                        text: {
                            if (root.activeSubTab === "OFFLINE_MAPS") {
                                if (root._currentlyImportOrExporting) return qsTr("IMPORTING TILES (%1%)").arg(root._mapEngineManager ? root._mapEngineManager.actionProgress : 0)
                                return qsTr("OFFLINE CACHE READY")
                            }
                            return root._logging ? qsTr("RECORDING (%1 HZ)").arg(root._rateHz) : qsTr("LOGGING STOPPED")
                        }
                        color: {
                            if (root.activeSubTab === "OFFLINE_MAPS") {
                                return root._currentlyImportOrExporting ? CompanyTheme.warning : CompanyTheme.success
                            }
                            return root._logging ? CompanyTheme.success : CompanyTheme.textMuted
                        }
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        font.letterSpacing: 0.4
                    }
                }
            }
        }

        // ================================================================
        // 1B. HORIZONTAL SUB-TAB NAVIGATION STRIP (INDEPENDENTLY SCROLLABLE)
        // ================================================================
        Flickable {
            id: tabFlickable
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            implicitHeight: 34
            contentWidth: Math.max(width, settingsTabsRow.implicitWidth + 8)
            contentHeight: height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick
            clip: true

            Row {
                id: settingsTabsRow
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: 8

                Rectangle {
                    id: subTabLoggingBtn
                    implicitWidth: Math.max(120, subTabLoggingRow.implicitWidth + 24)
                    implicitHeight: 30
                    radius: CompanyTheme.radiusSm
                    color: root.activeSubTab === "TELEMETRY" ? CompanyTheme.primary : CompanyTheme.bgCardSecondary
                    border.color: root.activeSubTab === "TELEMETRY" ? CompanyTheme.primary : CompanyTheme.borderCard
                    border.width: 1

                    RowLayout {
                        id: subTabLoggingRow
                        anchors.centerIn: parent
                        spacing: 6
                        IconVector {
                            name: "logs"
                            size: 14
                            color: root.activeSubTab === "TELEMETRY" ? CompanyTheme.bgApp : CompanyTheme.textSecondary
                        }
                        Text {
                            text: qsTr("DATA LOGGING")
                            color: root.activeSubTab === "TELEMETRY" ? CompanyTheme.bgApp : CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: root.activeSubTab === "TELEMETRY"
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeSubTab = "TELEMETRY"
                    }
                }

                Rectangle {
                    id: subTabNetworkBtn
                    implicitWidth: Math.max(140, subTabNetworkRow.implicitWidth + 24)
                    implicitHeight: 30
                    radius: CompanyTheme.radiusSm
                    color: root.activeSubTab === "NETWORK" ? CompanyTheme.primary : CompanyTheme.bgCardSecondary
                    border.color: root.activeSubTab === "NETWORK" ? CompanyTheme.primary : CompanyTheme.borderCard
                    border.width: 1

                    RowLayout {
                        id: subTabNetworkRow
                        anchors.centerIn: parent
                        spacing: 6
                        IconVector {
                            name: "radio"
                            size: 14
                            color: root.activeSubTab === "NETWORK" ? CompanyTheme.bgApp : CompanyTheme.textSecondary
                        }
                        Text {
                            text: qsTr("NETWORK & LINKS")
                            color: root.activeSubTab === "NETWORK" ? CompanyTheme.bgApp : CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: root.activeSubTab === "NETWORK"
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeSubTab = "NETWORK"
                    }
                }

                Rectangle {
                    id: subTabOfflineMapsBtn
                    implicitWidth: Math.max(120, subTabOfflineMapsRow.implicitWidth + 24)
                    implicitHeight: 30
                    radius: CompanyTheme.radiusSm
                    color: root.activeSubTab === "OFFLINE_MAPS" ? CompanyTheme.primary : CompanyTheme.bgCardSecondary
                    border.color: root.activeSubTab === "OFFLINE_MAPS" ? CompanyTheme.primary : CompanyTheme.borderCard
                    border.width: 1

                    RowLayout {
                        id: subTabOfflineMapsRow
                        anchors.centerIn: parent
                        spacing: 6
                        IconVector {
                            name: "map"
                            size: 14
                            color: root.activeSubTab === "OFFLINE_MAPS" ? CompanyTheme.bgApp : CompanyTheme.textSecondary
                        }
                        Text {
                            text: qsTr("OFFLINE MAPS")
                            color: root.activeSubTab === "OFFLINE_MAPS" ? CompanyTheme.bgApp : CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: root.activeSubTab === "OFFLINE_MAPS"
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.activeSubTab = "OFFLINE_MAPS"
                            if (root._mapEngineManager) {
                                root._mapEngineManager.loadTileSets()
                            }
                        }
                    }
                }
            }

            ScrollBar.horizontal: ScrollBar {
                id: hScrollBar
                policy: (tabFlickable.contentWidth > tabFlickable.width) ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
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
                    var maxContentX = Math.max(0, tabFlickable.contentWidth - tabFlickable.width)
                    tabFlickable.contentX = Math.max(0, Math.min(maxContentX, tabFlickable.contentX - delta))
                }
            }
        }

        // Subtle separator below tab strip
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: CompanyTheme.borderCard
        }

            // ================================================================
            // 2. SCROLLABLE CONTENT BODY (TELEMETRY & NETWORK SUB-TABS)
            // ================================================================
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: CompanyTheme.spacingMd

                    // ================================================================
                    // SUB-TAB A: TELEMETRY & LOGGING (PHASE 7B ARCHITECTURE)
                    // ================================================================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: CompanyTheme.spacingMd
                visible: root.activeSubTab === "TELEMETRY"

                // 2. MAIN CARD: TELEMETRY CSV LOGGING CONFIGURATION
                Rectangle {
                    Layout.fillWidth: true
                    radius: CompanyTheme.radiusMd
                    color: CompanyTheme.bgCard
                    border.color: CompanyTheme.borderCard
                    border.width: 1
                    implicitHeight: csvCardCol.implicitHeight + CompanyTheme.spacingLg * 2

                    ColumnLayout {
                        id: csvCardCol
                        anchors.fill: parent
                        anchors.margins: CompanyTheme.spacingLg
                        spacing: CompanyTheme.spacingMd

                        // Card Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingSm

                            IconVector {
                                name: "logs"
                                size: 18
                                color: CompanyTheme.primary
                            }

                            Text {
                                text: qsTr("TELEMETRY CSV DATA LOGGING")
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontH2
                                font.bold: true
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: CompanyTheme.borderSubtle
                        }

                        // Row A: Master ON / OFF Toggle
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingMd

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true

                                Text {
                                    text: qsTr("CSV Telemetry Recording")
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: CompanyTheme.fontBody
                                    font.bold: true
                                }

                                Text {
                                    text: qsTr("Record continuous flight telemetry, raw sensors (barometer, magnetometer, LRF) and payload FOV to CSV")
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: CompanyTheme.fontSmall
                                }
                            }

                            // Toggle Button
                            CompanyButton {
                                id: toggleLoggingBtn
                                text: root._logging ? qsTr("LOGGING: ON") : qsTr("LOGGING: OFF")
                                isOutline: !root._logging
                                onClicked: {
                                    if (typeof CompanyCsvLogger !== "undefined" && CompanyCsvLogger) {
                                        CompanyCsvLogger.setLoggingActive(!root._logging)
                                    } else if (typeof companyCsvLogger !== "undefined" && companyCsvLogger) {
                                        companyCsvLogger.setLoggingActive(!root._logging)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: CompanyTheme.borderSubtle
                        }

                        // Row B: Logging Rate Selector
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingMd

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true

                                Text {
                                    text: qsTr("Telemetry Sample Rate")
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: CompanyTheme.fontBody
                                    font.bold: true
                                }

                                Text {
                                    text: qsTr("Interval between periodic telemetry rows written to CSV (1 Hz recommended for standard flights)")
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: CompanyTheme.fontSmall
                                }
                            }

                            // Rate Selector Segmented Buttons
                            RowLayout {
                                spacing: 4

                                Repeater {
                                    model: [1, 2, 5, 10]
                                    delegate: Rectangle {
                                        id: rateBtn
                                        required property int modelData

                                        implicitWidth: 54
                                        implicitHeight: 32
                                        radius: CompanyTheme.radiusSm
                                        color: (root._rateHz === rateBtn.modelData) ? CompanyTheme.primary : (rateMouseArea.containsMouse ? CompanyTheme.bgCardHover : CompanyTheme.bgCardSecondary)
                                        border.color: (root._rateHz === rateBtn.modelData) ? CompanyTheme.primary : CompanyTheme.borderCard
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: rateBtn.modelData + " Hz"
                                            color: (root._rateHz === rateBtn.modelData) ? CompanyTheme.bgApp : CompanyTheme.textPrimary
                                            font.pointSize: CompanyTheme.fontSmall
                                            font.bold: root._rateHz === rateBtn.modelData
                                            font.family: CompanyTheme.fontMono
                                        }

                                        MouseArea {
                                            id: rateMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (typeof CompanyCsvLogger !== "undefined" && CompanyCsvLogger) {
                                                    CompanyCsvLogger.setLoggingRateHz(rateBtn.modelData)
                                                } else if (typeof companyCsvLogger !== "undefined" && companyCsvLogger) {
                                                    companyCsvLogger.setLoggingRateHz(rateBtn.modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: CompanyTheme.borderSubtle
                        }

                        // Row C: Active File & Statistics
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            columnSpacing: CompanyTheme.spacingMd
                            rowSpacing: CompanyTheme.spacingSm

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true

                                Text {
                                    text: qsTr("CURRENT ACTIVE LOG FILE")
                                    color: CompanyTheme.textMuted
                                    font.pointSize: CompanyTheme.fontTiny
                                    font.bold: true
                                    font.letterSpacing: 0.6
                                }

                                Text {
                                    text: root._fileName !== "" ? root._fileName : qsTr("No active file (logging idle)")
                                    color: root._fileName !== "" ? CompanyTheme.primary : CompanyTheme.textSecondary
                                    font.pointSize: CompanyTheme.fontSmall
                                    font.family: CompanyTheme.fontMono
                                    font.bold: root._fileName !== ""
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.preferredWidth: 140

                                Text {
                                    text: qsTr("SAMPLES LOGGED")
                                    color: CompanyTheme.textMuted
                                    font.pointSize: CompanyTheme.fontTiny
                                    font.bold: true
                                    font.letterSpacing: 0.6
                                }

                                Text {
                                    text: qsTr("%1 rows").arg(root._sampleCount)
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: CompanyTheme.fontSmall
                                    font.family: CompanyTheme.fontMono
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.preferredWidth: 160

                                Text {
                                    text: qsTr("EVENT RECORDS")
                                    color: CompanyTheme.textMuted
                                    font.pointSize: CompanyTheme.fontTiny
                                    font.bold: true
                                    font.letterSpacing: 0.6
                                }

                                Text {
                                    text: qsTr("%1 events (snapshots / videos)").arg(root._eventCount)
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: CompanyTheme.fontSmall
                                    font.family: CompanyTheme.fontMono
                                    font.bold: true
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: CompanyTheme.borderSubtle
                        }

                        // Row D: Storage Directory & Open Button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingMd

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true

                                Text {
                                    text: qsTr("TELEMETRY STORAGE DIRECTORY")
                                    color: CompanyTheme.textMuted
                                    font.pointSize: CompanyTheme.fontTiny
                                    font.bold: true
                                    font.letterSpacing: 0.6
                                }

                                Text {
                                    text: root._savePath !== "" ? root._savePath : qsTr("Standard IZI GCS / Telemetry")
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: CompanyTheme.fontSmall
                                    font.family: CompanyTheme.fontMono
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                            }

                            CompanyButton {
                                text: qsTr("Open Log Folder")
                                isOutline: true
                                onClicked: {
                                    if (CompanyCsvLogger) {
                                        CompanyCsvLogger.openLogFolder()
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. LIVE RAW SENSORS STREAM CARD
                Rectangle {
                    Layout.fillWidth: true
                    radius: CompanyTheme.radiusMd
                    color: CompanyTheme.bgCard
                    border.color: CompanyTheme.borderCard
                    border.width: 1
                    implicitHeight: sensorsCardCol.implicitHeight + CompanyTheme.spacingLg * 2

                    ColumnLayout {
                        id: sensorsCardCol
                        anchors.fill: parent
                        anchors.margins: CompanyTheme.spacingLg
                        spacing: CompanyTheme.spacingMd

                        // Header
                        Text {
                            text: qsTr("LIVE SENSOR STREAMS (CHANDIPUR REQUIREMENT MAPPING)")
                            color: CompanyTheme.textPrimary
                            font.pointSize: CompanyTheme.fontH2
                            font.bold: true
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: CompanyTheme.borderSubtle
                        }

                        // Sensor Matrix Grid (4 columns)
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 4
                            columnSpacing: CompanyTheme.spacingMd
                            rowSpacing: CompanyTheme.spacingMd

                            // Tile 1: GPS Navigation
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: CompanyTheme.radiusSm
                                color: CompanyTheme.bgCardSecondary
                                border.color: CompanyTheme.borderCard
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: CompanyTheme.spacingSm
                                    spacing: 2

                                    Text {
                                        text: qsTr("GPS NAVIGATION")
                                        color: CompanyTheme.textMuted
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.bold: true
                                    }
                                    Text {
                                        text: CompanyTelemetry.gpsFixValid ?
                                              (CompanyTelemetry.latitude.toFixed(4) + "°, " + CompanyTelemetry.longitude.toFixed(4) + "°") :
                                              qsTr("No GPS Fix")
                                        color: CompanyTelemetry.gpsFixValid ? CompanyTheme.success : CompanyTheme.warning
                                        font.pointSize: CompanyTheme.fontSmall
                                        font.bold: true
                                        font.family: CompanyTheme.fontMono
                                    }
                                    Text {
                                        text: qsTr("Sats: %1 • HDOP: %2").arg(CompanyTelemetry.satelliteCount).arg(CompanyTelemetry.hdopStr)
                                        color: CompanyTheme.textSecondary
                                        font.pointSize: 8
                                    }
                                }
                            }

                            // Tile 2: Autopilot Attitude
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: CompanyTheme.radiusSm
                                color: CompanyTheme.bgCardSecondary
                                border.color: CompanyTheme.borderCard
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: CompanyTheme.spacingSm
                                    spacing: 2

                                    Text {
                                        text: qsTr("AUTOPILOT ATTITUDE")
                                        color: CompanyTheme.textMuted
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.bold: true
                                    }
                                    Text {
                                        text: qsTr("P: %1°  R: %2°").arg(CompanyTelemetry.pitch.toFixed(1)).arg(CompanyTelemetry.roll.toFixed(1))
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontSmall
                                        font.bold: true
                                        font.family: CompanyTheme.fontMono
                                    }
                                    Text {
                                        text: qsTr("Heading: %1°").arg(CompanyTelemetry.heading.toFixed(0))
                                        color: CompanyTheme.textSecondary
                                        font.pointSize: 8
                                    }
                                }
                            }

                            // Tile 3: Gimbal Attitude
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: CompanyTheme.radiusSm
                                color: CompanyTheme.bgCardSecondary
                                border.color: CompanyTheme.borderCard
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: CompanyTheme.spacingSm
                                    spacing: 2

                                    Text {
                                        text: qsTr("GIMBAL ATTITUDE")
                                        color: CompanyTheme.textMuted
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.bold: true
                                    }
                                    Text {
                                        text: qsTr("P: %1  Y: %2").arg(CompanyTelemetry.gimbalPitchStr).arg(CompanyTelemetry.gimbalYawStr)
                                        color: CompanyTelemetry.gimbalTelemetryAvailable ? CompanyTheme.info : CompanyTheme.textSecondary
                                        font.pointSize: CompanyTheme.fontSmall
                                        font.bold: true
                                        font.family: CompanyTheme.fontMono
                                    }
                                    Text {
                                        text: qsTr("Roll: %1").arg(CompanyTelemetry.gimbalRollStr)
                                        color: CompanyTheme.textSecondary
                                        font.pointSize: 8
                                    }
                                }
                            }

                            // Tile 4: LRF Distance
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: CompanyTheme.radiusSm
                                color: CompanyTheme.bgCardSecondary
                                border.color: CompanyTheme.borderCard
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: CompanyTheme.spacingSm
                                    spacing: 2

                                    Text {
                                        text: qsTr("LRF DISTANCE")
                                        color: CompanyTheme.textMuted
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.bold: true
                                    }
                                    Text {
                                        text: (CompanyCsvLogger && CompanyCsvLogger.hasLrfDistance) ?
                                              qsTr("%1 m").arg(CompanyCsvLogger.lastLrfDistance.toFixed(2)) :
                                              qsTr("N/A")
                                        color: (CompanyCsvLogger && CompanyCsvLogger.hasLrfDistance) ? CompanyTheme.success : CompanyTheme.textSecondary
                                        font.pointSize: CompanyTheme.fontSmall
                                        font.bold: true
                                        font.family: CompanyTheme.fontMono
                                    }
                                    Text {
                                        text: qsTr("MAVLink #173 Rangefinder")
                                        color: CompanyTheme.textSecondary
                                        font.pointSize: 8
                                    }
                                }
                            }

                            // Tile 5: Barometer Pressure
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: CompanyTheme.radiusSm
                                color: CompanyTheme.bgCardSecondary
                                border.color: CompanyTheme.borderCard
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: CompanyTheme.spacingSm
                                    spacing: 2

                                    Text {
                                        text: qsTr("BAROMETER PRESSURE")
                                        color: CompanyTheme.textMuted
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.bold: true
                                    }
                                    Text {
                                        text: (CompanyCsvLogger && CompanyCsvLogger.hasBaroPressure) ?
                                              qsTr("%1 hPa").arg(CompanyCsvLogger.lastBaroPressure.toFixed(1)) :
                                              qsTr("N/A")
                                        color: (CompanyCsvLogger && CompanyCsvLogger.hasBaroPressure) ? CompanyTheme.success : CompanyTheme.textSecondary
                                        font.pointSize: CompanyTheme.fontSmall
                                        font.bold: true
                                        font.family: CompanyTheme.fontMono
                                    }
                                    Text {
                                        text: qsTr("Altitude: %1 m").arg((CompanyTelemetry.altitudeAmsl || 0).toFixed(1))
                                        color: CompanyTheme.textSecondary
                                        font.pointSize: 8
                                    }
                                }
                            }

                            // Tile 6: Magnetometer Field
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: CompanyTheme.radiusSm
                                color: CompanyTheme.bgCardSecondary
                                border.color: CompanyTheme.borderCard
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: CompanyTheme.spacingSm
                                    spacing: 2

                                    Text {
                                        text: qsTr("MAGNETOMETER (mG)")
                                        color: CompanyTheme.textMuted
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.bold: true
                                    }
                                    Text {
                                        text: (CompanyCsvLogger && CompanyCsvLogger.hasMag) ?
                                              qsTr("%1, %2, %3").arg(CompanyCsvLogger.lastMagX.toFixed(0)).arg(CompanyCsvLogger.lastMagY.toFixed(0)).arg(CompanyCsvLogger.lastMagZ.toFixed(0)) :
                                              qsTr("N/A")
                                        color: (CompanyCsvLogger && CompanyCsvLogger.hasMag) ? CompanyTheme.success : CompanyTheme.textSecondary
                                        font.pointSize: CompanyTheme.fontSmall
                                        font.bold: true
                                        font.family: CompanyTheme.fontMono
                                    }
                                    Text {
                                        text: qsTr("Raw IMU X, Y, Z Field")
                                        color: CompanyTheme.textSecondary
                                        font.pointSize: 8
                                    }
                                }
                            }

                            // Tile 7: Camera Optical FOV
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: CompanyTheme.radiusSm
                                color: CompanyTheme.bgCardSecondary
                                border.color: CompanyTheme.borderCard
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: CompanyTheme.spacingSm
                                    spacing: 2

                                    Text {
                                        text: qsTr("CAMERA FOV")
                                        color: CompanyTheme.textMuted
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.bold: true
                                    }
                                    Text {
                                        text: CompanyTelemetry.rgbHfovStr !== "--" ? CompanyTelemetry.rgbHfovStr : qsTr("N/A")
                                        color: CompanyTelemetry.rgbHfovStr !== "--" ? CompanyTheme.info : CompanyTheme.textSecondary
                                        font.pointSize: CompanyTheme.fontSmall
                                        font.bold: true
                                        font.family: CompanyTheme.fontMono
                                    }
                                    Text {
                                        text: qsTr("Thermal FOV: %1").arg(CompanyTelemetry.thermalHfovStr)
                                        color: CompanyTheme.textSecondary
                                        font.pointSize: 8
                                    }
                                }
                            }

                            // Tile 8: Snapshot Correlation Log
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: CompanyTheme.radiusSm
                                color: CompanyTheme.bgCardSecondary
                                border.color: CompanyTheme.borderCard
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: CompanyTheme.spacingSm
                                    spacing: 2

                                    Text {
                                        text: qsTr("SNAPSHOT EVENT LOG")
                                        color: CompanyTheme.textMuted
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.bold: true
                                    }
                                    Text {
                                        text: qsTr("snapshots_metadata.csv")
                                        color: CompanyTheme.primary
                                        font.pointSize: CompanyTheme.fontSmall
                                        font.bold: true
                                        font.family: CompanyTheme.fontMono
                                    }
                                    Text {
                                        text: qsTr("Auto-correlated on shutter")
                                        color: CompanyTheme.textSecondary
                                        font.pointSize: 8
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ================================================================
            // SUB-TAB B: NETWORK & COMMUNICATIONS CONFIGURATION (PHASE 7C)
            // ================================================================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: CompanyTheme.spacingMd
                visible: root.activeSubTab === "NETWORK"

                // ------------------------------------------------------------
                // 1. VEHICLE / MAVLINK LINK CONFIGURATION
                // ------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    radius: CompanyTheme.radiusMd
                    color: CompanyTheme.bgCard
                    border.color: CompanyTheme.borderCard
                    border.width: 1
                    implicitHeight: mavlinkCardCol.implicitHeight + CompanyTheme.spacingLg * 2

                    ColumnLayout {
                        id: mavlinkCardCol
                        anchors.fill: parent
                        anchors.margins: CompanyTheme.spacingLg
                        spacing: CompanyTheme.spacingMd

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingSm
                            IconVector { name: "radio"; size: 18; color: CompanyTheme.primary }
                            Text {
                                text: qsTr("VEHICLE / MAVLINK LINK (ARDUPILOT / PX4)")
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontH2
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            StatusBadge {
                                text: root._hasVehicle ? qsTr("CONNECTED") : qsTr("DISCONNECTED")
                                badgeColor: root._hasVehicle ? CompanyTheme.success : CompanyTheme.warning
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            columnSpacing: CompanyTheme.spacingMd
                            rowSpacing: CompanyTheme.spacingSm

                            // Inbound UDP Listen Port
                            ColumnLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Text { text: qsTr("Inbound UDP Listen Port"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: CompanyTheme.borderCard
                                    border.width: 1
                                    TextInput {
                                        id: udpListenPortInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.family: CompanyTheme.fontMono
                                        selectByMouse: true
                                        text: root._autoConnectSettings ? root._autoConnectSettings.udpListenPort.rawValue : "14550"
                                        onEditingFinished: {
                                            var p = parseInt(text)
                                            if (p >= 1024 && p <= 65535 && root._autoConnectSettings) {
                                                root._autoConnectSettings.udpListenPort.rawValue = p
                                            }
                                        }
                                    }
                                }
                            }

                            // Outbound Target Vehicle IP
                            ColumnLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Text { text: qsTr("Target Vehicle IP (Unicast)"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: (udpTargetIpInput.text === "" || (root._netSettings && root._netSettings.isValidIPv4(udpTargetIpInput.text))) ? CompanyTheme.borderCard : CompanyTheme.danger
                                    border.width: 1
                                    TextInput {
                                        id: udpTargetIpInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.family: CompanyTheme.fontMono
                                        selectByMouse: true
                                        text: root._autoConnectSettings ? root._autoConnectSettings.udpTargetHostIP.rawValue : ""
                                        onEditingFinished: {
                                            if (root._autoConnectSettings) {
                                                root._autoConnectSettings.udpTargetHostIP.rawValue = text
                                            }
                                        }
                                    }
                                }
                            }

                            // Outbound Target Vehicle Port
                            ColumnLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Text { text: qsTr("Target Vehicle Port"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: CompanyTheme.borderCard
                                    border.width: 1
                                    TextInput {
                                        id: udpTargetPortInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.family: CompanyTheme.fontMono
                                        selectByMouse: true
                                        text: root._autoConnectSettings ? root._autoConnectSettings.udpTargetHostPort.rawValue : "14550"
                                        onEditingFinished: {
                                            var p = parseInt(text)
                                            if (p >= 1024 && p <= 65535 && root._autoConnectSettings) {
                                                root._autoConnectSettings.udpTargetHostPort.rawValue = p
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // MAVLink Options Row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingMd

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                Text { text: qsTr("UDP Auto-Connect Service"); color: CompanyTheme.textPrimary; font.bold: true; font.pointSize: CompanyTheme.fontSmall }
                                Text { text: qsTr("Automatically open and bind UDP listen port upon application startup"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny }
                            }

                            CompanyButton {
                                id: autoConnectBtn
                                text: (root._autoConnectSettings && root._autoConnectSettings.autoConnectUDP.rawValue) ? qsTr("UDP AUTOCONNECT: ON") : qsTr("UDP AUTOCONNECT: OFF")
                                isOutline: !(root._autoConnectSettings && root._autoConnectSettings.autoConnectUDP.rawValue)
                                onClicked: {
                                    if (root._autoConnectSettings) {
                                        root._autoConnectSettings.autoConnectUDP.rawValue = !root._autoConnectSettings.autoConnectUDP.rawValue
                                    }
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------------------------
                // 1B. TCP TELEMETRY LINK (HOST & PORT)
                // ------------------------------------------------------------
                Rectangle {
                    id: tcpLinkCard
                    Layout.fillWidth: true
                    radius: CompanyTheme.radiusMd
                    color: CompanyTheme.bgCard
                    border.color: CompanyTheme.borderCard
                    border.width: 1
                    implicitHeight: tcpCardCol.implicitHeight + CompanyTheme.spacingLg * 2

                    function getTcpConfig() {
                        if (!QGroundControl.linkManager || !QGroundControl.linkManager.linkConfigurations) return null
                        for (var i = 0; i < QGroundControl.linkManager.linkConfigurations.count; i++) {
                            var cfg = QGroundControl.linkManager.linkConfigurations.get(i)
                            if (cfg && cfg.type === 2) { // TypeTcp
                                return cfg
                            }
                        }
                        return null
                    }

                    property var _tcpConfig: getTcpConfig()
                    readonly property bool _isTcpActive: _tcpConfig ? _tcpConfig.linkActive : false

                    ColumnLayout {
                        id: tcpCardCol
                        anchors.fill: parent
                        anchors.margins: CompanyTheme.spacingLg
                        spacing: CompanyTheme.spacingMd

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingSm
                            IconVector { name: "radio"; size: 18; color: CompanyTheme.primary }
                            Text {
                                text: qsTr("TCP TELEMETRY LINK (HOST & PORT)")
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontH2
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            StatusBadge {
                                text: tcpLinkCard._isTcpActive ? qsTr("CONNECTED") : qsTr("DISCONNECTED")
                                badgeColor: tcpLinkCard._isTcpActive ? CompanyTheme.success : CompanyTheme.warning
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: CompanyTheme.spacingMd
                            rowSpacing: CompanyTheme.spacingSm

                            // TCP Host IP
                            ColumnLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Text { text: qsTr("Target TCP Host IP"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: CompanyTheme.borderCard
                                    border.width: 1
                                    TextInput {
                                        id: tcpHostInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.family: CompanyTheme.fontMono
                                        selectByMouse: true
                                        text: tcpLinkCard._tcpConfig ? tcpLinkCard._tcpConfig.host : "192.168.168.11"
                                        onEditingFinished: {
                                            if (tcpLinkCard._tcpConfig) {
                                                tcpLinkCard._tcpConfig.host = text.trim()
                                            }
                                        }
                                    }
                                }
                            }

                            // TCP Port
                            ColumnLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Text { text: qsTr("Target TCP Port"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: CompanyTheme.borderCard
                                    border.width: 1
                                    TextInput {
                                        id: tcpPortInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.family: CompanyTheme.fontMono
                                        selectByMouse: true
                                        text: tcpLinkCard._tcpConfig ? String(tcpLinkCard._tcpConfig.port) : "20002"
                                        onEditingFinished: {
                                            var p = parseInt(text)
                                            if (p >= 1 && p <= 65535 && tcpLinkCard._tcpConfig) {
                                                tcpLinkCard._tcpConfig.port = p
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // TCP Action Controls
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingMd

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                Text { text: qsTr("Direct TCP Telemetry Client"); color: CompanyTheme.textPrimary; font.bold: true; font.pointSize: CompanyTheme.fontSmall }
                                Text { text: qsTr("Connect directly to an onboard or ground station TCP telemetry server (e.g. 192.168.168.11:20002)"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny }
                            }

                            CompanyButton {
                                id: tcpConnectBtn
                                text: tcpLinkCard._isTcpActive ? qsTr("DISCONNECT TCP") : qsTr("CONNECT TCP")
                                isOutline: !tcpLinkCard._isTcpActive
                                onClicked: {
                                    var cfg = tcpLinkCard._tcpConfig
                                    if (!cfg) {
                                        cfg = QGroundControl.linkManager.createConfiguration(2, "GroundStation_TCP")
                                        if (cfg) {
                                            cfg.host = tcpHostInput.text.trim()
                                            cfg.port = parseInt(tcpPortInput.text) || 20002
                                            cfg.autoConnect = false
                                            QGroundControl.linkManager.endCreateConfiguration(cfg)
                                            tcpLinkCard._tcpConfig = cfg
                                        }
                                    } else {
                                        cfg.host = tcpHostInput.text.trim()
                                        cfg.port = parseInt(tcpPortInput.text) || 20002
                                    }
                                    if (cfg) {
                                        if (cfg.linkActive) {
                                            QGroundControl.linkManager.disconnectLinkConfiguration(cfg)
                                        } else {
                                            QGroundControl.linkManager.createConnectedLink(cfg)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------------------------
                // 2. RGB PAYLOAD VIDEO STREAM
                // ------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    radius: CompanyTheme.radiusMd
                    color: CompanyTheme.bgCard
                    border.color: CompanyTheme.borderCard
                    border.width: 1
                    implicitHeight: rgbCardCol.implicitHeight + CompanyTheme.spacingLg * 2

                    ColumnLayout {
                        id: rgbCardCol
                        anchors.fill: parent
                        anchors.margins: CompanyTheme.spacingLg
                        spacing: CompanyTheme.spacingMd

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingSm
                            IconVector { name: "video"; size: 18; color: CompanyTheme.primary }
                            Text {
                                text: qsTr("RGB OPTICAL PAYLOAD STREAM")
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontH2
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            Text {
                                text: QGroundControl.videoManager.decoding ? qsTr("DECODING (%1)").arg(CompanyTelemetry.resolutionStr) : qsTr("STANDBY")
                                color: QGroundControl.videoManager.decoding ? CompanyTheme.success : CompanyTheme.warning
                                font.pointSize: CompanyTheme.fontSmall
                                font.bold: true
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: CompanyTheme.spacingMd
                            rowSpacing: CompanyTheme.spacingSm

                            // RTSP Stream URL
                            ColumnLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Text { text: qsTr("RTSP Stream URL"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: CompanyTheme.borderCard
                                    border.width: 1
                                    TextInput {
                                        id: rgbRtspUrlInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.family: CompanyTheme.fontMono
                                        selectByMouse: true
                                        text: root._videoSettings ? root._videoSettings.rtspUrl.rawValue : "rtsp://127.0.0.1:8554/live"
                                        onEditingFinished: {
                                            if (root._videoSettings) {
                                                root._videoSettings.rtspUrl.rawValue = text
                                            }
                                        }
                                    }
                                }
                            }

                            // UDP Port
                            ColumnLayout {
                                spacing: 4
                                Layout.preferredWidth: 200
                                Text { text: qsTr("UDP Port (H.264 / H.265)"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: CompanyTheme.borderCard
                                    border.width: 1
                                    TextInput {
                                        id: rgbUdpPortInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.family: CompanyTheme.fontMono
                                        selectByMouse: true
                                        text: root._videoSettings ? root._videoSettings.udpUrl.rawValue : "5600"
                                        onEditingFinished: {
                                            if (root._videoSettings) {
                                                root._videoSettings.udpUrl.rawValue = text
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingMd

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                Text { text: qsTr("Video Stream Decode Engine"); color: CompanyTheme.textPrimary; font.bold: true; font.pointSize: CompanyTheme.fontSmall }
                                Text { text: qsTr("Enable GStreamer video pipeline decoding for primary camera viewport"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny }
                            }

                            CompanyButton {
                                text: (root._videoSettings && root._videoSettings.streamEnabled.rawValue) ? qsTr("STREAM: ENABLED") : qsTr("STREAM: DISABLED")
                                isOutline: !(root._videoSettings && root._videoSettings.streamEnabled.rawValue)
                                onClicked: {
                                    if (root._videoSettings) {
                                        root._videoSettings.streamEnabled.rawValue = !root._videoSettings.streamEnabled.rawValue
                                    }
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------------------------
                // 3. THERMAL IR PAYLOAD STREAM
                // ------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    radius: CompanyTheme.radiusMd
                    color: CompanyTheme.bgCard
                    border.color: CompanyTheme.borderCard
                    border.width: 1
                    implicitHeight: thermalCardCol.implicitHeight + CompanyTheme.spacingLg * 2

                    ColumnLayout {
                        id: thermalCardCol
                        anchors.fill: parent
                        anchors.margins: CompanyTheme.spacingLg
                        spacing: CompanyTheme.spacingMd

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingSm
                            IconVector { name: "satellite"; size: 18; color: CompanyTheme.warning }
                            Text {
                                text: qsTr("THERMAL IR PAYLOAD STREAM")
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontH2
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            Text {
                                text: QGroundControl.videoManager.hasThermal ? qsTr("THERMAL ACTIVE") : qsTr("THERMAL STANDBY")
                                color: QGroundControl.videoManager.hasThermal ? CompanyTheme.success : CompanyTheme.warning
                                font.pointSize: CompanyTheme.fontSmall
                                font.bold: true
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: CompanyTheme.spacingMd
                            rowSpacing: CompanyTheme.spacingSm

                            // Thermal Stream Endpoint URL
                            ColumnLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Text { text: qsTr("Thermal Stream Endpoint URL (RTSP / UDP)"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: CompanyTheme.borderCard
                                    border.width: 1
                                    TextInput {
                                        id: thermalUrlInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.family: CompanyTheme.fontMono
                                        selectByMouse: true
                                        text: root._netSettings ? root._netSettings.thermalVideoUrl : "rtsp://127.0.0.1:8554/thermal"
                                        onEditingFinished: {
                                            if (root._netSettings) {
                                                root._netSettings.setThermalVideoUrl(text)
                                            }
                                        }
                                    }
                                }
                            }

                            // Thermal Stream Port
                            ColumnLayout {
                                spacing: 4
                                Layout.preferredWidth: 200
                                Text { text: qsTr("Thermal Stream Port"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: CompanyTheme.borderCard
                                    border.width: 1
                                    TextInput {
                                        id: thermalPortInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.family: CompanyTheme.fontMono
                                        selectByMouse: true
                                        text: root._netSettings ? root._netSettings.thermalVideoPort.toString() : "8554"
                                        onEditingFinished: {
                                            var p = parseInt(text)
                                            if (p >= 1 && p <= 65535 && root._netSettings) {
                                                root._netSettings.setThermalVideoPort(p)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------------------------
                // 4. UDP TELEMETRY OUTPUT (CHANDIPUR FORWARDING)
                // ------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    radius: CompanyTheme.radiusMd
                    color: CompanyTheme.bgCard
                    border.color: CompanyTheme.borderCard
                    border.width: 1
                    implicitHeight: fwdCardCol.implicitHeight + CompanyTheme.spacingLg * 2

                    ColumnLayout {
                        id: fwdCardCol
                        anchors.fill: parent
                        anchors.margins: CompanyTheme.spacingLg
                        spacing: CompanyTheme.spacingMd

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingSm
                            IconVector { name: "flight"; size: 18; color: CompanyTheme.info }
                            Text {
                                text: qsTr("UDP TELEMETRY BROADCAST (CHANDIPUR EVALUATION)")
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontH2
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            Rectangle {
                                implicitWidth: 100
                                implicitHeight: 24
                                radius: CompanyTheme.radiusSm
                                color: (root._netSettings && root._netSettings.udpTelemetryEnabled) ? CompanyTheme.successDim : CompanyTheme.bgCardSecondary
                                border.color: (root._netSettings && root._netSettings.udpTelemetryEnabled) ? CompanyTheme.success : CompanyTheme.borderCard
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: (root._netSettings && root._netSettings.udpTelemetryEnabled) ? qsTr("BROADCASTING") : qsTr("MUTED")
                                    color: (root._netSettings && root._netSettings.udpTelemetryEnabled) ? CompanyTheme.success : CompanyTheme.textMuted
                                    font.pointSize: CompanyTheme.fontTiny
                                    font.bold: true
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingMd

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                Text { text: qsTr("Forward MAVLink / CSV Telemetry Stream"); color: CompanyTheme.textPrimary; font.bold: true; font.pointSize: CompanyTheme.fontSmall }
                                Text { text: qsTr("Transmit real-time telemetry stream packets to external radar or range monitoring software"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny }
                            }

                            CompanyButton {
                                text: (root._netSettings && root._netSettings.udpTelemetryEnabled) ? qsTr("FORWARDING: ON") : qsTr("FORWARDING: OFF")
                                isOutline: !(root._netSettings && root._netSettings.udpTelemetryEnabled)
                                onClicked: {
                                    if (root._netSettings) {
                                        root._netSettings.setUdpTelemetryEnabled(!root._netSettings.udpTelemetryEnabled)
                                    }
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            columnSpacing: CompanyTheme.spacingMd
                            rowSpacing: CompanyTheme.spacingSm

                            // Destination IP
                            ColumnLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                RowLayout {
                                    Text { text: qsTr("Destination IPv4 Address"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall; Layout.fillWidth: true }
                                    Text {
                                        visible: root._netSettings && !root._netSettings.isValidIPv4(destIpInput.text)
                                        text: qsTr("INVALID IP")
                                        color: CompanyTheme.danger
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.bold: true
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: (root._netSettings && root._netSettings.isValidIPv4(destIpInput.text)) ? CompanyTheme.borderCard : CompanyTheme.danger
                                    border.width: 1
                                    TextInput {
                                        id: destIpInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.family: CompanyTheme.fontMono
                                        selectByMouse: true
                                        text: root._netSettings ? root._netSettings.udpTelemetryDestIP : "127.0.0.1"
                                        onEditingFinished: {
                                            if (root._netSettings && root._netSettings.isValidIPv4(text)) {
                                                root._netSettings.setUdpTelemetryDestIP(text)
                                            }
                                        }
                                    }
                                }
                            }

                            // Destination Port
                            ColumnLayout {
                                spacing: 4
                                Layout.preferredWidth: 160
                                Text { text: qsTr("Destination UDP Port"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: CompanyTheme.borderCard
                                    border.width: 1
                                    TextInput {
                                        id: destPortInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.family: CompanyTheme.fontMono
                                        selectByMouse: true
                                        text: root._netSettings ? root._netSettings.udpTelemetryDestPort.toString() : "14445"
                                        onEditingFinished: {
                                            var p = parseInt(text)
                                            if (p >= 1024 && p <= 65535 && root._netSettings) {
                                                root._netSettings.setUdpTelemetryDestPort(p)
                                            }
                                        }
                                    }
                                }
                            }

                            // Transmission Rate
                            ColumnLayout {
                                spacing: 4
                                Layout.preferredWidth: 220
                                Text { text: qsTr("Transmission Rate"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                                RowLayout {
                                    spacing: 4
                                    Repeater {
                                        model: [1, 2, 5, 10]
                                        delegate: Rectangle {
                                            id: fwdRateBtn
                                            required property int modelData
                                            implicitWidth: 48
                                            implicitHeight: 34
                                            radius: CompanyTheme.radiusSm
                                            color: (root._netSettings && root._netSettings.udpTelemetryRateHz === fwdRateBtn.modelData) ? CompanyTheme.primary : CompanyTheme.bgCardSecondary
                                            border.color: (root._netSettings && root._netSettings.udpTelemetryRateHz === fwdRateBtn.modelData) ? CompanyTheme.primary : CompanyTheme.borderCard
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: fwdRateBtn.modelData + " Hz"
                                                color: (root._netSettings && root._netSettings.udpTelemetryRateHz === fwdRateBtn.modelData) ? CompanyTheme.bgApp : CompanyTheme.textPrimary
                                                font.pointSize: CompanyTheme.fontSmall
                                                font.bold: (root._netSettings && root._netSettings.udpTelemetryRateHz === fwdRateBtn.modelData)
                                                font.family: CompanyTheme.fontMono
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (root._netSettings) {
                                                        root._netSettings.setUdpTelemetryRateHz(fwdRateBtn.modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Live Telemetry Output Status & Metrics Strip
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: CompanyTheme.radiusSm
                            color: CompanyTheme.bgCardSecondary
                            border.color: (root._dataOutput && root._dataOutput.lastError.length > 0) ? CompanyTheme.danger : CompanyTheme.borderSubtle
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: CompanyTheme.spacingMd

                                RowLayout {
                                    spacing: 6
                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: (root._dataOutput && root._dataOutput.isStreaming) ? CompanyTheme.success : CompanyTheme.textMuted
                                    }
                                    Text {
                                        text: (root._dataOutput && root._dataOutput.isStreaming) ? qsTr("BROADCAST ACTIVE") : qsTr("BROADCAST IDLE")
                                        color: (root._dataOutput && root._dataOutput.isStreaming) ? CompanyTheme.success : CompanyTheme.textMuted
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.bold: true
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                RowLayout {
                                    spacing: 4
                                    Text { text: qsTr("Packets Sent:"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny }
                                    Text {
                                        text: root._dataOutput ? root._dataOutput.packetsSent.toString() : "0"
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.family: CompanyTheme.fontMono
                                        font.bold: true
                                    }
                                }

                                Rectangle { width: 1; height: 16; color: CompanyTheme.borderSubtle }

                                RowLayout {
                                    spacing: 4
                                    Text { text: qsTr("Bytes Sent:"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny }
                                    Text {
                                        text: root._dataOutput ? (root._dataOutput.bytesSent > 1048576 ? (root._dataOutput.bytesSent / 1048576).toFixed(1) + " MB" : (root._dataOutput.bytesSent / 1024).toFixed(1) + " KB") : "0 KB"
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.family: CompanyTheme.fontMono
                                    }
                                }

                                Rectangle { width: 1; height: 16; color: CompanyTheme.borderSubtle }

                                RowLayout {
                                    spacing: 4
                                    Text { text: qsTr("ICD Schema:"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny }
                                    Text {
                                        text: qsTr("IZI TEST V1 (PENDING DRDO ICD)")
                                        color: CompanyTheme.warning
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.family: CompanyTheme.fontMono
                                    }
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------------------------
                // 5. HIGH-SPEED ETHERNET LOG & PAYLOAD OFFLOAD
                // ------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    radius: CompanyTheme.radiusMd
                    color: CompanyTheme.bgCard
                    border.color: CompanyTheme.borderCard
                    border.width: 1
                    implicitHeight: ethLogCardCol.implicitHeight + CompanyTheme.spacingLg * 2

                    ColumnLayout {
                        id: ethLogCardCol
                        anchors.fill: parent
                        anchors.margins: CompanyTheme.spacingLg
                        spacing: CompanyTheme.spacingMd

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingSm
                            IconVector { name: "signal"; size: 18; color: CompanyTheme.success }
                            Text {
                                text: qsTr("HIGH-SPEED ETHERNET LOG & PAYLOAD OFFLOAD")
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontH2
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            StatusBadge {
                                text: (root._netSettings && root._netSettings.ethernetLogEnabled) ? qsTr("ENABLED") : qsTr("DISABLED")
                                badgeColor: (root._netSettings && root._netSettings.ethernetLogEnabled) ? CompanyTheme.success : CompanyTheme.textMuted
                            }
                        }

                        Text {
                            text: qsTr("High-bandwidth Ethernet data path for rapid onboard .bin flight log & payload acquisition (prevents IP conflicts with range networks).")
                            color: CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontBody
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            columnSpacing: CompanyTheme.spacingMd
                            rowSpacing: CompanyTheme.spacingSm

                            // Drone Ethernet IPv4 Address (Configurable to prevent IP conflict)
                            ColumnLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                RowLayout {
                                    spacing: 4
                                    Text { text: qsTr("Drone / Payload IP Address"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                                    Text {
                                        visible: root._netSettings && !root._netSettings.isValidIPv4(ethDroneIpInput.text)
                                        text: qsTr("(Invalid IPv4)")
                                        color: CompanyTheme.danger
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.bold: true
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: (root._netSettings && !root._netSettings.isValidIPv4(ethDroneIpInput.text)) ? CompanyTheme.danger : CompanyTheme.borderCard
                                    border.width: 1
                                    TextInput {
                                        id: ethDroneIpInput
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        text: root._netSettings ? root._netSettings.ethernetLogDroneIP : "192.168.168.2"
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.family: CompanyTheme.fontMono
                                        verticalAlignment: TextInput.AlignVCenter
                                        onEditingFinished: {
                                            if (root._netSettings && root._netSettings.isValidIPv4(text.trim())) {
                                                root._netSettings.setEthernetLogDroneIP(text.trim())
                                            }
                                        }
                                    }
                                }
                            }

                            // MAVLink FTP Port (UDP)
                            ColumnLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Text { text: qsTr("MAVLink FTP Port (UDP)"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: CompanyTheme.borderCard
                                    border.width: 1
                                    TextInput {
                                        id: ethLogPortInput
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        text: root._netSettings ? root._netSettings.ethernetLogPort.toString() : "14550"
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.family: CompanyTheme.fontMono
                                        verticalAlignment: TextInput.AlignVCenter
                                        onEditingFinished: {
                                            var p = parseInt(text.trim())
                                            if (root._netSettings && root._netSettings.isValidPort(p)) {
                                                root._netSettings.setEthernetLogPort(p)
                                            }
                                        }
                                    }
                                }
                            }

                            // Direct HTTP / TCP Port
                            ColumnLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Text { text: qsTr("Companion HTTP Offload Port"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: CompanyTheme.borderCard
                                    border.width: 1
                                    TextInput {
                                        id: ethHttpPortInput
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        text: root._netSettings ? root._netSettings.ethernetLogHttpPort.toString() : "8080"
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.family: CompanyTheme.fontMono
                                        verticalAlignment: TextInput.AlignVCenter
                                        onEditingFinished: {
                                            var p = parseInt(text.trim())
                                            if (root._netSettings && root._netSettings.isValidPort(p)) {
                                                root._netSettings.setEthernetLogHttpPort(p)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Switches and Action Row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingLg

                            // Enable Toggle
                            RowLayout {
                                spacing: CompanyTheme.spacingSm
                                Switch {
                                    id: ethLogEnableSwitch
                                    checked: root._netSettings ? root._netSettings.ethernetLogEnabled : true
                                    onToggled: {
                                        if (root._netSettings) root._netSettings.setEthernetLogEnabled(checked)
                                    }
                                }
                                Text {
                                    text: qsTr("Enable High-Speed Offload")
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: CompanyTheme.fontSmall
                                    font.bold: true
                                }
                            }

                            // Auto-Offload Toggle
                            RowLayout {
                                spacing: CompanyTheme.spacingSm
                                Switch {
                                    id: ethAutoOffloadSwitch
                                    checked: root._netSettings ? root._netSettings.ethernetLogAutoOffload : true
                                    onToggled: {
                                        if (root._netSettings) root._netSettings.setEthernetLogAutoOffload(checked)
                                    }
                                }
                                Text {
                                    text: qsTr("Auto-Offload Post-Flight")
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: CompanyTheme.fontSmall
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Quick Action Button
                            CompanyButton {
                                text: qsTr("Save & Test Link")
                                isOutline: true
                                onClicked: {
                                    if (root._netSettings) {
                                        root._netSettings.saveSettings()
                                        QGroundControl.showMessageDialog(root, qsTr("Ethernet Configuration"), qsTr("High-speed Ethernet configuration updated.\nDrone IP: %1\nMAVLink Port: %2\nHTTP Offload: %3").arg(root._netSettings.ethernetLogDroneIP).arg(root._netSettings.ethernetLogPort).arg(root._netSettings.ethernetLogHttpPort))
                                    }
                                }
                            }
                        }

                        // Operational Status Pill Bar
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: CompanyTheme.radiusSm
                            color: CompanyTheme.bgCardSecondary
                            border.color: CompanyTheme.borderSubtle
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: CompanyTheme.spacingMd
                                anchors.rightMargin: CompanyTheme.spacingMd
                                spacing: CompanyTheme.spacingLg

                                RowLayout {
                                    spacing: 4
                                    Text { text: qsTr("Link Transport:"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny }
                                    Text {
                                        text: (typeof companyFlightLogManager !== "undefined" && companyFlightLogManager) ? companyFlightLogManager.activeTransportName : qsTr("DISCONNECTED")
                                        color: (typeof companyFlightLogManager !== "undefined" && companyFlightLogManager && companyFlightLogManager.isEthernetLink) ? CompanyTheme.success : CompanyTheme.info
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.family: CompanyTheme.fontMono
                                        font.bold: true
                                    }
                                }

                                Rectangle { width: 1; height: 16; color: CompanyTheme.borderSubtle }

                                RowLayout {
                                    spacing: 4
                                    Text { text: qsTr("Offload Throughput:"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny }
                                    Text {
                                        text: (typeof companyFlightLogManager !== "undefined" && companyFlightLogManager && companyFlightLogManager.isEthernetLink) ? qsTr("~100 Mbps (Wire Speed)") : qsTr("57.6 kbps (Serial)")
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.family: CompanyTheme.fontMono
                                    }
                                }

                                Rectangle { width: 1; height: 16; color: CompanyTheme.borderSubtle }

                                RowLayout {
                                    spacing: 4
                                    Text { text: qsTr("Network Isolation:"); color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny }
                                    Text {
                                        text: qsTr("CONFIGURABLE (NO IP CONFLICT)")
                                        color: CompanyTheme.success
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.family: CompanyTheme.fontMono
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------------------------
                // 6. STORAGE DIRECTORIES
                // ------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    radius: CompanyTheme.radiusMd
                    color: CompanyTheme.bgCard
                    border.color: CompanyTheme.borderCard
                    border.width: 1
                    implicitHeight: storageCardCol.implicitHeight + CompanyTheme.spacingLg * 2

                    ColumnLayout {
                        id: storageCardCol
                        anchors.fill: parent
                        anchors.margins: CompanyTheme.spacingLg
                        spacing: CompanyTheme.spacingMd

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingSm
                            IconVector { name: "logs"; size: 18; color: CompanyTheme.secondaryBlue }
                            Text {
                                text: qsTr("STORAGE DIRECTORIES & LOG LOCATIONS")
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontH2
                                font.bold: true
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        // Telemetry CSV Path
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingMd
                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                Text { text: qsTr("Telemetry CSV Logs Directory"); color: CompanyTheme.textPrimary; font.bold: true; font.pointSize: CompanyTheme.fontSmall }
                                Text {
                                    text: root._appSettings ? root._appSettings.telemetrySavePath : "/home/Documents/Telemetry"
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: CompanyTheme.fontTiny
                                    font.family: CompanyTheme.fontMono
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                            }
                            CompanyButton {
                                text: qsTr("Open Telemetry Folder")
                                isOutline: true
                                onClicked: {
                                    if (CompanyCsvLogger) {
                                        CompanyCsvLogger.openLogFolder()
                                    }
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        // Onboard Flight Logs Path
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingMd
                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                Text { text: qsTr("Onboard Dataflash Logs Directory"); color: CompanyTheme.textPrimary; font.bold: true; font.pointSize: CompanyTheme.fontSmall }
                                Text {
                                    text: root._appSettings ? root._appSettings.logSavePath : "/home/Documents/Logs"
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: CompanyTheme.fontTiny
                                    font.family: CompanyTheme.fontMono
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                            }
                            CompanyButton {
                                text: qsTr("Open Logs Folder")
                                isOutline: true
                                onClicked: {
                                    if (root._appSettings) {
                                        Qt.openUrlExternally("file://" + root._appSettings.logSavePath)
                                    }
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: CompanyTheme.borderSubtle }

                        // Photo / Snapshot Path
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingMd
                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                Text { text: qsTr("Camera Snapshots & Metadata Directory"); color: CompanyTheme.textPrimary; font.bold: true; font.pointSize: CompanyTheme.fontSmall }
                                Text {
                                    text: root._appSettings ? root._appSettings.photoSavePath : "/home/Documents/Photo"
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: CompanyTheme.fontTiny
                                    font.family: CompanyTheme.fontMono
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                            }
                            CompanyButton {
                                text: qsTr("Open Photos Folder")
                                isOutline: true
                                onClicked: {
                                    if (root._appSettings) {
                                        Qt.openUrlExternally("file://" + root._appSettings.photoSavePath)
                                    }
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------------------------
                // 6. PMDDL (POINT-TO-MULTIPOINT DIGITAL DATA LINK)
                // ------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    radius: CompanyTheme.radiusMd
                    color: CompanyTheme.bgCard
                    border.color: CompanyTheme.borderCard
                    border.width: 1
                    implicitHeight: pmddlCardCol.implicitHeight + CompanyTheme.spacingLg * 2

                    ColumnLayout {
                        id: pmddlCardCol
                        anchors.fill: parent
                        anchors.margins: CompanyTheme.spacingLg
                        spacing: CompanyTheme.spacingMd

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: CompanyTheme.spacingSm
                            IconVector { name: "fleet"; size: 18; color: CompanyTheme.warning }
                            Text {
                                text: qsTr("PMDDL TACTICAL DATA LINK (INTERFACE BOUNDARY)")
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontH2
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            Rectangle {
                                implicitWidth: 120
                                implicitHeight: 24
                                radius: CompanyTheme.radiusSm
                                color: CompanyTheme.bgCardSecondary
                                border.color: CompanyTheme.borderCard
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: root._netSettings ? root._netSettings.pmddlStatusText : qsTr("STANDBY")
                                    color: CompanyTheme.warning
                                    font.pointSize: CompanyTheme.fontTiny
                                    font.bold: true
                                }
                            }
                        }

                        // Boundary Disclaimer Card
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: CompanyTheme.radiusSm
                            color: Qt.rgba(0.96, 0.62, 0.04, 0.10)
                            border.color: Qt.rgba(0.96, 0.62, 0.04, 0.35)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8
                                IconVector { name: "flight"; size: 14; color: CompanyTheme.warning }
                                Text {
                                    text: qsTr("TACTICAL DATA LINK INTERFACE BOUNDARY — NO PROPRIETARY PACKET FORMAT ASSUMED")
                                    color: CompanyTheme.warning
                                    font.pointSize: CompanyTheme.fontTiny
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            columnSpacing: CompanyTheme.spacingMd
                            rowSpacing: CompanyTheme.spacingSm

                            // Operating Mode
                            ColumnLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Text { text: qsTr("Link Operating Mode"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: CompanyTheme.borderCard
                                    border.width: 1
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        spacing: 2
                                        Repeater {
                                            model: ["STANDBY", "AIRBORNE", "GROUND", "DISABLED"]
                                            delegate: Rectangle {
                                                id: pmddlModeBtn
                                                required property string modelData
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                radius: CompanyTheme.radiusSm
                                                color: (root._netSettings && root._netSettings.pmddlLinkMode === pmddlModeBtn.modelData) ? CompanyTheme.primary : "transparent"
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: pmddlModeBtn.modelData
                                                    color: (root._netSettings && root._netSettings.pmddlLinkMode === pmddlModeBtn.modelData) ? CompanyTheme.bgApp : CompanyTheme.textSecondary
                                                    font.pointSize: 9
                                                    font.bold: (root._netSettings && root._netSettings.pmddlLinkMode === pmddlModeBtn.modelData)
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (root._netSettings) {
                                                            root._netSettings.setPmddlLinkMode(pmddlModeBtn.modelData)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Transceiver IP
                            ColumnLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                RowLayout {
                                    Text { text: qsTr("Transceiver Remote IP"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall; Layout.fillWidth: true }
                                    Text {
                                        visible: root._netSettings && !root._netSettings.isValidIPv4(pmddlIpInput.text)
                                        text: qsTr("INVALID IP")
                                        color: CompanyTheme.danger
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.bold: true
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: (root._netSettings && root._netSettings.isValidIPv4(pmddlIpInput.text)) ? CompanyTheme.borderCard : CompanyTheme.danger
                                    border.width: 1
                                    TextInput {
                                        id: pmddlIpInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.family: CompanyTheme.fontMono
                                        selectByMouse: true
                                        text: root._netSettings ? root._netSettings.pmddlRemoteIP : "192.168.1.10"
                                        onEditingFinished: {
                                            if (root._netSettings && root._netSettings.isValidIPv4(text)) {
                                                root._netSettings.setPmddlRemoteIP(text)
                                            }
                                        }
                                    }
                                }
                            }

                            // Data Port
                            ColumnLayout {
                                spacing: 4
                                Layout.preferredWidth: 160
                                Text { text: qsTr("Data Port"); color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontSmall }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgInput
                                    border.color: CompanyTheme.borderCard
                                    border.width: 1
                                    TextInput {
                                        id: pmddlPortInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.family: CompanyTheme.fontMono
                                        selectByMouse: true
                                        text: root._netSettings ? root._netSettings.pmddlDataPort.toString() : "14555"
                                        onEditingFinished: {
                                            var p = parseInt(text)
                                            if (p >= 1024 && p <= 65535 && root._netSettings) {
                                                root._netSettings.setPmddlDataPort(p)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        }
                    }
                    }

                    // ================================================================
                    // SUB-TAB C: OFFLINE MAPS & TILE CACHE (PHASE 8A ARCHITECTURE)
                    // ================================================================
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: CompanyTheme.spacingMd
                        visible: root.activeSubTab === "OFFLINE_MAPS"

                        // 1. OFFLINE MAP ENGINE STATUS & METRICS CARD
                        Rectangle {
                            Layout.fillWidth: true
                            radius: CompanyTheme.radiusMd
                            color: CompanyTheme.bgCard
                            border.color: CompanyTheme.borderCard
                            border.width: 1
                            implicitHeight: mapOverviewCol.implicitHeight + CompanyTheme.spacingLg * 2

                            ColumnLayout {
                                id: mapOverviewCol
                                anchors.fill: parent
                                anchors.margins: CompanyTheme.spacingLg
                                spacing: CompanyTheme.spacingMd

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: CompanyTheme.spacingSm

                                    IconVector {
                                        name: "map"
                                        size: 18
                                        color: CompanyTheme.primary
                                    }

                                    ColumnLayout {
                                        spacing: 1
                                        Layout.fillWidth: true
                                        Text {
                                            text: qsTr("OFFLINE MAP CACHE & CHANDIPUR TILE ENGINE")
                                            color: CompanyTheme.textPrimary
                                            font.pointSize: CompanyTheme.fontH2
                                            font.bold: true
                                        }
                                        Text {
                                            text: qsTr("Local SQLite tile database (qgcMapCache.db) provides instant, seamless mapping when disconnected from the internet")
                                            color: CompanyTheme.textSecondary
                                            font.pointSize: CompanyTheme.fontSmall
                                        }
                                    }

                                    CompanyButton {
                                        text: qsTr("Reload Tile Sets")
                                        isOutline: true
                                        enabled: !root._currentlyImportOrExporting
                                        onClicked: {
                                            if (root._mapEngineManager) {
                                                root._mapEngineManager.loadTileSets()
                                            }
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: CompanyTheme.borderCard }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: CompanyTheme.spacingMd

                                    // Tile 1: Installed Tile Sets
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 64
                                        radius: CompanyTheme.radiusSm
                                        color: CompanyTheme.bgCardSecondary
                                        border.color: CompanyTheme.borderCard
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: CompanyTheme.spacingSm
                                            spacing: 2

                                            Text {
                                                text: qsTr("INSTALLED TILE SETS")
                                                color: CompanyTheme.textMuted
                                                font.pointSize: CompanyTheme.fontTiny
                                                font.bold: true
                                            }
                                            Text {
                                                text: root._mapEngineManager && root._mapEngineManager.tileSets ? root._mapEngineManager.tileSets.count.toString() : "0"
                                                color: CompanyTheme.textPrimary
                                                font.pointSize: CompanyTheme.fontH2
                                                font.bold: true
                                                font.family: CompanyTheme.fontMono
                                            }
                                            Text {
                                                text: qsTr("sets")
                                                color: CompanyTheme.textSecondary
                                                font.pointSize: 8
                                            }
                                        }
                                    }

                                    // Tile 2: Total Cached Tiles
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 64
                                        radius: CompanyTheme.radiusSm
                                        color: CompanyTheme.bgCardSecondary
                                        border.color: CompanyTheme.borderCard
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: CompanyTheme.spacingSm
                                            spacing: 2

                                            Text {
                                                text: qsTr("TOTAL CACHED TILES")
                                                color: CompanyTheme.textMuted
                                                font.pointSize: CompanyTheme.fontTiny
                                                font.bold: true
                                            }
                                            Text {
                                                text: root._mapEngineManager ? root._mapEngineManager.tileCountStr : "0"
                                                color: CompanyTheme.textPrimary
                                                font.pointSize: CompanyTheme.fontH2
                                                font.bold: true
                                                font.family: CompanyTheme.fontMono
                                            }
                                            Text {
                                                text: qsTr("tiles")
                                                color: CompanyTheme.textSecondary
                                                font.pointSize: 8
                                            }
                                        }
                                    }

                                    // Tile 3: Disk Cache Size
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 64
                                        radius: CompanyTheme.radiusSm
                                        color: CompanyTheme.bgCardSecondary
                                        border.color: CompanyTheme.borderCard
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: CompanyTheme.spacingSm
                                            spacing: 2

                                            Text {
                                                text: qsTr("DISK CACHE SIZE")
                                                color: CompanyTheme.textMuted
                                                font.pointSize: CompanyTheme.fontTiny
                                                font.bold: true
                                            }
                                            Text {
                                                text: root._mapEngineManager ? root._mapEngineManager.tileSizeStr : "0 MB"
                                                color: CompanyTheme.textPrimary
                                                font.pointSize: CompanyTheme.fontH2
                                                font.bold: true
                                                font.family: CompanyTheme.fontMono
                                            }
                                            Text {
                                                text: qsTr("storage")
                                                color: CompanyTheme.textSecondary
                                                font.pointSize: 8
                                            }
                                        }
                                    }

                                    // Tile 4: Offline Status
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 64
                                        radius: CompanyTheme.radiusSm
                                        color: CompanyTheme.bgCardSecondary
                                        border.color: CompanyTheme.borderCard
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: CompanyTheme.spacingSm
                                            spacing: 2

                                            Text {
                                                text: qsTr("OFFLINE STATUS")
                                                color: CompanyTheme.textMuted
                                                font.pointSize: CompanyTheme.fontTiny
                                                font.bold: true
                                            }
                                            Text {
                                                text: qsTr("READY")
                                                color: CompanyTheme.success
                                                font.pointSize: CompanyTheme.fontH2
                                                font.bold: true
                                                font.family: CompanyTheme.fontMono
                                            }
                                            Text {
                                                text: qsTr("zero-net")
                                                color: CompanyTheme.textSecondary
                                                font.pointSize: 8
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 2. OFFLINE MAP PACKAGE IMPORT WORKFLOW CARD
                        Rectangle {
                            Layout.fillWidth: true
                            radius: CompanyTheme.radiusMd
                            color: CompanyTheme.bgCard
                            border.color: CompanyTheme.borderCard
                            border.width: 1
                            implicitHeight: importWorkflowCol.implicitHeight + CompanyTheme.spacingLg * 2

                            ColumnLayout {
                                id: importWorkflowCol
                                anchors.fill: parent
                                anchors.margins: CompanyTheme.spacingLg
                                spacing: CompanyTheme.spacingMd

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: CompanyTheme.spacingSm

                                    IconVector {
                                        name: "logs"
                                        size: 18
                                        color: CompanyTheme.primary
                                    }

                                    ColumnLayout {
                                        spacing: 1
                                        Layout.fillWidth: true
                                        Text {
                                            text: qsTr("IMPORT OFFLINE MAP PACKAGE")
                                            color: CompanyTheme.textPrimary
                                            font.pointSize: CompanyTheme.fontH2
                                            font.bold: true
                                        }
                                        Text {
                                            text: qsTr("Ingest pre-packaged satellite imagery and elevation terrain files (.qct, .zip, .tar.gz) into the local QGC map cache")
                                            color: CompanyTheme.textSecondary
                                            font.pointSize: CompanyTheme.fontSmall
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: CompanyTheme.borderCard }

                                // Import Action Row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: CompanyTheme.spacingMd

                                    CompanyButton {
                                        text: qsTr("Select Map Package (.qct / .zip / .tar.gz)")
                                        enabled: !root._currentlyImportOrExporting
                                        onClicked: {
                                            if (root._mapEngineManager) {
                                                root._mapEngineManager.resetAction()
                                            }
                                            mapImportDialog.openForLoad()
                                        }
                                    }

                                    Text {
                                        text: qsTr("Supported formats: QGC Tile Set (*.qct), Archive (*.zip, *.tar.gz, *.tgz)")
                                        color: CompanyTheme.textMuted
                                        font.pointSize: CompanyTheme.fontSmall
                                        Layout.fillWidth: true
                                    }
                                }

                                // Active Import Progress Banner
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 48
                                    visible: root._currentlyImportOrExporting
                                    radius: CompanyTheme.radiusSm
                                    color: Qt.rgba(CompanyTheme.primary.r, CompanyTheme.primary.g, CompanyTheme.primary.b, 0.15)
                                    border.color: CompanyTheme.primary
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: CompanyTheme.spacingMd
                                        spacing: CompanyTheme.spacingMd

                                        IconVector {
                                            name: "signal"
                                            size: 16
                                            color: CompanyTheme.primary
                                        }

                                        ColumnLayout {
                                            spacing: 2
                                            Layout.fillWidth: true

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    text: qsTr("Ingesting Map Package into Local Cache...")
                                                    color: CompanyTheme.textPrimary
                                                    font.pointSize: CompanyTheme.fontSmall
                                                    font.bold: true
                                                }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: "%1%".arg(root._mapEngineManager ? root._mapEngineManager.actionProgress : 0)
                                                    color: CompanyTheme.primary
                                                    font.pointSize: CompanyTheme.fontSmall
                                                    font.family: CompanyTheme.fontMono
                                                    font.bold: true
                                                }
                                            }

                                            // Progress bar track
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 6
                                                radius: 3
                                                color: CompanyTheme.bgCardSecondary

                                                Rectangle {
                                                    height: parent.height
                                                    radius: 3
                                                    color: CompanyTheme.primary
                                                    width: parent.width * (root._mapEngineManager ? Math.max(0, Math.min(100, root._mapEngineManager.actionProgress)) / 100.0 : 0)
                                                }
                                            }
                                        }
                                    }
                                }

                                // Error Banner
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    visible: root._mapEngineManager && root._mapEngineManager.errorMessage !== ""
                                    radius: CompanyTheme.radiusSm
                                    color: Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.15)
                                    border.color: CompanyTheme.danger
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: CompanyTheme.spacingMd
                                        spacing: CompanyTheme.spacingSm

                                        Text {
                                            text: qsTr("Import Error: %1").arg(root._mapEngineManager ? root._mapEngineManager.errorMessage : "")
                                            color: CompanyTheme.danger
                                            font.pointSize: CompanyTheme.fontSmall
                                            font.bold: true
                                            Layout.fillWidth: true
                                        }

                                        CompanyButton {
                                            text: qsTr("Dismiss")
                                            isOutline: true
                                            onClicked: {
                                                if (root._mapEngineManager) {
                                                    root._mapEngineManager.errorMessage = ""
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 3. INSTALLED TILE SETS LIST CARD
                        Rectangle {
                            Layout.fillWidth: true
                            radius: CompanyTheme.radiusMd
                            color: CompanyTheme.bgCard
                            border.color: CompanyTheme.borderCard
                            border.width: 1
                            implicitHeight: tileSetsListCol.implicitHeight + CompanyTheme.spacingLg * 2

                            ColumnLayout {
                                id: tileSetsListCol
                                anchors.fill: parent
                                anchors.margins: CompanyTheme.spacingLg
                                spacing: CompanyTheme.spacingMd

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: CompanyTheme.spacingSm

                                    Text {
                                        text: qsTr("INSTALLED TILE SETS")
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontH2
                                        font.bold: true
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: qsTr("Stored in ~/.local/share/QGroundControl.org/QGroundControl/qgcMapCache.db")
                                        color: CompanyTheme.textMuted
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.family: CompanyTheme.fontMono
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: CompanyTheme.borderCard }

                                // Empty State
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: CompanyTheme.spacingSm
                                    visible: !root._mapEngineManager || !root._mapEngineManager.tileSets || root._mapEngineManager.tileSets.count === 0

                                    Item { Layout.preferredHeight: 12 }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: qsTr("NO CUSTOM TILE SETS INSTALLED")
                                        color: CompanyTheme.textPrimary
                                        font.pointSize: CompanyTheme.fontBody
                                        font.bold: true
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: qsTr("Import a Chandipur range tile set package above for complete offline mission planning.")
                                        color: CompanyTheme.textSecondary
                                        font.pointSize: CompanyTheme.fontSmall
                                    }
                                    Item { Layout.preferredHeight: 12 }
                                }

                                // Repeater for Installed Tile Sets
                                Repeater {
                                    model: root._mapEngineManager ? root._mapEngineManager.tileSets : null

                                    Rectangle {
                                        id: tileSetRow
                                        required property var object
                                        required property int index

                                        Layout.fillWidth: true
                                        implicitHeight: 44
                                        radius: CompanyTheme.radiusSm
                                        color: index % 2 === 0 ? "transparent" : CompanyTheme.bgCardSecondary
                                        border.color: CompanyTheme.borderCard
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: CompanyTheme.spacingMd
                                            spacing: CompanyTheme.spacingMd

                                            Text {
                                                text: tileSetRow.object ? tileSetRow.object.name : ""
                                                color: CompanyTheme.textPrimary
                                                font.pointSize: CompanyTheme.fontSmall
                                                font.bold: true
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: tileSetRow.object ? tileSetRow.object.mapTypeStr : ""
                                                color: CompanyTheme.textSecondary
                                                font.pointSize: CompanyTheme.fontTiny
                                                font.family: CompanyTheme.fontMono
                                                Layout.preferredWidth: 140
                                            }

                                            Text {
                                                text: (tileSetRow.object && tileSetRow.object.totalTileCountStr) ? tileSetRow.object.totalTileCountStr : "0"
                                                color: CompanyTheme.primary
                                                font.pointSize: CompanyTheme.fontSmall
                                                font.family: CompanyTheme.fontMono
                                                font.bold: true
                                                Layout.preferredWidth: 100
                                            }

                                            Text {
                                                text: (tileSetRow.object && tileSetRow.object.totalTilesSizeStr) ? tileSetRow.object.totalTilesSizeStr : "0 B"
                                                color: CompanyTheme.textPrimary
                                                font.pointSize: CompanyTheme.fontSmall
                                                font.family: CompanyTheme.fontMono
                                                Layout.preferredWidth: 90
                                            }

                                            CompanyButton {
                                                text: qsTr("Delete")
                                                isOutline: true
                                                enabled: !tileSetRow.object.deleting && !root._currentlyImportOrExporting
                                                onClicked: {
                                                    if (root._mapEngineManager && tileSetRow.object) {
                                                        root._mapEngineManager.deleteTileSet(tileSetRow.object)
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

    // Offline Map Import File Dialog
    QGCFileDialog {
        id: mapImportDialog
        folder: QGroundControl.settingsManager.appSettings.missionSavePath
        nameFilters: [ qsTr("Map Tile Sets (*.qct *.zip *.tar.gz *.tgz *.db)") ]
        title: qsTr("Select Offline Map Package")

        onAcceptedForLoad: (file) => {
            close()
            if (root._mapEngineManager) {
                root._mapEngineManager.resetAction()
                var f = file.toLowerCase()
                if (f.endsWith(".zip") || f.endsWith(".tar.gz") || f.endsWith(".tgz")) {
                    root._mapEngineManager.importArchive(file)
                } else {
                    root._mapEngineManager.importSets(file)
                }
            }
        }
    }
}
