# ios-xc-tool

[![Build Tquic.framework](https://github.com/9xhk-1/ios-xc-tool/actions/workflows/build.yml/badge.svg)](https://github.com/9xhk-1/ios-xc-tool/actions/workflows/build.yml)

Injects an **ImGui debug overlay** into any iOS app at runtime.

## How it works

1. Dylib loads via `LC_LOAD_DYLIB` or framework replacement
2. `__attribute__((constructor))` fires 2 seconds after app launch
3. Creates a transparent `UIWindow` at high z-order
4. Renders ImGui via Metal (`MTKView`) on top of the app

## Project structure

```
ios-xc-tool/
├── src/
│   ├── main.mm             # Entry point (constructor)
│   ├── OverlayView.h       # Overlay view header
│   ├── OverlayView.mm      # ImGui + Metal rendering
│   ├── Config.h            # Configuration constants
│   └── backends/
├── .github/workflows/
│   └── build.yml           # CI: auto-build Tquic.framework
├── deps/imgui/             # Dear ImGui (after setup.sh)
├── build/                  # Build output
├── dist/                   # Packaged framework
├── setup.sh                # Download dependencies
├── build.sh                # Compile dylib
├── package_framework.sh    # Package as .framework
├── Makefile
└── README.md
```

## Quick start (local build)

```bash
# 1. Install dependencies
./setup.sh

# 2. Build dylib
./build.sh

# 3. Package as .framework (for IPA replacement)
./package_framework.sh
# Output: dist/Tquic.framework/
```

**Prerequisites:** macOS + Xcode + Command Line Tools

## CI / GitHub Actions

Push to `master` and the workflow auto-builds `Tquic.framework`.
Download from **Actions → latest run → Artifacts**.

## Injection methods

### Method A: Framework replacement (easiest)

Download `Tquic.framework` from CI Artifacts, then:

```bash
# 1. Unzip
unzip target.ipa -d Payload

# 2. Replace the framework
rm -rf Payload/App.app/Frameworks/Tquic.framework
cp -R Tquic.framework Payload/App.app/Frameworks/

# 3. Resign
codesign -f -s "iPhone Developer: xxx" \
  Payload/App.app/Frameworks/Tquic.framework/Tquic
codesign -f -s "iPhone Developer: xxx" \
  --entitlements entitlements.plist Payload/App.app

# 4. Repack
zip -qr injected.ipa Payload
```

The dylib's `install_name` is `@rpath/Tquic.framework/Tquic` so it matches the original Tencent TQUIC framework path.

### Method B: insert_dylib

```bash
unzip target.ipa -d Payload
insert_dylib @executable_path/ios_xc_tool.dylib Payload/App.app/App --inplace
cp build/ios_xc_tool.dylib Payload/App.app/
codesign -f -s "iPhone Developer: xxx" Payload/App.app/ios_xc_tool.dylib
codesign -f -s "iPhone Developer: xxx" --entitlements entitlements.plist Payload/App.app
zip -qr injected.ipa Payload
```

### Method C: DYLD_INSERT_LIBRARIES

```bash
# On jailbroken device
scp build/ios_xc_tool.dylib root@device:/usr/lib/
ssh root@device "DYLD_INSERT_LIBRARIES=/usr/lib/ios_xc_tool.dylib launchctl kickstart ..."
```

## Menu tabs

| Tab | Content |
|-----|---------|
| Home | App info, device info |
| Test | Checkbox, sliders, buttons |
| Log | Runtime log messages |
| About | Version info |
