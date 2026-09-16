import QtQuick
import QtQuick.Layouts
import Company.UI

Rectangle {
    id: root

    property string label: ""
    property string value: "--"
    property string unit: ""
    property string subtext: ""
    property color accentColor: CompanyTheme.accent
    property bool isHighlighted: false

    implicitWidth: 160
    implicitHeight: 88

    color: isHighlighted ? CompanyTheme.bgCardElevated : CompanyTheme.bgCard
    radius: CompanyTheme.radiusMd
    border.color: isHighlighted ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.4) : CompanyTheme.borderCard
    border.width: 1

    // Top accent bar
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        color: root.accentColor
        opacity: 0.8
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: CompanyTheme.spacingSm + 2
        anchors.bottomMargin: CompanyTheme.spacingSm
        anchors.leftMargin: CompanyTheme.spacingMd
        anchors.rightMargin: CompanyTheme.spacingMd
        spacing: 2

        // Top Row: Label and accent indicator
        RowLayout {
            Layout.fillWidth: true
            spacing: CompanyTheme.spacingXs

            Rectangle {
                Layout.preferredWidth: 5
                Layout.preferredHeight: 5
                radius: 2.5
                color: root.accentColor
            }

            Text {
                text: root.label.toUpperCase()
                color: CompanyTheme.textSecondary
                font.pointSize: CompanyTheme.fontSmall
                font.bold: true
                font.letterSpacing: 0.6
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        // Middle Row: Value and Unit
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: root.value
                color: CompanyTheme.textPrimary
                font.pointSize: CompanyTheme.fontMetricValue
                font.bold: true
                font.family: CompanyTheme.fontMono
                elide: Text.ElideRight
            }

            Text {
                text: root.unit
                color: CompanyTheme.textSecondary
                font.pointSize: CompanyTheme.fontBody
                font.bold: true
                visible: root.unit !== ""
                Layout.alignment: Qt.AlignBaseline
            }
        }

        // Bottom subtext (secondary telemetry metric)
        Text {
            text: root.subtext
            color: CompanyTheme.textMuted
            font.pointSize: CompanyTheme.fontSmall
            font.family: CompanyTheme.fontMono
            visible: root.subtext !== ""
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
