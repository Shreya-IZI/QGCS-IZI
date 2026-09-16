pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtMultimedia
import QGroundControl
import QGroundControl.Controls
import Company.UI

ApplicationWindow {
    id: mainWindow

    title: "COMPANY GCS - Enterprise Flight Control"
    visible: true
    width: 1280
    height: 800
    minimumWidth: 960
    minimumHeight: 600

    color: CompanyTheme.bgApp

    // ------------------------------------------------------------------------
    // Global Scope Objects & Functions (Required by QGC Dialogs & Controls)
    // ------------------------------------------------------------------------
    QtObject {
        id: globals

        readonly property var  activeVehicle:            QGroundControl.multiVehicleManager.activeVehicle
        property int           validationErrorCount:     0
        property string        navigationBlockedReason:  ""
        property bool          commingFromRIDIndicator:  false
    }

    function allowViewSwitch(previousValidationErrorCount, showErrorOnDisallow) {
        if (globals.navigationBlockedReason !== "") {
            return false
        }
        var prev = (previousValidationErrorCount !== undefined && previousValidationErrorCount !== null) ? previousValidationErrorCount : 0
        return globals.validationErrorCount <= prev
    }

    // ------------------------------------------------------------------------
    // Global Application Message Dialogs (Invoked by QGCApplication C++)
    // ------------------------------------------------------------------------
    function _showMessageDialogWorker(owner, dialogTitle, dialogText, buttons, acceptFunction, closeFunction) {
        var dialog = simpleMessageDialogComponent.createObject(owner, {
            title: dialogTitle,
            text: dialogText,
            buttons: (buttons !== undefined && buttons !== null) ? buttons : Dialog.Ok,
            acceptFunction: (acceptFunction !== undefined) ? acceptFunction : null,
            closeFunction: (closeFunction !== undefined) ? closeFunction : null
        })
        if (dialog) {
            dialog.open()
        }
    }

    function _showMessageDialog(dialogTitle, dialogText) {
        _showMessageDialogWorker(mainWindow, dialogTitle, dialogText)
    }

    function _showRebootVehicleDialog(dialogTitle, dialogText) {
        _showMessageDialogWorker(mainWindow, dialogTitle,
            dialogText + " " + qsTr("Click Ok to reboot the vehicle now."),
            Dialog.Ok | Dialog.Cancel,
            function() {
                var activeVehicle = QGroundControl.multiVehicleManager.activeVehicle
                if (activeVehicle) {
                    activeVehicle.rebootVehicle()
                }
            })
    }

    Connections {
        target: QGroundControl
        function onShowMessageDialogRequested(owner, title, text, buttons, acceptFunction, closeFunction) {
            mainWindow._showMessageDialogWorker(owner ? owner : mainWindow, title, text, buttons, acceptFunction, closeFunction)
        }
    }

    Component {
        id: simpleMessageDialogComponent
        QGCSimpleMessageDialog { }
    }

    // ------------------------------------------------------------------------
    // VideoManager Pipeline Sinks (Required by QGC VideoManager initialization)
    // ------------------------------------------------------------------------
    Item {
        id: videoSinkHost
        visible: false
        width: 0
        height: 0

        VideoOutput {
            objectName: "videoContent"
            visible: false
        }

        VideoOutput {
            objectName: "thermalVideo"
            visible: false
        }
    }

    // ------------------------------------------------------------------------
    // Mission Control Top Status Header
    // ------------------------------------------------------------------------
    TopBar {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        z: 10
    }

    // ------------------------------------------------------------------------
    // Main Workspace Layout (Sidebar + Content View)
    // ------------------------------------------------------------------------
    RowLayout {
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        // Navigation Sidebar
        Sidebar {
            id: sidebar
            Layout.fillHeight: true
            currentTab: 1
            onTabSelected: (index) => {
                contentArea.switchTab(index)
            }
        }

        // Central Content Area
        Item {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            function switchTab(index) {
                sidebar.currentTab = index
                viewStack.currentIndex = index
                if (index === 0) {
                    dashboardView.currentSubView = "PFD"
                } else if (index === 1) {
                    dashboardView.currentSubView = "MAP"
                }
            }

            // Single unified DashboardView instance for Flight Operations (Tabs 0 & 1)
            DashboardView {
                id: dashboardView
                anchors.fill: parent
                visible: sidebar.currentTab === 0 || sidebar.currentTab === 1
                Component.onCompleted: dashboardView.navigateToTab.connect(contentArea.switchTab)
            }

            Connections {
                target: dashboardView
                function onCurrentSubViewChanged() {
                    if (sidebar.currentTab === 0 || sidebar.currentTab === 1) {
                        if (dashboardView.currentSubView === "PFD") {
                            sidebar.currentTab = 0
                        } else if (dashboardView.currentSubView === "MAP") {
                            sidebar.currentTab = 1
                        }
                    }
                }
            }

            StackLayout {
                id: viewStack
                anchors.fill: parent
                anchors.margins: 0
                currentIndex: sidebar.currentTab
                visible: sidebar.currentTab >= 2

                // Tab 0 & 1: Lightweight placeholders (DashboardView is rendered above)
                Item { id: tab0Placeholder }
                Item { id: tab1Placeholder }

                // Tab 2: Mission Planning
                MissionPlannerView {
                    id: missionsView
                }

                // Tab 3: Fleet Management
                Placeholders {
                    id: fleetView
                    pageTitle: "Fleet Management"
                    pageSubtitle: "Multi-vehicle tracking, swarm telemetry & UAS asset allocation"
                    iconName: "fleet"
                    moduleTag: "FLEET"
                    Component.onCompleted: fleetView.navigateToTab.connect(contentArea.switchTab)
                }

                // Tab 4: Flight Logs & Dataflash
                Placeholders {
                    id: logsView
                    pageTitle: "Flight Logs & Analysis"
                    pageSubtitle: "ULog parser, telemetry graphs & flight dataflash inspection"
                    iconName: "logs"
                    moduleTag: "ULOG"
                    Component.onCompleted: logsView.navigateToTab.connect(contentArea.switchTab)
                }

                // Tab 5: System Settings
                Placeholders {
                    id: settingsView
                    pageTitle: "System Settings"
                    pageSubtitle: "Communication links, radio configurations & GCS preferences"
                    iconName: "settings"
                    moduleTag: "CONFIG"
                    Component.onCompleted: settingsView.navigateToTab.connect(contentArea.switchTab)
                }
            }
        }
    }
}
