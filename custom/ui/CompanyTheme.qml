pragma Singleton

import QtQuick

QtObject {
    id: theme

    // ------------------------------------------------------------------------
    // Colors - Exact Reference Specification
    // ------------------------------------------------------------------------
    readonly property color bgApp:          "#0B1118"  // Dark canvas background
    readonly property color bgSidebar:      "#101720"  // Navigation sidebar
    readonly property color bgTopBar:       "#101720"  // Top status header
    readonly property color bgCard:         "#17212C"  // Primary container card
    readonly property color bgCardSecondary:"#1B2633"  // Secondary well / button container
    readonly property color bgCardHover:    "#1E2938"  // Hover card state
    readonly property color bgCardElevated: "#1B2633"  // Elevated container state
    readonly property color bgInput:        "#131C26"  // Input / inner viewport well
    readonly property color bgOverlay:      Qt.rgba(0.09, 0.13, 0.17, 0.88) // QGC-style floating panel overlay
    readonly property color bgOverlayDark:  Qt.rgba(0.06, 0.09, 0.13, 0.94) // High-contrast translucent panel

    readonly property color borderCard:     "#283544"  // Standard card & divider border
    readonly property color borderSubtle:   "#1E2A38"  // Subtle internal line
    readonly property color borderActive:   "#3B82F6"  // Active state border

    // Accent & Operational Colors
    readonly property color primary:        "#3B82F6"  // Primary brand blue
    readonly property color primaryHover:   "#60A5FA"  // Light blue hover
    readonly property color primaryDim:     "#162A44"  // Active navigation blue tint
    readonly property color accent:         "#3B82F6"  // Accent alias

    readonly property color success:        "#22C55E"  // Active / Ready / Online
    readonly property color warning:        "#F59E0B"  // Standby / Waiting / Caution
    readonly property color danger:         "#EF4444"  // Alert / Armed / No Fix
    readonly property color info:           "#38BDF8"  // Information

    // Typography Colors
    readonly property color textPrimary:    "#F1F5F9"  // High contrast white
    readonly property color textSecondary:  "#94A3B8"  // Cool gray labels & subtitles
    readonly property color textMuted:      "#64748B"  // Darker muted text
    readonly property color textLight:      "#FFFFFF"  // Pure white

    // ------------------------------------------------------------------------
    // Primary Flight Display (PFD) Tokens
    // ------------------------------------------------------------------------
    readonly property color pfdSkyGradientStart:    "#0B1522"
    readonly property color pfdSkyGradientEnd:      "#152538"

    readonly property color pfdGroundGradientStart: "#1A2026"
    readonly property color pfdGroundGradientEnd:   "#0E1317"

    readonly property color pfdHorizonLine:         "#38BDF8"

    readonly property color pfdTapeBg:              Qt.rgba(0.06, 0.09, 0.13, 0.90)

    readonly property color pfdTapeTick:            "#64748B"
    readonly property color pfdTapeText:            "#F1F5F9"

    readonly property color pfdPointerBox:          "#0F172A"
    readonly property color pfdPointerBorder:       "#3B82F6"

    // ------------------------------------------------------------------------
    // Typography Scale (Clean Modern Sans-Serif)
    // ------------------------------------------------------------------------
    readonly property string fontMono:      "Monospace"
    readonly property real fontMetricValue: 24
    readonly property real fontTitle:       18
    readonly property real fontH1:          16
    readonly property real fontH2:          14
    readonly property real fontH3:          12
    readonly property real fontBody:        11
    readonly property real fontSmall:       9.5
    readonly property real fontTiny:        8.5

    // ------------------------------------------------------------------------
    // Spacing & Radius Tokens
    // ------------------------------------------------------------------------
    readonly property real spacingXs:       4
    readonly property real spacingSm:       8
    readonly property real spacingMd:       12
    readonly property real spacingLg:       16
    readonly property real spacingXl:       20

    readonly property real radiusSm:        4
    readonly property real radiusMd:        8
    readonly property real radiusLg:        10
    readonly property real radiusPill:      999

    readonly property real topBarHeight:         44
    readonly property real sidebarWidth:          56
    readonly property real sidebarWidthCompact:   56
    readonly property real sidebarWidthExpanded:  190
}
