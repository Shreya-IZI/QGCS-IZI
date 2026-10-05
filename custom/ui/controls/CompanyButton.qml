import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Company.UI

Button {
    id: root

    property bool isPrimary: false
    property bool isDanger: false
    property bool isOutline: false
    property color customColor: "transparent"
    property string iconText: ""

    implicitHeight: 34
    implicitWidth: Math.max(90, buttonLayout.implicitWidth + CompanyTheme.spacingMd * 2)

    contentItem: RowLayout {
        id: buttonLayout
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.iconText
            color: root._textColor
            font.pointSize: CompanyTheme.fontBody
            visible: root.iconText !== ""
        }

        Text {
            text: root.text
            color: root._textColor
            font.pointSize: CompanyTheme.fontBody
            font.bold: root.isPrimary || root.isDanger
            font.letterSpacing: 0.4
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    readonly property color _baseColor: {
        if (customColor !== "transparent") return customColor
        if (isDanger) return CompanyTheme.danger
        if (isPrimary) return CompanyTheme.primary
        if (isOutline) return "transparent"
        return CompanyTheme.bgCard
    }

    readonly property color _textColor: {
        if (!root.enabled) return CompanyTheme.textMuted
        if (isPrimary) return CompanyTheme.bgApp
        if (isDanger) return CompanyTheme.textLight
        if (isOutline) return CompanyTheme.accent
        return CompanyTheme.textPrimary
    }

    background: Rectangle {
        radius: CompanyTheme.radiusSm
        color: {
            if (!root.enabled) return Qt.rgba(0.15, 0.18, 0.25, 0.5)
            if (root.pressed) return root.isOutline ? CompanyTheme.primaryDim : Qt.darker(root._baseColor, 1.3)
            if (root.hovered) {
                if (root.isOutline) return CompanyTheme.primaryDim
                return Qt.lighter(root._baseColor, 1.2)
            }
            return root._baseColor
        }
        border.color: {
            if (!root.enabled) return CompanyTheme.borderSubtle
            if (root.isOutline) return root.hovered ? CompanyTheme.accent : Qt.rgba(CompanyTheme.accent.r, CompanyTheme.accent.g, CompanyTheme.accent.b, 0.5)
            if (root.isPrimary || root.isDanger) return "transparent"
            return root.hovered ? CompanyTheme.borderActive : CompanyTheme.borderCard
        }
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }
}
