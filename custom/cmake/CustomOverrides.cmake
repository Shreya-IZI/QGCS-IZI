# ============================================================================
# IZI Ground Control Station - Build Configuration Overrides
# ============================================================================

# ----------------------------------------------------------------------------
# Application Branding
# Note: QGC_APP_NAME is the CMake executable target name and must not contain spaces.
# ----------------------------------------------------------------------------
set(QGC_APP_NAME "QGroundControl" CACHE STRING "App Name" FORCE)
set(QGC_APP_DESCRIPTION "IZI Ground Control Station" CACHE STRING "Application description" FORCE)
set(QGC_ORG_NAME "IZI" CACHE STRING "Organization name" FORCE)
set(QGC_ORG_DOMAIN "izi.internal" CACHE STRING "Organization domain" FORCE)

# Official IZI Windows Application & Installer Icons
if(EXISTS "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/deploy/windows/WindowsIZI.ico")
    set(QGC_WINDOWS_ICON_PATH "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/deploy/windows/WindowsIZI.ico" CACHE FILEPATH "Windows Icon Path" FORCE)
    set(CPACK_NSIS_MUI_ICON "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/deploy/windows/WindowsIZI.ico" CACHE FILEPATH "NSIS Installer Icon" FORCE)
    set(CPACK_NSIS_MUI_UNIICON "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/deploy/windows/WindowsIZI.ico" CACHE FILEPATH "NSIS Uninstaller Icon" FORCE)
endif()
