cmake_minimum_required(VERSION 3.19)           # 3.19 for reliable Swift+Xcode
project(libcimbar-ios LANGUAGES C CXX OBJCXX Swift)

# ── iOS toolchain ──────────────────────────────────────────────
set(CMAKE_CXX_STANDARD            17)
set(CMAKE_CXX_STANDARD_REQUIRED   ON)
set(CMAKE_SYSTEM_NAME             iOS)
set(CMAKE_OSX_ARCHITECTURES       arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET   15.0)

add_definitions("-DGF256_TARGET_MOBILE")
add_definitions("-DLIBCIMBAR_PROJECT_ROOT=\"${CMAKE_SOURCE_DIR}/libcimbar\"")

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Release")
endif()

set(CMAKE_C_FLAGS   "${CMAKE_C_FLAGS}   -Wall -std=c99 -Os -fPIC")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -O2 -fPIC")

# ── OpenCV for iOS ─────────────────────────────────────────────
if(DEFINED OPENCV_DIR)
    set(OPENCV_INCLUDE_DIR "${OPENCV_DIR}/Headers")
    set(OPENCV_FRAMEWORK   "${OPENCV_DIR}")
else()
    set(OPENCV_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/opencv2.framework/Headers")
    set(OPENCV_FRAMEWORK   "${CMAKE_SOURCE_DIR}/opencv2.framework/opencv2")
endif()

include_directories(
    ${OPENCV_INCLUDE_DIR}
    ${CMAKE_SOURCE_DIR}/libcimbar/src/lib
    ${CMAKE_SOURCE_DIR}/libcimbar/src/third_party_lib
)

# Prevent wirehair from adding -march=native (iOS is always cross-compiled)
set(ANDROID TRUE CACHE BOOL "" FORCE)

# ── Decoder-only sub-projects from libcimbar ───────────────────
set(DECODER_PROJECTS
    src/lib/bit_file              src/lib/chromatic_adaptation
    src/lib/cimb_translator       src/lib/compression
    src/lib/extractor             src/lib/fountain
    src/lib/image_hash            src/lib/serialize
    src/lib/util

    src/third_party_lib/base91    src/third_party_lib/intx
    src/third_party_lib/libcorrect
    src/third_party_lib/libpopcnt
    src/third_party_lib/wirehair
    src/third_party_lib/zstd
)

foreach(proj ${DECODER_PROJECTS})
    add_subdirectory(${CMAKE_SOURCE_DIR}/libcimbar/${proj} build/${proj})
endforeach()

# ── Combined C++ static library ────────────────────────────────
add_library(cimbar-core STATIC
    $<TARGET_OBJECTS:cimb_translator>
    $<TARGET_OBJECTS:extractor>
    $<TARGET_OBJECTS:wirehair>
    $<TARGET_OBJECTS:correct_static>
    $<TARGET_OBJECTS:zstd>
)
set_target_properties(cimbar-core PROPERTIES OUTPUT_NAME cimbar_core)
target_include_directories(cimbar-core PUBLIC
    ${OPENCV_INCLUDE_DIR}
    ${CMAKE_SOURCE_DIR}/libcimbar/src/lib
    ${CMAKE_SOURCE_DIR}/libcimbar/src/third_party_lib
)
target_link_libraries(cimbar-core PUBLIC
    "-framework opencv2"
    "-framework Accelerate"
)

# ── iOS App bundle ─────────────────────────────────────────────
set(APP_SOURCES
    ios/CimbarApp.swift
    ios/ContentView.swift
    ios/CimbarSession.swift
    ios/CameraPreview.swift
    ios/FileListView.swift

    ios/Bridge/CimbarDecoderBridge.h
    ios/Bridge/CimbarDecoderBridge.mm
)

add_executable(CimbarApp
    ${APP_SOURCES}
)

set_target_properties(CimbarApp PROPERTIES
    MACOSX_BUNDLE              TRUE
    MACOSX_BUNDLE_INFO_PLIST   "${CMAKE_SOURCE_DIR}/ios/CimbarApp-Info.plist"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.zzx.lensdrop"
    MACOSX_BUNDLE_BUNDLE_NAME   "LensDrop"
    MACOSX_BUNDLE_BUNDLE_VERSION "1.0"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.zzx.lensdrop"
    XCODE_ATTRIBUTE_SWIFT_VERSION "5.0"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    XCODE_ATTRIBUTE_ENABLE_HARDENED_RUNTIME YES
    XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
    XCODE_ATTRIBUTE_ENABLE_USER_SCRIPT_SANDBOXING NO
    XCODE_ATTRIBUTE_INFOPLIST_FILE "${CMAKE_SOURCE_DIR}/ios/CimbarApp-Info.plist"
)

target_link_libraries(CimbarApp PRIVATE
    cimbar-core
    "-framework opencv2"
    "-framework Accelerate"
    "-framework AVFoundation"
    "-framework VideoToolbox"
)

target_include_directories(CimbarApp PRIVATE
    ${OPENCV_INCLUDE_DIR}
    ${CMAKE_SOURCE_DIR}/libcimbar/src/lib
    ${CMAKE_SOURCE_DIR}/libcimbar/src/third_party_lib
)

# Expose our bridge header so Swift can see Obj-C symbols
set_target_properties(CimbarApp PROPERTIES
    XCODE_ATTRIBUTE_SWIFT_OBJC_INTEROP_MODE "objcxx"
)
