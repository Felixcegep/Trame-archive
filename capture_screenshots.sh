#!/bin/bash
set -euo pipefail

WORKSPACE_DIR="/Users/felixlachapelle/Desktop/GymTracker"
SCREENSHOT_DIR="$WORKSPACE_DIR/Screenshots"
SIMULATOR_ID="11536E2C-BBE1-411D-AF6C-DF4ADCD332D1"
APP_BUNDLE_ID="felix.GymTracker"

echo "=== Booting screenshot simulator ==="
xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR_ID" -b

echo "=== Removing stale GymTracker app data ==="
xcrun simctl terminate "$SIMULATOR_ID" "$APP_BUNDLE_ID" 2>/dev/null || true
xcrun simctl uninstall "$SIMULATOR_ID" "$APP_BUNDLE_ID" 2>/dev/null || true

echo "=== Cleaning previous screenshots ==="
rm -rf "$SCREENSHOT_DIR"
mkdir -p "$SCREENSHOT_DIR"

echo "=== Running screenshot capture test suite ==="
xcodebuild \
  -project "$WORKSPACE_DIR/GymTracker.xcodeproj" \
  -scheme GymTracker \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:GymTrackerUITEST/GymTrackerUITEST/testCaptureScreenshots \
  test

shopt -s nullglob
screenshots=("$SCREENSHOT_DIR"/*.png)
if (( ${#screenshots[@]} == 0 )); then
  echo "Screenshot capture finished without producing PNG files."
  exit 1
fi

echo "=== Success! Screenshots saved to: $SCREENSHOT_DIR ==="
ls -lh "${screenshots[@]}"

echo "=== Opening screenshots folder ==="
open "$SCREENSHOT_DIR"
