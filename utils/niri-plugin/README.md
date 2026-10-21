# Niri Plugin

This QML extension exposes the niri compositor to Quickshell. It connects to
`NIRI_SOCKET`, keeps window and workspace models in sync from the event stream,
and provides focus and close actions.

Build it against the Qt installation used by Quickshell (Qt 6.11):

```sh
cmake -S utils/niri-plugin -B build -G Ninja -DCMAKE_PREFIX_PATH="/path/to/qtbase;/path/to/qtdeclarative"
cmake --build build
```

The build writes `libniriplugin.so`, `qmldir`, and `niriplugin.qmltypes` to
`dot_config/quickshell/Niri/`, where Quickshell imports it from.
