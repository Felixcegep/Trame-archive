#!/bin/bash
set -e

# Path to workspace
WORKSPACE_DIR="/Users/felixlachapelle/Desktop/GymTracker"
SCREENSHOT_DIR="$WORKSPACE_DIR/Screenshots"

echo "=== Cleaning previous screenshots ==="
rm -rf "$SCREENSHOT_DIR"
mkdir -p "$SCREENSHOT_DIR"

echo "=== Booting simulator ==="
xcrun simctl boot 11536E2C-BBE1-411D-AF6C-DF4ADCD332D1 || true

echo "=== Running screenshot capture test suite ==="
xcodebuild \
  -project "$WORKSPACE_DIR/GymTracker.xcodeproj" \
  -scheme GymTracker \
  -destination 'platform=iOS Simulator,id=11536E2C-BBE1-411D-AF6C-DF4ADCD332D1' \
  -disable-concurrent-testing \
  -only-testing:GymTrackerUITEST/GymTrackerUITEST/testCaptureScreenshots \
  test

echo "=== Success! Screenshots saved to: $SCREENSHOT_DIR ==="
ls -lh "$SCREENSHOT_DIR"

echo "=== Opening screenshots folder ==="
open "$SCREENSHOT_DIR"
