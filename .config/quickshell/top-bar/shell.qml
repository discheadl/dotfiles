import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import "lib" as Lib
import "bar" as Bar
import "hub" as Hub
import "overview" as Overview

ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: v
            property var modelData

            // Manejo de Tema
            property bool _isDarkMode: true
            readonly property string _themeModePath: Quickshell.env("HOME") + "/.cache/quickshell/theme_mode"

            FileView {
                id: themeModeFile
                path: v._themeModePath
                watchChanges: true
                preload: true
                onLoaded: v._isDarkMode = (String(text() || "").trim().toLowerCase() !== "light")
                onTextChanged: v._isDarkMode = (String(text() || "").trim().toLowerCase() !== "light")
                onFileChanged: reload()
                onLoadFailed: v._isDarkMode = true
            }

            Lib.ThemeEngine {
                id: screenTheme
                isDarkMode: v._isDarkMode
            }

            // Componentes principales
            Hub.HubWindow {
                id: hub
                screen: v.modelData
                visible: false
                
                // Si presionas ESC dentro del hub, se cierra solo
                Keys.onEscapePressed: v.toggleHub()
            }

            Bar.Bar {
                id: bar
                screen: v.modelData
            }

            Overview.Overview {
                id: overview
                screen: v.modelData
                theme: screenTheme
            }

            // OSDs (Opcionales, agrégalos si tienes los archivos en lib)
            // Lib.VolumeOSD { theme: screenTheme; screen: v.modelData }
            // Lib.BrightnessOSD { theme: screenTheme; screen: v.modelData }

            // Lógica de Toggle Corregida
            function toggleHub() {
                hub.visible = !hub.visible
                if (hub.visible) {
                    // Usamos un pequeño delay para asegurar que la ventana existe antes de pedir el foco
                    focusTimer.restart()
                }
            }

            function toggleOverview() {
                overview.overviewOpen = !overview.overviewOpen
            }

            Timer {
                id: focusTimer
                interval: 50
                onTriggered: hub.forceActiveFocus()
            }

            // Conexión con los clics de la barra
            Connections {
                target: bar
                // El nombre de la función debe coincidir con la señal que emite Bar.qml
                function onRequestHubToggle() { v.toggleHub() }
            }

            // Atajo de teclado (Super + Espacio o lo que tengas en hyprland)
            GlobalShortcut {
                name: "hubToggle"
                onPressed: v.toggleHub()
            }

            GlobalShortcut {
                name: "overviewToggle"
                onPressed: v.toggleOverview()
            }
        }
    }
}