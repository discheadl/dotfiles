import QtQuick
import Quickshell
import Quickshell.Io

// =====================================================================
// ThemeEngine
//
// Live theme object passed as `theme:` to every hub card.
//
// All semantic colour tokens used by the cards (text, accents, item
// backgrounds, hover overlays, etc.) are derived from the palette that
// wallust regenerates every time the wallpaper changes — the engine
// watches `~/.config/wallust/colores/colors-hypr.conf` directly via
// `FileView`, so a new wallust run reflows every card automatically.
//
// Sizing/font tokens and the panel/card surfaces remain hardcoded
// because the rest of the hub layout depends on stable values.
//
// Contrast strategy:
//   - `tintRaw`  flips between fgRaw (dark mode) and bgRaw (light mode)
//                so that subtle overlays are always *visible* against
//                the underlying surface.
//   - Accents switch wallust slots per mode so they read against either
//     the dark or the light card background.
//   - textSecondary is derived from textPrimary, never from a wallust
//     slot — wallust's color8 is wallpaper-dependent and frequently
//     collapses into the surface in light mode.
// =====================================================================
QtObject {
    id: root
    property bool isDarkMode: true

    // ---- Sizing & Fonts ----
    readonly property int    radiusOuter: 24
    readonly property int    radiusInner: 16
    readonly property int    padCard:     12
    readonly property int    gapCard:     10
    readonly property int    btnH:        54
    readonly property int    sliderH:     24
    readonly property string textFont:    "Manrope"
    readonly property string iconFont:    "JetBrainsMono Nerd Font"

    // ---- Raw wallust palette (filled from colors-hypr.conf) ----
    property color bgRaw:  "#111111"
    property color fgRaw:  "#FEFAF3"
    property color color0: "#393939"
    property color color1: "#754D43"
    property color color2: "#355D6A"
    property color color3: "#A78D31"
    property color color4: "#B98B8E"
    property color color5: "#8E9EA2"
    property color color6: "#FDF0DD"
    property color color7: "#F6EFE6"
    property color color8: "#ACA7A1"
    property color color9:  "#754D43"
    property color color10: "#355D6A"
    property color color11: "#A78D31"
    property color color12: "#B98B8E"
    property color color13: "#8E9EA2"
    property color color14: "#FDF0DD"
    property color color15: "#F6EFE6"

    // ---- Tint that flips between light/dark so overlays stay visible ----
    // Dark mode: tint with the bright fg → adds a soft white veil over dark.
    // Light mode: tint with the dark bg → adds a soft dark veil over light.
    readonly property color tintRaw: isDarkMode ? fgRaw : bgRaw

    // ---- 1) Surfaces ----
    readonly property color bgPanel: isDarkMode
        ? Qt.rgba(bgRaw.r, bgRaw.g, bgRaw.b, 0.90)
        : Qt.rgba(fgRaw.r, fgRaw.g, fgRaw.b, 0.92)
    readonly property color bgMain: isDarkMode ? bgRaw : fgRaw
    readonly property color bgCard: isDarkMode
        ? Qt.rgba(bgRaw.r, bgRaw.g, bgRaw.b, 0.95)
        : Qt.rgba(fgRaw.r, fgRaw.g, fgRaw.b, 0.95)
    readonly property color bgItem:      Qt.rgba(tintRaw.r, tintRaw.g, tintRaw.b, isDarkMode ? 0.12 : 0.10)
    readonly property color bgItemHover: Qt.rgba(tintRaw.r, tintRaw.g, tintRaw.b, isDarkMode ? 0.18 : 0.14)
    readonly property color bgWidget:    bgItem
    readonly property color bgOSD:       isDarkMode ? Qt.rgba(bgRaw.r, bgRaw.g, bgRaw.b, 0.97)
                                                    : Qt.rgba(fgRaw.r, fgRaw.g, fgRaw.b, 0.97)

    // ---- 2) Text ----
    // textPrimary: highest-contrast text on the current surface.
    readonly property color textPrimary:   isDarkMode ? fgRaw : Qt.rgba(0.10, 0.12, 0.13, 1.0)
    // Derive secondary from primary so it always reads — never use a
    // wallpaper-derived slot here, those are unreliable in light mode.
    readonly property color textSecondary: Qt.rgba(textPrimary.r, textPrimary.g, textPrimary.b, isDarkMode ? 0.62 : 0.58)
    readonly property color textOnAccent:  isDarkMode ? Qt.rgba(bgRaw.r, bgRaw.g, bgRaw.b, 1.0)
                                                      : Qt.rgba(fgRaw.r, fgRaw.g, fgRaw.b, 1.0)
    readonly property color textOSD:       textSecondary

    // ---- 3) Accents (mapped onto wallust slots that contrast each mode) ----
    // Dark mode: prefer the bright slots (color6 ≈ near-white).
    // Light mode: prefer the saturated mid-tone slots (color2 / color1).
    readonly property color accent:        isDarkMode ? color6 : color2
    readonly property color accentSlider:  isDarkMode ? color6 : color2
    readonly property color accentBlue:    color2
    readonly property color accentRed:     isDarkMode ? color4 : color1
    readonly property color accentSlider2: isDarkMode ? color4 : color1

    // ---- 4) Lines, hovers, misc ----
    readonly property color border:          Qt.rgba(tintRaw.r, tintRaw.g, tintRaw.b, isDarkMode ? 0.14 : 0.18)
    readonly property color outline:         Qt.rgba(tintRaw.r, tintRaw.g, tintRaw.b, 0.12)
    readonly property color subtleFill:      Qt.rgba(tintRaw.r, tintRaw.g, tintRaw.b, isDarkMode ? 0.10 : 0.08)
    readonly property color subtleFillHover: Qt.rgba(tintRaw.r, tintRaw.g, tintRaw.b, isDarkMode ? 0.18 : 0.14)
    readonly property color hoverSpotlight:  Qt.rgba(tintRaw.r, tintRaw.g, tintRaw.b, isDarkMode ? 0.16 : 0.12)

    // ---- 5) Weather ----
    readonly property color weatherColor: textSecondary

    // ---- File watcher ----
    property FileView _file: FileView {
        path: Quickshell.env("HOME") + "/.config/wallust/colores/colors-hypr.conf"
        watchChanges: true
        preload: true
        onLoaded: root._parse(text())
        onTextChanged: root._parse(text())
        onFileChanged: reload()
    }

    function _parse(src) {
        if (!src) return
        const re = /\$(bg|fg|color\d+)\s*=\s*rgb\(\s*([0-9A-Fa-f]{6})\s*\)/g
        let m
        while ((m = re.exec(src)) !== null) {
            const key = m[1]
            const hex = "#" + m[2]
            if (key === "bg") root.bgRaw = hex
            else if (key === "fg") root.fgRaw = hex
            else if (key in root) root[key] = hex
        }
    }
}
