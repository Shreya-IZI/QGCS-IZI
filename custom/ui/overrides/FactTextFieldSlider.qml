import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

/// Fact-bound text field with an optional slider and enable/disable checkbox.
/// The slider range is determined by (in priority order): explicit sliderMin/Max,
/// fact.userMin/Max, or fact.min/max when allowUsingMinMax is true.
Rectangle {
    id:             control
    implicitHeight: mainLayout.implicitHeight
    implicitWidth:  mainLayout.implicitWidth
    color:          backgroundColor
    radius:         ScreenTools.defaultBorderRadius

    property string label
    property alias fact:                    factTextField.fact
    property alias textFieldPreferredWidth: factTextField.textFieldPreferredWidth
    property alias textFieldUnitsLabel:     factTextField.textFieldUnitsLabel
    property alias textFieldShowUnits:      factTextField.textFieldShowUnits
    property alias textFieldShowHelp:       factTextField.textFieldShowHelp
    property alias textField:               factTextField
    property alias enableCheckBoxChecked:   enableCheckbox.checked
    property bool  warnOnUserMinMaxInvalid: true  ///< true: warn if userMin/userMax are invalid, false: no warning

    property bool   showEnableCheckbox: false ///< true: show enable/disable checkbox, false: hide
    property bool   allowUsingMinMax:   false ///< true: fall back to fact.min/max when userMin/Max not set
    property var    sliderMin:          undefined ///< explicit slider minimum, overrides fact.userMin/min
    property var    sliderMax:          undefined ///< explicit slider maximum, overrides fact.userMax/max
    property color  backgroundColor:    _ftfsBackgroundColor

    signal enableCheckboxClicked

    property bool _loadComplete:            false
    property bool _showSlider:              _sliderMin !== undefined && _sliderMax !== undefined
    property color _ftfsBackgroundColor:    Qt.rgba(qgcPal.windowShadeLight.r, qgcPal.windowShadeLight.g, qgcPal.windowShadeLight.b, 0.2)
    property var  _sliderMin:               sliderMin !== undefined ? sliderMin : (fact.userMin !== undefined ? fact.userMin : (allowUsingMinMax ? fact.min : undefined))
    property var  _sliderMax:               sliderMax !== undefined ? sliderMax : (fact.userMax !== undefined ? fact.userMax : (allowUsingMinMax ? fact.max : undefined))

    function updateSliderToClampedValue() {
        if (_showSlider && sliderLoader.item) {
            let clampedSliderValue = control.fact.value
            if (clampedSliderValue > control._sliderMax) {
                clampedSliderValue = control._sliderMax
            } else if (clampedSliderValue < control._sliderMin) {
                clampedSliderValue = control._sliderMin
            }
            sliderLoader.item.value = clampedSliderValue
        }
    }

    Component.onCompleted: {
        _loadComplete = true
        if (warnOnUserMinMaxInvalid && !allowUsingMinMax && sliderMin === undefined && sliderMax === undefined && (fact.userMin === undefined || fact.userMax === undefined)) {
            console.warn("FactTextFieldSlider: userMin/userMax not set for", fact.name)
        }
    }

    Connections {
        target: control.fact

        function onValueChanged() {
            control.updateSliderToClampedValue()
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    ColumnLayout {
        id:             mainLayout
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.top:    parent.top
        spacing:        ScreenTools.defaultFontPixelHeight * 0.25

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth

            QGCCheckBox {
                id:                     enableCheckbox
                Layout.fillWidth:       true
                Layout.minimumWidth:    ScreenTools.defaultFontPixelWidth * 12
                text:                   control.label
                visible:                control.showEnableCheckbox

                onClicked: control.enableCheckboxClicked()
            }

            // Flexible layout spacer separating the checkbox label and the input text field
            Item {
                Layout.fillWidth: true
                visible: control.showEnableCheckbox
            }

            LabelledFactTextField {
                id:                     factTextField
                Layout.fillWidth:       !control.showEnableCheckbox
                Layout.alignment:       Qt.AlignRight | Qt.AlignVCenter
                label:                  control.showEnableCheckbox ? "" : control.label
                fact:                   control.fact
                enabled:                !control.showEnableCheckbox || enableCheckbox.checked
            }
        }

        Loader {
            id:                 sliderLoader
            Layout.fillWidth:   true
            sourceComponent:    control._showSlider ? sliderComponent : null
            enabled:            !control.showEnableCheckbox || enableCheckbox.checked

            onLoaded: control.updateSliderToClampedValue()
        }

        Component {
            id: sliderComponent

            QGCSlider {
                id:                 slider
                Layout.fillWidth:   true
                from:               control._sliderMin
                to:                 control._sliderMax
                showBoundaryValues: true

                onMoved: {
                    if (control._loadComplete) {
                        control.fact.value = slider.value
                    }
                }
            }
        }
    }
}
