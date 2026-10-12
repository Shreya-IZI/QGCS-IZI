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

# Official IZI Windows Installer Header
if(EXISTS "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/deploy/windows/installheader.bmp")
    set(QGC_WINDOWS_INSTALL_HEADER_PATH "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/deploy/windows/installheader.bmp" CACHE FILEPATH "Windows Install Header Path" FORCE)
    set(CPACK_NSIS_MUI_HEADERIMAGE "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/deploy/windows/installheader.bmp" CACHE FILEPATH "NSIS Header Image" FORCE)
endif()

# Official IZI Windows Resource File
if(EXISTS "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/deploy/windows/QGroundControl.rc")
    set(QGC_WINDOWS_RESOURCE_FILE_PATH "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/deploy/windows/QGroundControl.rc" CACHE FILEPATH "Windows resource file" FORCE)
endif()

# Official IZI Linux AppImage & Desktop Icons
if(EXISTS "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/res/icons/izi_icon.png")
    set(QGC_APPIMAGE_ICON_256_PATH "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/res/icons/izi_icon.png" CACHE FILEPATH "AppImage 256x256 icon path" FORCE)
endif()
if(EXISTS "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/res/icons/izi_icon.svg")
    set(QGC_APPIMAGE_ICON_SCALABLE_PATH "${CMAKE_SOURCE_DIR}/${QGC_CUSTOM_DIR}/res/icons/izi_icon.svg" CACHE FILEPATH "AppImage SVG icon path" FORCE)
endif()
