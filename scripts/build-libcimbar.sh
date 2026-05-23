#!/bin/bash
#
# Build libcimbar.a for iOS (arm64).
# Requires: cmake, Xcode with iOS SDK.
#
# Usage:
#   ./scripts/build-libcimbar.sh [debug|release]
#
# Output: build/ios/lib/libcimbar.a

set -euo pipefail

BUILD_TYPE="${1:-release}"

case "$BUILD_TYPE" in
    debug)   CMAKE_BUILD_TYPE="Debug" ;;
    release) CMAKE_BUILD_TYPE="Release" ;;
    *)       echo "Unknown build type: $BUILD_TYPE"; exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build/ios"

echo "=== Building libcimbar for iOS ($CMAKE_BUILD_TYPE) ==="

cmake -S "$PROJECT_DIR" \
      -B "$BUILD_DIR" \
      -G Xcode \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_OSX_ARCHITECTURES=arm64 \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
      -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
      -DCMAKE_XCODE_ATTRIBUTE_ENABLE_HARDENED_RUNTIME=YES

cmake --build "$BUILD_DIR" \
      --config "$CMAKE_BUILD_TYPE" \
      --target cimbar-ios \
      -- -sdk iphoneos

# Copy output
LIB_OUT="$PROJECT_DIR/build/ios/lib/$CMAKE_BUILD_TYPE"
mkdir -p "$LIB_OUT"

# Find the built .a
LIB_PATH=$(find "$BUILD_DIR" -name "*.a" -path "*/$CMAKE_BUILD_TYPE*" | head -1)
if [ -z "$LIB_PATH" ]; then
    echo "ERROR: Could not find built libcimbar.a"
    exit 1
fi

cp "$LIB_PATH" "$LIB_OUT/libcimbar.a"
echo "=== Done: $LIB_OUT/libcimbar.a ==="
