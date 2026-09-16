# ============================================================================
# Company Ground Control Station - Custom Plugin & UI Overlay
# ============================================================================

message(STATUS "QGC: Adding Company Custom Plugin & UI Overlay")

# ----------------------------------------------------------------------------
# Custom QML Module
# ----------------------------------------------------------------------------
qt_add_library(CompanyUIModule STATIC)
qgc_configure_target(CompanyUIModule)

set(COMPANY_UI_QML_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/CompanyTheme.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/CompanyTelemetry.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/MainWindow.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/TopBar.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/Sidebar.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/DashboardView.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/PrimaryFlightDisplay.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/TacticalMapView.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/SystemDiagnosticsView.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/MissionPlannerView.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/Placeholders.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/controls/CompanyCard.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/controls/CompanyButton.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/controls/StatusBadge.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/controls/MetricTile.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/controls/IconVector.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/controls/DroneGraphic.qml
)

# Set resource aliases to filename so they are cleanly accessible in QML and C++
qgc_set_qt_resource_alias(${COMPANY_UI_QML_FILES})

# Register CompanyTheme and CompanyTelemetry as QML singletons
set_source_files_properties(
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/CompanyTheme.qml
    ${CMAKE_CURRENT_SOURCE_DIR}/ui/CompanyTelemetry.qml
    PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(CompanyUIModule
    URI Company.UI
    VERSION 1.0
    RESOURCE_PREFIX /qml
    QML_FILES
        ${COMPANY_UI_QML_FILES}
    NO_PLUGIN
)

# ----------------------------------------------------------------------------
# Custom Plugin Sources & Configuration
# ----------------------------------------------------------------------------
set(CUSTOM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomPlugin.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomPlugin.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomOptions.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CustomOptions.h
    PARENT_SCOPE
)

set(CUSTOM_LIBRARIES
    CompanyUIModule
    PARENT_SCOPE
)

set(CUSTOM_INCLUDE_DIRECTORIES
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    PARENT_SCOPE
)

set(CUSTOM_DEFINITIONS
    QGC_CUSTOM_BUILD
    CUSTOMHEADER="CustomPlugin.h"
    CUSTOMCLASS=CustomPlugin
    PARENT_SCOPE
)

set(CUSTOM_QT_COMPONENTS
    Core
    Quick
    Qml
    PARENT_SCOPE
)
