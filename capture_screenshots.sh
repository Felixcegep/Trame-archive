#!/bin/bash
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$WORKSPACE_DIR/ui_test_simulator_lock.sh"
SCREENSHOT_DIR="$WORKSPACE_DIR/Screenshots"
# Override per process to allow independent scene groups to run on separate simulators.
# The default remains the established screenshot simulator for local, single-device capture.
SIMULATOR_ID="${SIMULATOR_ID:-11536E2C-BBE1-411D-AF6C-DF4ADCD332D1}"
SIMULATOR_ID_2="${SIMULATOR_ID_2:-700D60D5-78C9-4E1E-9C66-A8B2280B1C4B}"
APP_BUNDLE_ID="felix.GymTracker"

# Detect whether we should run tests on two simulators concurrently
USE_PARALLEL=false
if [[ -n "${SIMULATOR_ID_2:-}" && "$SIMULATOR_ID" != "$SIMULATOR_ID_2" ]]; then
  USE_PARALLEL=true
fi

# Separate capture agents use different simulators. Keep Xcode's intermediate
# build products and result bundle separate too, otherwise concurrent test
# runners corrupt the shared DerivedData test logs.
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/private/tmp/GymTrackerScreenshotDerivedData/$SIMULATOR_ID}"
RESULT_BUNDLE_DIRECTORY="${RESULT_BUNDLE_DIRECTORY:-/private/tmp/GymTrackerScreenshotResults/$SIMULATOR_ID}"

if [[ "$USE_PARALLEL" == true ]]; then
  DERIVED_DATA_PATH_2="${DERIVED_DATA_PATH_2:-/private/tmp/GymTrackerScreenshotDerivedData/$SIMULATOR_ID_2}"
  RESULT_BUNDLE_DIRECTORY_2="${RESULT_BUNDLE_DIRECTORY_2:-/private/tmp/GymTrackerScreenshotResults/$SIMULATOR_ID_2}"
fi


usage() {
  cat <<'EOF'
Usage: ./capture_screenshots.sh [--open] [list|all|SCENE ...]

Capture all screenshots (the default) or only selected scene groups.

Scenes:
  overview               Main Home, Library, empty History, and Settings screens
  pages                  Home, Library, and Settings secondary page states
  active                 Active Workout, tools, completed, discard, and review states
  rest                   Running, paused, and ready Rest Between Sets cards
  history                Saved-workout History list and detail
  recommendation         Progression decisions, actions, and recommendation with rest
  performance            Planned-versus-performed save and history feedback
  template-progression   Template progression controls
  plan-review            Per-day assignments and plan change review
  plan-calendar          Active program agenda and a scheduled-day detail
  hidden                 Hidden and archived exercise management
  exercise-insights      Per-exercise history and progression insights
  muscle-balance        Estimated weekly muscle-group balance

Options:
  list                   Print every scene and its screenshot paths
  --open                 Open the Screenshots folder after a successful run
  -h, --help             Show this help

Examples:
  ./capture_screenshots.sh
  ./capture_screenshots.sh recommendation
  ./capture_screenshots.sh overview template-progression
EOF
}

tests_for_scene() {
  case "$1" in
    overview) echo "testCaptureOverviewScreenshots" ;;
    pages) echo "testCaptureHomeTemplateSheetScreenshot testCaptureHomeConflictScreenshot testCaptureLibrarySecondaryStatesScreenshots testCaptureSettingsImportErrorScreenshot testCaptureSettingsImportPreviewScreenshot" ;;
    active) echo "testCaptureActiveEmptyAndResumeScreenshots testCaptureActiveToolScreenshots testCaptureCompletedSetScreenshot testCaptureCompletedExerciseCollapsedScreenshot testCapturePartialSaveScreenshots testCaptureDiscardWorkoutScreenshot testCaptureDurationTimerScreenshots" ;;
    rest) echo "testCaptureRunningRestScreenshot testCapturePausedRestScreenshot testCaptureReadyRestScreenshot" ;;
    history) echo "testCaptureHistoryScreenshots" ;;
    recommendation) echo "testCaptureIncreaseRecommendationScreenshots testCaptureHoldRecommendationScreenshot testCaptureInsufficientHistoryRecommendationScreenshots testCaptureRecommendationWithRunningRestScreenshot testCaptureRecommendationWithPausedRestScreenshot" ;;
    performance) echo "testCapturePerformanceComparisonReviewScreenshot testCapturePerformanceComparisonHistoryScreenshot" ;;
    template-progression) echo "testCaptureTemplateProgressionScreenshot" ;;
    plan-review) echo "testCapturePlanReviewScreenshot testCaptureActivePlanRunScreenshot" ;;
    plan-calendar) echo "testCapturePlanCalendarScreenshots" ;;
    hidden) echo "testCaptureHiddenExercisesScreenshot" ;;
    exercise-insights) echo "testCaptureExerciseDetailInsightsScreenshot" ;;
    muscle-balance) echo "testCaptureMuscleBalanceScreenshot" ;;
    *) return 1 ;;
  esac
}

