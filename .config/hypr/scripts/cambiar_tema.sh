#!/bin/bash

if [ -z "$1" ]; then
    echo "Error: Necesitas pasarme la ruta de una imagen."
    echo "Uso: cambiar_tema /ruta/a/tu/imagen.jpg"
    exit 1
fi

echo "🖼️ Aplicando fondo con transición..."
awww img "$1" --transition-type wipe

echo "🎨 Escaneando paleta de colores..."
wallust run "$1"

echo "🔄 Recargando Waybar..."
killall -SIGUSR2 waybar

echo "🔔 Recargando Dunst..."
killall dunst
sleep 0.5

# Levantamos Dunst explícitamente y lo mandamos al fondo
dunst &
disown
sleep 0.5

# Ahora sí, lanzamos la notificación sabiendo que Dunst está despierto
notify-send -u low "🎨 Tema aplicado" "Los colores se han actualizado."

echo "🔊 Recargando SwayOSD..."
killall swayosd-server
swayosd-server > /dev/null 2>&1 & disown

echo "🔄 Recargando bordes de Hyprland..."
hyprctl reload

echo "✅ ¡Cambio de tema completado con éxito!"