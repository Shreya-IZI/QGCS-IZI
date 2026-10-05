pragma ComponentBehavior: Bound
// qmllint disable unqualified

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtMultimedia
import QtCore as QtSys
import QGroundControl
import QGroundControl.Controls
import Company.UI

ApplicationWindow {
    id: mainWindow

    title: "IZI GCS - Enterprise Flight Control"
    visible: true
    width: ScreenTools.isMobile ? 860 : 1280
    height: ScreenTools.isMobile ? 450 : 800
    minimumWidth: ScreenTools.isMobile ? 360 : 640
    minimumHeight: ScreenTools.isMobile ? 240 : 400

    color: CompanyTheme.bgApp

    readonly property bool _isNarrow: width < 1024 || ScreenTools.isMobile

    // ------------------------------------------------------------------------
    // Persistent App Settings (QtCore.Settings)
    // ------------------------------------------------------------------------
    QtSys.Settings {
        id: appSettings
        category: "IZI_GCS"
        property bool onboardingComplete: false
    }

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
    // Mission Control Top Status Header
    // ------------------------------------------------------------------------
    TopBar {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        z: 10
        onTabRequested: (tabIndex) => {
            contentArea.switchTab(tabIndex)
        }
        onToggleDrawerRequested: () => {
            navDrawer.isOpen = !navDrawer.isOpen
        }
        onShowUserGuideRequested: () => {
            onboardingLoader.active = true
        }
    }

    // ------------------------------------------------------------------------
    // Main Workspace Layout
    // ------------------------------------------------------------------------
    Item {
        id: workspaceRoot
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        // Drawer controller state
        QtObject {
            id: navDrawer
            property bool isOpen: false
        }

        // --------------------------------------------------------------------
        // Central Content Area
        // On mobile/narrow: occupies full screen width.
        // On desktop: positioned to the right of the docked sidebar.
        // --------------------------------------------------------------------
        Item {
            id: contentArea
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: mainWindow._isNarrow ? parent.left : sidebar.right
            anchors.right: parent.right

            function switchTab(index) {
                sidebar.currentTab = index
                viewStack.currentIndex = index
                if (index <= 1) {
                    sidebar.activeSection = "OPERATIONS"
                    sidebar.activeTool = -1
                    sidebar.activeVehicleItem = -1
                    if (index === 0) {
                        dashboardView.currentSubView = "PFD"
                    }
                } else if (index === 6 || index === 7) {
                    sidebar.activeSection = "VEHICLE"
                    sidebar.activeVehicleItem = index
                    sidebar.activeTool = -1
                } else {
                    sidebar.activeSection = "TOOLS"
                    sidebar.activeTool = index
                    sidebar.activeVehicleItem = -1
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
                    sidebar.activeSubView = dashboardView.currentSubView
                    if (sidebar.currentTab >= 2) {
                        contentArea.switchTab(1)
                    }
                }
            }

            StackLayout {
                id: viewStack
                anchors.fill: parent
                anchors.margins: 0
                currentIndex: sidebar.currentTab
                visible: sidebar.currentTab >= 2

                // Tab 0 & 1: Placeholders (DashboardView is rendered above)
                Item { id: tab0Placeholder }
                Item { id: tab1Placeholder }

                // Tab 2: Mission Planning
                MissionPlannerView {
                    id: missionsView
                    onFlightActionRequested: (actionType) => {
                        contentArea.switchTab(1)
                        dashboardView.requestActionConfirmation(actionType)
                    }
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
                FlightLogsView {
                    id: logsView
                }

                // Tab 5: System Settings & Telemetry
                SettingsView {
                    id: settingsView
                }

                // Tab 6: Parameters & Flight Controller Tuning
                Item {
                    id: parametersPage
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Loader {
                        id: parametersLoader
                        anchors.fill: parent
                        active: sidebar.currentTab === 6 || item !== null
                        source: "ParametersView.qml"
                    }
                }

                // Tab 7: Vehicle Setup & Hardware Calibration
                Item {
                    id: vehicleSetupPage
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Loader {
                        id: vehicleConfigLoader
                        anchors.fill: parent
                        active: sidebar.currentTab === 7
                        source: "qrc:/qml/QGroundControl/VehicleSetup/VehicleConfigView.qml"
                    }
                }
            }
        }

        // --------------------------------------------------------------------
        // Mobile Edge Tap Opener (Thin strip along left edge to open drawer)
        // --------------------------------------------------------------------
        MouseArea {
            id: edgeSwipeArea
            visible: mainWindow._isNarrow && !navDrawer.isOpen
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 20
            z: 50
            onClicked: navDrawer.isOpen = true
        }

        // --------------------------------------------------------------------
        // Dimming Backdrop (Tap outside to close drawer on mobile)
        // --------------------------------------------------------------------
        Rectangle {
            id: drawerBackdrop
            visible: mainWindow._isNarrow && (navDrawer.isOpen || sidebar.x > -sidebar.width)
            anchors.fill: parent
            color: "#CC000000"
            opacity: navDrawer.isOpen ? 1.0 : 0.0
            z: 180

            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: navDrawer.isOpen = false
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 16
                text: "✕ TAP TO CLOSE"
                color: "#80FFFFFF"
                font.pointSize: 9
                font.bold: true
                font.letterSpacing: 1.2
            }
        }

        // --------------------------------------------------------------------
        // Unified Navigation Sidebar
        // - Desktop mode: docked on left (x = 0, z = 1).
        // - Mobile/Narrow mode: overlay Drawer (slides between -width and 0, z = 200).
        // --------------------------------------------------------------------
        Sidebar {
            id: sidebar
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            // Absolutely NO anchors.left here!
            x: mainWindow._isNarrow ? (navDrawer.isOpen ? 0 : -sidebar.width) : 0
            z: mainWindow._isNarrow ? 200 : 1
            visible: !mainWindow._isNarrow || navDrawer.isOpen || x > -sidebar.width
            isExpanded: mainWindow._isNarrow ? true : isExpanded

            Behavior on x {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            currentTab: 1
            activeSubView: dashboardView.currentSubView

            onCloseRequested: {
                navDrawer.isOpen = false
            }

            onTabSelected: (index) => {
                if (mainWindow._isNarrow) navDrawer.isOpen = false
                contentArea.switchTab(index)
            }
            onSubViewSelected: (viewId) => {
                if (mainWindow._isNarrow) navDrawer.isOpen = false
                dashboardView.currentSubView = viewId
                contentArea.switchTab(1)
            }
            onFlightActionRequested: (actionType) => {
                if (mainWindow._isNarrow) navDrawer.isOpen = false
                contentArea.switchTab(1)
                dashboardView.requestActionConfirmation(actionType)
            }
            onToolSelected: (tabIndex) => {
                if (mainWindow._isNarrow) navDrawer.isOpen = false
                contentArea.switchTab(tabIndex)
            }
            onVehicleItemSelected: (tabIndex) => {
                if (mainWindow._isNarrow) navDrawer.isOpen = false
                contentArea.switchTab(tabIndex)
            }
        }
    }

    // ------------------------------------------------------------------------
    // First-Run / Field Onboarding Guide Overlay
    // ------------------------------------------------------------------------
    Loader {
        id: onboardingLoader
        anchors.fill: parent
        z: 500
        active: false
        source: "OnboardingGuide.qml"
    }

    Component.onCompleted: {
        if (!appSettings.onboardingComplete) {
            onboardingLoader.active = true
        }
    }

    Connections {
        target: onboardingLoader.item
        function onDismissed() {
            appSettings.onboardingComplete = true
            onboardingLoader.active = false
        }
        ignoreUnknownSignals: true
    }
}
