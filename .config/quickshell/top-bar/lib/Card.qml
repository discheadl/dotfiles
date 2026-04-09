import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme

Rectangle {
    id: root
    property QtObject theme: null
    readonly property bool themed: theme !== null
    readonly property bool isDark: !themed
                                  || (theme.isDarkMode === undefined ? true : theme.isDarkMode)

    // Background
    color: themed && theme.bgCard !== undefined ? theme.bgCard : Theme.bgCard
    radius: Theme.radiusOuter

    // Hover
    HoverHandler { id: hoverHandler }

    // Lift
    scale: hoverHandler.hovered ? 1.005 : 1.0
    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

    // Border — always 1px so the card edge stays visible in light mode too,
    // sourced from the engine so it follows wallust + dark/light tinting.
    border.width: 1
    border.color: {
        if (themed && theme.border !== undefined) {
            return hoverHandler.hovered && theme.subtleFillHover !== undefined
                ? theme.subtleFillHover
                : theme.border
        }
        return isDark ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.14)
    }
    Behavior on border.color { ColorAnimation { duration: 200 } }

    // Content
    default property alias content: container.data
    property int pad: Theme.padCard

    implicitHeight: container.implicitHeight + (pad * 2)
    implicitWidth: container.implicitWidth + (pad * 2)

    // Shadow
    Rectangle {
        z: -1
        anchors.fill: parent
        anchors.topMargin: 10
        color: "black"
        // Slightly softer in light mode 
        opacity: isDark ? 0.22 : 0.14
        radius: parent.radius
    }

    ColumnLayout {
        id: container
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.pad
        spacing: 0
    }
}
