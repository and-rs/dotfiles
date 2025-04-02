#!/usr/bin/env bash

if ! pgrep kitty > /dev/null; then
    kitty &
fi

if ! pgrep zen > /dev/null; then
    zen &
fi

if ! pgrep spotify > /dev/null; then
    spotify &
fi

if ! pgrep google-chrome > /dev/null; then
    google-chrome &
fi
