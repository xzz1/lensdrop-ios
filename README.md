# LensDrop for iOS

LensDrop receives files from animated [cimbar](https://github.com/sz3/libcimbar) codes through the iPhone camera, with no network, Bluetooth, or NFC required. It is an iOS receiver powered by `libcimbar` and compatible with the `cimbar.org` sender and the Android [CameraFileCopy (cfc)](https://github.com/sz3/cfc) ecosystem.

## How it works

1. Open [cimbar.org](https://cimbar.org) on a computer, select a file to send
2. Launch LensDrop, tap **Start Scanning**, point the camera at the animated barcode
3. When complete, tap **Save to Files** to choose where to save the received file

## Screenshots

| Scan | Receiving | Complete |
|------|-----------|----------|
| Camera preview with Start button | Progress bar during decoding | File info with Save button |

## Prerequisites

- Xcode 16+
- iOS 18+ device
- [opencv2.framework](https://github.com/opencv/opencv/releases) (iOS package) placed at project root
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build

```bash
# Clone with submodule
git clone --recurse-submodules https://github.com/xzz1/lensdrop-ios.git
cd lensdrop-ios

# Download OpenCV iOS framework and place at project root
# https://github.com/opencv/opencv/releases (opencv-4.x.x-ios-framework.zip)

# Generate Xcode project
./scripts/generate-xcode.sh

# Open and build
open CimbarApp.xcodeproj
```

## Project structure

```
├── CimbarApp.xcodeproj    # Generated via xcodegen
├── project.yml            # XcodeGen project spec
├── core/                  # App-owned C API wrapper around libcimbar
│   ├── cimbar_c.h
│   └── cimbar_c.cpp
├── ios/                   # iOS app (SwiftUI + Obj-C++ bridge)
│   ├── CimbarApp.swift
│   ├── ScanView.swift
│   ├── SettingsView.swift
│   ├── CimbarSession.swift
│   ├── CameraPreview.swift
│   └── Bridge/            # Obj-C++ bridging layer
├── libcimbar/             # Git submodule: sz3/libcimbar (C++ core)
├── scripts/
│   └── generate-xcode.sh
└── opencv2.framework/     # Downloaded separately
```

## Architecture

```
SwiftUI → CimbarSession → CimbarDecoderBridge (Obj-C++) → cimbar_c (C API)
                                                              └── Decoder (C++)
                                                                   ├── Extractor (corner detection + perspective transform)
                                                                   ├── CimbReader (symbol + color decoding)
                                                                   ├── Interleave (deinterleaving)
                                                                   ├── Reed-Solomon ECC (libcorrect)
                                                                   ├── Fountain codes (wirehair)
                                                                   └── zstd decompression
```

## Credits

Built on [libcimbar](https://github.com/sz3/libcimbar) by Stephen Zhang ([@sz3](https://github.com/sz3)).
Inspired by the [cfc](https://github.com/sz3/cfc) Android decoder app.

## License

This project is [MIT](LICENSE). libcimbar and its bundled dependencies have their own licenses (MPL 2.0, BSD, MIT, etc.).
