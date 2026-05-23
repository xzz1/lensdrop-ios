<div align="center">
  <img src="ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" alt="LensDrop 应用图标" width="128">

  # LensDrop iOS 版

  [English](README.md) | **简体中文**

  通过动态彩色图标矩阵条形码进行光学文件接收，无需通过网络传输文件。

  [![TestFlight](https://img.shields.io/badge/TestFlight-加入测试-0D96F6?style=for-the-badge&logo=appstore)](https://testflight.apple.com/join/8mEjTABF)
</div>

> LensDrop 当前处于公开测试阶段。欢迎通过 [GitHub Issues](https://github.com/xzz1/lensdrop-ios/issues) 反馈问题与建议。

LensDrop 是一款由 [libcimbar](https://github.com/sz3/libcimbar) 驱动的 iPhone 与 iPad 接收端应用。电脑端发送页面会将文件显示为动态 `cimbar` 码，LensDrop 使用相机扫描屏幕，并在设备本地恢复文件。它兼容 `cimbar.org` 发送端以及 Android [CameraFileCopy (cfc)](https://github.com/sz3/cfc) 生态。

## 功能特点

- **离线光学接收** — 通过相机接收文件，无需网络连接。
- **保存到文件** — 使用系统文件选择器导出已接收的文件。
- **内置离线发送端** — 可在设置中导出独立的 `cimbar_js.html`，用于完全离线场景。

## 使用方法

1. 在电脑上打开发送端。你可以使用从 LensDrop 导出的 sender HTML、从 App 取得官方最新版发送端，或直接打开 [cimbar.org](https://cimbar.org)。
2. 在发送页面中选择文件，使其显示为动态 cimbar 码。
3. 在 iPhone 或 iPad 上启动 LensDrop，点击 **开始扫描**。
4. 将相机对准电脑屏幕中的码图。
5. 接收完成后，点击 **保存到文件** 并选择保存位置。

LensDrop 不会通过网络发送所接收的文件；相机画面只在设备本地用于解码。详情请阅读[隐私政策](PRIVACY.md)。

## 公开测试

最新公开测试版本可通过 TestFlight 安装：

**[通过 TestFlight 下载 LensDrop Beta](https://testflight.apple.com/join/8mEjTABF)**

在测试期间，TestFlight 构建可能持续变化。反馈问题时，建议附上复现步骤、设备信息以及所使用的发送/接收流程，并提交至 [GitHub Issues](https://github.com/xzz1/lensdrop-ios/issues)。

## 从源码构建

### 环境要求

- Xcode 15 或更高版本，并带有 iOS 16 或更高版本 SDK。
- 运行 iOS 16 或更高版本的 iPhone 或 iPad。
- [xcodegen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）。
- iOS 版 [opencv2.framework](https://github.com/opencv/opencv/releases)，放置于项目根目录。
- 支持 submodule 的 Git。

### 构建步骤

```bash
# 克隆仓库并初始化 libcimbar 子模块。
git clone --recurse-submodules https://github.com/xzz1/lensdrop-ios.git
cd lensdrop-ios

# 下载 OpenCV iOS framework，并将 opencv2.framework 放到项目根目录。
# https://github.com/opencv/opencv/releases

# 修改 project.yml 后，通过 XcodeGen 重新生成工程。
./scripts/generate-xcode.sh

# 打开生成的工程，并选择真机编译运行。
open CimbarApp.xcodeproj
```

## 项目结构

```text
├── CimbarApp.xcodeproj       # 通过 XcodeGen 生成
├── project.yml               # XcodeGen 配置
├── core/                     # App 自有的 libcimbar C API 封装
├── ios/
│   ├── Assets.xcassets/      # LensDrop App 图标
│   ├── Bridge/               # Objective-C++ 桥接层
│   ├── Resources/            # 内置 sender HTML 与第三方许可
│   ├── en.lproj/             # 英文 UI 与 Info.plist 本地化
│   ├── zh-Hans.lproj/        # 简体中文本地化
│   ├── CimbarApp.swift       # App 外壳、Tab 与生命周期行为
│   ├── CimbarSession.swift   # 扫描/解码会话状态
│   ├── Localization.swift    # App 内语言选择支持
│   ├── PrivacyPolicyView.swift
│   ├── ScanView.swift
│   └── SettingsView.swift
├── libcimbar/                # sz3/libcimbar git 子模块
├── PRIVACY.md                # 公开隐私政策（English / 简体中文）
├── scripts/generate-xcode.sh
└── opencv2.framework/        # 需单独下载，不纳入仓库
```

## 架构

```text
SwiftUI → CimbarSession → CimbarDecoderBridge (Objective-C++) → cimbar_c (C API)
                                                              └── Decoder (C++)
                                                                   ├── 提取与透视变换
                                                                   ├── 符号与颜色解码
                                                                   ├── Reed-Solomon 纠错
                                                                   ├── 喷泉码重组
                                                                   └── zstd 解压缩
```

## 隐私

LensDrop 为离线接收而设计：不收集、出售或上传个人信息。相机输入只在设备本地用于解码，完整接收的文件也只有在你通过系统文件界面选择保存位置后才会写入。

完整的双语隐私政策请见 [PRIVACY.md](PRIVACY.md)。

## 致谢与许可

LensDrop 基于 Stephen Zhang（[@sz3](https://github.com/sz3)）开发的 [libcimbar](https://github.com/sz3/libcimbar)，并受到 Android [cfc](https://github.com/sz3/cfc) 解码端应用启发。

App 内置的官方 `libcimbar` 发送端与 `libcimbar` 代码依据 Mozilla Public License 2.0 分发；随附许可位于 `ios/Resources/Licenses/libcimbar-MPL-2.0.txt`。其他第三方依赖继续遵循各自的许可协议。
