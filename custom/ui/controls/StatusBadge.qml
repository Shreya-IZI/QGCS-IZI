import QtQuick
import QtQuick.Layouts
import Company.UI

Rectangle {
    id: root

    property string text: ""
    property color badgeColor: CompanyTheme.info
    property bool showDot: true
    property bool pulse: false

    implicitWidth: badgeLayout.implicitWidth + CompanyTheme.spacingSm * 2
    implicitHeight: 22

    radius: CompanyTheme.radiusPill
    color: Qt.rgba(badgeColor.r, badgeColor.g, badgeColor.b, 0.12)
    border.color: Qt.rgba(badgeColor.r, badgeColor.g, badgeColor.b, 0.35)
    border.width: 1

    RowLayout {
        id: badgeLayout
        anchors.centerIn: parent
        spacing: 5

        Rectangle {
            id: dot
            Layout.preferredWidth: 6
            Layout.preferredHeight: 6
            radius: 3
            color: root.badgeColor
            visible: root.showDot

            SequentialAnimation on opacity {
                running: root.pulse
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.2; duration: 700; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.2; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
            }
        }

        Text {
            text: root.text.toUpperCase()
            color: root.badgeColor
            font.pointSize: CompanyTheme.fontSmall
            font.bold: true
            font.letterSpacing: 0.6
            verticalAlignment: Text.AlignVCenter
        }
    }
}
