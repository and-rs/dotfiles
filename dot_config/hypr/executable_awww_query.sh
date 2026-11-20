#!/usr/bin/env bash

timeout 1s awww query --all 2>/dev/null |
    awk -F'currently displaying: image: ' 'NF > 1 { print $2; exit }'
