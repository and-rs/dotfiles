#!/usr/bin/env bash

QUICKSHELL_LOG=warn QML_IMPORT_PATH="$HOME/.config/quickshell${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" quickshell -n --log-rules "*.debug=false"
