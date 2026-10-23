# IconValidation

This QML extension validates Quickshell `image://icon/...` sources with the
same in-process `QIcon::pixmap()` call used by Quickshell's icon provider.
SVG warnings are suppressed only during validation on the calling thread;
other messages are forwarded to the existing Qt message handler. Rejected
icons use the tray fallback without being loaded again by QML.

Build it against the Qt installation used by Quickshell:

```sh
cmake -S utils/icon-validation -B /tmp/iconvalidation-build -G Ninja -DCMAKE_PREFIX_PATH=/path/to/qtbase/lib/cmake
cmake --build /tmp/iconvalidation-build
ctest --test-dir /tmp/iconvalidation-build --output-on-failure
```

The build writes `libiconvalidationplugin.so` to
`dot_config/quickshell/IconValidation/`, where Quickshell imports it. QtSvg
must be available to the running Quickshell process, as it is for SVG tray
icons.
