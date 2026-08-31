# IconValidation

This QML extension validates Quickshell `image://icon/...` sources with the
same in-process `QIcon::pixmap()` call used by Quickshell's icon provider.

Build it against the Qt installation used by Quickshell:

```sh
cmake -S . -B /tmp/iconvalidation-build -G Ninja -DCMAKE_PREFIX_PATH=/path/to/qtbase/lib/cmake
cmake --build /tmp/iconvalidation-build
```

The build writes `libiconvalidationplugin.so` into this directory. QtSvg must
be available to the running Quickshell process, as it is for SVG tray icons.
