import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "lib" as Lib
import "hub" as Hub

ShellRoot {
    PanelWindow {
        anchors.top:   true
        anchors.right: true
        color: "transparent"
        implicitWidth:  340
        implicitHeight: 400

        Lib.ThemeEngine { id: theme; isDarkMode: true }

        Rectangle {
            anchors.fill: parent
            color: theme.bgMain
            radius: 24

            ColumnLayout {
                anchors.fill:    parent
                anchors.margins: 12
                spacing: 10

                Hub.Header {
                    Layout.fillWidth: true
                    theme: theme
                    active: true
                    onCloseRequested: {}
                    onPowerAction: function(act, lbl) { console.log(act) }
                }

                Hub.ButtonsSlidersCard {
                    Layout.fillWidth: true
                    theme: theme
                    active: true
                    onCloseRequested: {}
                    onBatteryToggleRequested: {}
                }
            }
        }
    }
}