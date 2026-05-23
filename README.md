<div align="center">
  <img src="ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" alt="LensDrop app icon" width="128">

  # LensDrop for iOS

  **English** | [简体中文](README.zh-CN.md)

  Receive files optically from animated color icon matrix barcodes, with no network transfer required.

  [![TestFlight](https://img.shields.io/badge/TestFlight-Join_Beta-0D96F6?style=for-the-badge&logo=appstore)](https://testflight.apple.com/join/8mEjTABF)
</div>

> LensDrop is currently in public beta. Feedback and bug reports are welcome through [GitHub Issues](https://github.com/xzz1/lensdrop-ios/issues).

LensDrop is an iPhone and iPad receiver powered by [libcimbar](https://github.com/sz3/libcimbar). A sender page on your computer displays a file as animated `cimbar` codes; LensDrop scans the screen through the camera and reconstructs the file locally on your device. It is compatible with the `cimbar.org` sender and the Android [CameraFileCopy (cfc)](https://github.com/sz3/cfc) ecosystem.

## Features

- **Offline optical reception** — receive files through the camera, no network connection required.
- **Save to Files** — export completed files using the system file picker.
- **Bundled offline sender** — export a self-contained `cimbar_js.html` from Settings for air-gapped usage.

## How It Works

1. On a computer, open the sender. You can use the sender HTML exported by LensDrop, download the latest official sender from the app, or open [cimbar.org](https://cimbar.org).
2. Choose a file on the sender page to display it as animated cimbar codes.
3. On your iPhone or iPad, launch LensDrop and tap **Start Scanning**.
4. Point the camera at the code on the computer screen.
5. When reception completes, tap **Save to Files** and choose a destination.

No transferred file is sent by LensDrop over a network. Camera frames are processed locally for decoding; see the [Privacy Policy](PRIVACY.md) for details.

## Public Beta

The latest public testing build is available through TestFlight:

**[Download LensDrop Beta on TestFlight](https://testflight.apple.com/join/8mEjTABF)**

TestFlight builds may change while the app is being tested. Please report reproducible issues, device details, and any problematic sender/receiver workflow through [GitHub Issues](https://github.com/xzz1/lensdrop-ios/issues).

## Build from Source

### Requirements

- Xcode 15 or later with an iOS 16 or later SDK.
- An iPhone or iPad running iOS 16 or later.
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
- [opencv2.framework](https://github.com/opencv/opencv/releases) for iOS, placed at the project root.
- Git with submodule support.

### Build

```bash
# Clone with the libcimbar submodule.
git clone --recurse-submodules https://github.com/xzz1/lensdrop-ios.git
cd lensdrop-ios

# Download the OpenCV iOS framework and place opencv2.framework at the project root.
# https://github.com/opencv/opencv/releases

# Generate the Xcode project after changes to project.yml.
./scripts/generate-xcode.sh

# Open the generated project and build for a device.
open CimbarApp.xcodeproj
```

## Project Structure

```text
├── CimbarApp.xcodeproj       # Generated through XcodeGen
├── project.yml               # XcodeGen specification
├── core/                     # App-owned C API wrapper around libcimbar
├── ios/
│   ├── Assets.xcassets/      # LensDrop App Icon
│   ├── Bridge/               # Objective-C++ bridging layer
│   ├── Resources/            # Bundled sender HTML and third-party license
│   ├── en.lproj/             # English UI and Info.plist localizations
│   ├── zh-Hans.lproj/        # Simplified Chinese localizations
│   ├── CimbarApp.swift       # App shell, tabs, lifecycle behavior
│   ├── CimbarSession.swift   # Scan/decode session state
│   ├── Localization.swift    # In-app language selection support
│   ├── PrivacyPolicyView.swift
│   ├── ScanView.swift
│   └── SettingsView.swift
├── libcimbar/                # sz3/libcimbar git submodule
├── PRIVACY.md                # Public privacy policy (English / 简体中文)
├── scripts/generate-xcode.sh
└── opencv2.framework/        # Downloaded separately, not committed
```

## Architecture

```text
SwiftUI → CimbarSession → CimbarDecoderBridge (Objective-C++) → cimbar_c (C API)
                                                              └── Decoder (C++)
                                                                   ├── Extraction and perspective transform
                                                                   ├── Symbol and color decoding
                                                                   ├── Reed-Solomon error correction
                                                                   ├── Fountain code reassembly
                                                                   └── zstd decompression
```

## Privacy

LensDrop is designed for offline reception: it does not collect, sell, or upload personal information. Camera input is used locally for decoding, and completed files are written only when you choose a destination through the system file interface.

Read the full bilingual policy in [PRIVACY.md](PRIVACY.md).

## Credits and License

LensDrop is powered by [libcimbar](https://github.com/sz3/libcimbar) by Stephen Zhang ([@sz3](https://github.com/sz3)) and inspired by the Android [cfc](https://github.com/sz3/cfc) decoder.

The bundled official `libcimbar` sender and `libcimbar` code are distributed under the Mozilla Public License 2.0; the bundled notice is included in `ios/Resources/Licenses/libcimbar-MPL-2.0.txt`. Other bundled dependencies retain their respective licenses.
