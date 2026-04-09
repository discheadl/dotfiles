#!/bin/bash
LAPTOP="eDP-1"
EXTERNAL="HDMI-A-1"
LAPTOP_RES="1920x1080@60"
EXTERNAL_RES="preferred"

CHOICE=$(printf "󰲐  PC screen only\n󰆟  Duplicate\n󱋊  Extend\n󰹑  Second screen only" | rofi \
    -dmenu \
    -no-custom \
    -theme-str '
    window { width: 400px; location: center; border: 2px; }
    mainbox { children: [listview]; padding: 10px; }
    listview { lines: 4; fixed-height: true; spacing: 5px; }
    element { padding: 12px 15px; border-radius: 8px; }
    element selected { border-radius: 8px; }
    inputbar { enabled: false; }
    ')

case "$CHOICE" in
    *"PC screen only"*)
        hyprctl keyword misc:vrr 1
        hyprctl keyword monitor "$LAPTOP,$LAPTOP_RES,0x0,1"
        hyprctl keyword monitor "$EXTERNAL,disable"
        ;;
    *"Duplicate"*)
        hyprctl keyword misc:vrr 0
        hyprctl keyword monitor "$LAPTOP,$LAPTOP_RES,0x0,1"
        hyprctl keyword monitor "$EXTERNAL,$EXTERNAL_RES,1920x0,1"
        sleep 0.5
        hyprctl keyword monitor "$EXTERNAL,$LAPTOP_RES,0x0,1,mirror,$LAPTOP"
        sleep 0.2
        hyprctl dispatch dpms on
        ;;
    *"Extend"*)
        hyprctl keyword misc:vrr 1
        hyprctl keyword monitor "$LAPTOP,$LAPTOP_RES,0x0,1"
        hyprctl keyword monitor "$EXTERNAL,$EXTERNAL_RES,1920x0,1"
        ;;
    *"Second screen only"*)
        hyprctl keyword misc:vrr 1
        hyprctl keyword monitor "$EXTERNAL,$EXTERNAL_RES,0x0,1"
        sleep 0.3
        hyprctl keyword monitor "$LAPTOP,disable"
        ;;
    *)
        exit 0
        ;;
esac

sleep 0.1