files_for_scene() {
  case "$1" in
    overview) echo "overview/01_Home.png overview/02_Library.png overview/03_History_Empty.png overview/04_Settings.png" ;;
    pages) echo "overview/01b_Home_Template_Sheet.png overview/01c_Home_Workout_Conflict.png overview/02b_Library_Templates.png overview/02c_Library_Plans.png overview/02d_Library_Empty_Search.png overview/04b_Settings_Import_Error.png overview/04c_Settings_Import_Preview.png" ;;
    active) echo "active-workout/05_Active_Workout_Empty.png overview/05_Home_With_Active_Workout.png active-workout/06_Add_Exercise_Sheet.png active-workout/07_Plate_Calculator.png active-workout/07b_Set_Details.png active-workout/08_Active_Workout_With_Set.png active-workout/08d_Completed_Exercise_Collapsed.png active-workout/08e_Discard_Workout.png active-workout/08f_Duration_Timer_Idle.png active-workout/08g_Duration_Timer_Running.png active-workout/08h_Duration_Timer_Paused.png active-workout/08i_Duration_Timer_Complete.png review/09_Save_Workout.png review/09b_Partial_Save_Confirmation.png" ;;
    rest) echo "active-workout/08_Rest_Countdown.png active-workout/08b_Rest_Paused.png active-workout/08c_Rest_Ready.png" ;;
    history) echo "history/10_History_With_Workout.png history/11_History_Detail.png" ;;
    recommendation) echo "progression/10_Previous_Performance.png progression/10b_Progression_Hold.png progression/10c_Progression_Starting_Weight.png progression/10d_Progression_Manual_Edit.png progression/10e_Progression_Applied_Weight.png progression/10f_Progression_With_Rest_Running.png progression/10g_Progression_With_Rest_Paused.png" ;;
    performance) echo "review/14_Save_Performance_Comparison.png history/15_History_Performance_Comparison.png" ;;
    template-progression) echo "templates/12_Template_Progression.png" ;;
    plan-review) echo "plans/13_Plan_Day_Assignments.png plans/13c_Program_Equipment.png plans/13d_Plan_Deload_Schedule.png plans/13_Plan_Review.png plans/13b_Plan_Active_Run.png overview/01d_Home_Active_Plan.png" ;;
    plan-calendar) echo "plans/13e_Plan_Calendar.png plans/13f_Plan_Calendar_Day.png" ;;
    hidden) echo "exercises/16_Hidden_Exercises.png" ;;
    exercise-insights) echo "exercises/17_Exercise_Insights.png" ;;
    muscle-balance) echo "history/16_Muscle_Balance.png" ;;
    *) return 1 ;;
  esac
}

ALL_SCENES="overview pages active rest history recommendation performance template-progression plan-review plan-calendar hidden exercise-insights muscle-balance"
SELECTED_SCENES=""
OPEN_AFTER_CAPTURE=false

validate_catalog() {
  local catalog="$WORKSPACE_DIR/ScreenshotCoverage.md"
  local runner_files=""

  for scene in $ALL_SCENES; do
    runner_files="${runner_files:+$runner_files }$(files_for_scene "$scene")"
  done

  for filename in $runner_files; do
    local basename="${filename##*/}"
    if ! grep -Fq "\`$basename\`" "$catalog"; then
      echo "Screenshot runner path is missing from ScreenshotCoverage.md: $filename"
      exit 1
    fi
  done

  while IFS= read -r basename; do
    local found=false
    for filename in $runner_files; do
      if [[ "${filename##*/}" == "$basename" ]]; then
        found=true
        break
      fi
    done
    if [[ "$found" == false ]]; then
      echo "ScreenshotCoverage.md entry is missing from the runner: $basename"
      exit 1
    fi
  done < <(sed -n 's/.*`\([^`]*\.png\)`.*/\1/p' "$catalog")
}

