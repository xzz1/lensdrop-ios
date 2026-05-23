# LensDrop iOS 解码端 App 实现方案

## Context

基于 [sz3/libcimbar](https://github.com/sz3/libcimbar) 开源库（MPL 2.0），构建一个 iOS 解码端 App。libcimbar 通过屏幕显示动画彩色条码 → 手机摄像头读取的方式，实现纯光学、无网络数据传输（~850 kbps）。Android 解码器 [cfc](https://github.com/sz3/cfc) 已存在，iOS 端尚空缺。

## 架构总览

```
┌───────────────────────────────────────────────┐
│  SwiftUI Layer                               │
│  CameraPreview / DecodeProgress / FileList   │
├───────────────────────────────────────────────┤
│  AVFoundation → CMSampleBuffer → CVPixelBuffer│
├───────────────────────────────────────────────┤
│  Obj-C++ Bridge (CimbarDecoder.mm)           │
│  - 相机帧格式转换 (YUV→RGB/BGRA)             │
│  - 帧筛选 & 解码调度                         │
├───────────────────────────────────────────────┤
│  libcimbar C++ Core (vendored as source)      │
│  Extractor → CimbReader → FountainDecoder    │
│  → libcorrect ECC → zstd decompress          │
├───────────────────────────────────────────────┤
│  opencv2.framework (裁剪版)                   │
│  imgproc + core modules only (~15MB)          │
└───────────────────────────────────────────────┘
```

## 解码管线

```
摄像头帧 → 灰度化+GaussianBlur → 阈值化 → 四角锚点检测 → 透视变换
→ 逐tile图像哈希匹配(4bits) + 颜色解码(2bits) → 去交织 → Reed-Solomon ECC
→ Fountain Code重组 → zstd解压 → 输出文件
```

## 项目结构

```
lensdrop-ios/
├── CimbarApp.xcodeproj
├── libcimbar/                    # 源码: pinned git submodule
│   ├── src/lib/                  # 核心库
│   │   ├── bit_file/
│   │   ├── chromatic_adaptation/
│   │   ├── cimb_translator/      # 解码核心: CimbDecoder, CimbReader
│   │   ├── compression/          # zstd 封装: zstd_decompressor
│   │   ├── extractor/            # 锚点检测+透视变换: Scanner, Extractor, Deskewer
│   │   ├── fountain/             # fountain code: FountainDecoder, fountain_decoder_sink
│   │   ├── image_hash/           # 图像哈希 tile 匹配
│   │   ├── serialize/
│   │   └── util/
│   └── src/third_party_lib/     # 第三方依赖
│       ├── base91/
│       ├── cxxopts/
│       ├── intx/
│       ├── libcorrect/           # Reed-Solomon ECC
│       ├── libpopcnt/
│       ├── wirehair/             # Fountain codes (C)
│       └── zstd/
├── ios/                          # iOS 原生代码
│   ├── CimbarApp.swift           # App 入口
│   ├── ContentView.swift         # 主界面
│   ├── CameraViewModel.swift     # 相机管理 + 解码状态
│   ├── CameraPreview.swift       # UIViewRepresentable 相机预览
│   ├── FileListView.swift        # 已接收文件列表
│   ├── CimbarSession.swift       # 解码会话调度
│   ├── Bridge/                   # Obj-C++ 桥接层
│   │   ├── CimbarDecoderBridge.h
│   │   └── CimbarDecoderBridge.mm
│   └── Assets.xcassets/
├── core/                         # App 自有的 libcimbar C API wrapper
│   ├── cimbar_c.h
│   └── cimbar_c.cpp
├── cimbar.xcframework/           # 预编译 libcimbar.a + headers
├── opencv2.framework             # 预编译裁剪版 OpenCV (core+imgproc)
├── CMakeLists.txt                # libcimbar.a 的 iOS 交叉编译
└── doc/
    └── CIMBAR_IOS_PLAN.md
```

## 构建系统

### CMake iOS 交叉编译

使用 CMake 将 libcimbar C++ 源码编译为 `libcimbar.a` 静态库：

```cmake
cmake_minimum_required(VERSION 3.15)
project(libcimbar-ios LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET 15.0)
```

### OpenCV 裁剪

libcimbar 解码端实际只用到的 OpenCV 模块：
- `core` — Mat 基础操作
- `imgproc` — cvtColor, GaussianBlur, threshold, adaptiveThreshold, warpPerspective, getPerspectiveTransform, filter2D

完整 framework ~150MB → 裁剪后 ~15MB。使用 `build_framework.py --without` 排除不需要的模块。

## 桥接层设计 (CimbarDecoderBridge)

```objc
@interface CimbarDecodeResult : NSObject
@property (nonatomic, assign) BOOL success;
@property (nonatomic, assign) float progress;      // 0.0 ~ 1.0
@property (nonatomic, strong) NSData *fileData;
@property (nonatomic, copy)   NSString *fileName;
@end

@interface CimbarDecoderBridge : NSObject
- (instancetype)initWithExpectedFileSize:(uint64_t)expectedSize
                             colorBits:(unsigned)colorBits
                            symbolBits:(unsigned)symbolBits
                                  dark:(BOOL)dark;
- (CimbarDecodeResult *)processFrame:(CMSampleBufferRef)sampleBuffer;
- (float)decodeProgress;
- (void)reset;
@end
```

### 帧处理管线 (.mm 实现)

1. `CMSampleBufferRef` → `CVPixelBufferRef`
2. `CVPixelBufferLockBaseAddress` → 获取 BGRA 原始像素
3. `cv::Mat` 零拷贝构造（使用 CVPixelBuffer data pointer）
4. `Extractor::extract()` → 四角检测 + 透视变换
5. `CimbReader::read()` → 逐 tile 解码
6. `fountain_decoder_sink` → 收集帧 → fountain 重组
7. `zstd_decompressor` → 解压 → 最终文件

## UI 状态机

```
┌──────────┐   对准成功    ┌──────────┐   解码完成   ┌──────────┐
│  SCANNING │────────────→│ DECODING │────────────→│  COMPLETE │
│ 相机预览  │              │ 显示进度  │              │ 文件预览  │
│ 寻找条码  │              │ 收集帧   │              │ 保存/分享 │
└──────────┘              └──────────┘              └──────────┘
      ↑                                                 │
      └─────────────────────────────────────────────────┘
                      重新扫描
```

## 实施顺序

1. **构建系统搭建** — `git submodule add` libcimbar + CMake iOS 编译脚本
2. **C++ 适配** — 确认所有源文件 iOS arm64 编译通过，修复编译问题
3. **Obj-C++ 桥接** — 实现帧→解码管线的最小可工作版本
4. **SwiftUI 界面** — 相机预览 + 进度 + 文件保存
5. **性能优化** — 降采样、帧跳过、Metal UMat 加速
6. **测试与调优** — 多种场景解码成功率

## 依赖清单

### Vendored (从 libcimbar 仓库)

| 依赖 | 路径 | License | 类型 |
|------|------|---------|------|
| libcimbar core | `src/lib/*` | MPL 2.0 | 源码 (C++) |
| wirehair | `src/third_party_lib/wirehair/` | ? | 源码 (C) |
| libcorrect | `src/third_party_lib/libcorrect/` | BSD | 源码 (C) |
| zstd | `src/third_party_lib/zstd/` | BSD | 源码 (C) |
| concurrentqueue | `src/third_party_lib/` | BSD | header-only |
| intx | `src/third_party_lib/intx/` | MIT | header-only |
| libpopcnt | `src/third_party_lib/libpopcnt/` | MIT | header-only |
| fmt | `src/third_party_lib/` | MIT | header-only |
| stb_image | `src/third_party_lib/` | MIT/PD | header-only |

### 外部

| 依赖 | 获取方式 | License |
|------|---------|---------|
| opencv2.framework | OpenCV 官方 iOS 包 | Apache 2.0 |

## 验证方式

1. `cimbar_send` CLI 在电脑屏幕播放条码
2. iOS App 真机对准屏幕解码
3. SHA256 校验解码文件与原始文件一致
