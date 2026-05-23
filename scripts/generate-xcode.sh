#!/bin/bash
#
# Generate Xcode project for the LensDrop iOS app using xcodegen.
# Requires: xcodegen (brew install xcodegen)
#
# Usage:
#   ./scripts/generate-xcode.sh
#
# Then open: CimbarApp.xcodeproj

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if ! command -v xcodegen &>/dev/null; then
    echo "ERROR: xcodegen not found. Install with: brew install xcodegen"
    exit 1
fi

echo "=== Generating Xcode project ==="
cd "$PROJECT_DIR"
xcodegen generate --spec project.yml --project ./

echo ""
echo "=== Done ==="
echo "Open: open $PROJECT_DIR/CimbarApp.xcodeproj"
