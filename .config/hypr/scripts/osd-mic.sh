#!/bin/bash

MIC_NAME=$(pactl get-default-source)

wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

swayosd-client --input-volume mute-toggle --device "$MIC_NAME"
