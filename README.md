#  ios-xc-tool

Injects an **ImGui debug overlay** into any iOS app at runtime.

## How it works

1. Dylib loads via `LC_LOAD_DYLIB` (inserted into Mach-O) or `DYLD_INSERT_LIBRARIES`
2. `__attribute__((constructor))` fires 2 seconds after app launch
3. Creates a transparent `UIWindow` at high z-order
4. Renders ImGui via Metal (`MTKView`) on top of the app

## Project structure

```
ios-xc-tool/
├── src/
│   ├── main.mm          # Entry point (constructor)
│   ├── OverlayView.h    # Overlay view header
│   ├── OverlayView.mm   # ImGui + Metal rendering
│   ├── Config.h         # Configuration constants
│   └── backends/        # (optional) custom backends
├── deps/                # Downloaded dependencies
│   └── imgui/           # Dear ImGui (after setup.sh)
├── build/               # Build output
├── setup.sh             # Download dependencies
├── build.sh             # Compile dylib
├── Makefile             # Alternative build
└── README.md
```

## Quick start

```bash
# 1. Install dependencies
./setup.sh

# 2. Build
./build.sh

# Output: build/ios_xc_tool.dylib
```

**Prerequisites:**
- macOS with Xcode installed
- Command Line Tools (`xcode-select --install`)

## Injection methods

### Method A: insert_dylib (recommended)

```bash
# 1. Unzip
unzip target.ipa -d Payload

# 2. Inject load command
insert_dylib @executable_path/ios_xc_tool.dylib \
    Payload/App.app/App --inplace

# 3. Copy dylib
cp build/ios_xc_tool.dylib Payload/App.app/

# 4. Resign
codesign -f -s "iPhone Developer: xxx" Payload/App.app/ios_xc_tool.dylib
codesign -f -s "iPhone Developer: xxx" --entitlements entitlements.plist Payload/App.app

# 5. Repack
zip -qr injected.ipa Payload
```

### Method B: Framework replacement

Replace any existing `.framework` in `Frameworks/` and rename dylib to match.

## Menu tabs

| Tab | Content |
|-----|---------|
| Home | App info, device info |
| Test | Checkbox, sliders, buttons |
| Log | Runtime log messages |
| About | Version info |
