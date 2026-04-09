#!/bin/bash

WATCH_DIR="/home/dischead/Shared"

# Necesario para que notify-send/dunstify llegue al dunst de tu sesión
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

inotifywait -m -e close_write -e moved_to "$WATCH_DIR" --format '%f' |
while read -r filename; do
    # Ignorar archivos temporales del iPhone (.sb-*, ._*, .DS_Store)
    [[ "$filename" =~ ^\. ]] && continue
    [[ "$filename" =~ \.sb- ]] && continue

    filepath="$WATCH_DIR/$filename"
    ext="${filename##*.}"

    case "${ext,,}" in
        jpg|jpeg|png|gif|webp|heic) icon="image-x-generic"      ;;
        pdf)                         icon="application-pdf"      ;;
        doc|docx|odt)                icon="x-office-document"    ;;
        xls|xlsx|csv)                icon="x-office-spreadsheet" ;;
        mp4|mov|mkv|avi)             icon="video-x-generic"      ;;
        mp3|aac|flac|m4a)            icon="audio-x-generic"      ;;
        zip|rar|tar|gz)              icon="package-x-generic"    ;;
        *)                           icon="text-x-generic"       ;;
    esac

    action=$(dunstify \
        --icon="$icon" \
        --action="open,Abrir" \
        "Archivo recibido" \
        "$filename")

    [[ "$action" == "open" ]] && xdg-open "$filepath"
done