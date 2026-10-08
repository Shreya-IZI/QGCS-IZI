// qmllint disable unqualified

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import Company.UI

Rectangle {
    id: root
    anchors.fill: parent

    color: CompanyTheme.bgApp

    readonly property var  _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool _hasVehicle:    _activeVehicle !== null
    readonly property bool _paramsReady:   _hasVehicle && _activeVehicle.parameterManager && _activeVehicle.parameterManager.parametersReady
    readonly property bool _showRCToParam: _hasVehicle && _activeVehicle.px4Firmware
    readonly property var  _appSettings:   QGroundControl.settingsManager.appSettings

    property Fact   selectedFact:       null
    property string candidateValue:     ""
    property int    candidateEnumIndex: -1
    property string validationError:    ""
    property bool   advancedChecked:    false
    property bool   forceSaveChecked:   false
    property bool   forceEditChecked:   false

    readonly property bool _isNarrow: width < 1024 || ScreenTools.isMobile
    property bool showCategoriesOnMobile: false

    readonly property bool isSearching: controller.searchText.trim() !== "" || controller.showModifiedOnly || controller.showFavoritesOnly

    readonly property string constraintsString: {
        if (!selectedFact) return ""
        var parts = []
        if (!selectedFact.minIsDefaultForType && selectedFact.minString !== "") {
            parts.push("Min: " + selectedFact.minString)
        }
        if (!selectedFact.maxIsDefaultForType && selectedFact.maxString !== "") {
            parts.push("Max: " + selectedFact.maxString)
        }
        if (selectedFact.defaultValueAvailable && selectedFact.defaultValueString !== "") {
            parts.push("Default: " + selectedFact.defaultValueString)
        }
        return parts.join("  ")
    }

    onSelectedFactChanged: {
        validationError = ""
        advancedChecked = false
        forceSaveChecked = false
        forceEditChecked = false
        if (selectedFact) {
            candidateValue = selectedFact.valueString
            candidateEnumIndex = selectedFact.enumIndex
        } else {
            candidateValue = ""
            candidateEnumIndex = -1
        }
    }

    ParameterEditorController {
        id: controller
    }

    function applySelectedFact() {
        if (!selectedFact) return
        if (selectedFact.readOnly && !forceEditChecked) return

        if (selectedFact.enumStrings && selectedFact.enumStrings.length > 0 && selectedFact.bitmaskStrings.length === 0) {
            selectedFact.enumIndex = candidateEnumIndex
            selectedFact = null
            return
        }

        var err = selectedFact.validate(candidateValue, forceSaveChecked)
        if (err === "") {
            selectedFact.value = candidateValue
            selectedFact.valueChanged(selectedFact.value)
            selectedFact = null
        } else {
            validationError = err
        }
    }

    function resetSelectedFactToDefault() {
        if (!selectedFact || !selectedFact.defaultValueAvailable) return
        if (selectedFact.enumStrings && selectedFact.enumStrings.length > 0) {
            var defaultStr = selectedFact.defaultValueString
            var idx = selectedFact.enumStrings.indexOf(defaultStr)
            if (idx >= 0) candidateEnumIndex = idx
        } else {
            candidateValue = selectedFact.defaultValueString
            if (editField) editField.text = candidateValue
        }
        validationError = ""
    }

    function ensureInitialSelection() {
        if (root.isSearching) return
        if (!controller.currentCategory && controller.categories && controller.categories.count > 0) {
            controller.currentCategory = controller.categories.get(0)
        }
        if (controller.currentCategory && !controller.currentGroup && controller.currentCategory.groups && controller.currentCategory.groups.count > 0) {
            controller.currentGroup = controller.currentCategory.groups.get(0)
        }
    }

    Component.onCompleted: {
        ensureInitialSelection()
    }

    Connections {
        target: controller
        function onCurrentCategoryChanged() {
            if (root.isSearching) return
            if (controller.currentCategory && controller.currentCategory.groups && controller.currentCategory.groups.count > 0) {
                if (!controller.currentGroup || controller.currentCategory.groups.indexOf(controller.currentGroup) === -1) {
                    controller.currentGroup = controller.currentCategory.groups.get(0)
                }
            }
        }
    }

    Connections {
        target: controller.categories
        function onCountChanged() {
            ensureInitialSelection()
        }
    }

    Connections {
        target: root._activeVehicle ? root._activeVehicle.parameterManager : null
        function onParametersReadyChanged() {
            if (root._paramsReady) {
                controller.refresh()
                ensureInitialSelection()
            }
        }
    }

    // ========================================================================
    // Tools Menu & Dialogs (Screenshot 4)
    // ========================================================================
    QGCMenu {
        id: toolsMenu

        QGCMenuItem {
            text: qsTr("Refresh")
            onTriggered: controller.refresh()
        }
        QGCMenuItem {
            text: qsTr("Reset all to defaults")
            onTriggered: QGroundControl.showMessageDialog(root, qsTr("Reset All"),
                qsTr("Select Reset to reset all parameters to their defaults.\n\nNote that this will also completely reset everything, including UAVCAN nodes, all vehicle settings, setup and calibrations."),
                Dialog.Cancel | Dialog.Reset,
                function() { controller.resetAllToDefaults() })
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            text: qsTr("Load from file...")
            onTriggered: {
                fileDialog.title = qsTr("Load Parameters")
                fileDialog.openForLoad()
            }
        }
        QGCMenuItem {
            text: qsTr("Save to file...")
            onTriggered: {
                fileDialog.title = qsTr("Save Parameters")
                fileDialog.openForSave()
            }
        }
        QGCMenuSeparator { visible: root._showRCToParam }
        QGCMenuItem {
            text: qsTr("Clear RC to Param")
            visible: root._showRCToParam
            onTriggered: {
                if (root._activeVehicle) {
                    root._activeVehicle.clearAllParamMapRC()
                }
            }
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            text: qsTr("Reboot Vehicle")
            onTriggered: QGroundControl.showMessageDialog(root, qsTr("Reboot Vehicle"),
                qsTr("Select Ok to reboot vehicle."),
                Dialog.Cancel | Dialog.Ok,
                function() {
                    if (root._activeVehicle) {
                        root._activeVehicle.rebootVehicle()
                    }
                })
        }
    }

    QGCFileDialog {
        id: fileDialog
        folder: root._appSettings ? root._appSettings.parameterSavePath : ""
        nameFilters: [
            qsTr("Parameter Files (*.%1)").arg(root._appSettings ? root._appSettings.parameterFileExtension : "params"),
            qsTr("Mission Planner Files (*.param)"),
            qsTr("All Files (*)")
        ]

        onAcceptedForSave: (file) => {
            controller.saveToFile(file)
            close()
        }

        onAcceptedForLoad: (file) => {
            close()
            if (controller.buildDiffFromFile(file)) {
                parameterDiffDialogFactory.open()
            }
        }
    }

    QGCPopupDialogFactory {
        id: parameterDiffDialogFactory
        dialogComponent: parameterDiffDialog
    }

    Component {
        id: parameterDiffDialog
        ParameterDiffDialog {
            paramController: controller
        }
    }

    // ========================================================================
    // Top Bar: Search: [   ] [Clear]                                   [Tools]
    // (Screenshots 1, 2, 3, 4)
    // ========================================================================
    Item {
        id: header
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        height: root._isNarrow ? 66 : 32

        ColumnLayout {
            anchors.fill: parent
            spacing: 6

            // Row 1: Search + Input + Clear + (desktop filter buttons) + Spacer + Tools
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 8

                Text {
                    text: qsTr("Search:")
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                }

                Rectangle {
                    Layout.fillWidth: root._isNarrow
                    Layout.preferredWidth: root._isNarrow ? -1 : 200
                    Layout.maximumWidth: root._isNarrow ? 360 : 200
                    Layout.preferredHeight: 28
                    radius: 3
                    color: CompanyTheme.bgInput
                    border.color: searchInput.activeFocus ? CompanyTheme.borderActive : CompanyTheme.borderCard

                    TextField {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        background: null
                        text: controller.searchText
                        onDisplayTextChanged: controller.searchText = displayText
                    }
                }

                Button {
                    id: clearBtn
                    text: qsTr("Clear")
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 54

                    contentItem: Text {
                        text: clearBtn.text
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 3
                        color: clearBtn.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                        border.color: CompanyTheme.borderCard
                    }

                    onClicked: {
                        searchInput.text = ""
                        controller.searchText = ""
                    }
                }

                // Desktop-only Filter Buttons
                Button {
                    id: modifiedOnlyBtn
                    visible: !root._isNarrow
                    text: qsTr("Modified")
                    checkable: true
                    checked: controller.showModifiedOnly
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 70

                    contentItem: Text {
                        text: modifiedOnlyBtn.text
                        color: modifiedOnlyBtn.checked ? CompanyTheme.warning : CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: modifiedOnlyBtn.checked
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 3
                        color: modifiedOnlyBtn.checked ? Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.18) : (modifiedOnlyBtn.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCard)
                        border.color: modifiedOnlyBtn.checked ? CompanyTheme.warning : CompanyTheme.borderCard
                    }

                    onClicked: {
                        controller.showModifiedOnly = !controller.showModifiedOnly
                    }
                }

                Button {
                    id: favoritesOnlyBtn
                    visible: !root._isNarrow
                    text: qsTr("★ Favorites")
                    checkable: true
                    checked: controller.showFavoritesOnly
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 86

                    contentItem: Text {
                        text: favoritesOnlyBtn.text
                        color: favoritesOnlyBtn.checked ? CompanyTheme.warning : CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: favoritesOnlyBtn.checked
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 3
                        color: favoritesOnlyBtn.checked ? Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.18) : (favoritesOnlyBtn.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCard)
                        border.color: favoritesOnlyBtn.checked ? CompanyTheme.warning : CompanyTheme.borderCard
                    }

                    onClicked: {
                        controller.showFavoritesOnly = !controller.showFavoritesOnly
                    }
                }

                Button {
                    id: hideReadOnlyBtn
                    visible: !root._isNarrow
                    text: qsTr("Hide Read-Only")
                    checkable: true
                    checked: controller.hideReadOnly
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 104

                    contentItem: Text {
                        text: hideReadOnlyBtn.text
                        color: hideReadOnlyBtn.checked ? CompanyTheme.primary : CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: hideReadOnlyBtn.checked
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 3
                        color: hideReadOnlyBtn.checked ? CompanyTheme.primaryDim : (hideReadOnlyBtn.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCard)
                        border.color: hideReadOnlyBtn.checked ? CompanyTheme.primary : CompanyTheme.borderCard
                    }

                    onClicked: {
                        controller.hideReadOnly = !controller.hideReadOnly
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    id: toolsBtn
                    text: qsTr("Tools")
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 64

                    contentItem: Text {
                        text: toolsBtn.text
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 3
                        color: toolsBtn.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                        border.color: CompanyTheme.borderCard
                    }

                    onClicked: toolsMenu.popup()
                }
            }

            // Row 2: Visible ONLY on mobile / narrow viewports
            RowLayout {
                visible: root._isNarrow
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                spacing: 6

                Button {
                    id: mobileCategoriesBtn
                    text: root.showCategoriesOnMobile ? qsTr("Hide Groups") : qsTr("Groups")
                    checkable: true
                    checked: root.showCategoriesOnMobile
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 88

                    contentItem: Text {
                        text: mobileCategoriesBtn.text
                        color: mobileCategoriesBtn.checked ? CompanyTheme.primary : CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: mobileCategoriesBtn.checked
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 3
                        color: mobileCategoriesBtn.checked ? CompanyTheme.primaryDim : (mobileCategoriesBtn.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCard)
                        border.color: mobileCategoriesBtn.checked ? CompanyTheme.primary : CompanyTheme.borderCard
                    }

                    onClicked: root.showCategoriesOnMobile = !root.showCategoriesOnMobile
                }

                Button {
                    id: mobileModifiedBtn
                    text: qsTr("Modified")
                    checkable: true
                    checked: controller.showModifiedOnly
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 74

                    contentItem: Text {
                        text: mobileModifiedBtn.text
                        color: mobileModifiedBtn.checked ? CompanyTheme.warning : CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: mobileModifiedBtn.checked
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 3
                        color: mobileModifiedBtn.checked ? Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.18) : (mobileModifiedBtn.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCard)
                        border.color: mobileModifiedBtn.checked ? CompanyTheme.warning : CompanyTheme.borderCard
                    }

                    onClicked: controller.showModifiedOnly = !controller.showModifiedOnly
                }

                Button {
                    id: mobileFavoritesBtn
                    text: qsTr("★ Favorites")
                    checkable: true
                    checked: controller.showFavoritesOnly
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 84

                    contentItem: Text {
                        text: mobileFavoritesBtn.text
                        color: mobileFavoritesBtn.checked ? CompanyTheme.warning : CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: mobileFavoritesBtn.checked
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 3
                        color: mobileFavoritesBtn.checked ? Qt.rgba(CompanyTheme.warning.r, CompanyTheme.warning.g, CompanyTheme.warning.b, 0.18) : (mobileFavoritesBtn.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCard)
                        border.color: mobileFavoritesBtn.checked ? CompanyTheme.warning : CompanyTheme.borderCard
                    }

                    onClicked: controller.showFavoritesOnly = !controller.showFavoritesOnly
                }

                Button {
                    id: mobileHideReadOnlyBtn
                    text: qsTr("Hide R/O")
                    checkable: true
                    checked: controller.hideReadOnly
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 76

                    contentItem: Text {
                        text: mobileHideReadOnlyBtn.text
                        color: mobileHideReadOnlyBtn.checked ? CompanyTheme.primary : CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: mobileHideReadOnlyBtn.checked
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 3
                        color: mobileHideReadOnlyBtn.checked ? CompanyTheme.primaryDim : (mobileHideReadOnlyBtn.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCard)
                        border.color: mobileHideReadOnlyBtn.checked ? CompanyTheme.primary : CompanyTheme.borderCard
                    }

                    onClicked: controller.hideReadOnly = !controller.hideReadOnly
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    // ========================================================================
    // Left Column: Categories & Groups (Screenshots 1 & 3)
    // Hides dynamically when searching (Screenshot 2)
    // ========================================================================
    ScrollView {
        id: groupScroll
        width: ScreenTools.defaultFontPixelWidth * 25
        anchors.top: header.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.left: parent.left
        anchors.leftMargin: 12
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        visible: !root.isSearching && (!root._isNarrow || root.showCategoriesOnMobile)
        z: root._isNarrow ? 40 : 1

        Column {
            id: categoryColumn
            width: groupScroll.availableWidth
            spacing: 2

            Repeater {
                model: controller.categories
                delegate: Column {
                    id: catCol
                    width: categoryColumn.width
                    spacing: 2

                    readonly property var categoryObj: (typeof object !== "undefined" && object !== null) ? object : (model && model.object ? model.object : null)
                    readonly property bool isCurrentCat: controller.currentCategory === catCol.categoryObj

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: 3
                        color: catCol.isCurrentCat ? "#383838" : (catMouse.containsMouse ? CompanyTheme.bgCardHover : "#282828")
                        border.color: catCol.isCurrentCat ? CompanyTheme.borderActive : CompanyTheme.borderCard

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 6

                            Text {
                                text: catCol.isCurrentCat ? "▼" : "▶"
                                color: catCol.isCurrentCat ? CompanyTheme.primary : CompanyTheme.textMuted
                                font.pointSize: 8
                            }

                            Text {
                                text: catCol.categoryObj ? catCol.categoryObj.name : ""
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: catMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: false
                            onClicked: {
                                if (catCol.categoryObj) {
                                    controller.currentCategory = catCol.categoryObj
                                    if (catCol.categoryObj.groups && catCol.categoryObj.groups.count > 0) {
                                        controller.currentGroup = catCol.categoryObj.groups.get(0)
                                    }
                                }
                            }
                        }
                    }

                    // Child Groups (shown under category)
                    Column {
                        visible: catCol.isCurrentCat
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: (catCol.isCurrentCat && catCol.categoryObj) ? catCol.categoryObj.groups : null
                            delegate: Button {
                                id: grpBtn
                                width: parent.width
                                height: 30

                                readonly property var groupObj: (typeof object !== "undefined" && object !== null) ? object : (model && model.object ? model.object : null)
                                readonly property bool isCurrentGrp: controller.currentGroup === grpBtn.groupObj

                                contentItem: Text {
                                    text: grpBtn.groupObj ? grpBtn.groupObj.name : ""
                                    color: grpBtn.isCurrentGrp ? CompanyTheme.textPrimary : CompanyTheme.textSecondary
                                    font.pointSize: CompanyTheme.fontSmall
                                    font.bold: grpBtn.isCurrentGrp
                                    horizontalAlignment: Text.AlignLeft
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 14
                                    elide: Text.ElideRight
                                }

                                background: Rectangle {
                                    radius: 3
                                    color: grpBtn.isCurrentGrp ? "#4a4a4a" : (grpBtn.hovered ? CompanyTheme.bgCardHover : "#333333")
                                    border.color: grpBtn.isCurrentGrp ? CompanyTheme.borderActive : "transparent"
                                    border.width: grpBtn.isCurrentGrp ? 1 : 0
                                }

                                onClicked: {
                                    if (grpBtn.groupObj) {
                                        controller.currentGroup = grpBtn.groupObj
                                        if (root._isNarrow) root.showCategoriesOnMobile = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    // Center: Parameter Table View (Screenshots 1, 2, 3)
    // Left: Parameter Name
    // Center: Value (in RED/ORANGE if modified from default)
    // Right: Description
    // ========================================================================
    TableView {
        id: tableView
        anchors.top: header.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.left: (root.isSearching || (root._isNarrow && !root.showCategoriesOnMobile)) ? parent.left : groupScroll.right
        anchors.leftMargin: (root.isSearching || (root._isNarrow && !root.showCategoriesOnMobile)) ? 12 : 8
        anchors.right: (!root._isNarrow && root.selectedFact !== null) ? editorDrawer.left : parent.right
        anchors.rightMargin: 12
        columnSpacing: 0
        rowSpacing: 0
        model: controller.parameters
        contentWidth: width
        clip: true

        Timer {
            id: forceLayoutTimer
            interval: 500
            repeat: false
            onTriggered: tableView.forceLayout()
        }

        onWidthChanged: forceLayoutTimer.start()
        onTopRowChanged: forceLayoutTimer.start()
        onModelChanged: {
            positionViewAtRow(0, TableView.AlignLeft | TableView.AlignTop)
            forceLayoutTimer.start()
        }

        delegate: Rectangle {
            id: cellDelegate
            implicitWidth: column === 0 ? ScreenTools.defaultFontPixelWidth * 3
                         : column === 1 ? (root._isNarrow ? Math.max(140, tableView.width * 0.38) : ScreenTools.defaultFontPixelWidth * 22)
                         : column === 2 ? (root._isNarrow ? Math.max(90, tableView.width * 0.24) : ScreenTools.defaultFontPixelWidth * 16)
                         : Math.max(ScreenTools.defaultFontPixelWidth * 20, tableView.width - (root._isNarrow ? (tableView.width * 0.62 + ScreenTools.defaultFontPixelWidth * 3) : ScreenTools.defaultFontPixelWidth * 41))
            implicitHeight: ScreenTools.defaultFontPixelHeight * 1.8
            clip: true

            readonly property bool isSelected: root.selectedFact && fact && (root.selectedFact.name === fact.name)

            color: isSelected ? Qt.rgba(CompanyTheme.primary.r, CompanyTheme.primary.g, CompanyTheme.primary.b, 0.25)
                 : cellMouse.containsMouse ? CompanyTheme.bgCardHover
                 : row % 2 === 0 ? "transparent" : Qt.rgba(1, 1, 1, 0.02)

            // Bottom border line
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: CompanyTheme.borderCard
                opacity: 0.25
            }

            // Selection indicator border (Screenshot 3 red highlight box)
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: CompanyTheme.warning
                border.width: 1
                visible: cellDelegate.isSelected
            }

            // Column 0: Favorite / Star (Task 1 & Task 2)
            Item {
                visible: column === 0
                anchors.fill: parent

                Text {
                    anchors.centerIn: parent
                    readonly property bool isFav: Boolean(fact && controller.favoriteParameterNames.indexOf(fact.name) !== -1)
                    text: isFav ? "★" : "☆"
                    color: isFav ? CompanyTheme.warning : CompanyTheme.textMuted
                    font.pointSize: 11
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (fact) {
                            controller.toggleFavorite(fact.name)
                        }
                    }
                }
            }

            // Column 1: Parameter Name
            RowLayout {
                visible: column === 1
                anchors.fill: parent
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth / 2
                spacing: 4

                Text {
                    text: (column === 1 && fact) ? fact.name : ""
                    color: cellDelegate.isSelected ? CompanyTheme.primary : CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.bold: cellDelegate.isSelected
                    font.family: CompanyTheme.fontMono
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                IconVector {
                    visible: fact && fact.readOnly
                    name: "lock"
                    size: 11
                    color: CompanyTheme.textMuted
                }
            }

            // Column 2: Value + Units (Highlighted RED/ORANGE if modified)
            RowLayout {
                visible: column === 2
                anchors.fill: parent
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth / 2
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth / 2
                spacing: 4

                Text {
                    text: {
                        if (!fact || column !== 2) return ""
                        if (fact.enumStrings && fact.enumStrings.length > 0) return fact.enumStringValue
                        if (fact.bitmaskStrings && fact.bitmaskStrings.length > 0) return fact.selectedBitmaskStrings.join(',')
                        return (fact.valueString || "") + (fact.units ? (" " + fact.units) : "")
                    }
                    color: (fact && fact.defaultValueAvailable && !fact.valueEqualsDefault) ? CompanyTheme.warning : CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.family: CompanyTheme.fontMono
                    font.bold: fact && fact.defaultValueAvailable && !fact.valueEqualsDefault
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            // Column 3: Description
            Text {
                visible: column === 3
                anchors.fill: parent
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth / 2
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth
                verticalAlignment: Text.AlignVCenter
                text: (column === 3 && fact) ? (fact.shortDescription || "") : ""
                color: CompanyTheme.textSecondary
                font.pointSize: CompanyTheme.fontSmall
                elide: Text.ElideRight
            }

            MouseArea {
                id: cellMouse
                anchors.fill: parent
                visible: column !== 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (fact) {
                        root.selectedFact = fact
                        root.candidateValue = fact.valueString
                        root.candidateEnumIndex = fact.enumIndex
                        root.validationError = ""
                        root.forceSaveChecked = false
                        root.forceEditChecked = false
                        root.advancedChecked = false
                    }
                }
            }
        }
    }

    // ========================================================================
    // Dimming backdrop for mobile overlay editor
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        visible: root._isNarrow && root.selectedFact !== null
        z: 45
        MouseArea {
            anchors.fill: parent
            onClicked: root.selectedFact = null
        }
    }

    // Right: Parameter Editor Drawer (Screenshot 3)
    // ========================================================================
    Rectangle {
        id: editorDrawer
        width: root._isNarrow ? Math.min(parent.width - 24, 400) : Math.min(parent.width * 0.45, ScreenTools.defaultFontPixelWidth * 42)
        anchors.top: header.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 12
        radius: 4
        color: CompanyTheme.bgCard
        border.color: CompanyTheme.borderCard
        border.width: 1
        visible: root.selectedFact !== null
        z: root._isNarrow ? 50 : 1
        clip: true

        onVisibleChanged: {
            if (visible && editField && !enumCombo.visible) {
                editField.forceActiveFocus()
                editField.selectAll()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header Bar: "Parameter Editor" | [Cancel] [Save]
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                color: CompanyTheme.bgCardElevated
                border.color: CompanyTheme.borderCard

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: qsTr("Parameter Editor")
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontH2
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        id: cancelBtn
                        text: qsTr("Cancel")
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: 64

                        contentItem: Text {
                            text: cancelBtn.text
                            color: CompanyTheme.textPrimary
                            font.pointSize: CompanyTheme.fontSmall
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: 3
                            color: cancelBtn.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                            border.color: CompanyTheme.borderCard
                        }

                        onClicked: {
                            root.selectedFact = null
                        }
                    }

                    Button {
                        id: saveBtn
                        text: qsTr("Save")
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: 64

                        contentItem: Text {
                            text: saveBtn.text
                            color: CompanyTheme.textLight
                            font.pointSize: CompanyTheme.fontSmall
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: 3
                            color: saveBtn.hovered ? CompanyTheme.primaryHover : CompanyTheme.primary
                        }

                        onClicked: {
                            root.applySelectedFact()
                        }
                    }
                }
            }

            // Scrollable Content
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: editorDrawer.width - 24
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    Layout.topMargin: 12
                    Layout.bottomMargin: 12
                    spacing: 12

                    // Read-only indicator (if applicable)
                    Text {
                        visible: root.selectedFact && root.selectedFact.readOnly
                        text: root.forceEditChecked ? qsTr("Warning: This parameter is read-only. Force edit is enabled.")
                                                    : qsTr("This parameter is read-only and cannot be modified.")
                        color: root.forceEditChecked ? CompanyTheme.warning : CompanyTheme.textMuted
                        font.pointSize: CompanyTheme.fontSmall
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // Value Edit Row + [Reset to default] button
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: !(root.selectedFact && root.selectedFact.readOnly && !root.forceEditChecked)

                        // Enum Dropdown
                        ComboBox {
                            id: enumCombo
                            visible: root.selectedFact && root.selectedFact.enumStrings && root.selectedFact.enumStrings.length > 0 && root.selectedFact.bitmaskStrings.length === 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            model: root.selectedFact ? root.selectedFact.enumStrings : []
                            currentIndex: root.candidateEnumIndex >= 0 ? root.candidateEnumIndex : 0
                            onActivated: (index) => {
                                root.candidateEnumIndex = index
                            }
                        }

                        // Text / Numeric Input Field
                        Rectangle {
                            id: textInputBox
                            visible: !enumCombo.visible
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 3
                            color: CompanyTheme.bgInput
                            border.color: root.validationError !== "" ? CompanyTheme.danger : (editField.activeFocus ? CompanyTheme.borderActive : CompanyTheme.borderCard)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 4

                                TextField {
                                    id: editField
                                    Layout.fillWidth: true
                                    text: root.candidateValue
                                    color: CompanyTheme.textPrimary
                                    font.family: CompanyTheme.fontMono
                                    font.pointSize: CompanyTheme.fontSmall
                                    background: null
                                    selectByMouse: true
                                    onTextEdited: {
                                        root.candidateValue = text
                                        if (root.selectedFact) {
                                            root.validationError = root.selectedFact.validate(text, root.forceSaveChecked)
                                        }
                                    }
                                    onAccepted: {
                                        root.applySelectedFact()
                                    }
                                }

                                Text {
                                    text: (root.selectedFact && root.selectedFact.units) ? root.selectedFact.units : ""
                                    color: CompanyTheme.textMuted
                                    font.pointSize: CompanyTheme.fontSmall
                                }
                            }
                        }

                        // [Reset to default] Button
                        Button {
                            id: resetDefBtn
                            text: qsTr("Reset to default")
                            Layout.preferredHeight: 32
                            visible: root.selectedFact && root.selectedFact.defaultValueAvailable

                            contentItem: Text {
                                text: resetDefBtn.text
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontSmall
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 8
                                rightPadding: 8
                            }

                            background: Rectangle {
                                radius: 3
                                color: resetDefBtn.hovered ? CompanyTheme.bgCardHover : CompanyTheme.bgCard
                                border.color: CompanyTheme.borderCard
                            }

                            onClicked: {
                                root.resetSelectedFactToDefault()
                            }
                        }
                    }

                    // Bitmask checkboxes (if applicable)
                    ColumnLayout {
                        visible: root.selectedFact && root.selectedFact.bitmaskStrings && root.selectedFact.bitmaskStrings.length > 0
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: (root.selectedFact && root.selectedFact.bitmaskStrings) ? root.selectedFact.bitmaskStrings : []
                            delegate: CheckBox {
                                required property var modelData
                                required property int index
                                text: modelData
                                checked: {
                                    if (!root.selectedFact) return false
                                    var val = parseInt(root.candidateValue) || 0
                                    var bitVal = root.selectedFact.bitmaskValues[index]
                                    return (val & bitVal) !== 0
                                }
                                onToggled: {
                                    if (!root.selectedFact) return
                                    var val = parseInt(root.candidateValue) || 0
                                    var bitVal = root.selectedFact.bitmaskValues[index]
                                    if (checked) {
                                        val |= bitVal
                                    } else {
                                        val &= ~bitVal
                                    }
                                    root.candidateValue = val.toString()
                                }
                            }
                        }
                    }

                    // Description
                    Text {
                        text: {
                            if (!root.selectedFact) return ""
                            return root.selectedFact.longDescription || root.selectedFact.shortDescription || qsTr("No description available.")
                        }
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // Min / Max / Default constraints
                    Text {
                        text: root.constraintsString
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        visible: root.constraintsString !== ""
                        Layout.fillWidth: true
                    }

                    // Parameter Name: MIS_TAKEOFF_ALT
                    Text {
                        text: qsTr("Parameter name: %1").arg(root.selectedFact ? root.selectedFact.name : "")
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.family: CompanyTheme.fontMono
                        Layout.fillWidth: true
                    }

                    // Flight safety warning
                    Text {
                        text: qsTr("Warning: Modifying values while vehicle is in flight can lead to vehicle instability and possible vehicle loss. Make sure you know what you are doing and double-check your values before Save!")
                        color: "#cccccc"
                        font.pointSize: CompanyTheme.fontSmall
                        wrapMode: Text.WordWrap
                        visible: root.selectedFact && !root.selectedFact.readOnly
                        Layout.fillWidth: true
                    }

                    // Validation Error (if any)
                    Text {
                        text: "⚠ " + root.validationError
                        color: CompanyTheme.danger
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        visible: root.validationError !== ""
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // Advanced settings divider
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: CompanyTheme.borderCard
                        }

                        CheckBox {
                            id: advCheck
                            text: qsTr("Advanced settings")
                            checked: root.advancedChecked
                            onCheckedChanged: root.advancedChecked = checked
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: CompanyTheme.borderCard
                        }
                    }

                    // Advanced options (visible when checked)
                    ColumnLayout {
                        visible: root.advancedChecked
                        Layout.fillWidth: true
                        spacing: 6

                        CheckBox {
                            id: forceSaveCheck
                            text: qsTr("Force save (dangerous!)")
                            checked: root.forceSaveChecked
                            onCheckedChanged: root.forceSaveChecked = checked
                        }

                        CheckBox {
                            id: forceEditCheck
                            visible: root.selectedFact && root.selectedFact.readOnly
                            text: qsTr("Force edit read-only param")
                            checked: root.forceEditChecked
                            onCheckedChanged: root.forceEditChecked = checked
                        }
                    }
                }
            }
        }
    }
}
