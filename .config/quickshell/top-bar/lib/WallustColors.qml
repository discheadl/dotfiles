import QtQuick
import Quickshell
import Quickshell.Io

// =====================================================================
// Centralised colour source for the bar.
//
// Reads ~/.config/wallust/colores/colors-hypr.conf (regenerated every
// time wallust runs) and exposes the parsed `$colorN`, `$bg`, `$fg`
// values plus a handful of semantic aliases the bar uses.
//
// Every component in `bar/` should pull its colours from here so that a
// new wallpaper / wallust run reflows the whole bar instantly.
// =====================================================================
QtObject {
    id: root

    // ---- Raw palette (filled from colors-hypr.conf) ----
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
    property color color9: "#754D43"
    property color color10: "#355D6A"
    property color color11: "#A78D31"
    property color color12: "#B98B8E"
    property color color13: "#8E9EA2"
    property color color14: "#FDF0DD"
    property color color15: "#F6EFE6"

    // ---- Theme mode (mirrors what bar/hub already do) ----
    property bool isDarkMode: true

    // ---- Semantic tokens used by the bar ----
    // SOLID island background (workspaces, tray, battery, clock, launcher).
    // Elegant charcoal in dark mode, warm off-white in light mode — fully
    // opaque, no transparency, no gradient.
    readonly property color island:        isDarkMode ? "#1a1c20" : "#f4f1ea"
    readonly property color islandHover:   Qt.rgba(fgRaw.r, fgRaw.g, fgRaw.b, isDarkMode ? 0.14 : 0.10)
    readonly property color islandBorder:  Qt.rgba(fgRaw.r, fgRaw.g, fgRaw.b, isDarkMode ? 0.08 : 0.10)

    readonly property color textPrimary:   isDarkMode ? fgRaw : Qt.rgba(0.12, 0.14, 0.15, 1.0)
    readonly property color textSecondary: color8
    readonly property color textOnAccent:  Qt.rgba(0.12, 0.14, 0.15, 1.0)

    readonly property color accent:        color6
    readonly property color accentAlt:     color3
    readonly property color accentRed:     color1
    readonly property color launcher:      color2

    // Active workspace pill colour
    readonly property color activePill:    color6

    // Hover gradient stops used by the workspace pill
    readonly property color hoverPillG0: Qt.rgba(color6.r, color6.g, color6.b, 0.15)
    readonly property color hoverPillG1: Qt.rgba(color6.r, color6.g, color6.b, 0.28)
    readonly property color hoverPillG2: Qt.rgba(color6.r, color6.g, color6.b, 0.15)

    // Battery thresholds
    readonly property color battCrit: color1
    readonly property color battLow:  color4
    readonly property color battMid:  color3

    // ---- Card / hub tokens (used by NotificationsCard et al.) ----
    // Subtle pill background — e.g. the count badge in NotificationsCard.
    readonly property color bgItem:          Qt.rgba(fgRaw.r, fgRaw.g, fgRaw.b, isDarkMode ? 0.08 : 0.06)
    // Soft button fill
    readonly property color subtleFill:      Qt.rgba(fgRaw.r, fgRaw.g, fgRaw.b, isDarkMode ? 0.05 : 0.05)
    readonly property color subtleFillHover: Qt.rgba(fgRaw.r, fgRaw.g, fgRaw.b, isDarkMode ? 0.15 : 0.10)
    // Generic spotlight overlay (alias for islandHover, kept for clarity at call sites)
    readonly property color hoverSpotlight:  islandHover

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