for argument in "$@"; do
  case "$argument" in
    -h|--help)
      usage
      exit 0
      ;;
    --open)
      OPEN_AFTER_CAPTURE=true
      ;;
    list)
      if [[ "$#" -ne 1 ]]; then
        echo "'list' cannot be combined with other arguments."
        exit 2
      fi
      validate_catalog
      for scene in $ALL_SCENES; do
        echo "$scene"
        for filename in $(files_for_scene "$scene"); do
          echo "  Screenshots/$filename"
        done
      done
      exit 0
      ;;
    all)
      if [[ -n "$SELECTED_SCENES" ]]; then
        echo "'all' cannot be combined with named scenes."
        usage
        exit 2
      fi
      SELECTED_SCENES="$ALL_SCENES"
      ;;
    *)
      if ! tests_for_scene "$argument" >/dev/null; then
        echo "Unknown screenshot scene: $argument"
        usage
        exit 2
      fi
      if [[ " $SELECTED_SCENES " == *" $argument "* ]]; then
        echo "Duplicate screenshot scene: $argument"
        exit 2
      fi
      SELECTED_SCENES="${SELECTED_SCENES:+$SELECTED_SCENES }$argument"
      ;;
  esac
done

if [[ -z "$SELECTED_SCENES" ]]; then
  SELECTED_SCENES="$ALL_SCENES"
fi

validate_catalog

acquire_ui_test_simulator_lock "$SIMULATOR_ID" "capture_screenshots.sh"
if [[ "$USE_PARALLEL" == true ]]; then
  acquire_ui_test_simulator_lock "$SIMULATOR_ID_2" "capture_screenshots.sh"
fi
trap release_ui_test_simulator_locks EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "=== Booting screenshot simulator 1: $SIMULATOR_ID ==="
xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR_ID" -b

echo "=== Removing stale GymTracker app data on simulator 1 ==="
xcrun simctl terminate "$SIMULATOR_ID" "$APP_BUNDLE_ID" 2>/dev/null || true
xcrun simctl uninstall "$SIMULATOR_ID" "$APP_BUNDLE_ID" 2>/dev/null || true

if [[ "$USE_PARALLEL" == true ]]; then
  echo "=== Booting screenshot simulator 2: $SIMULATOR_ID_2 ==="
  xcrun simctl boot "$SIMULATOR_ID_2" 2>/dev/null || true
  xcrun simctl bootstatus "$SIMULATOR_ID_2" -b

  echo "=== Removing stale GymTracker app data on simulator 2 ==="
  xcrun simctl terminate "$SIMULATOR_ID_2" "$APP_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl uninstall "$SIMULATOR_ID_2" "$APP_BUNDLE_ID" 2>/dev/null || true
fi

echo "=== Cleaning requested screenshots ==="
mkdir -p "$SCREENSHOT_DIR"
EXPECTED_FILES=""
for scene in $SELECTED_SCENES; do
  for filename in $(files_for_scene "$scene"); do
    rm -f "$SCREENSHOT_DIR/$filename"
    EXPECTED_FILES="${EXPECTED_FILES:+$EXPECTED_FILES }$filename"
  done
done

echo "=== Capturing scenes: $SELECTED_SCENES ==="
CAPTURE_STARTED_AT=$(date +%s)
CAPTURE_RUN_ID="$CAPTURE_STARTED_AT"
mkdir -p "$DERIVED_DATA_PATH" "$RESULT_BUNDLE_DIRECTORY"
if [[ "$USE_PARALLEL" == true ]]; then
  mkdir -p "$DERIVED_DATA_PATH_2" "$RESULT_BUNDLE_DIRECTORY_2"
fi

echo "=== Building for Simulator 1 ($SIMULATOR_ID) ==="
xcodebuild -quiet -project "$WORKSPACE_DIR/GymTracker.xcodeproj" -scheme GymTracker -destination "platform=iOS Simulator,id=$SIMULATOR_ID" -derivedDataPath "$DERIVED_DATA_PATH" build-for-testing

