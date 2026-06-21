<div align="center">
  <img src="ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" alt="LensDrop app icon" width="120">

  # LensDrop

  **English** | [简体中文](README.zh-CN.md)

  iOS receiver for files sent as animated `cimbar` codes.

  [TestFlight public beta](https://testflight.apple.com/join/8mEjTABF)
</div>

LensDrop scans a computer screen and rebuilds the file on the phone. The sender can be [cimbar.org](https://cimbar.org), the official `cimbar_js.html`, or the offline sender HTML exported from LensDrop settings.

The transfer is optical: the file is shown as animated color matrix codes, and the camera reads those codes. LensDrop does not upload the received file or camera frames.

## Status

This app is in public beta. If something fails, please open a [GitHub issue](https://github.com/xzz1/lensdrop-ios/issues) with:

- device model and iOS version
- sender used: `cimbar.org`, bundled HTML, or another build
- file size and file type
- what the scan screen showed, especially decoded/extracted frame counts

## Use It

1. Install the beta from [TestFlight](https://testflight.apple.com/join/8mEjTABF), or build from source.
2. On a computer, open [cimbar.org](https://cimbar.org) or an offline `cimbar_js.html` sender.
3. Choose a file in the sender.
4. In LensDrop, tap **Start Scanning** and point the camera at the screen.
5. When the file is complete, save it with **Save to Files**.

For offline use, open Settings in LensDrop and export the bundled sender HTML. That file can be opened directly in a desktop browser.

## What Is Here

- SwiftUI iOS app for receiving `cimbar` transfers.
- Objective-C++ bridge around `libcimbar`.
- Bundled official `libcimbar` sender HTML.
- English and Simplified Chinese UI.
- Local privacy policy and third-party license notice.

## Build

Requirements:

- Xcode 15 or newer
- iOS 16 deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- OpenCV iOS framework, placed at `opencv2.framework` in the repo root
- Git submodules

```bash
git clone --recurse-submodules https://github.com/xzz1/lensdrop-ios.git
cd lensdrop-ios

# Download OpenCV for iOS and place opencv2.framework here.
# https://github.com/opencv/opencv/releases

./scripts/generate-xcode.sh
open CimbarApp.xcodeproj
```

Build and run on a real device. The camera path is the important part; the simulator is not useful for testing reception.

## Layout

```text
core/                  C API wrapper around libcimbar
ios/                   SwiftUI app and Objective-C++ bridge
ios/Resources/         bundled sender HTML and license files
libcimbar/             upstream libcimbar submodule
project.yml            XcodeGen project definition
scripts/generate-xcode.sh
```

## Privacy

LensDrop works locally. It uses the camera to decode the screen and writes a received file only after you choose a destination through the system file picker.

See [PRIVACY.md](PRIVACY.md) for the full policy.

## Credits

LensDrop uses [libcimbar](https://github.com/sz3/libcimbar) by Stephen Zhang and follows the same file-transfer format as the Android [cfc](https://github.com/sz3/cfc) app.

The bundled `libcimbar` sender and `libcimbar` code are distributed under MPL 2.0. The bundled notice is at `ios/Resources/Licenses/libcimbar-MPL-2.0.txt`.
