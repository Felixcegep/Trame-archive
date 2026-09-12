#!/bin/bash
set -euo pipefail

# Unit-test lanes deliberately stay separate from GymTrackerUITEST. The
# dedicated scheme contains only GymTrackerTests, so unit builds never build
# the UI-test target as an incidental test-plan member.
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WORKSPACE_DIR/Scripts/ui_test_simulator_lock.sh"
SIMULATOR_ID="${SIMULATOR_ID:-11536E2C-BBE1-411D-AF6C-DF4ADCD332D1}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/private/tmp/GymTrackerUnitTestDerivedData/$SIMULATOR_ID}"
RESULTS_ROOT="${RESULTS_ROOT:-/private/tmp/GymTrackerUnitTestResults/$SIMULATOR_ID}"
RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"

usage() {
  cat <<'EOF'
Usage: ./Scripts/run_unit_tests.sh [all|persistence|diagnostic|asan|tsan|affected] [selector ...]

  all          Run the complete GymTrackerTests target (default).
  persistence  Run the persistence, backup, migration, rollback, and
               historical-integrity contract classes.
  diagnostic   Run the opt-in 100,000-set history performance probes. This
               lane requires GYMTRACKER_RUN_PERFORMANCE_TESTS=1.
  asan         Run the complete unit target with Address Sanitizer enabled.
  tsan         Run the complete unit target with Thread Sanitizer enabled.
  affected     Run only the supplied class or class/test-method selectors.

Examples:
  ./Scripts/run_unit_tests.sh persistence
  ./Scripts/run_unit_tests.sh asan
  ./Scripts/run_unit_tests.sh affected WorkoutProgressionTests
  ./Scripts/run_unit_tests.sh affected WorkoutProgressionTests/testUnitConversionPreservesEquivalentLoad

The script builds once, then uses test-without-building. It always uses one
explicit simulator and serial test execution. UI tests are excluded here;
use run_ui_tests.sh for behavioral, screenshot, and reboot lanes.
EOF
}

LANE="${1:-all}"
if [[ "$LANE" == "-h" || "$LANE" == "--help" ]]; then
  usage
  exit 0
fi
if [[ "$LANE" != "all" && "$LANE" != "persistence" && "$LANE" != "diagnostic" && "$LANE" != "asan" && "$LANE" != "tsan" && "$LANE" != "affected" ]]; then
  echo "Unknown unit-test lane: $LANE" >&2
  usage >&2
  exit 2
fi

PERSISTENCE_CLASSES=(
  GymTrackerFrozenV2SchemaTests
  GymTrackerPersistenceConfigurationTests
  StoreExceptionBoundaryTests
  StoreRecoveryTests
  DataSafetyServiceTests
  BackupExportSelectionTests
  BackupFieldCoverageTests
  StrengthBackupValidatorTests
  HistoricalIntegrityMatrixDigestTests
  WorkoutDataIntegrityTests
  WorkoutIntegrityTests
  WorkoutBackupFailureTests
  WorkoutBackupRoundTripTests
  WorkoutExecutionBlockSplitServiceTests
  RepeatingPlanBackupTests
  RepeatingPlanWorkoutLifecycleTests
  RepeatingPlanMobilityLifecycleTests
  RepeatingPlanMobilityLinkageTests
  MobilityAssessmentBackupTests
  MobilityRoutinePurposeBackupTests
  NutritionTests
  TodayFoundationTests
  PortableTrainingPackageImportTests
  ProgramBackupDTORoundTripTests
  ProgramSnapshotIntegrationTests
  ProgramRunTransitionIntegrationTests
  ProgramEngineIntegrationTests
  ProgramCatalogIntegrationTests
  ActiveWorkoutInputPersistenceTests
)

validate_class_exists() {
  local class_name="$1"
  if ! rg -q "(^|[[:space:]])class[[:space:]]+$class_name([[:space:]:{]|$)" "$WORKSPACE_DIR/GymTrackerTests" -g '*.swift'; then
    echo "Unit-test lane references missing class: $class_name" >&2
    exit 1
  fi
}

validate_selector_exists() {
  local selector="$1"
  local class_name="${selector%%/*}"
  validate_class_exists "$class_name"
  if [[ "$selector" != */* ]]; then
    return
  fi
  local method_name="${selector#*/}"
  local found=0
  while IFS= read -r source_file; do
    if rg -q "func[[:space:]]+$method_name[[:space:]]*\\(" "$source_file"; then
      found=1
      break
    fi
  done < <(rg -l "(^|[[:space:]])class[[:space:]]+$class_name([[:space:]:{]|$)" "$WORKSPACE_DIR/GymTrackerTests" -g '*.swift')
  if [[ "$found" -ne 1 ]]; then
    echo "Unit-test lane references missing method: $class_name/$method_name" >&2
    exit 1
  fi
}

# Keep the expensive benchmark class out of routine correctness/sanitizer
# lanes entirely. The diagnostic lane below selects it explicitly.
PERFORMANCE_TEST_SELECTOR="GymTrackerTests/LargeHistoryPerformanceTests"
TEST_FILTERS=(
  -only-testing:GymTrackerTests
  "-skip-testing:$PERFORMANCE_TEST_SELECTOR"
)
SANITIZER_ARGUMENTS=()
case "$LANE" in
  persistence)
    TEST_FILTERS=()
    for class_name in "${PERSISTENCE_CLASSES[@]}"; do
      validate_class_exists "$class_name"
      TEST_FILTERS+=("-only-testing:GymTrackerTests/$class_name")
    done
    ;;
  diagnostic)
    if [[ "${GYMTRACKER_RUN_PERFORMANCE_TESTS:-0}" != "1" ]]; then
      echo "The diagnostic lane is opt-in; set GYMTRACKER_RUN_PERFORMANCE_TESTS=1." >&2
      exit 2
    fi
    TEST_FILTERS=(
      -only-testing:GymTrackerTests/LargeHistoryPerformanceTests
    )
    validate_class_exists LargeHistoryPerformanceTests
    ;;
  asan)
    SANITIZER_ARGUMENTS=(-enableAddressSanitizer YES)
    ;;
  tsan)
    SANITIZER_ARGUMENTS=(-enableThreadSanitizer YES)
    ;;
  affected)
    if [[ "$#" -lt 2 ]]; then
      echo "The affected lane requires at least one test class or method selector." >&2
      usage >&2
      exit 2
    fi
    TEST_FILTERS=()
    shift
    for selector in "$@"; do
      selector="${selector#GymTrackerTests/}"
      validate_selector_exists "$selector"
      TEST_FILTERS+=("-only-testing:GymTrackerTests/$selector")
    done
    ;;