if [[ "$USE_PARALLEL" == true ]]; then
  echo "=== Building for Simulator 2 ($SIMULATOR_ID_2) ==="
  xcodebuild -quiet -project "$WORKSPACE_DIR/GymTracker.xcodeproj" -scheme GymTracker -destination "platform=iOS Simulator,id=$SIMULATOR_ID_2" -derivedDataPath "$DERIVED_DATA_PATH_2" build-for-testing
fi

SELECTED_TESTS=()
for scene in $SELECTED_SCENES; do
  for test_name in $(tests_for_scene "$scene"); do
    SELECTED_TESTS+=("$test_name")
  done
done

TESTS_1=()
TESTS_2=()
if [[ "$USE_PARALLEL" == true ]]; then
  for i in "${!SELECTED_TESTS[@]}"; do
    if (( i % 2 == 0 )); then
      TESTS_1+=("${SELECTED_TESTS[i]}")
    else
      TESTS_2+=("${SELECTED_TESTS[i]}")
    fi
  done
else
  TESTS_1=("${SELECTED_TESTS[@]}")
fi

run_test_list() {
  local sim_id="$1"
  local dd_path="$2"
  local rb_dir="$3"
  shift 3
  local tests=("$@")

  local xcode_args=(
    -quiet
    -project "$WORKSPACE_DIR/GymTracker.xcodeproj"
    -scheme GymTracker
    -destination "platform=iOS Simulator,id=$sim_id"
    -derivedDataPath "$dd_path"
    -parallel-testing-enabled NO
    -maximum-concurrent-test-simulator-destinations 1
  )

  for test_name in "${tests[@]}"; do
    echo "=== [$sim_id] Running test $test_name ==="
    # Each method receives a fresh UI-test runner. This prevents a failed app
    # relaunch from cancelling unrelated screenshot states in the same scene.
    xcodebuild "${xcode_args[@]}" \
      -resultBundlePath "$rb_dir/$CAPTURE_RUN_ID-$test_name.xcresult" \
      "-only-testing:GymTrackerUITEST/GymTrackerUITEST/$test_name" \
      test-without-building
  done
}

export SCREENSHOT_OUTPUT_DIR="$SCREENSHOT_DIR"

PID1=""
PID2=""

if [[ ${#TESTS_1[@]} -gt 0 ]]; then
  echo "=== Running ${#TESTS_1[@]} tests on simulator 1 ($SIMULATOR_ID) ==="
  run_test_list "$SIMULATOR_ID" "$DERIVED_DATA_PATH" "$RESULT_BUNDLE_DIRECTORY" "${TESTS_1[@]}" &
  PID1=$!
fi

if [[ "$USE_PARALLEL" == true && ${#TESTS_2[@]} -gt 0 ]]; then
  echo "=== Running ${#TESTS_2[@]} tests on simulator 2 ($SIMULATOR_ID_2) ==="
  run_test_list "$SIMULATOR_ID_2" "$DERIVED_DATA_PATH_2" "$RESULT_BUNDLE_DIRECTORY_2" "${TESTS_2[@]}" &
  PID2=$!
fi

EXIT_STATUS=0
if [[ -n "$PID1" ]]; then
  wait "$PID1" || EXIT_STATUS=$?
fi

if [[ -n "$PID2" ]]; then
  wait "$PID2" || {
    if [[ $EXIT_STATUS -eq 0 ]]; then
      EXIT_STATUS=$?
    fi
  }
fi

if [[ $EXIT_STATUS -ne 0 ]]; then
  echo "Error: One or more test runs failed."
  exit $EXIT_STATUS
fi



for filename in $EXPECTED_FILES; do
  if [[ ! -s "$SCREENSHOT_DIR/$filename" ]]; then
    echo "Missing or empty screenshot: $SCREENSHOT_DIR/$filename"
    exit 1
  fi
done

echo "=== Success! Screenshots saved to: $SCREENSHOT_DIR ==="
for filename in $EXPECTED_FILES; do
  ls -lh "$SCREENSHOT_DIR/$filename"
done
echo "=== Capture duration: $(( $(date +%s) - CAPTURE_STARTED_AT ))s ==="

if [[ "$OPEN_AFTER_CAPTURE" == true ]]; then
  echo "=== Opening screenshots folder ==="
  open "$SCREENSHOT_DIR"
fi
