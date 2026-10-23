// Custom override for PX4 Safety Configuration Page with responsive card width and padding
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

SetupPage {
    id: configPage
    pageComponent: pageComponent

    Component {
        id: pageComponent

        Item {
            width: Math.max(availableWidth, outerColumn.width)
            height: outerColumn.height

            FactPanelController {
                id: controller
            }

            property real _margins: ScreenTools.defaultFontPixelHeight

            readonly property var _rtlLandDelayParamValueLandImmediately: 0
            readonly property var _rtlLandDelayParamValueLoiterIndefinitely: -1
            readonly property var _rtlLandDelayParamValueLoiterDefault: 60

            property var _cpDist: controller.getParameterFact(-1, "CP_DIST")
            property var _fenceRadius: controller.getParameterFact(-1, "GF_MAX_HOR_DIST")
            property var _fenceAlt: controller.getParameterFact(-1, "GF_MAX_VER_DIST")
            property var _disarmLandDelay: controller.getParameterFact(-1, "COM_DISARM_LAND")
            property var _landSpeedMCExists: controller.parameterExists(-1, "MPC_LAND_SPEED")
            property var _rtlLandDelay: controller.getParameterFact(-1, "RTL_LAND_DELAY")

            property string sectionIdFilter: ""

            // Keyed by untranslated section ID (must match VehicleComponent::sectionIds())
            readonly property var _searchTerms: ({
                "Low Battery Failsafe": ["bat_crit_thr", "bat_emergen_thr", "bat_low_thr", "battery", "battery emergency level", "battery failsafe level", "battery warn level", "com_low_bat_act", "critical battery", "emergency", "failsafe", "failsafe action", "low", "low battery", "power", "voltage"],
                "Object Detection": ["avoidance", "collision", "collision prevention minimum distance", "cp_dist", "detection", "distance", "object", "obstacle", "proximity", "show obstacle distance overlay"],
                "RC/Joystick Loss Failsafe": ["com_rc_loss_t", "failsafe", "failsafe action", "joystick", "loss", "nav_rcl_act", "radio", "rc loss", "rc/joystick", "rc/joystick loss timeout", "receiver", "signal loss", "transmitter"],
                "Data Link Loss Failsafe": ["com_dl_loss_t", "data", "data link loss timeout", "disconnect", "failsafe", "failsafe action", "gcs", "ground station", "link", "link loss", "loss", "nav_dll_act", "telemetry"],
                "Geofence Failsafe": ["action on breach", "altitude", "boundary", "breach", "containment", "failsafe", "fence", "geofence", "gf_action", "gf_max_hor_dist", "gf_max_ver_dist", "max altitude", "max radius", "radius"],
                "Return to launch settings": ["altitude", "climb to altitude of", "land", "launch", "loiter", "loiter altitude", "loiter time", "return", "return home", "return to launch", "return to launch, then:", "rtl", "rtl_descend_alt", "rtl_land_delay", "rtl_return_alt", "settings", "to"],
                "Land Mode Settings": ["com_disarm_land", "descent", "disarm", "disarm after", "land", "landing", "landing descent rate", "mode", "mpc_land_speed", "settings", "touchdown"]
            })

            readonly property var _translatableSearchTerms: ({
                "Low Battery Failsafe": ["Battery emergency level", "Battery failsafe level", "Battery warn level", "Failsafe action", "Low Battery Failsafe", "battery", "critical battery", "emergency", "low battery", "power", "voltage"],
                "Object Detection": ["Collision prevention minimum distance", "Object Detection", "Show obstacle distance overlay", "avoidance", "collision", "distance", "obstacle", "proximity"],
                "RC/Joystick Loss Failsafe": ["Failsafe action", "RC/Joystick Loss Failsafe", "RC/joystick loss timeout", "joystick", "radio", "rc loss", "receiver", "signal loss", "transmitter"],
                "Data Link Loss Failsafe": ["Data Link Loss Failsafe", "Data link loss timeout", "Failsafe action", "disconnect", "gcs", "ground station", "link loss", "telemetry"],
                "Geofence Failsafe": ["Action on breach", "Geofence Failsafe", "Max altitude", "Max radius", "altitude", "boundary", "breach", "containment", "fence", "geofence", "radius"],
                "Return to launch settings": ["Climb to altitude of", "Loiter altitude", "Loiter time", "Return to launch settings", "Return to launch, then:", "altitude", "land", "loiter", "return home", "return to launch", "rtl"],
                "Land Mode Settings": ["Disarm after", "Land Mode Settings", "Landing descent rate", "descent", "disarm", "landing", "touchdown"]
            })

            // sectionId must be untranslated; repeat sections pass their base ID as searchKey
            function sectionMatchesFilter(sectionId, searchKey) {
                if (sectionIdFilter === "") {
                    return true
                }
                if (sectionIdFilter === sectionId) {
                    return true
                }
                if (searchKey === undefined) {
                    searchKey = sectionId
                }
                let filter = sectionIdFilter.toLowerCase()
                let terms = _searchTerms[searchKey]
                if (terms) {
                    for (let i = 0; i < terms.length; i++) {
                        if (terms[i].indexOf(filter) >= 0) {
                            return true
                        }
                    }
                }
                let trTerms = _translatableSearchTerms[searchKey]
                if (trTerms) {
                    for (let j = 0; j < trTerms.length; j++) {
                        if (qsTranslate("Safety.VehicleConfig.json", trTerms[j]).toLowerCase().indexOf(filter) >= 0) {
                            return true
                        }
                    }
                }
                return false
            }

            function sectionVisible(sectionId) {
                switch (sectionId) {
                default:
                    return true
                }
            }

            property real _maxLeftMargin: ScreenTools.defaultFontPixelWidth * 20
            readonly property real _maxCardWidth: 750

            ColumnLayout {
                id: outerColumn
                spacing: _margins * 1.25
                width: Math.min(parent.width - 2 * _margins, _maxCardWidth)
                anchors.left: parent.left
                anchors.leftMargin: Math.max(_margins, Math.min((parent.width - width) / 2, _maxLeftMargin))

                ConfigSection {
                    Layout.fillWidth: true
                    visible: sectionMatchesFilter("Low Battery Failsafe")
                    heading: qsTranslate("Safety.VehicleConfig.json", "Low Battery Failsafe")
                    iconSource: "/qmlimages/LowBattery.svg"

                    LabelledFactComboBox {
                        visible: fact !== null
                        label: qsTranslate("Safety.VehicleConfig.json", "Failsafe action")
                        Layout.fillWidth: true
                        comboBoxPreferredWidth: ScreenTools.defaultFontPixelWidth * 30
                        fact: controller.getParameterFact(-1, "COM_LOW_BAT_ACT", false)
                        indexModel: false
                    }

                    LabelledFactTextField {
                        visible: fact !== null
                        label: qsTranslate("Safety.VehicleConfig.json", "Battery warn level")
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BAT_LOW_THR", false)
                    }

                    LabelledFactTextField {
                        visible: fact !== null
                        label: qsTranslate("Safety.VehicleConfig.json", "Battery failsafe level")
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BAT_CRIT_THR", false)
                    }

                    LabelledFactTextField {
                        visible: fact !== null
                        label: qsTranslate("Safety.VehicleConfig.json", "Battery emergency level")
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BAT_EMERGEN_THR", false)
                    }
                }

                ConfigSection {
                    Layout.fillWidth: true
                    visible: sectionMatchesFilter("Object Detection")
                    heading: qsTranslate("Safety.VehicleConfig.json", "Object Detection")
                    iconSource: "/qmlimages/ObjectAvoidance.svg"

                    FactTextFieldSlider {
                        Layout.fillWidth: true
                        label: qsTranslate("Safety.VehicleConfig.json", "Collision prevention minimum distance")
                        fact: controller.getParameterFact(-1, "CP_DIST")
                        allowUsingMinMax: true
                        showEnableCheckbox: true
                        enableCheckBoxChecked: _cpDist.rawValue > 0
                        onEnableCheckboxClicked: { _cpDist.rawValue = enableCheckBoxChecked ? 5 : -1 }
                    }

                    FactCheckBoxSlider {
                        Layout.fillWidth: true
                        text: qsTranslate("Safety.VehicleConfig.json", "Show obstacle distance overlay")
                        fact: QGroundControl.settingsManager.flyViewSettings.showObstacleDistanceOverlay
                    }
                }

                ConfigSection {
                    Layout.fillWidth: true
                    visible: sectionMatchesFilter("RC/Joystick Loss Failsafe")
                    heading: qsTranslate("Safety.VehicleConfig.json", "RC/Joystick Loss Failsafe")
                    iconSource: "/qmlimages/RCLoss.svg"

                    LabelledFactComboBox {
                        visible: fact !== null
                        label: qsTranslate("Safety.VehicleConfig.json", "Failsafe action")
                        Layout.fillWidth: true
                        comboBoxPreferredWidth: ScreenTools.defaultFontPixelWidth * 30
                        fact: controller.getParameterFact(-1, "NAV_RCL_ACT", false)
                        indexModel: false
                    }

                    LabelledFactTextField {
                        visible: fact !== null
                        label: qsTranslate("Safety.VehicleConfig.json", "RC/joystick loss timeout")
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "COM_RC_LOSS_T", false)
                    }
                }

                ConfigSection {
                    Layout.fillWidth: true
                    visible: sectionMatchesFilter("Data Link Loss Failsafe")
                    heading: qsTranslate("Safety.VehicleConfig.json", "Data Link Loss Failsafe")
                    iconSource: "/qmlimages/DatalinkLoss.svg"

                    LabelledFactComboBox {
                        visible: fact !== null
                        label: qsTranslate("Safety.VehicleConfig.json", "Failsafe action")
                        Layout.fillWidth: true
                        comboBoxPreferredWidth: ScreenTools.defaultFontPixelWidth * 30
                        fact: controller.getParameterFact(-1, "NAV_DLL_ACT", false)
                        indexModel: false
                    }

                    LabelledFactTextField {
                        visible: fact !== null
                        label: qsTranslate("Safety.VehicleConfig.json", "Data link loss timeout")
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "COM_DL_LOSS_T", false)
                    }
                }

                ConfigSection {
                    Layout.fillWidth: true
                    visible: sectionMatchesFilter("Geofence Failsafe")
                    heading: qsTranslate("Safety.VehicleConfig.json", "Geofence Failsafe")
                    iconSource: "/qmlimages/GeoFence.svg"

                    LabelledFactComboBox {
                        visible: fact !== null
                        label: qsTranslate("Safety.VehicleConfig.json", "Action on breach")
                        Layout.fillWidth: true
                        comboBoxPreferredWidth: ScreenTools.defaultFontPixelWidth * 30
                        fact: controller.getParameterFact(-1, "GF_ACTION", false)
                        indexModel: false
                    }

                    FactTextFieldSlider {
                        Layout.fillWidth: true
                        label: qsTranslate("Safety.VehicleConfig.json", "Max radius")
                        fact: controller.getParameterFact(-1, "GF_MAX_HOR_DIST")
                        allowUsingMinMax: true
                        showEnableCheckbox: true
                        enableCheckBoxChecked: _fenceRadius.value > 0
                        onEnableCheckboxClicked: { _fenceRadius.value = enableCheckBoxChecked ? 100 : 0 }
                    }

                    FactTextFieldSlider {
                        Layout.fillWidth: true
                        label: qsTranslate("Safety.VehicleConfig.json", "Max altitude")
                        fact: controller.getParameterFact(-1, "GF_MAX_VER_DIST")
                        allowUsingMinMax: true
                        showEnableCheckbox: true
                        enableCheckBoxChecked: _fenceAlt.value > 0
                        onEnableCheckboxClicked: { _fenceAlt.value = enableCheckBoxChecked ? 100 : 0 }
                    }
                }

                ConfigSection {
                    Layout.fillWidth: true
                    visible: sectionMatchesFilter("Return to launch settings")
                    heading: qsTranslate("Safety.VehicleConfig.json", "Return to launch settings")
                    iconSource: "/qmlimages/ReturnToHomeAltitudeCopter.svg"

                    LabelledFactTextField {
                        visible: fact !== null
                        label: qsTranslate("Safety.VehicleConfig.json", "Climb to altitude of")
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "RTL_RETURN_ALT", false)
                    }

                    QGCLabel {
                        text: qsTranslate("Safety.VehicleConfig.json", "Return to launch, then:")
                    }
                    ColumnLayout {
                        spacing: 0
                        QGCRadioButton {
                            text: qsTranslate("Safety.VehicleConfig.json", "Land immediately")
                            checked: _rtlLandDelay.value === _rtlLandDelayParamValueLandImmediately
                            onClicked: controller.getParameterFact(-1, "RTL_LAND_DELAY").value = _rtlLandDelayParamValueLandImmediately
                        }
                        QGCRadioButton {
                            text: qsTranslate("Safety.VehicleConfig.json", "Loiter and do not land")
                            checked: _rtlLandDelay.value < _rtlLandDelayParamValueLandImmediately
                            onClicked: controller.getParameterFact(-1, "RTL_LAND_DELAY").value = _rtlLandDelayParamValueLoiterIndefinitely
                        }
                        QGCRadioButton {
                            text: qsTranslate("Safety.VehicleConfig.json", "Loiter and land after specified time")
                            checked: _rtlLandDelay.value > _rtlLandDelayParamValueLandImmediately
                            onClicked: controller.getParameterFact(-1, "RTL_LAND_DELAY").value = _rtlLandDelayParamValueLoiterDefault
                        }
                    }

                    LabelledFactTextField {
                        label: qsTranslate("Safety.VehicleConfig.json", "Loiter time")
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "RTL_LAND_DELAY")
                        enabled: _rtlLandDelay.value > _rtlLandDelayParamValueLandImmediately
                    }

                    LabelledFactTextField {
                        visible: fact !== null
                        label: qsTranslate("Safety.VehicleConfig.json", "Loiter altitude")
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "RTL_DESCEND_ALT", false)
                        enabled: _rtlLandDelay.value !== _rtlLandDelayParamValueLandImmediately
                    }
                }

                ConfigSection {
                    Layout.fillWidth: true
                    visible: sectionMatchesFilter("Land Mode Settings")
                    heading: qsTranslate("Safety.VehicleConfig.json", "Land Mode Settings")
                    iconSource: "/qmlimages/LandModeCopter.svg"

                    LabelledFactTextField {
                        visible: fact !== null && (_landSpeedMCExists)
                        label: qsTranslate("Safety.VehicleConfig.json", "Landing descent rate")
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "MPC_LAND_SPEED", false)
                    }

                    FactTextFieldSlider {
                        Layout.fillWidth: true
                        label: qsTranslate("Safety.VehicleConfig.json", "Disarm after")
                        fact: controller.getParameterFact(-1, "COM_DISARM_LAND")
                        allowUsingMinMax: true
                        sliderMin: 0
                        sliderMax: 10
                        showEnableCheckbox: true
                        enableCheckBoxChecked: _disarmLandDelay.value > 0
                        onEnableCheckboxClicked: { _disarmLandDelay.value = enableCheckBoxChecked ? 2 : 0 }
                    }
                }
            }
        }
    }
}
