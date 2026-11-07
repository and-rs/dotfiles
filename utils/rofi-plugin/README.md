# Rofi tab memory

Build against the installed Rofi's headers and GLib/Cairo development files.
Set `PKG_CONFIG_PATH` or `CMAKE_PREFIX_PATH` when needed, as with the Quickshell plugins.

```sh
cmake -S utils/rofi-plugin -B utils/rofi-plugin/build -G Ninja
cmake --build utils/rofi-plugin/build
```

The build writes `libtabmemory.so` into `dot_config/rofi/plugins/` for deployment
with the dotfiles. The normal launcher restores the last tab, defaulting to Apps.
The plugin captures mode names once at startup, then uses Rofi's final mode index
to save the last tab's name on normal exit. No timer or ongoing observer. Only launcher sessions with
`ROFI_LAST_MODE_FILE` set are recorded. It uses exported Rofi internals;
rebuild and verify after Rofi upgrades.
