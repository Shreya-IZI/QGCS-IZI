pragma Singleton

import QtQuick

QtObject {
    id: theme

    // ------------------------------------------------------------------------
    // Colors - IZI Aerospace/Defence Specification
    // Palette: Black / White / Charcoal with razor-thin borders and restrained status
    // Strictly NO generic SaaS blue dominance, NO excessive gradients or glows.
    // ------------------------------------------------------------------------
    readonly property color bgApp:           "#080A0D"  // Matte aerospace deep charcoal canvas
    readonly property color bgSidebar:       "#0E1217"  // Tactical navigation panel
    readonly property color bgTopBar:        "#0E1217"  // Tactical status header
    readonly property color bgWorkspace:     "#0B0E13"  // Operational workspace canvas
    readonly property color bgCard:          "#11161D"  // Primary instrument card / panel
    readonly property color bgCardSecondary: "#151B23"  // Secondary well / segmented container
    readonly property color bgCardElevated:  "#1A212B"  // Elevated control / active well
    readonly property color bgCardHover:     "#1E2632"  // Interactive hover state
    readonly property color bgInput:         "#0A0D11"  // Input field / inset telemetry readout
    readonly property color bgOverlay:       Qt.rgba(0.04, 0.06, 0.08, 0.88) // Tactical translucent overlay
    readonly property color bgOverlayDark:   Qt.rgba(0.03, 0.04, 0.06, 0.96) // High-contrast HUD overlay

    // Border Tokens (Razor-thin, technical precision lines)
    readonly property color borderCard:      "#1E2530"  // Standard instrument & card divider
    readonly property color borderActive:    "#475569"  // Active state / high-contrast steel border
    readonly property color borderSubtle:    "#161B23"  // Internal subtle separator

    // Primary & Interactive Accent Tokens (Restrained, high-contrast monochrome)
    readonly property color primary:         "#F8FAFC"  // Operational high-contrast white
    readonly property color primaryHover:    "#E2E8F0"  // Steel hover
    readonly property color primaryDim:      Qt.rgba(1.0, 1.0, 1.0, 0.08) // Subtle tactical highlight
    readonly property color secondaryBlue:   "#64748B"  // Technical slate grey
    readonly property color accent:          "#F8FAFC"  // Clean high-contrast accent
    readonly property color accentDim:       Qt.rgba(1.0, 1.0, 1.0, 0.06)

    // Status Colors (Strictly Restrained Military Telemetry Standards)
    // Green -> Connected / Healthy / Armed-Ready
    // Amber -> Standby / Caution / Waiting
    // Red   -> Critical fault / Danger / Armed
    readonly property color success:         "#10B981"  // Operational green
    readonly property color successDim:      Qt.rgba(0.06, 0.72, 0.50, 0.15)
    readonly property color warning:         "#F59E0B"  // Caution amber
    readonly property color warningDim:      Qt.rgba(0.96, 0.62, 0.04, 0.15)
    readonly property color danger:          "#EF4444"  // Alert / Armed / Fault red
    readonly property color dangerDim:       Qt.rgba(0.94, 0.27, 0.27, 0.15)
    readonly property color error:           danger
    readonly property color errorDim:        dangerDim
    readonly property color info:            "#94A3B8"  // Informational slate grey

    // Typography Colors
    readonly property color textPrimary:     "#F8FAFC"  // Crisp high-contrast white
    readonly property color textSecondary:   "#94A3B8"  // Technical secondary cool grey
    readonly property color textMuted:       "#64748B"  // Darker slate text
    readonly property color textLight:       "#FFFFFF"  // Pure white

    // ------------------------------------------------------------------------
    // Primary Flight Display (PFD) HUD Tokens (Aviation Grade)
    // ------------------------------------------------------------------------
    readonly property color pfdSkyGradientStart:    "#0A111A"
    readonly property color pfdSkyGradientEnd:      "#121A26"

    readonly property color pfdGroundGradientStart: "#181A1D"
    readonly property color pfdGroundGradientEnd:   "#0B0D0F"

    readonly property color pfdHorizonLine:         "#10B981"  // Tactical HUD green horizon
    readonly property color pfdTapeBg:              Qt.rgba(0.03, 0.04, 0.06, 0.94)
    readonly property color pfdTapeTick:            "#64748B"
    readonly property color pfdTapeText:            "#F8FAFC"

    readonly property color pfdPointerBox:          "#0E1217"
    readonly property color pfdPointerBorder:       "#CBD5E1"

    // ------------------------------------------------------------------------
    // Typography Scale (Industrial Technical Sans-Serif & Monospace)
    // ------------------------------------------------------------------------
    readonly property string fontMono:       "Monospace"
    readonly property real fontMetricValue:  22
    readonly property real fontTitle:        15
    readonly property real fontH1:           14
    readonly property real fontH2:           12
    readonly property real fontH3:           11
    readonly property real fontBody:         11
    readonly property real fontSmall:        10
    readonly property real fontTiny:         9

    // ------------------------------------------------------------------------
    // Spacing & Geometric Sharp Radius Tokens (No rounded pill cards)
    // ------------------------------------------------------------------------
    readonly property real spacingXs:        4
    readonly property real spacingSm:        8
    readonly property real spacingMd:        12
    readonly property real spacingLg:        16
    readonly property real spacingXl:        20

    // Minimal sharp corners (0 to 2px)
    readonly property real radiusSm:         1
    readonly property real radiusMd:         2
    readonly property real radiusLg:         2
    readonly property real radiusPill:       2   // Rectangular technical tags

    readonly property real topBarHeight:         44
    readonly property real bottomBarHeight:      38
    readonly property real sidebarWidth:         56
    readonly property real sidebarWidthCompact:  56
    readonly property real sidebarWidthExpanded: 196
}
