#!/bin/bash
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIMULATOR_ID="${SIMULATOR_ID:-11536E2C-BBE1-411D-AF6C-DF4ADCD332D1}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/private/tmp/GymTrackerStrictConcurrency/$SIMULATOR_ID}"
LOG_PATH="${LOG_PATH:-/private/tmp/GymTrackerStrictConcurrency-$SIMULATOR_ID.log}"

mkdir -p "$DERIVED_DATA_PATH"

set -o pipefail
xcodebuild \
  -project "$WORKSPACE_DIR/GymTracker.xcodeproj" \
  -scheme GymTracker \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  SWIFT_STRICT_CONCURRENCY=complete \
  build 2>&1 | tee "$LOG_PATH"

if rg -n -i 'warning:.*(actor[- ]isolated|sendable|non[- ]sendable|data race|sending .* risks)' "$LOG_PATH"; then
  echo "Strict-concurrency diagnostics remain; see $LOG_PATH" >&2
  exit 1
fi

echo "Strict-concurrency build passed; log: $LOG_PATH"
