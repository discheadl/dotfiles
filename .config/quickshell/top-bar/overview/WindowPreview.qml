import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
    id: root

    property var theme
    property var toplevel
    property var winData
    property string address
    property real wsScale
    property real wsWidth
    property real wsHeight
    property int wsGap
    property int wsCols
    property int wsRows
    property real outerRadius
    property real innerRadius
    property var monitorData
    property bool overviewOpen
    property int gapOffset: 0
    // Updated by Overview while a drag is in progress so the delegate can
    // tell a same-workspace drop apart from a cross-workspace drop.
    property int currentTargetWs: -1
    signal repositioned()
    property var iconSubstitutions: ({
        "code-url-handler": "visual-studio-code",
        "Code": "visual-studio-code",
        "gnome-tweaks": "org.gnome.tweaks",
        "pavucontrol-qt": "pavucontrol",
        "wps": "wps-office2019-kprometheus",
        "wpsoffice": "wps-office2019-kprometheus",
        "footclient": "foot"
    })
    property var iconRegexSubstitutions: [
        { regex: /^steam_app_(\d+)$/, replace: "steam_icon_$1" },
        { regex: /Minecraft.*/, replace: "minecraft" },
        { regex: /.*polkit.*/, replace: "system-lock-screen" },
        { regex: /gcr.prompter/, replace: "system-lock-screen" }
    ]

    signal windowClicked()
    signal windowMiddleClicked()
    signal dragStarted(int fromWs)
    signal dragEnded()

    function iconExists(iconName) {
        if (!iconName || iconName.length === 0)
            return false
        var path = Quickshell.iconPath(iconName, true)
        return path && path.length > 0 && !iconName.includes("image-missing")
    }

    function reverseDomainAppName(str) {
        return String(str).split(".").slice(-1)[0]
    }

    function kebabName(str) {
        return String(str).toLowerCase().replace(/\s+/g, "-")
    }

    function underscoreToKebab(str) {
        return String(str).toLowerCase().replace(/_/g, "-")
    }

    function guessIcon(str) {
        if (!str || str.length === 0)
            return "application-x-executable"

        var entry = DesktopEntries.byId(str)
        if (entry)
            return entry.icon

        if (iconSubstitutions[str])
            return iconSubstitutions[str]

        var lowered = String(str).toLowerCase()
        if (iconSubstitutions[lowered])
            return iconSubstitutions[lowered]

        for (var i = 0; i < iconRegexSubstitutions.length; i++) {
            var substitution = iconRegexSubstitutions[i]
            var replaced = String(str).replace(substitution.regex, substitution.replace)
            if (replaced !== str)
                return replaced
        }

        if (iconExists(str))
            return str

        if (iconExists(lowered))
            return lowered

        var reverseDomain = reverseDomainAppName(str)
        if (iconExists(reverseDomain))
            return reverseDomain

        var reverseLower = reverseDomain.toLowerCase()
        if (iconExists(reverseLower))
            return reverseLower

        var kebab = kebabName(str)
        if (iconExists(kebab))
            return kebab

        var underscored = underscoreToKebab(str)
        if (iconExists(underscored))
            return underscored

        var heuristic = DesktopEntries.heuristicLookup(str)
        if (heuristic)
            return heuristic.icon

        return "application-x-executable"
    }

    readonly property int wsId: winData?.workspace?.id ?? 1
    readonly property int wsRow: Math.floor((wsId - 1) / wsCols)
    readonly property int wsCol: (wsId - 1) % wsCols
    readonly property real cellOffsetX: wsCol * (wsWidth + wsGap)
    readonly property real cellOffsetY: wsRow * (wsHeight + wsGap)
    readonly property real winAtX: winData?.at?.[0] ?? 0
    readonly property real winAtY: winData?.at?.[1] ?? 0
    readonly property real winSizeW: winData?.size?.[0] ?? 200
    readonly property real winSizeH: winData?.size?.[1] ?? 200
    readonly property real monitorX: monitorData?.x ?? 0
    readonly property real monitorY: monitorData?.y ?? 0
    readonly property real reservedLeft: monitorData?.reserved?.[0] ?? 0
    readonly property real reservedTop: monitorData?.reserved?.[1] ?? 0
    readonly property real reservedRight: monitorData?.reserved?.[2] ?? 0
    readonly property real reservedBottom: monitorData?.reserved?.[3] ?? 0
    readonly property real monitorDisplayScale: monitorData?.scale ?? 1
    readonly property bool monitorRotated: ((monitorData?.transform ?? 0) % 2) === 1
    readonly property real rawMonitorWidth: (monitorData?.width ?? (wsWidth / Math.max(wsScale, 0.001))) / monitorDisplayScale
    readonly property real rawMonitorHeight: (monitorData?.height ?? (wsHeight / Math.max(wsScale, 0.001))) / monitorDisplayScale
    readonly property real monitorWidth: monitorRotated ? rawMonitorHeight : rawMonitorWidth
    readonly property real monitorHeight: monitorRotated ? rawMonitorWidth : rawMonitorHeight
    readonly property real usableMonitorWidth: Math.max(1, monitorWidth - reservedLeft - reservedRight)
    readonly property real usableMonitorHeight: Math.max(1, monitorHeight - reservedTop - reservedBottom)
    readonly property real contentWidth: Math.max(1, usableMonitorWidth - gapOffset * 2)
    readonly property real contentHeight: Math.max(1, usableMonitorHeight - gapOffset * 2)
    readonly property real posScaleX: wsWidth / contentWidth
    readonly property real posScaleY: wsHeight / contentHeight
    readonly property real rawLocalX: Math.max((winAtX - monitorX - reservedLeft - gapOffset) * posScaleX, 0)
    readonly property real rawLocalY: Math.max((winAtY - monitorY - reservedTop - gapOffset) * posScaleY, 0)
    readonly property real scaledW: Math.max(winSizeW * posScaleX, 16)
    readonly property real scaledH: Math.max(winSizeH * posScaleY, 16)
    readonly property real fitW: Math.min(scaledW, Math.max(16, wsWidth))
    readonly property real fitH: Math.min(scaledH, Math.max(16, wsHeight))
    readonly property real localX: Math.min(rawLocalX, Math.max(0, wsWidth - fitW))
    readonly property real localY: Math.min(rawLocalY, Math.max(0, wsHeight - fitH))
    readonly property real initX: cellOffsetX + localX
    readonly property real initY: cellOffsetY + localY
    readonly property bool isDragging: dragArea.drag.active
    readonly property bool workspaceAtLeft: wsCol === 0
    readonly property bool workspaceAtRight: wsCol === wsCols - 1
    readonly property bool workspaceAtTop: wsRow === 0
    readonly property bool workspaceAtBottom: wsRow === wsRows - 1
    readonly property real minRadius: 8
    readonly property real distanceFromLeftEdge: localX
    readonly property real distanceFromRightEdge: wsWidth - (localX + fitW)
    readonly property real distanceFromTopEdge: localY
    readonly property real distanceFromBottomEdge: wsHeight - (localY + fitH)
    readonly property real topLeftCornerDistance: Math.max(distanceFromLeftEdge, distanceFromTopEdge)
    readonly property real topRightCornerDistance: Math.max(distanceFromRightEdge, distanceFromTopEdge)
    readonly property real bottomLeftCornerDistance: Math.max(distanceFromLeftEdge, distanceFromBottomEdge)
    readonly property real bottomRightCornerDistance: Math.max(distanceFromRightEdge, distanceFromBottomEdge)
    readonly property real topLeftRadius: Math.max(((workspaceAtLeft && workspaceAtTop) ? outerRadius : innerRadius) - topLeftCornerDistance, minRadius)
    readonly property real topRightRadius: Math.max(((workspaceAtRight && workspaceAtTop) ? outerRadius : innerRadius) - topRightCornerDistance, minRadius)
    readonly property real bottomLeftRadius: Math.max(((workspaceAtLeft && workspaceAtBottom) ? outerRadius : innerRadius) - bottomLeftCornerDistance, minRadius)
    readonly property real bottomRightRadius: Math.max(((workspaceAtRight && workspaceAtBottom) ? outerRadius : innerRadius) - bottomRightCornerDistance, minRadius)
    readonly property bool compactMode: Math.min(fitW, fitH) < 44
    readonly property real iconRatio: compactMode ? 0.60 : 0.35
    readonly property int iconSizePx: Math.max(14, Math.round(Math.min(fitW, fitH) * iconRatio))
    readonly property int iconSourcePx: iconSizePx * 2
    readonly property string iconName: guessIcon(winData?.class ?? "")

    x: initX
    y: initY
    width: fitW
    height: fitH
    z: isDragging ? 99999 : ((winData?.floating ?? false) ? 2 : 1)

    Drag.active: dragArea.drag.active
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomLeftRadius: root.bottomLeftRadius
            bottomRightRadius: root.bottomRightRadius
        }
    }

    ScreencopyView {
        id: preview
        anchors.fill: parent
        captureSource: root.overviewOpen ? root.toplevel : null
        live: true
    }

    Rectangle {
        anchors.fill: parent
        color: dragArea.pressed ? Qt.rgba(1, 1, 1, 0.12)
             : dragArea.containsMouse ? Qt.rgba(1, 1, 1, 0.07)
             : Qt.rgba(1, 1, 1, 0.03)
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        border.width: 1
        border.color: root.isDragging ? (root.theme?.accent ?? "#a7c080")
                     : (root.theme?.outline ?? Qt.rgba(1, 1, 1, 0.12))
        scale: root.isDragging ? 1.03 : 1.0
        opacity: root.isDragging ? 0.96 : 1.0

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }

    Image {
        id: appIcon
        anchors.centerIn: parent
        width: root.iconSizePx
        height: root.iconSizePx
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        sourceSize: Qt.size(root.iconSourcePx, root.iconSourcePx)
        source: {
            return Quickshell.iconPath(root.iconName, "application-x-executable") ?? ""
        }
        visible: source !== ""
        opacity: 1.0
        z: 2
    }

    // Reposition the window within its current workspace.
    //
    // Only floating windows are repositioned: they're placed at the released
    // pixel position via `movewindowpixel exact`, which is the inverse of the
    // cell→monitor scale used to render the preview.
    //
    // Tiled windows are intentionally not handled — Hyprland's `swapwindow`
    // walks the dwindle binary tree by direction (l/r/u/d) and has no
    // dispatcher that swaps two arbitrary windows by address, so there's no
    // reliable way to "drop a tiled window at a pixel". They snap back to
    // their tree position, which matches dwindle's actual layout behaviour.
    function repositionWithinWorkspace(dx, dy) {
        var floating = root.winData?.floating ?? false
        if (!floating)
            return

        var newLocalX = Math.max(0, Math.min(root.x - root.cellOffsetX, root.wsWidth - root.fitW))
        var newLocalY = Math.max(0, Math.min(root.y - root.cellOffsetY, root.wsHeight - root.fitH))

        var sx = Math.max(root.posScaleX, 0.0001)
        var sy = Math.max(root.posScaleY, 0.0001)
        var absX = Math.round(newLocalX / sx + root.monitorX + root.reservedLeft + root.gapOffset)
        var absY = Math.round(newLocalY / sy + root.monitorY + root.reservedTop + root.gapOffset)
        Hyprland.dispatch("movewindowpixel exact " + absX + " " + absY + ",address:" + root.address)
        root.repositioned()
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        drag.target: parent

        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton)
                root.dragStarted(root.wsId)
        }

        onReleased: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                var dx = root.x - root.initX
                var dy = root.y - root.initY
                if (Math.abs(dx) < 5 && Math.abs(dy) < 5) {
                    root.windowClicked()
                    root.dragEnded()
                } else {
                    var sameWs = (root.currentTargetWs === -1 || root.currentTargetWs === root.wsId)
                    if (sameWs) {
                        root.repositionWithinWorkspace(dx, dy)
                    }
                    root.dragEnded()
                }
                root.x = root.initX
                root.y = root.initY
            }
        }

        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton || mouse.button === Qt.RightButton)
                root.windowMiddleClicked()
        }
    }

    Behavior on x {
        enabled: !root.isDragging
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    Behavior on y {
        enabled: !root.isDragging
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }
}
