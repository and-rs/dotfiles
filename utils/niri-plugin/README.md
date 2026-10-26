# Niri Plugin

This QML extension exposes the niri compositor to Quickshell. It connects to
`NIRI_SOCKET`, keeps window and workspace models in sync from the event stream,
and provides focus and close actions.

Build it against the same Qt installation used by Quickshell:

```sh
cmake -S utils/niri-plugin -B build -G Ninja -DCMAKE_PREFIX_PATH="/path/to/qtbase;/path/to/qtdeclarative"
cmake --build build
```

The build writes `libniriplugin.so`, `qmldir`, and `niriplugin.qmltypes` to
`dot_config/quickshell/Niri/`, where Quickshell imports it from.

Run the IPC connection, reconnect, and teardown regression test with:

```sh
ctest --test-dir build --output-on-failure
```
