import QtQuick
import QtQuick.Layouts
import Company.UI

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property color headerAccent: "transparent"
    property bool isElevated: false
    default property alias content: contentContainer.data

    color: isElevated ? CompanyTheme.bgCardElevated : CompanyTheme.bgCard
    radius: CompanyTheme.radiusMd
    border.color: root.headerAccent !== "transparent" ? Qt.rgba(headerAccent.r, headerAccent.g, headerAccent.b, 0.4) : CompanyTheme.borderCard
    border.width: 1
    clip: true

    implicitWidth: 320
    implicitHeight: Math.max(160, mainCardLayout.implicitHeight + CompanyTheme.spacingMd * 2)

    // Top accent indicator line (when headerAccent specified)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        color: root.headerAccent
        visible: root.headerAccent !== "transparent"
    }

    ColumnLayout {
        id: mainCardLayout
        anchors.fill: parent
        anchors.margins: CompanyTheme.spacingMd
        spacing: CompanyTheme.spacingSm

        // Card Header (rendered when title is non-empty)
        RowLayout {
            Layout.fillWidth: true
            visible: root.title !== ""
            spacing: CompanyTheme.spacingSm

            Rectangle {
                Layout.preferredWidth: 3
                Layout.preferredHeight: titleLabel.height
                radius: 1.5
                color: root.headerAccent !== "transparent" ? root.headerAccent : CompanyTheme.accent
                visible: root.headerAccent !== "transparent"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    id: titleLabel
                    text: root.title.toUpperCase()
                    color: CompanyTheme.textPrimary
                    font.pointSize: CompanyTheme.fontH3
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Text {
                    text: root.subtitle
                    color: CompanyTheme.textSecondary
                    font.pointSize: CompanyTheme.fontSmall
                    visible: root.subtitle !== ""
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        // Header Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: CompanyTheme.borderSubtle
            visible: root.title !== ""
        }

        // Card Body Container
        Item {
            id: contentContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: childrenRect.height
        }
    }
}
