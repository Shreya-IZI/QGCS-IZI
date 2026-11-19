pragma Singleton

import QtQuick

QtObject {
    id: theme

    // Operational Mode: High-Contrast Sunlight Visibility
    property bool isSunlightMode: false

    // ------------------------------------------------------------------------
    // Colors - IZI GCS GRAPHITE GREEN Brand Identity
    // Palette:
    // - Main background:      #0B1118
    // - Secondary background: #101720
    // - Card background:      #17212C
    // - Primary accent:       #8BEA68
    // - Primary text:         #FFFFFF
    // - Secondary text:       #A7B0B8
    // - Borders:              subtle graphite grey (#222F3D)
    // - Success:              green (#8BEA68)
    // - Warning:              amber (#F59E0B)
    // - Critical:             red (#EF4444)
    // STRICT DESIGN RULE: No blue, cyan, purple or blue gradients anywhere.
    // ------------------------------------------------------------------------
    readonly property color bgApp:           isSunlightMode ? "#000000" : "#0B1118"  // Tactical graphite canvas
    readonly property color bgSidebar:       isSunlightMode ? "#05070A" : "#101720"  // Secondary graphite panel
    readonly property color bgTopBar:        isSunlightMode ? "#05070A" : "#101720"  // Tactical header
    readonly property color bgWorkspace:     isSunlightMode ? "#000000" : "#0B1118"  // Primary workspace
    readonly property color bgCard:          isSunlightMode ? "#0D141D" : "#17212C"  // Primary instrument card
    readonly property color bgCardSecondary: isSunlightMode ? "#101720" : "#101720"  // Secondary container
    readonly property color bgCardElevated:  isSunlightMode ? "#151F2B" : "#1D2A37"  // Elevated control / active card
    readonly property color bgCardHover:     "#233242"  // Interactive hover state
    readonly property color bgInput:         isSunlightMode ? "#000000" : "#0E151F"  // Inset input field
    readonly property color bgOverlay:       Qt.rgba(0.043, 0.067, 0.094, 0.88)     // Translucent dark overlay (#0B1118)
    readonly property color bgOverlayDark:   Qt.rgba(0.043, 0.067, 0.094, 0.96)     // High-contrast HUD overlay

    // Border Tokens (Subtle graphite grey precision lines)
    readonly property color borderCard:      isSunlightMode ? "#475569" : "#222F3D"  // Subtle graphite grey
    readonly property color borderActive:    "#8BEA68"                               // Electric tactical green active border
    readonly property color borderSubtle:    isSunlightMode ? "#334155" : "#1A2430"  // Internal divider

    // Primary & Interactive Accent Tokens (IZI Graphite Green Specification)
    readonly property color primary:         "#8BEA68"  // IZI Signature Electric Tactical Green
    readonly property color primaryHover:    "#9EFA7C"  // Brightened Green Hover
    readonly property color primaryDim:      Qt.rgba(0.545, 0.918, 0.408, 0.16) // Subtle Green Glow
    readonly property color secondaryBlue:   "#6A7785"  // Technical slate grey (no blue)
    readonly property color accent:          "#8BEA68"  // Tactical Green Accent
    readonly property color accentHover:     "#9EFA7C"  // Brightened Green Hover
    readonly property color accentDim:       Qt.rgba(0.545, 0.918, 0.408, 0.16)
    readonly property color djiBlue:         "#8BEA68"  // Aliased to IZI Green (eliminates blue)
    readonly property color djiBlueHover:    "#9EFA7C"
    readonly property color djiBlueDim:      Qt.rgba(0.545, 0.918, 0.408, 0.16)
    readonly property color djiCyan:         "#8BEA68"  // Aliased to IZI Green (eliminates cyan)
    readonly property color djiCyanDim:      Qt.rgba(0.545, 0.918, 0.408, 0.16)
    readonly property color bgGlass:         Qt.rgba(0.09, 0.13, 0.17, 0.90)    // Frosted graphite glass (#17212C)
    readonly property color borderGlass:     Qt.rgba(0.545, 0.918, 0.408, 0.20) // Subtle green-tinted glass edge

    // Status Colors (Strictly Restrained Military Telemetry Standards)
    readonly property color success:         "#8BEA68"  // Operational / Ready Green
    readonly property color successDim:      Qt.rgba(0.545, 0.918, 0.408, 0.15)
    readonly property color warning:         "#F59E0B"  // Caution Amber
    readonly property color warningDim:      Qt.rgba(0.96, 0.62, 0.04, 0.15)
    readonly property color danger:          "#EF4444"  // Alert / Armed / Fault Red
    readonly property color dangerDim:       Qt.rgba(0.94, 0.27, 0.27, 0.15)
    readonly property color error:           danger
    readonly property color errorDim:        dangerDim
    readonly property color info:            "#A7B0B8"  // Informational slate grey

    // Typography Colors
    readonly property color textPrimary:     isSunlightMode ? "#FFFFFF" : "#FFFFFF"  // Crisp Pure White
    readonly property color textSecondary:   isSunlightMode ? "#CBD5E1" : "#A7B0B8"  // Secondary cool graphite grey
    readonly property color textMuted:       isSunlightMode ? "#94A3B8" : "#6A7785"  // Darker slate text
    readonly property color textLight:       "#FFFFFF"  // Pure White

    // ------------------------------------------------------------------------
    // Primary Flight Display (PFD) HUD Tokens (Aviation Grade)
    // ------------------------------------------------------------------------
    readonly property color pfdSkyGradientStart:    "#0B1118"
    readonly property color pfdSkyGradientEnd:      "#101720"

    readonly property color pfdGroundGradientStart: "#17212C"
    readonly property color pfdGroundGradientEnd:   "#0B1118"

    readonly property color pfdHorizonLine:         "#8BEA68"  // Tactical HUD Green Horizon
    readonly property color pfdTapeBg:              Qt.rgba(0.043, 0.067, 0.094, 0.94)
    readonly property color pfdTapeTick:            "#6A7785"
    readonly property color pfdTapeText:            "#FFFFFF"

    readonly property color pfdPointerBox:          "#101720"
    readonly property color pfdPointerBorder:       "#8BEA68"

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

    // Refined Aerospace Corner Radii (DJI Professional Specification)
    readonly property real radiusSm:         4
    readonly property real radiusMd:         6
    readonly property real radiusLg:         8
    readonly property real radiusPill:       16  // Smooth pill tags

    readonly property real topBarHeight:         44
    readonly property real bottomBarHeight:      38
    readonly property real sidebarWidth:         56
    readonly property real sidebarWidthCompact:  56
    readonly property real sidebarWidthExpanded: 196
}
