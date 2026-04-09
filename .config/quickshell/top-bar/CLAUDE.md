# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running & Reloading

```bash
# Start
quickshell -p ~/.config/quickshell/top-bar/shell.qml

# Full reload (kill + restart)
pkill -x quickshell; quickshell -p ~/.config/quickshell/top-bar/shell.qml

# Toggle hub open/close from terminal
bash ~/.config/quickshell/top-bar/toggle-hub.sh
# (which calls: hyprctl dispatch global quickshell:hubToggle)

# Toggle dark/light theme
bash ~/.config/quickshell/top-bar/bar/theme-mode.sh dark
bash ~/.config/quickshell/top-bar/bar/theme-mode.sh light
```

There is no build step — Quickshell interprets QML files directly. Syntax errors appear in the terminal where quickshell is running.

## Architecture Overview

### Entry Point: `shell.qml`
Uses `Variants { model: Quickshell.screens }` to instantiate one `Scope` per monitor. Each scope owns:
- `ThemeEngine` — live theme object passed as `theme:` prop to all hub cards
- `Bar.Bar` — the always-visible top panel
- `Hub.HubWindow` — the popup hub panel (hidden by default)
- A `GlobalShortcut` named `"hubToggle"` connected to `toggleHub()`

### Bar (`bar/Bar.qml`)
A `PanelWindow` anchored top/left/right. Contains: Arch launcher (its own island), workspace pills (Hyprland), an empty fill-width center spacer, system tray, battery, and clock. The clock click emits `requestHubToggle()` which `shell.qml` catches via `Connections`.

The bar runs a small local `QtObject { id: palette }` whose properties (`bg`, `textPrimary`, `accent`, `border`, `hoverPillG0..2`, …) are **thin aliases over `Lib.WallustColors`** (`id: wal`), not independent constants. To recolour the bar, edit `lib/WallustColors.qml` — never the literal hex values inside `Bar.qml`.

The Arch launcher icon's colour is intentionally hardcoded to `#1793d1` (Arch blue) and is the only colour in the bar that does NOT flow from wallust. The island background, border and hover overlay around the icon DO use wallust.

Hyprland workspace windows are cached in `hyCache.wsMap` (a JS object keyed by workspace ID) and rebuilt via `Qt.callLater()` to collapse burst events.

### Hub (`hub/HubWindow.qml`)
A `PanelWindow` with `aboveWindows: true` that anchors to all four edges. The actual panel is a `Rectangle` positioned top-right. Layout:
```
HubWindow
└── panel (Rectangle, top-right)
    └── ColumnLayout
        ├── Header
        ├── ButtonsSlidersCard  ← WiFi/BT/GPU/DND buttons + brightness/volume sliders
        ├── BatteryHealthCard
        ├── MediaCard
        ├── CalendarWeatherCard
        └── NotificationsCard
```
Clicking outside the panel closes the hub (outer `MouseArea`). An inner `MouseArea` on the panel prevents those clicks from propagating outward.

### `lib/Card.qml` — Critical Caveat
```qml
default property alias content: container.data
```
**All children declared inside `Lib.Card { }` in consumer files are routed to an internal `ColumnLayout` (`container`), NOT to the `Card` Rectangle root.** This means:
- A `WheelHandler` or `MouseArea` placed as a child of `Lib.Card` in a consumer file ends up inside the layout, not on the root rectangle.
- To attach an event handler at the Card rectangle level, it must be defined **inside `Card.qml` itself** and exposed via a property or signal.

**Consequence for wheel/scroll events:** a `WheelHandler` inside `Lib.ExpressiveSlider { }` or inside a `RowLayout { }` within the card DOES work, because those items are not subject to the alias (only direct children of `Lib.Card` are redirected). That is the correct place to add scroll input handling.

### `lib/CommandPoll.qml`
Wrapper around `Quickshell.Io.Process` that runs a shell command on a timer. Key behavior:
- `busy` flag prevents concurrent executions — if a command is slow, ticks are skipped.
- `onUpdated` signal fires **only when the parsed value changes** (not every poll).
- Usage pattern in cards: `onUpdated: if (!slider.pressed) slider.value = value`

### Theming
Three parallel systems — know which one applies before editing colours:
- **`theme.js`** — `.pragma library` static constants used via `import "../theme.js" as Theme` in `lib/` components as fallback values.
- **`lib/ThemeEngine.qml`** — live `QtObject` with `isDarkMode` binding, instantiated in `HubWindow.qml` and passed as `theme:` prop to every hub card. All hub cards source colours, fonts and sizing from `engine.*` (alias of `theme`). Hardcoded everforest-ish hex values live here.
- **`lib/WallustColors.qml`** — live `QtObject` that watches `~/.config/wallust/colores/colors-hypr.conf` via `FileView` and parses `$bg`, `$fg`, `$colorN` into reactive `color` properties, plus semantic tokens (`island`, `islandHover`, `islandBorder`, `textPrimary`, `accent`, `activePill`, `hoverPillG0..2`, `battCrit/Low/Mid`, `bgItem`, `subtleFill/Hover`, `hoverSpotlight`). The bar (`Bar.qml`) sources its colours exclusively from this. Hub cards still use `ThemeEngine`. To make the whole bar repaint after `wallust run …`, do nothing — the `FileView` reloads automatically.

Theme mode (dark/light, independent of wallust palette) persists to `~/.cache/quickshell/theme_mode` (string `"dark"` or `"light"`). Both `Bar.qml` and `HubWindow.qml` watch this file with `FileView { watchChanges: true }` and propagate `isDarkMode` to `WallustColors` and `ThemeEngine`. Toggle scripts: `bar/theme-mode.sh dark|light`.

### Configuration (`config.js`)
Hardcoded paths: profile image/name, weather cache/script paths, events command, screenshot command. Edit this file to adapt to a different user environment.

## Common Patterns

**Shell commands in cards:**
```qml
function sh(cmd) { return ["bash", "-lc", cmd] }
function det(cmd) { Quickshell.execDetached(sh(cmd)) }
```

**Optimistic UI with poll sync:**
```qml
// Poll syncs slider only when not being dragged
onUpdated: if (!mySlider.pressed) mySlider.value = value
// Slider fires command via debounce timer
onUserChanged: sendTimer.restart()
```

**Adding a new hub card:** Create `hub/MyCard.qml` extending `Lib.Card`, add it to the `ColumnLayout` in `HubWindow.qml`, pass `theme: theme` and `active: win.visible`.
