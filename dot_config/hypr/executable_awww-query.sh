#!/usr/bin/env bash

awww query --all | awk -F'image: ' '/image: / { print $2; exit }'
