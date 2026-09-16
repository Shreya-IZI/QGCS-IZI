pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Company.UI
import "controls"

Item {
    id: root

    property string pageTitle: "Module"
    property string pageSubtitle: "Under development"
    property string iconName: "missions"
    property string moduleTag: "PLAN"
    signal navigateToTab(int tabIndex)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: CompanyTheme.spacingLg
        spacing: CompanyTheme.spacingMd

        // --------------------------------------------------------------------
        // 1. Header Row
        // --------------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: CompanyTheme.spacingMd

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                Text {
                    text: root.pageTitle.toUpperCase()
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontH1
                    font.bold: true
                    font.letterSpacing: 0.6
                }

                Text {
                    text: root.pageSubtitle
                    color: CompanyTheme.textSecondary
                    font.pointSize: CompanyTheme.fontBody
                }
            }

            Rectangle {
                Layout.preferredHeight: 30
                radius: CompanyTheme.radiusSm
                color: CompanyTheme.bgCard
                border.color: CompanyTheme.borderCard
                border.width: 1
                implicitWidth: statusLayout.implicitWidth + CompanyTheme.spacingMd * 2

                RowLayout {
                    id: statusLayout
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: CompanyTheme.primary
                    }

                    Text {
                        text: root.moduleTag + " • READY"
                        color: CompanyTheme.primary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                    }
                }
            }
        }

        // --------------------------------------------------------------------
        // 2. Main Two-Column Subsystem Workspace
        // --------------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: CompanyTheme.spacingMd

            // Left Subsystem Information Card
            Rectangle {
                Layout.preferredWidth: 380
                Layout.fillHeight: true
                Layout.minimumHeight: 320
                color: CompanyTheme.bgCard
                radius: CompanyTheme.radiusMd
                border.color: CompanyTheme.borderCard
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: CompanyTheme.spacingLg
                    spacing: CompanyTheme.spacingMd

                    Text {
                        text: (root.pageTitle + " DETAILS").toUpperCase()
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        font.letterSpacing: 0.8
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: CompanyTheme.borderCard
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Repeater {
                            model: [
                                { label: "Subsystem Core", value: "QGC Native C++", status: "Active" },
                                { label: "MAVLink Interface", value: "Protocol v2.0", status: "Ready" },
                                { label: "Parameter Store", value: "FactSystem Synchronized", status: "Online" }
                            ]

                            delegate: RowLayout {
                                id: rowItem
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: CompanyTheme.spacingSm

                                ColumnLayout {
                                    spacing: 2
                                    Layout.fillWidth: true
                                    Text { text: rowItem.modelData.label; color: CompanyTheme.textSecondary; font.pointSize: CompanyTheme.fontBody }
                                    Text { text: rowItem.modelData.value; color: CompanyTheme.textPrimary; font.pointSize: CompanyTheme.fontSmall; font.bold: true }
                                }

                                Rectangle {
                                    Layout.preferredHeight: 22
                                    radius: CompanyTheme.radiusSm
                                    color: CompanyTheme.bgCardSecondary
                                    border.color: CompanyTheme.borderCard
                                    border.width: 1
                                    implicitWidth: badgeRow.implicitWidth + 12

                                    RowLayout {
                                        id: badgeRow
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Rectangle { Layout.preferredWidth: 5; Layout.preferredHeight: 5; radius: 2.5; color: CompanyTheme.success }
                                        Text { text: rowItem.modelData.status; color: CompanyTheme.success; font.pointSize: CompanyTheme.fontTiny; font.bold: true }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: CompanyTheme.borderCard
                    }

                    Text {
                        text: "All core flight safety, mission parameters, and telemetry feeds remain fully synchronized in the native backend."
                        color: CompanyTheme.textMuted
                        font.pointSize: CompanyTheme.fontTiny
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            // Right Viewport Card
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 320
                color: CompanyTheme.bgCard
                radius: CompanyTheme.radiusMd
                border.color: CompanyTheme.borderCard
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: CompanyTheme.spacingLg
                    spacing: CompanyTheme.spacingSm

                    Text {
                        text: "VIEWPORT CANVAS"
                        color: CompanyTheme.textPrimary
                        font.pointSize: CompanyTheme.fontSmall
                        font.bold: true
                        font.letterSpacing: 0.8
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: CompanyTheme.radiusSm
                        color: CompanyTheme.bgInput
                        border.color: CompanyTheme.borderCard
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: CompanyTheme.spacingSm

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 46
                                radius: CompanyTheme.radiusSm
                                color: "transparent"
                                border.color: CompanyTheme.borderCard
                                border.width: 1.5

                                IconVector {
                                    anchors.centerIn: parent
                                    name: root.iconName
                                    size: 22
                                    color: CompanyTheme.textSecondary
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.pageTitle + " Viewport"
                                color: CompanyTheme.textPrimary
                                font.pointSize: CompanyTheme.fontH2
                                font.bold: true
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.maximumWidth: 320
                                text: "Dedicated " + root.pageTitle.toLowerCase() + " module interface designed for Phase 2 integration."
                                color: CompanyTheme.textSecondary
                                font.pointSize: CompanyTheme.fontBody
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }

        // --------------------------------------------------------------------
        // 3. Bottom Quick Links Card
        // --------------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 74
            implicitHeight: 74
            color: CompanyTheme.bgCard
            radius: CompanyTheme.radiusMd
            border.color: CompanyTheme.borderCard
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: CompanyTheme.spacingLg
                anchors.rightMargin: CompanyTheme.spacingLg
                spacing: CompanyTheme.spacingLg

                Text {
                    text: "QUICK LINKS"
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontSmall
                    font.bold: true
                    font.letterSpacing: 0.8
                    Layout.preferredWidth: 100
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 32
                    color: CompanyTheme.borderCard
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.fill: parent
                        spacing: CompanyTheme.spacingSm
                        Rectangle {
                            Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                            color: CompanyTheme.bgCardSecondary; border.color: CompanyTheme.borderCard; border.width: 1
                            IconVector { anchors.centerIn: parent; name: "flight"; size: 14; color: CompanyTheme.textSecondary }
                        }
                        ColumnLayout {
                            spacing: 0
                            Text { text: "Flight View"; color: CompanyTheme.textPrimary; font.pointSize: CompanyTheme.fontSmall; font.bold: true }
                            Text { text: "HUD & Map"; color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny }
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.navigateToTab(1) }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.fill: parent
                        spacing: CompanyTheme.spacingSm
                        Rectangle {
                            Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                            color: CompanyTheme.bgCardSecondary; border.color: CompanyTheme.borderCard; border.width: 1
                            IconVector { anchors.centerIn: parent; name: "missions"; size: 14; color: CompanyTheme.textSecondary }
                        }
                        ColumnLayout {
                            spacing: 0
                            Text { text: "Missions"; color: CompanyTheme.textPrimary; font.pointSize: CompanyTheme.fontSmall; font.bold: true }
                            Text { text: "Plan & Execute"; color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny }
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.navigateToTab(2) }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.fill: parent
                        spacing: CompanyTheme.spacingSm
                        Rectangle {
                            Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                            color: CompanyTheme.bgCardSecondary; border.color: CompanyTheme.borderCard; border.width: 1
                            IconVector { anchors.centerIn: parent; name: "fleet"; size: 14; color: CompanyTheme.textSecondary }
                        }
                        ColumnLayout {
                            spacing: 0
                            Text { text: "Fleet"; color: CompanyTheme.textPrimary; font.pointSize: CompanyTheme.fontSmall; font.bold: true }
                            Text { text: "Manage Units"; color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny }
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.navigateToTab(3) }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.fill: parent
                        spacing: CompanyTheme.spacingSm
                        Rectangle {
                            Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                            color: CompanyTheme.bgCardSecondary; border.color: CompanyTheme.borderCard; border.width: 1
                            IconVector { anchors.centerIn: parent; name: "settings"; size: 14; color: CompanyTheme.textSecondary }
                        }
                        ColumnLayout {
                            spacing: 0
                            Text { text: "Settings"; color: CompanyTheme.textPrimary; font.pointSize: CompanyTheme.fontSmall; font.bold: true }
                            Text { text: "Configure GCS"; color: CompanyTheme.textMuted; font.pointSize: CompanyTheme.fontTiny }
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.navigateToTab(5) }
                }
            }
        }
    }
}
