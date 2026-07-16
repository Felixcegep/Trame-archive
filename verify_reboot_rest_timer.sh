#!/bin/bash
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$WORKSPACE_DIR/ui_test_simulator_lock.sh"
SIMULATOR_ID="${SIMULATOR_ID:-11536E2C-BBE1-411D-AF6C-DF4ADCD332D1}"

acquire_ui_test_simulator_lock "$SIMULATOR_ID" "verify_reboot_rest_timer.sh"
trap release_ui_test_simulator_locks EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

XCODE_ARGUMENTS=(
  -project "$WORKSPACE_DIR/GymTracker.xcodeproj"
  -scheme GymTracker
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID"
  -parallel-testing-enabled NO
  -maximum-concurrent-test-simulator-destinations 1
)

echo "Preparing a running rest timer on simulator $SIMULATOR_ID"
xcodebuild "${XCODE_ARGUMENTS[@]}" test \
  -only-testing:GymTrackerUITEST/GymTrackerUITEST/testPrepareRunningRestForSimulatorReboot

echo "Restarting the same simulator without erasing app data"
# Xcode may already shut down the simulator after the preparation test. Both
# states are valid: the key requirement is that we boot the same, un-erased
# simulator before the verification phase.
xcrun simctl shutdown "$SIMULATOR_ID" 2>/dev/null || true
xcrun simctl boot "$SIMULATOR_ID"
xcrun simctl bootstatus "$SIMULATOR_ID" -b

echo "Verifying persisted rest timer after simulator reboot"
xcodebuild "${XCODE_ARGUMENTS[@]}" test \
  -only-testing:GymTrackerUITEST/GymTrackerUITEST/testVerifiesRunningRestAfterSimulatorReboot

echo "Simulator reboot rest-timer verification passed."
