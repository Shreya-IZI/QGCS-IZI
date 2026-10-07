pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import Company.UI

Item {
    id: root
    anchors.fill: parent

    readonly property bool _hasVehicle:      companyFlightLogManager.hasVehicle
    readonly property bool _isArmed:         companyFlightLogManager.isArmed
    readonly property bool _downloading:     companyFlightLogManager.isDownloading || OnboardLogController.downloadingLogs
    readonly property bool _requestingList:  companyFlightLogManager.isRequestingList || OnboardLogController.requestingList
    readonly property int  _logCount:        companyFlightLogManager.logEntries ? companyFlightLogManager.logEntries.count : 0
    readonly property int  _selectedCount:   companyFlightLogManager.selectedCount
    readonly property bool _isNarrow:        width < 1180 || ScreenTools.isMobile

    property string filterMode: "all" // "all", "onboard", "telemetry"

    // ------------------------------------------------------------------------
    // Helper: Byte size formatter
    // ------------------------------------------------------------------------
    function formatBytes(bytes) {
        if (!bytes || bytes <= 0) return "0 B"
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB"
        return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB"
    }

    // ------------------------------------------------------------------------
    // Helper: State-specific status color
    // ------------------------------------------------------------------------
    function getStatusColor(status) {
        var s = (status || "").toUpperCase()
        if (s === "RECORDING") return CompanyTheme.info
        if (s === "WAITING FOR FLIGHT END") return CompanyTheme.warning
        if (s === "LOG DETECTED") return CompanyTheme.primary
        if (s === "DOWNLOADING") return CompanyTheme.primary
        if (s === "VERIFYING") return "#A855F7" // Purple
        if (s === "SAVED") return CompanyTheme.success
        if (s === "ALREADY SAVED") return CompanyTheme.success
        if (s === "RETRYING") return CompanyTheme.warning
        if (s === "FAILED") return CompanyTheme.danger
        if (s === "NO LOG AVAILABLE") return CompanyTheme.textMuted
        return CompanyTheme.textSecondary
    }

    // ------------------------------------------------------------------------
    // Navigation Safety Lockout during Download
    // ------------------------------------------------------------------------
    function _updateNavigationBlocked() {
        if (typeof globals !== "undefined" && globals && globals.navigationBlockedReason !== undefined) {
            if (root._downloading) {
                globals.navigationBlockedReason = qsTr("Download in progress — please wait before leaving Logs.")
            } else {
                globals.navigationBlockedReason = ""
            }
        }
    }

    Connections {
        target: companyFlightLogManager
        function onIsDownloadingChanged() {
            root._updateNavigationBlocked()
        }
    }

    Connections {
        target: OnboardLogController
        function onDownloadingLogsChanged() {
            root._updateNavigationBlocked()
        }
    }

    Component.onCompleted: {
        root._updateNavigationBlocked()
        if (root._hasVehicle && root._logCount === 0 && !root._isArmed) {
            companyFlightLogManager.refresh()
        }
    }

    Component.onDestruction: {
        if (typeof globals !== "undefined" && globals && globals.navigationBlockedReason !== undefined) {
            globals.navigationBlockedReason = ""
        }
    }

    // ------------------------------------------------------------------------
    // Background Layout
    // ------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: CompanyTheme.bgApp
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: CompanyTheme.spacingLg
        spacing: CompanyTheme.spacingMd

        // ====================================================================
        // 1. TOP HEADER & OVERALL SYSTEM STATE
        // ====================================================================
        RowLayout {
            Layout.fillWidth: true
            spacing: CompanyTheme.spacingMd

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                RowLayout {
                    spacing: CompanyTheme.spacingSm

                    Text {
                        text: qsTr("FLIGHT LOGS & TELEMETRY ARCHIVE")
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontH1
                        font.bold: true
                        font.letterSpacing: 0.6
                    }

                    // Total entry count pill
                    Rectangle {
                        visible: root._logCount > 0
                        Layout.preferredHeight: 20
                        radius: CompanyTheme.radiusSm
                        color: CompanyTheme.bgCardSecondary
                        border.color: CompanyTheme.borderCard
                        border.width: 1
                        implicitWidth: logCountText.implicitWidth + 12

                        Text {
                            id: logCountText
                            anchors.centerIn: parent
                            text: qsTr("%1 Records").arg(root._logCount)
                            color: CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                            font.family: CompanyTheme.fontMono
                        }
                    }
                }

                Text {
                    text: qsTr("Continuous ground telemetry (.tlog) recording & post-flight autopilot dataflash acquisition (.ulg / .bin)")
                    color: CompanyTheme.textSecondary
                    font.pointSize: CompanyTheme.fontBody
                }
            }

            // Ethernet Link / Transport Mode Badge
            Rectangle {
                Layout.preferredHeight: 32
                radius: CompanyTheme.radiusSm
                color: CompanyTheme.bgCard
                border.color: companyFlightLogManager.isEthernetLink ? CompanyTheme.success : CompanyTheme.borderCard
                border.width: 1
                implicitWidth: ethBadgeLayout.implicitWidth + CompanyTheme.spacingMd * 2

                RowLayout {
                    id: ethBadgeLayout
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: companyFlightLogManager.isEthernetLink ? CompanyTheme.success : (root._hasVehicle ? CompanyTheme.info : CompanyTheme.textMuted)
                    }

                    Text {
                        text: {
                            if (!root._hasVehicle) return qsTr("LINK: NONE")
                            if (companyFlightLogManager.isEthernetLink) return qsTr("ETHERNET (HIGH SPEED)")
                            return qsTr("LINK: %1").arg(companyFlightLogManager.activeTransportName)
                        }
                        color: companyFlightLogManager.isEthernetLink ? CompanyTheme.success : CompanyTheme.textSecondary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        font.letterSpacing: 0.4
                    }
                }
            }

            // High-Visibility Master System State Badge
            Rectangle {
                Layout.preferredHeight: 32
                radius: CompanyTheme.radiusSm
                color: CompanyTheme.bgCard
                border.color: CompanyTheme.borderCard
                border.width: 1
                implicitWidth: masterBadgeLayout.implicitWidth + CompanyTheme.spacingMd * 2

                RowLayout {
                    id: masterBadgeLayout
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: {
                            if (!root._hasVehicle) return CompanyTheme.textMuted
                            if (root._isArmed) return CompanyTheme.warning
                            if (root._downloading) return CompanyTheme.primary
                            if (root._requestingList) return CompanyTheme.warning
                            return CompanyTheme.success
                        }

                        SequentialAnimation on opacity {
                            running: root._downloading || root._requestingList || companyFlightLogManager.groundTelemetryRecording
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.2; duration: 700; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 0.2; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                        }
                    }

                    Text {
                        text: {
                            if (!root._hasVehicle) return qsTr("DISCONNECTED")
                            if (root._isArmed) return qsTr("ARMED — AIRBORNE LOCKOUT")
                            if (root._downloading) return qsTr("ACQUIRING ONBOARD LOG")
                            if (root._requestingList) return qsTr("FETCHING LOG CATALOG")
                            return qsTr("STANDBY / READY")
                        }
                        color: {
                            if (!root._hasVehicle) return CompanyTheme.textMuted
                            if (root._isArmed) return CompanyTheme.warning
                            if (root._downloading) return CompanyTheme.primary
                            if (root._requestingList) return CompanyTheme.warning
                            return CompanyTheme.success
                        }
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        font.letterSpacing: 0.4
                    }
                }
            }
        }

        // ====================================================================
        // 2. LOG ACQUISITION OVERVIEW CARDS
        // ====================================================================
        GridLayout {
            columns: root._isNarrow ? 1 : 2
            Layout.fillWidth: true
            rowSpacing: CompanyTheme.spacingSm
            columnSpacing: CompanyTheme.spacingMd

            // ----------------------------------------------------------------
            // Card 1: Ground Telemetry Stream (.tlog)
            // ----------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 112
                radius: CompanyTheme.radiusMd
                color: CompanyTheme.bgCard
                border.color: CompanyTheme.borderCard
                border.width: 1
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: CompanyTheme.spacingMd
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: CompanyTheme.spacingSm

                        IconVector {
                            name: "signal"
                            size: 16
                            color: companyFlightLogManager.groundTelemetryRecording ? CompanyTheme.info : CompanyTheme.textSecondary
                        }

                        Text {
                            text: qsTr("GROUND TELEMETRY STREAM (.tlog)")
                            color: CompanyTheme.textPrimary
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                            font.letterSpacing: 0.5
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        StatusBadge {
                            text: companyFlightLogManager.groundTelemetryStatus
                            badgeColor: root.getStatusColor(companyFlightLogManager.groundTelemetryStatus)
                            showDot: true
                            pulse: companyFlightLogManager.groundTelemetryRecording
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: CompanyTheme.spacingLg

                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text {
                                    text: qsTr("Active Session:")
                                    color: CompanyTheme.textMuted
                                    font.pointSize: CompanyTheme.fontTiny
                                }
                                Text {
                                    text: {
                                        var p = companyFlightLogManager.groundTelemetryPath
                                        if (!p || p.length === 0) return qsTr("Autonomous Continuous Recording Active")
                                        var parts = p.split("/")
                                        return parts[parts.length - 1]
                                    }
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: CompanyTheme.fontTiny
                                    font.family: CompanyTheme.fontMono
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: CompanyTheme.spacingMd
                                Text {
                                    text: qsTr("Recorded Bytes: %1").arg(root.formatBytes(companyFlightLogManager.groundTelemetryBytes))
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: CompanyTheme.fontTiny
                                    font.family: CompanyTheme.fontMono
                                }
                                Text {
                                    text: "•"
                                    color: CompanyTheme.textMuted
                                    font.pointSize: CompanyTheme.fontTiny
                                }
                                Text {
                                    text: qsTr("Never Deleted When Disarmed")
                                    color: CompanyTheme.success
                                    font.pointSize: CompanyTheme.fontTiny
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        CompanyButton {
                            text: qsTr("Open Folder")
                            isOutline: true
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            onClicked: companyFlightLogManager.openTelemetryDirectory()
                        }
                    }
                }
            }

            // ----------------------------------------------------------------
            // Card 2: Onboard Autopilot Flight Logs (.bin / .ulg)
            // ----------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 112
                radius: CompanyTheme.radiusMd
                color: CompanyTheme.bgCard
                border.color: CompanyTheme.borderCard
                border.width: 1
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: CompanyTheme.spacingMd
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: CompanyTheme.spacingSm

                        IconVector {
                            name: "logs"
                            size: 16
                            color: root.getStatusColor(companyFlightLogManager.onboardSyncStatus)
                        }

                        Text {
                            text: qsTr("ONBOARD AUTOPILOT LOG ACQUISITION")
                            color: CompanyTheme.textPrimary
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                            font.letterSpacing: 0.5
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        StatusBadge {
                            text: companyFlightLogManager.onboardSyncStatus
                            badgeColor: root.getStatusColor(companyFlightLogManager.onboardSyncStatus)
                            showDot: true
                            pulse: root._downloading || root._requestingList
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: CompanyTheme.spacingLg

                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text {
                                    text: qsTr("Safety Lockout:")
                                    color: CompanyTheme.textMuted
                                    font.pointSize: CompanyTheme.fontTiny
                                }
                                Text {
                                    text: root._isArmed ? qsTr("ACTIVE — Heavy downloads inhibited during flight") : qsTr("STANDBY — Post-flight sync armed")
                                    color: root._isArmed ? CompanyTheme.warning : CompanyTheme.success
                                    font.pointSize: CompanyTheme.fontTiny
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text {
                                    text: qsTr("Storage:")
                                    color: CompanyTheme.textMuted
                                    font.pointSize: CompanyTheme.fontTiny
                                }
                                Text {
                                    text: companyFlightLogManager.onboardLogSavePath
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: CompanyTheme.fontTiny
                                    font.family: CompanyTheme.fontMono
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        CompanyButton {
                            text: qsTr("Open Folder")
                            isOutline: true
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            onClicked: companyFlightLogManager.openLogDirectory()
                        }
                    }
                }
            }
        }

        // ====================================================================
        // 3. ACTIVE DOWNLOAD PROGRESS / SAFETY BANNER
        // ====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            visible: root._downloading
            radius: CompanyTheme.radiusSm
            color: Qt.rgba(CompanyTheme.primary.r, CompanyTheme.primary.g, CompanyTheme.primary.b, 0.15)
            border.color: CompanyTheme.primary
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: CompanyTheme.spacingMd
                anchors.rightMargin: CompanyTheme.spacingMd
                spacing: CompanyTheme.spacingSm

                IconVector {
                    name: "signal"
                    size: 14
                    color: CompanyTheme.primary
                }

                Text {
                    text: qsTr("Automated onboard log acquisition in progress — verified transfer to local archive.")
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.bold: true
                    Layout.fillWidth: true
                }

                // High-Speed Burst indicator pill
                Rectangle {
                    visible: companyFlightLogManager.fastEthernetMode
                    Layout.preferredHeight: 22
                    radius: CompanyTheme.radiusSm
                    color: Qt.rgba(CompanyTheme.success.r, CompanyTheme.success.g, CompanyTheme.success.b, 0.2)
                    border.color: CompanyTheme.success
                    border.width: 1
                    implicitWidth: burstText.implicitWidth + 12

                    Text {
                        id: burstText
                        anchors.centerIn: parent
                        text: qsTr("HIGH SPEED ETHERNET")
                        color: CompanyTheme.success
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                    }
                }

                // Live Speed & ETA Badge
                Text {
                    visible: companyFlightLogManager.downloadSpeedStr !== ""
                    text: qsTr("Rate: %1").arg(companyFlightLogManager.downloadSpeedStr)
                    color: CompanyTheme.primary
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }

                Text {
                    visible: companyFlightLogManager.downloadEtaStr !== ""
                    text: qsTr("ETA: %1").arg(companyFlightLogManager.downloadEtaStr)
                    color: CompanyTheme.warning
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: true
                }

                Text {
                    text: qsTr("Transfers: %1").arg(root._selectedCount > 0 ? root._selectedCount : 1)
                    color: CompanyTheme.textSecondary
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                }
            }
        }

        // ====================================================================
        // 4. ACTION TOOLBAR & VIEW FILTERS
        // ====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: CompanyTheme.radiusSm
            color: CompanyTheme.bgCard
            border.color: CompanyTheme.borderCard
            border.width: 1
            clip: true

            Flickable {
                anchors.fill: parent
                contentWidth: Math.max(parent.width, actionToolbarLayout.implicitWidth + 24)
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                RowLayout {
                    id: actionToolbarLayout
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: CompanyTheme.spacingMd
                    spacing: CompanyTheme.spacingSm

                // Refresh / Query Button
                CompanyButton {
                    text: root._requestingList ? qsTr("Querying...") : qsTr("Refresh / Sync")
                    isOutline: true
                    enabled: !root._requestingList && !root._downloading && root._hasVehicle && !root._isArmed
                    onClicked: {
                        if (!root._hasVehicle) {
                            QGroundControl.showMessageDialog(root, qsTr("Flight Logs"), qsTr("Connect to an autopilot to query onboard logs."))
                            return
                        }
                        companyFlightLogManager.refresh()
                    }
                }

                // Select All / Deselect All Toggle Button
                CompanyButton {
                    text: companyFlightLogManager.allLogsSelected ? qsTr("Deselect All") : qsTr("Select All")
                    isOutline: true
                    enabled: !root._requestingList && !root._downloading && root._logCount > 0
                    onClicked: companyFlightLogManager.selectAll(!companyFlightLogManager.allLogsSelected)
                }

                // Download Selected Button
                CompanyButton {
                    text: root._selectedCount > 0 ? qsTr("Download Selected (%1)").arg(root._selectedCount) : qsTr("Download Selected")
                    enabled: !root._requestingList && !root._downloading && root._selectedCount > 0 && root._hasVehicle && !root._isArmed
                    onClicked: companyFlightLogManager.downloadSelected()
                }

                // Direct High-Speed Ethernet Offload (HTTP/TCP Wire Speed)
                CompanyButton {
                    text: qsTr("Direct Eth Offload")
                    isOutline: true
                    enabled: !root._requestingList && !root._downloading && root._hasVehicle && !root._isArmed
                    onClicked: companyFlightLogManager.downloadDirectEthernet(-1)
                }

                // Fast Ethernet Burst Mode Toggle
                CompanyButton {
                    text: companyFlightLogManager.fastEthernetMode ? qsTr("Fast Eth: ON") : qsTr("Fast Eth: OFF")
                    isOutline: !companyFlightLogManager.fastEthernetMode
                    onClicked: companyFlightLogManager.setFastEthernetMode(!companyFlightLogManager.fastEthernetMode)
                }

                // Cancel Active Action Button
                CompanyButton {
                    text: qsTr("Cancel")
                    isOutline: true
                    visible: root._requestingList || root._downloading
                    enabled: root._requestingList || root._downloading
                    onClicked: companyFlightLogManager.cancel()
                }

                // Divider
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 22
                    color: CompanyTheme.borderSubtle
                }

                // Filter Pills: All / Onboard / Telemetry
                RowLayout {
                    spacing: 4

                    Rectangle {
                        implicitWidth: filterAllText.implicitWidth + 16
                        implicitHeight: 28
                        radius: CompanyTheme.radiusSm
                        color: root.filterMode === "all" ? CompanyTheme.primaryDim : "transparent"
                        border.color: root.filterMode === "all" ? CompanyTheme.primary : CompanyTheme.borderCard
                        border.width: 1

                        Text {
                            id: filterAllText
                            anchors.centerIn: parent
                            text: qsTr("All Logs")
                            color: root.filterMode === "all" ? CompanyTheme.primary : CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.filterMode = "all"
                        }
                    }

                    Rectangle {
                        implicitWidth: filterOnboardText.implicitWidth + 16
                        implicitHeight: 28
                        radius: CompanyTheme.radiusSm
                        color: root.filterMode === "onboard" ? CompanyTheme.primaryDim : "transparent"
                        border.color: root.filterMode === "onboard" ? CompanyTheme.primary : CompanyTheme.borderCard
                        border.width: 1

                        Text {
                            id: filterOnboardText
                            anchors.centerIn: parent
                            text: qsTr("Onboard Only")
                            color: root.filterMode === "onboard" ? CompanyTheme.primary : CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.filterMode = "onboard"
                        }
                    }

                    Rectangle {
                        implicitWidth: filterTelemetryText.implicitWidth + 16
                        implicitHeight: 28
                        radius: CompanyTheme.radiusSm
                        color: root.filterMode === "telemetry" ? CompanyTheme.primaryDim : "transparent"
                        border.color: root.filterMode === "telemetry" ? CompanyTheme.primary : CompanyTheme.borderCard
                        border.width: 1

                        Text {
                            id: filterTelemetryText
                            anchors.centerIn: parent
                            text: qsTr("Telemetry Only")
                            color: root.filterMode === "telemetry" ? CompanyTheme.primary : CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.filterMode = "telemetry"
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Transport Mode Badge (MAVLink FTP vs MAVLink Messages)
                Rectangle {
                    visible: root._hasVehicle && root._logCount > 0
                    Layout.preferredHeight: 28
                    radius: CompanyTheme.radiusSm
                    color: CompanyTheme.bgCardSecondary
                    border.color: CompanyTheme.borderCard
                    border.width: 1
                    implicitWidth: transportText.implicitWidth + 16

                    Text {
                        id: transportText
                        anchors.centerIn: parent
                        text: OnboardLogController.transport === "ftp" ? qsTr("TRANSPORT: MAVLINK FTP (FAST)") : qsTr("TRANSPORT: MAVLINK MSGS")
                        color: OnboardLogController.transport === "ftp" ? CompanyTheme.success : CompanyTheme.warning
                        font.pointSize: CompanyTheme.fontTiny
                        font.bold: true
                        font.family: CompanyTheme.fontMono
                    }
                }
            }
        }
    }

        // ====================================================================
        // 5. MAIN LOG TABLE CONTAINER
        // ====================================================================
        Rectangle {
            id: tableCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: CompanyTheme.radiusMd
            color: CompanyTheme.bgCard
            border.color: CompanyTheme.borderCard
            border.width: 1
            clip: true

            Flickable {
                anchors.fill: parent
                contentWidth: Math.max(parent.width, 920)
                contentHeight: parent.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    width: Math.max(tableCard.width, 920)
                    height: tableCard.height
                    spacing: 0

                // ------------------------------------------------------------
                // Table Column Headers
                // ------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: CompanyTheme.bgCardSecondary
                    border.color: CompanyTheme.borderCard
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: CompanyTheme.spacingMd
                        anchors.rightMargin: CompanyTheme.spacingMd
                        spacing: CompanyTheme.spacingSm

                        // Checkbox Header
                        Text {
                            Layout.preferredWidth: 32
                            text: ""
                        }

                        // UAS & Log ID Column
                        Text {
                            Layout.preferredWidth: 100
                            text: qsTr("SOURCE / ID")
                            color: CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                            font.letterSpacing: 0.5
                        }

                        // Log Type Column
                        Text {
                            Layout.preferredWidth: 130
                            text: qsTr("FORMAT / TYPE")
                            color: CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                            font.letterSpacing: 0.5
                        }

                        // Date & Time Column
                        Text {
                            Layout.preferredWidth: 180
                            text: qsTr("RECORDED TIMESTAMP")
                            color: CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                            font.letterSpacing: 0.5
                        }

                        // File Size Column
                        Text {
                            Layout.preferredWidth: 110
                            text: qsTr("FILE SIZE")
                            color: CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                            font.letterSpacing: 0.5
                        }

                        // Status Column
                        Text {
                            Layout.preferredWidth: 180
                            text: qsTr("LIFECYCLE STATUS")
                            color: CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                            font.letterSpacing: 0.5
                        }

                        // Integrity & Local Path Column
                        Text {
                            Layout.fillWidth: true
                            text: qsTr("INTEGRITY & LOCAL ARCHIVE PATH")
                            color: CompanyTheme.textMuted
                            font.pointSize: CompanyTheme.fontTiny
                            font.bold: true
                            font.letterSpacing: 0.5
                        }
                    }
                }

                // ------------------------------------------------------------
                // Table Rows / Empty State Views
                // ------------------------------------------------------------
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // State A: Disconnected State
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: CompanyTheme.spacingSm
                        visible: !root._hasVehicle && root._logCount === 0

                        IconVector {
                            Layout.alignment: Qt.AlignHCenter
                            name: "signal"
                            size: 40
                            color: CompanyTheme.textMuted
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("NO VEHICLE CONNECTED")
                            color: CompanyTheme.textPrimary
                            font.pointSize: CompanyTheme.fontH2
                            font.bold: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Connect UAS via telemetry link to access autonomous flight log acquisition.")
                            color: CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontSmall
                        }
                    }

                    // State C: Querying Log Directory
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: CompanyTheme.spacingSm
                        visible: root._hasVehicle && root._requestingList

                        StatusBadge {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("QUERYING ONBOARD LOG CATALOG...")
                            badgeColor: CompanyTheme.warning
                            showDot: true
                            pulse: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Requesting log index from connected flight controller...")
                            color: CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontSmall
                        }
                    }

                    // State B: Connected, but zero logs received
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: CompanyTheme.spacingSm
                        visible: root._hasVehicle && !root._requestingList && root._logCount === 0

                        IconVector {
                            Layout.alignment: Qt.AlignHCenter
                            name: "logs"
                            size: 38
                            color: CompanyTheme.textMuted
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("NO FLIGHT LOGS FOUND")
                            color: CompanyTheme.textPrimary
                            font.pointSize: CompanyTheme.fontH2
                            font.bold: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Autopilot memory has no recorded flight logs or catalog query has not completed.")
                            color: CompanyTheme.textSecondary
                            font.pointSize: CompanyTheme.fontSmall
                        }

                        Item { Layout.preferredHeight: 4 }

                        CompanyButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Query Autopilot Logs")
                            isOutline: true
                            onClicked: companyFlightLogManager.refresh()
                        }
                    }

                    // Logs List View
                    ListView {
                        id: logListView
                        anchors.fill: parent
                        visible: root._logCount > 0
                        clip: true
                        model: companyFlightLogManager.logEntries
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: rowDelegate
                            required property var object
                            required property int index

                            visible: {
                                if (root.filterMode === "onboard") return rowDelegate.object.isOnboard
                                if (root.filterMode === "telemetry") return rowDelegate.object.isTelemetry
                                return true
                            }

                            width: logListView.width
                            height: visible ? 42 : 0
                            color: {
                                if (rowDelegate.object.selected) {
                                    return Qt.rgba(CompanyTheme.primary.r, CompanyTheme.primary.g, CompanyTheme.primary.b, 0.12)
                                }
                                return rowMouseArea.containsMouse ? CompanyTheme.bgCardHover : (index % 2 === 0 ? "transparent" : CompanyTheme.bgCardSecondary)
                            }

                            // Subtle bottom divider
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: CompanyTheme.borderSubtle
                            }

                            MouseArea {
                                id: rowMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !root._downloading && rowDelegate.object.isOnboard
                                onClicked: {
                                    rowDelegate.object.selected = !rowDelegate.object.selected
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: CompanyTheme.spacingMd
                                anchors.rightMargin: CompanyTheme.spacingMd
                                spacing: CompanyTheme.spacingSm

                                // Checkbox Column
                                Item {
                                    Layout.preferredWidth: 32
                                    Layout.fillHeight: true

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 16
                                        height: 16
                                        radius: 3
                                        visible: rowDelegate.object.isOnboard
                                        color: rowDelegate.object.selected ? CompanyTheme.primary : "transparent"
                                        border.color: rowDelegate.object.selected ? CompanyTheme.primary : CompanyTheme.borderCard
                                        border.width: 1.5

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✓"
                                            color: CompanyTheme.textLight
                                            font.pixelSize: 11
                                            font.bold: true
                                            visible: rowDelegate.object.selected
                                        }
                                    }
                                }

                                // UAS & Log ID Column
                                Text {
                                    Layout.preferredWidth: 100
                                    text: {
                                        if (rowDelegate.object.isTelemetry) {
                                            return "UAS #" + rowDelegate.object.uasId + " (TLOG)"
                                        }
                                        return "UAS #" + rowDelegate.object.uasId + " - #" + rowDelegate.object.logId
                                    }
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: CompanyTheme.fontSmall
                                    font.family: CompanyTheme.fontMono
                                    font.bold: true
                                }

                                // Format / Type Column
                                Rectangle {
                                    Layout.preferredWidth: 130
                                    Layout.preferredHeight: 22
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgCardSecondary
                                    border.color: CompanyTheme.borderCard
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: rowDelegate.object.logType
                                        color: rowDelegate.object.isTelemetry ? CompanyTheme.info : CompanyTheme.textSecondary
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.family: CompanyTheme.fontMono
                                        font.bold: true
                                    }
                                }

                                // Date & Time Column
                                Text {
                                    Layout.preferredWidth: 180
                                    text: {
                                        var dt = rowDelegate.object.timestamp
                                        if (!dt || isNaN(dt.getTime()) || dt.getFullYear() < 2015) {
                                            return qsTr("Date Unknown")
                                        }
                                        return dt.toLocaleString(Qt.locale(), "yyyy-MM-dd HH:mm:ss")
                                    }
                                    color: CompanyTheme.textSecondary
                                    font.pointSize: CompanyTheme.fontSmall
                                    font.family: CompanyTheme.fontMono
                                }

                                // File Size Column
                                Text {
                                    Layout.preferredWidth: 110
                                    text: rowDelegate.object.fileSizeStr
                                    color: CompanyTheme.textPrimary
                                    font.pointSize: CompanyTheme.fontSmall
                                    font.family: CompanyTheme.fontMono
                                    font.bold: true
                                }

                                // Status Column (All 10 required states supported)
                                Rectangle {
                                    Layout.preferredWidth: 180
                                    Layout.preferredHeight: 22
                                    radius: CompanyTheme.radiusSm
                                    color: {
                                        var col = root.getStatusColor(rowDelegate.object.status)
                                        return Qt.rgba(col.r, col.g, col.b, 0.15)
                                    }
                                    border.color: root.getStatusColor(rowDelegate.object.status)
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Rectangle {
                                            Layout.preferredWidth: 6
                                            Layout.preferredHeight: 6
                                            radius: 3
                                            color: root.getStatusColor(rowDelegate.object.status)
                                            visible: rowDelegate.object.status === "RECORDING" || rowDelegate.object.status === "DOWNLOADING"

                                            SequentialAnimation on opacity {
                                                running: true
                                                loops: Animation.Infinite
                                                NumberAnimation { from: 1.0; to: 0.2; duration: 700; easing.type: Easing.InOutQuad }
                                                NumberAnimation { from: 0.2; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                                            }
                                        }

                                        Text {
                                            text: rowDelegate.object.status.toUpperCase()
                                            color: root.getStatusColor(rowDelegate.object.status)
                                            font.pointSize: CompanyTheme.fontTiny
                                            font.bold: true
                                            font.letterSpacing: 0.4
                                        }
                                    }
                                }

                                // Integrity & Local Archive Path Column
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: CompanyTheme.spacingSm

                                    // Integrity Badge
                                    Rectangle {
                                        Layout.preferredHeight: 20
                                        radius: CompanyTheme.radiusSm
                                        color: {
                                            var ist = (rowDelegate.object.integrityStatus || "").toLowerCase()
                                            if (ist.indexOf("verified") !== -1) return Qt.rgba(CompanyTheme.success.r, CompanyTheme.success.g, CompanyTheme.success.b, 0.18)
                                            if (ist.indexOf("fail") !== -1) return Qt.rgba(CompanyTheme.danger.r, CompanyTheme.danger.g, CompanyTheme.danger.b, 0.18)
                                            return Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.18)
                                        }
                                        border.color: {
                                            var ist = (rowDelegate.object.integrityStatus || "").toLowerCase()
                                            if (ist.indexOf("verified") !== -1) return CompanyTheme.success
                                            if (ist.indexOf("fail") !== -1) return CompanyTheme.danger
                                            return CompanyTheme.warning
                                        }
                                        border.width: 1
                                        implicitWidth: integrityText.implicitWidth + 12

                                        Text {
                                            id: integrityText
                                            anchors.centerIn: parent
                                            text: rowDelegate.object.integrityStatus
                                            color: {
                                                var ist = (rowDelegate.object.integrityStatus || "").toLowerCase()
                                                if (ist.indexOf("verified") !== -1) return CompanyTheme.success
                                                if (ist.indexOf("fail") !== -1) return CompanyTheme.danger
                                                return CompanyTheme.warning
                                            }
                                            font.pointSize: CompanyTheme.fontTiny
                                            font.bold: true
                                        }
                                    }

                                    // Local File Path Display
                                    Text {
                                        Layout.fillWidth: true
                                        text: {
                                            var lp = rowDelegate.object.localFilePath
                                            if (lp && lp.length > 0) return lp
                                            return qsTr("On Autopilot Flash Memory")
                                        }
                                        color: rowDelegate.object.localFilePath ? CompanyTheme.textPrimary : CompanyTheme.textMuted
                                        font.pointSize: CompanyTheme.fontTiny
                                        font.family: CompanyTheme.fontMono
                                        elide: Text.ElideMiddle
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
