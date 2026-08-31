# IconValidation

This QML extension validates Quickshell `image://icon/...` sources with the
same in-process `QIcon::pixmap()` call used by Quickshell's icon provider.

Build it against the Qt installation used by Quickshell:

```sh
cmake -S utils/icon-validation -B /tmp/iconvalidation-build -G Ninja -DCMAKE_PREFIX_PATH=/path/to/qtbase/lib/cmake
cmake --build /tmp/iconvalidation-build
```

The build writes `libiconvalidationplugin.so` to
`dot_config/quickshell/IconValidation/`, where Quickshell imports it. QtSvg
must be available to the running Quickshell process, as it is for SVG tray
icons.
