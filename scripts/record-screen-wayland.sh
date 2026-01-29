#!/usr/bin/env bash

if pgrep -x wf-recorder > /dev/null; then
    pkill wf-recorder
    notify-send -t 1000 "Recording stopped"
    echo "Recording stopped"
else
    timestamp=$(date +%Y-%m-%d_%H-%M)
    geometry=$(slurp)

    if [ -z "$geometry" ]; then
        echo "Selection cancelled"
        exit 1
    fi


    filename="$HOME/recording_${timestamp}.mp4"
    wf-recorder -g "$geometry" -c libx264rgb -p crf=22 -p preset=ultrafast --file="$filename" &
    notify-send -t 1000 "Recording started" "$filename" -a "wf-recorder"
    echo "Recording started: $filename"
fi
