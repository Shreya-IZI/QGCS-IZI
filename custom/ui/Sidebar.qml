pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Company.UI
import "controls"

Rectangle {
    id: root

    property int currentTab: 1 // 0: Dashboard, 1: Flight View, 2: Missions, 3: Fleet, 4: Logs, 5: Settings
    property bool isExpanded: false
    signal tabSelected(int index)

    width: isExpanded ? CompanyTheme.sidebarWidthExpanded : CompanyTheme.sidebarWidthCompact
    color: CompanyTheme.bgSidebar
    clip: true

    Behavior on width {
        NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
    }

    // Right border line
    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 1
        color: CompanyTheme.borderCard
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: CompanyTheme.spacingMd
        anchors.bottomMargin: CompanyTheme.spacingMd
        anchors.leftMargin: root.isExpanded ? CompanyTheme.spacingMd : 6
        anchors.rightMargin: root.isExpanded ? CompanyTheme.spacingMd : 6
        spacing: CompanyTheme.spacingSm

        // --------------------------------------------------------------------
        // Rail Header: Expand / Collapse Hamburger Toggle
        // --------------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            implicitHeight: 34
            radius: CompanyTheme.radiusSm
            color: toggleMouseArea.containsMouse ? CompanyTheme.bgCard : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                anchors.rightMargin: root.isExpanded ? CompanyTheme.spacingSm : 0
                spacing: CompanyTheme.spacingSm

                Item {
                    Layout.preferredWidth: root.isExpanded ? 24 : parent.width
                    Layout.fillHeight: true

                    // Hamburger lines icon
                    Column {
                        anchors.centerIn: parent
                        spacing: 3
                        Rectangle { width: 14; height: 2; radius: 1; color: toggleMouseArea.containsMouse ? CompanyTheme.textPrimary : CompanyTheme.textSecondary }
                        Rectangle { width: 14; height: 2; radius: 1; color: toggleMouseArea.containsMouse ? CompanyTheme.textPrimary : CompanyTheme.textSecondary }
                        Rectangle { width: 14; height: 2; radius: 1; color: toggleMouseArea.containsMouse ? CompanyTheme.textPrimary : CompanyTheme.textSecondary }
                    }
                }

                Text {
                    visible: root.isExpanded
                    text: qsTr("NAVIGATION")
                    color: CompanyTheme.textMuted
                    font.pointSize: CompanyTheme.fontTiny
                    font.bold: true
                    font.letterSpacing: 1.0
                    Layout.fillWidth: true
                }
            }

            MouseArea {
                id: toggleMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.isExpanded = !root.isExpanded
            }

            ToolTip.visible: toggleMouseArea.containsMouse && !root.isExpanded
            ToolTip.delay: 400
            ToolTip.text: qsTr("Expand Sidebar")
        }

        // Section Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: CompanyTheme.borderCard
        }

        // --------------------------------------------------------------------
        // Section 1: OPERATIONS
        // --------------------------------------------------------------------
        Text {
            visible: root.isExpanded
            Layout.leftMargin: CompanyTheme.spacingSm
            Layout.bottomMargin: 2
            text: qsTr("OPERATIONS")
            color: CompanyTheme.textMuted
            font.pointSize: CompanyTheme.fontTiny
            font.bold: true
            font.letterSpacing: 1.0
        }

        Repeater {
            model: [
                { title: qsTr("Dashboard"),   iconName: "dashboard", index: 0 },
                { title: qsTr("Flight View"), iconName: "flight",    index: 1 },
                { title: qsTr("Missions"),    iconName: "missions",  index: 2 }
            ]

            delegate: Rectangle {
                id: navOp
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 40
                implicitHeight: 40
                radius: CompanyTheme.radiusSm

                readonly property bool isSelected: root.currentTab === modelData.index
                readonly property bool isHovered: mouseAreaOp.containsMouse

                color: {
                    if (isSelected) return CompanyTheme.primaryDim
                    if (isHovered) return CompanyTheme.bgCard
                    return "transparent"
                }

                // Left active vertical indicator
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 20
                    radius: 1.5
                    color: CompanyTheme.primary
                    visible: navOp.isSelected
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.isExpanded ? CompanyTheme.spacingMd : 0
                    anchors.rightMargin: root.isExpanded ? CompanyTheme.spacingMd : 0
                    spacing: CompanyTheme.spacingMd

                    Item {
                        id: iconHostOp
                        Layout.preferredWidth: root.isExpanded ? 20 : parent.width
                        Layout.fillHeight: true

                        IconVector {
                            anchors.centerIn: iconHostOp
                            name: navOp.modelData.iconName
                            size: 18
                            color: navOp.isSelected ? CompanyTheme.textLight : (navOp.isHovered ? CompanyTheme.textPrimary : CompanyTheme.textSecondary)
                        }
                    }

                    Text {
                        visible: root.isExpanded
                        text: navOp.modelData.title
                        color: navOp.isSelected ? CompanyTheme.textLight : (navOp.isHovered ? CompanyTheme.textPrimary : CompanyTheme.textSecondary)
                        font.pointSize: CompanyTheme.fontBody
                        font.bold: navOp.isSelected
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: mouseAreaOp
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentTab = navOp.modelData.index
                        root.tabSelected(navOp.modelData.index)
                    }
                }

                ToolTip.visible: mouseAreaOp.containsMouse && !root.isExpanded
                ToolTip.delay: 300
                ToolTip.text: navOp.modelData.title
            }
        }

        // Section Spacing
        Item {
            Layout.preferredHeight: CompanyTheme.spacingSm
        }

        // --------------------------------------------------------------------
        // Section 2: MANAGEMENT
        // --------------------------------------------------------------------
        Text {
            visible: root.isExpanded
            Layout.leftMargin: CompanyTheme.spacingSm
            Layout.bottomMargin: 2
            text: qsTr("MANAGEMENT")
            color: CompanyTheme.textMuted
            font.pointSize: CompanyTheme.fontTiny
            font.bold: true
            font.letterSpacing: 1.0
        }

        Repeater {
            model: [
                { title: qsTr("Fleet"),    iconName: "fleet",    index: 3 },
                { title: qsTr("Logs"),     iconName: "logs",     index: 4 },
                { title: qsTr("Settings"), iconName: "settings", index: 5 }
            ]

            delegate: Rectangle {
                id: navMgmt
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 40
                implicitHeight: 40
                radius: CompanyTheme.radiusSm

                readonly property bool isSelected: root.currentTab === modelData.index
                readonly property bool isHovered: mouseAreaMgmt.containsMouse

                color: {
                    if (isSelected) return CompanyTheme.primaryDim
                    if (isHovered) return CompanyTheme.bgCard
                    return "transparent"
                }

                // Left active vertical indicator
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 20
                    radius: 1.5
                    color: CompanyTheme.primary
                    visible: navMgmt.isSelected
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.isExpanded ? CompanyTheme.spacingMd : 0
                    anchors.rightMargin: root.isExpanded ? CompanyTheme.spacingMd : 0
                    spacing: CompanyTheme.spacingMd

                    Item {
                        id: iconHostMgmt
                        Layout.preferredWidth: root.isExpanded ? 20 : parent.width
                        Layout.fillHeight: true

                        IconVector {
                            anchors.centerIn: iconHostMgmt
                            name: navMgmt.modelData.iconName
                            size: 18
                            color: navMgmt.isSelected ? CompanyTheme.textLight : (navMgmt.isHovered ? CompanyTheme.textPrimary : CompanyTheme.textSecondary)
                        }
                    }

                    Text {
                        visible: root.isExpanded
                        text: navMgmt.modelData.title
                        color: navMgmt.isSelected ? CompanyTheme.textLight : (navMgmt.isHovered ? CompanyTheme.textPrimary : CompanyTheme.textSecondary)
                        font.pointSize: CompanyTheme.fontBody
                        font.bold: navMgmt.isSelected
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: mouseAreaMgmt
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentTab = navMgmt.modelData.index
                        root.tabSelected(navMgmt.modelData.index)
                    }
                }

                ToolTip.visible: mouseAreaMgmt.containsMouse && !root.isExpanded
                ToolTip.delay: 300
                ToolTip.text: navMgmt.modelData.title
            }
        }

        // Push bottom status to bottom
        Item {
            Layout.fillHeight: true
        }

        // --------------------------------------------------------------------
        // Bottom System Status (Compact Dot or Full Card)
        // --------------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.isExpanded ? 52 : 36
            implicitHeight: root.isExpanded ? 52 : 36
            color: CompanyTheme.bgCard
            radius: root.isExpanded ? CompanyTheme.radiusMd : CompanyTheme.radiusSm
            border.color: CompanyTheme.borderCard
            border.width: 1

            // Compact status display (single dot centered)
            Item {
                anchors.fill: parent
                visible: !root.isExpanded

                Rectangle {
                    anchors.centerIn: parent
                    width: 8
                    height: 8
                    radius: 4
                    color: CompanyTheme.success
                }

                MouseArea {
                    id: statusCompactHover
                    anchors.fill: parent
                    hoverEnabled: true
                }

                ToolTip.visible: statusCompactHover.containsMouse
                ToolTip.delay: 300
                ToolTip.text: qsTr("GCS Engine Online • Core v5.0.3")
            }

            // Expanded status display
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: CompanyTheme.spacingSm + 2
                spacing: 2
                visible: root.isExpanded

                RowLayout {
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: CompanyTheme.success
                    }

                    Text {
                        text: qsTr("GCS ENGINE ONLINE")
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        font.letterSpacing: 0.4
                    }
                }

                Text {
                    Layout.leftMargin: 12
                    text: qsTr("Core v5.0.3  •  COMM OK")
                    color: CompanyTheme.textMuted
                    font.pointSize: CompanyTheme.fontTiny
                }
            }
        }
    }
}
