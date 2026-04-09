import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root

    property var theme
    property bool overviewOpen: false

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property int wsRows: 2
    readonly property int wsCols: 5
    readonly property int wsCount: wsRows * wsCols
    readonly property int activeWs: Math.max(1, Math.min(wsCount, monitor?.activeWorkspace?.id ?? 1))
    readonly property real wsScale: 0.15
    readonly property int wsGap: 5
    readonly property real containerPadding: 10
    readonly property real elevationMargin: 14
    readonly property real outerRadius: theme?.radiusOuter ?? 24
    readonly property real innerRadius: Math.max(8, Math.round((theme?.radiusInner ?? 16) * 0.55))
    readonly property real wsWidth: screen.width * wsScale
    readonly property real wsHeight: screen.height * wsScale
    readonly property real gridWidth: wsCols * wsWidth + (wsCols - 1) * wsGap
    readonly property real gridHeight: wsRows * wsHeight + (wsRows - 1) * wsGap

    property var windowList: []
    property var windowByAddress: ({})
    property var monitorList: []
    property var monitorById: ({})
    property int draggingFromWs: -1
    property int draggingTargetWs: -1
    property int hyprGapOffset: 0

    visible: overviewOpen
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell:overview"

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                var list = JSON.parse(clientsCollector.text)
                root.windowList = list
                var byAddr = {}
                for (var i = 0; i < list.length; i++) {
                    byAddr[list[i].address] = list[i]
                }
                root.windowByAddress = byAddr
            }
        }
    }

    Process {
        id: getGapConfig
        command: ["bash", "-c", "go=$(hyprctl -j getoption general:gaps_out | sed -n 's/.*\"custom\": *\"\\([0-9]*\\).*/\\1/p'); bs=$(hyprctl -j getoption general:border_size | sed -n 's/.*\"int\": *\\([0-9]*\\).*/\\1/p'); echo $((go + bs))"]
        stdout: StdioCollector {
            id: gapCollector
            onStreamFinished: {
                var val = parseInt(gapCollector.text.trim())
                if (!isNaN(val) && val > 0)
                    root.hyprGapOffset = val
            }
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                var list = JSON.parse(monitorsCollector.text)
                root.monitorList = list
                var byId = {}
                for (var i = 0; i < list.length; i++) {
                    byId[String(list[i].id)] = list[i]
                }
                root.monitorById = byId
            }
        }
    }

    function refreshHyprData() {
        getMonitors.running = true
        getClients.running = true
        if (hyprGapOffset === 0)
            getGapConfig.running = true
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["openlayer", "closelayer", "screencast"].includes(event.name))
                return
            root.refreshHyprData()
        }
    }

    Component.onCompleted: root.refreshHyprData()

    onOverviewOpenChanged: {
        if (overviewOpen)
            root.refreshHyprData()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.overviewOpen = false
    }

    Item {
        id: frame
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: container.implicitWidth + root.elevationMargin * 2
        height: container.implicitHeight + root.elevationMargin * 2

        Rectangle {
            anchors.fill: container
            anchors.topMargin: 12
            z: -1
            radius: container.radius
            color: "black"
            opacity: theme?.isDarkMode === false ? 0.14 : 0.24
        }

        Rectangle {
            id: container
            anchors.centerIn: parent
            implicitWidth: root.gridWidth + root.containerPadding * 2
            implicitHeight: root.gridHeight + root.containerPadding * 2
            radius: root.outerRadius + root.containerPadding
            color: root.theme?.bgPanel ?? Qt.rgba(20 / 255, 23 / 255, 25 / 255, 0.88)
            border.width: 1
            border.color: root.theme?.outline ?? Qt.rgba(1, 1, 1, 0.10)

            Item {
                id: canvas
                anchors.centerIn: parent
                width: root.gridWidth
                height: root.gridHeight

                Grid {
                    id: wsGrid
                    anchors.fill: parent
                    columns: root.wsCols
                    rows: root.wsRows
                    spacing: root.wsGap

                    Repeater {
                        model: root.wsCount

                        Rectangle {
                            id: wsCell
                            readonly property int wsId: index + 1
                            readonly property bool isActive: wsId === root.activeWs
                            readonly property int wsRow: Math.floor(index / root.wsCols)
                            readonly property int wsCol: index % root.wsCols
                            readonly property bool workspaceAtLeft: wsCol === 0
                            readonly property bool workspaceAtRight: wsCol === root.wsCols - 1
                            readonly property bool workspaceAtTop: wsRow === 0
                            readonly property bool workspaceAtBottom: wsRow === root.wsRows - 1
                            property bool dropHovered: false

                            width: root.wsWidth
                            height: root.wsHeight
                            color: dropHovered ? (root.theme?.bgItemHover ?? "#374145")
                                               : (root.theme?.bgCard ?? "#1e2326")
                            topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? root.outerRadius : root.innerRadius
                            topRightRadius: (workspaceAtRight && workspaceAtTop) ? root.outerRadius : root.innerRadius
                            bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? root.outerRadius : root.innerRadius
                            bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? root.outerRadius : root.innerRadius
                            border.width: dropHovered ? 2 : 0
                            border.color: dropHovered ? (root.theme?.accentBlue ?? "#7fbbb3") : "transparent"

                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on border.color { ColorAnimation { duration: 140 } }

                            Text {
                                anchors.centerIn: parent
                                text: wsCell.wsId
                                font.pixelSize: Math.min(root.wsWidth, root.wsHeight) * 0.24
                                font.family: root.theme?.textFont ?? "Manrope"
                                font.weight: Font.DemiBold
                                color: root.theme?.textSecondary ?? "#9da9a0"
                                opacity: 0.22
                            }

                            DropArea {
                                anchors.fill: parent
                                onEntered: {
                                    root.draggingTargetWs = wsCell.wsId
                                    if (root.draggingFromWs !== wsCell.wsId)
                                        wsCell.dropHovered = true
                                }
                                onExited: {
                                    wsCell.dropHovered = false
                                    if (root.draggingTargetWs === wsCell.wsId)
                                        root.draggingTargetWs = -1
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                z: -1
                                onClicked: {
                                    if (root.draggingTargetWs === -1) {
                                        Hyprland.dispatch("workspace " + wsCell.wsId)
                                        root.overviewOpen = false
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    z: 2

                    Repeater {
                        model: ScriptModel {
                            values: {
                                var toplevels = ToplevelManager.toplevels?.values ?? []
                                var result = []
                                for (var i = 0; i < toplevels.length; i++) {
                                    var tl = toplevels[i]
                                    var addr = "0x" + (tl.HyprlandToplevel?.address ?? "")
                                    var win = root.windowByAddress[addr]
                                    if (win && win.workspace && win.workspace.id >= 1 && win.workspace.id <= root.wsCount) {
                                        result.push({
                                            toplevel: tl,
                                            address: addr,
                                            winData: win
                                        })
                                    }
                                }
                                return result
                            }
                        }

                        WindowPreview {
                            id: windowDelegate
                            required property var modelData

                            theme: root.theme
                            toplevel: modelData.toplevel
                            winData: modelData.winData
                            address: modelData.address
                            wsScale: root.wsScale
                            wsWidth: root.wsWidth
                            wsHeight: root.wsHeight
                            wsGap: root.wsGap
                            wsCols: root.wsCols
                            wsRows: root.wsRows
                            outerRadius: root.outerRadius
                            innerRadius: root.innerRadius
                            monitorData: root.monitorById[String(modelData.winData?.monitor)] ?? null
                            overviewOpen: root.overviewOpen
                            gapOffset: root.hyprGapOffset
                            currentTargetWs: root.draggingTargetWs

                            onRepositioned: refreshTimer.restart()

                            onWindowClicked: {
                                Hyprland.dispatch("focuswindow address:" + modelData.address)
                                root.overviewOpen = false
                            }
                            onWindowMiddleClicked: {
                                Hyprland.dispatch("closewindow address:" + modelData.address)
                            }
                            onDragStarted: function(fromWs) {
                                root.draggingFromWs = fromWs
                            }
                            onDragEnded: {
                                var target = root.draggingTargetWs
                                var from = root.draggingFromWs
                                root.draggingFromWs = -1
                                root.draggingTargetWs = -1

                                if (target !== -1 && target !== from) {
                                    Hyprland.dispatch("movetoworkspacesilent " + target + ", address:" + modelData.address)
                                    refreshTimer.restart()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: focusedWorkspaceIndicator
                    readonly property int rowIndex: Math.floor((root.activeWs - 1) / root.wsCols)
                    readonly property int colIndex: (root.activeWs - 1) % root.wsCols
                    readonly property bool workspaceAtLeft: colIndex === 0
                    readonly property bool workspaceAtRight: colIndex === root.wsCols - 1
                    readonly property bool workspaceAtTop: rowIndex === 0
                    readonly property bool workspaceAtBottom: rowIndex === root.wsRows - 1

                    x: (root.wsWidth + root.wsGap) * colIndex
                    y: (root.wsHeight + root.wsGap) * rowIndex
                    width: root.wsWidth
                    height: root.wsHeight
                    color: "transparent"
                    z: 3
                    topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? root.outerRadius : root.innerRadius
                    topRightRadius: (workspaceAtRight && workspaceAtTop) ? root.outerRadius : root.innerRadius
                    bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? root.outerRadius : root.innerRadius
                    bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? root.outerRadius : root.innerRadius
                    border.width: 2
                    border.color: root.theme?.accent ?? "#a7c080"

                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 150
        onTriggered: root.refreshHyprData()
    }

    Keys.onEscapePressed: overviewOpen = false
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left) {
            Hyprland.dispatch("workspace e-1")
        } else if (event.key === Qt.Key_Right) {
            Hyprland.dispatch("workspace e+1")
        }
    }
}
