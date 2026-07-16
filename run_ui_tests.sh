#!/bin/bash
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$WORKSPACE_DIR/ui_test_simulator_lock.sh"
SIMULATOR_ID="${SIMULATOR_ID:-11536E2C-BBE1-411D-AF6C-DF4ADCD332D1}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/private/tmp/GymTrackerUITestDerivedData/$SIMULATOR_ID}"
RESULTS_ROOT="${RESULTS_ROOT:-/private/tmp/GymTrackerUITestResults/$SIMULATOR_ID}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"

# Behavioral tests deliberately exclude screenshot capture and the two-phase
# reboot verifier. Those lanes have their own deterministic runners below.
FAST_TESTS=(
  testStartFreeWorkout
  testResumesPersistedActiveWorkoutAfterRelaunch
  testResumesPersistedRestTimerAfterRelaunch
  testPersistsDraftSetValuesAfterTermination
  testResumesPausedRestTimerAfterRelaunch
  testStartSeededTemplateIncludesPrescription
  testPushFocusFiltersActiveExercisePicker
  testPlateCalculatorMatchesExerciseLoadingStyle
  testKeyboardOffersCopyLastSetValuesForFocusedSet
  testActiveWorkoutSetMutationsAndRestTimer
  testCompletedSetRequiresExplicitEditingAction
  testRejectsEmptyWorkoutSave
  testSavesCompletedWorkoutToHistory
  testShowsAndAppliesPreviousSessionPerformance
  testDiscardsActiveWorkout
  testCreatesCustomExercise
  testCreatesWorkoutTemplate
  testCreatesPlanStartsRunAndLaunchesPlannedWorkout
  testPlanCalendarShowsDerivedStatesAndKeepsCompletedSessionsLocked
  testRelaunchRefreshesHomeWithTheSessionScheduledForToday
  testPlannedWorkoutSavePersistsHistoryAndAdvancesRunAfterRelaunch
  testRecommendationEditFocusesTheFirstIncompleteSet
  testSettingsImportsValidBackupAndRestoresPreferencesAfterRelaunch
  testSettingsRejectsCorruptBackupWithoutReplacingData
  testDefaultCollectionSeededOnLaunch
)

usage() {
  cat <<'EOF'
Usage: ./run_ui_tests.sh [fast|screenshots|reboot|all]

  fast         Run the serial behavioral UI suite (default).
  screenshots  Run the screenshot scene runner.
  reboot       Run the dedicated prepare/reboot/verify flow.
  all          Run fast, screenshots, and reboot lanes sequentially.

Each xcodebuild invocation uses one explicit simulator and disables parallel
test destinations so the result is deterministic and safe to time.
EOF
}

LANE="${1:-fast}"
case "$LANE" in
  -h|--help)
    usage
    exit 0
    ;;
  fast|screenshots|reboot|all)
    ;;
  *)
    echo "Unknown lane: $LANE" >&2
    usage >&2
    exit 2
    ;;
esac

run_fast() {
  local started_at build_finished_at test_started_at test_finished_at
  started_at="$(date +%s)"
  local result_bundle="$RESULTS_ROOT/fast-$RUN_ID.xcresult"
  local summary_path="$result_bundle/summary.json"
  local tests_path="$result_bundle/tests.json"
  local slowest_tests_path="$result_bundle/slowest-tests.txt"

  acquire_ui_test_simulator_lock "$SIMULATOR_ID" "run_ui_tests.sh fast"
  trap release_ui_test_simulator_locks EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  mkdir -p "$DERIVED_DATA_PATH" "$RESULTS_ROOT"
  echo "=== Building UI tests on simulator $SIMULATOR_ID ==="
  if ! xcodebuild -quiet \
    -project "$WORKSPACE_DIR/GymTracker.xcodeproj" \
    -scheme GymTrackerUITEST \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    build-for-testing; then
    echo "UI-test build failed; no test timing was recorded." >&2
    return 1
  fi
  build_finished_at="$(date +%s)"

  local test_args=()
  for test_name in "${FAST_TESTS[@]}"; do
    test_args+=("-only-testing:GymTrackerUITEST/GymTrackerUITEST/$test_name")
  done

  echo "=== Running ${#FAST_TESTS[@]} behavioral UI tests ==="
  test_started_at="$(date +%s)"
  if ! xcodebuild -quiet \
    -project "$WORKSPACE_DIR/GymTracker.xcodeproj" \
    -scheme GymTrackerUITEST \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    -resultBundlePath "$result_bundle" \
    "${test_args[@]}" \
    test-without-building; then
    echo "UI-test execution failed; result bundle retained at $result_bundle" >&2
    return 1
  fi
  test_finished_at="$(date +%s)"

  if [[ ! -f "$result_bundle/Info.plist" ]]; then
    echo "UI-test execution exited without a complete result bundle: $result_bundle" >&2
    return 1
  fi
  if ! xcrun xcresulttool get test-results summary --path "$result_bundle" > "$summary_path"; then
    echo "Unable to read UI-test result summary: $result_bundle" >&2
    return 1
  fi
  if ! xcrun xcresulttool get test-results tests --path "$result_bundle" --compact > "$tests_path"; then
    echo "Unable to read UI-test result details: $result_bundle" >&2
    return 1
  fi

  local recorded_test_count
  recorded_test_count="$(/usr/bin/jq -r '.totalTestCount // 0' "$summary_path")"
  if [[ "$recorded_test_count" != "${#FAST_TESTS[@]}" ]]; then
    echo "Result bundle recorded $recorded_test_count tests; expected ${#FAST_TESTS[@]}." >&2
    return 1
  fi
  /usr/bin/jq -r '
    .testNodes[]
    | ..
    | objects
    | select(.nodeType == "Test Case")
    | [.durationInSeconds, .name]
    | @tsv
  ' "$tests_path" | sort -rn | head -n 5 > "$slowest_tests_path"

  echo "=== Fast UI suite duration: $(( test_finished_at - started_at ))s (build: $(( build_finished_at - started_at ))s, tests: $(( test_finished_at - test_started_at ))s) ==="
  echo "=== Result bundle: $result_bundle ==="
  echo "=== Result summary: $summary_path ==="
  echo "=== Per-test result data: $tests_path ==="
  echo "=== Five slowest tests: $slowest_tests_path ==="
  release_ui_test_simulator_locks
  trap - EXIT INT TERM
}

run_screenshots() {
  echo "=== Running screenshot UI lane ==="
  SIMULATOR_ID="$SIMULATOR_ID" ./capture_screenshots.sh all
}

run_reboot() {
  echo "=== Running simulator-reboot UI lane ==="
  SIMULATOR_ID="$SIMULATOR_ID" ./verify_reboot_rest_timer.sh
}

case "$LANE" in
  fast)
    run_fast
    ;;
  screenshots)
    run_screenshots
    ;;
  reboot)
    run_reboot
    ;;
  all)
    run_fast
    run_screenshots
    run_reboot
    ;;
esac