esac

RUN_DIRECTORY="$RESULTS_ROOT/$LANE-$RUN_ID"
RESULT_BUNDLE="$RUN_DIRECTORY/results.xcresult"
EXECUTION_LOG="$RUN_DIRECTORY/xcodebuild.log"
SUMMARY_PATH="$RUN_DIRECTORY/summary.json"
TESTS_PATH="$RUN_DIRECTORY/tests.json"
SLOWEST_TESTS_PATH="$RUN_DIRECTORY/slowest-tests.txt"
mkdir -p "$DERIVED_DATA_PATH" "$RUN_DIRECTORY"

acquire_ui_test_simulator_lock "$SIMULATOR_ID" "run_unit_tests.sh $LANE"
trap release_ui_test_simulator_locks EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

XCODE_ARGUMENTS=(
  -project "$WORKSPACE_DIR/GymTracker.xcodeproj"
  -scheme GymTrackerUnitTests
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -parallel-testing-enabled NO
  -maximum-concurrent-test-simulator-destinations 1
)

echo "=== Building unit-test lane '$LANE' on simulator $SIMULATOR_ID ==="
STARTED_AT="$(date +%s)"
# Selectors constrain execution; keep the build action independent so that the
# dedicated unit scheme can produce one reusable test bundle for the lane.
if [[ -n "${SANITIZER_ARGUMENTS[0]+set}" ]]; then
  xcodebuild -quiet "${XCODE_ARGUMENTS[@]}" "${SANITIZER_ARGUMENTS[@]}" build-for-testing
else
  xcodebuild -quiet "${XCODE_ARGUMENTS[@]}" build-for-testing
fi

echo "=== Running unit-test lane '$LANE' with ${#TEST_FILTERS[@]} execution filter(s) ==="
echo "=== Full Xcode output: $EXECUTION_LOG ==="
TEST_EXECUTION_ARGUMENTS=("${XCODE_ARGUMENTS[@]}")
if [[ -n "${SANITIZER_ARGUMENTS[0]+set}" ]]; then
  TEST_EXECUTION_ARGUMENTS+=("${SANITIZER_ARGUMENTS[@]}")
fi
TEST_EXECUTION_ARGUMENTS+=(
  -resultBundlePath "$RESULT_BUNDLE"
  "${TEST_FILTERS[@]}"
  test-without-building
)
if xcodebuild "${TEST_EXECUTION_ARGUMENTS[@]}" 2>&1 | tee "$EXECUTION_LOG"; then
  TEST_EXIT_STATUS=0
else
  TEST_EXIT_STATUS=$?
fi

FINISHED_AT="$(date +%s)"
if [[ -f "$RESULT_BUNDLE/Info.plist" ]]; then
  if xcrun xcresulttool get test-results summary --path "$RESULT_BUNDLE" > "$SUMMARY_PATH"; then
    if xcrun xcresulttool get test-results tests --path "$RESULT_BUNDLE" --compact > "$TESTS_PATH"; then
      /usr/bin/jq -r '
        .testNodes[]
        | ..
        | objects
        | select(.nodeType == "Test Case")
        | [.durationInSeconds, .name]
        | @tsv
      ' "$TESTS_PATH" | sort -rn | awk 'NR <= 5' > "$SLOWEST_TESTS_PATH"
    else
      echo "Per-test duration data was unavailable; the result bundle remains available." >&2
    fi
  else
    echo "Unable to read unit-test result summary: $RESULT_BUNDLE" >&2
  fi
else
  echo "Unit-test execution exited without a complete result bundle: $RESULT_BUNDLE" >&2
fi

echo "=== Unit-test lane '$LANE' finished in $((FINISHED_AT - STARTED_AT))s ==="
echo "=== Result bundle: $RESULT_BUNDLE ==="
if [[ -s "$SUMMARY_PATH" ]]; then
  echo "=== Result summary: $SUMMARY_PATH ==="
fi
if [[ -s "$SLOWEST_TESTS_PATH" ]]; then
  echo "=== Five slowest tests: $SLOWEST_TESTS_PATH ==="
fi
if [[ "$TEST_EXIT_STATUS" -ne 0 ]]; then
  echo "Unit-test lane '$LANE' failed; diagnostics retained at $RUN_DIRECTORY" >&2
  exit "$TEST_EXIT_STATUS"
fi
echo "=== Unit-test lane '$LANE' passed ==="
