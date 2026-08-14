#!/bin/bash
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# One explicit simulator is shared serially across the unit and UI release
# gates. Each child runner owns the simulator lock for its own invocation and
# releases it before the next lane begins.
export SIMULATOR_ID="${SIMULATOR_ID:-11536E2C-BBE1-411D-AF6C-DF4ADCD332D1}"

echo "=== Release verification: complete unit target ==="
"$WORKSPACE_DIR/Scripts/run_unit_tests.sh" all

echo "=== Release verification: behavioral, screenshot, and reboot UI lanes ==="
"$WORKSPACE_DIR/Scripts/run_ui_tests.sh" all

echo "=== Release verification passed on simulator $SIMULATOR_ID ==="
