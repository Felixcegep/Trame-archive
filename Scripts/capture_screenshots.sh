#!/bin/bash
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WORKSPACE_DIR/Scripts/ui_test_simulator_lock.sh"
SCREENSHOT_DIR="$WORKSPACE_DIR/Screenshots"
# Override per process to allow independent scene groups to run on separate simulators.
# The default remains the established screenshot simulator for local, single-device capture.
SIMULATOR_ID="${SIMULATOR_ID:-11536E2C-BBE1-411D-AF6C-DF4ADCD332D1}"
# A second simulator is opt-in. The repository's host-stability rule defaults
# screenshot work to one simulator and one UI-test stream.
SIMULATOR_ID_2="${SIMULATOR_ID_2:-}"
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
  brand                  Completed cold-launch brand frame
  onboarding             First-run path, core questions, equipment, and recommendations
  overview               Main Today, Train, empty Progress, and Settings screens
  settings-data-safety   Settings Data Safety section
  pages                  Today, Train, Nutrition, and Settings secondary page states
  coach-exchange        Coach Exchange package builder and import decisions
  journey                Training Journey list and timeline
  weightlifting          Weightlifting evidence dashboard
  athlete-intelligence   Athlete profile, Global Progress, and one sport lens
  progress-analysis      Progress hub, graphs, records, history, and specialist pages
  ledger                 Progression receipt ledger and detail
  mixed-workout          Eyes-up execution, round split, and complex evidence
  mobility               Mobility routine library and active execution
  mobility-assessment    Assessment hub cards, capture flow, and history detail
  mobility-profile       Read-only mobility profile with observations and side gap
  active                 Active Workout, tools, completed, discard, and review states
  active-panels          Warm-up groups, set badges, and complex-entry panel states
  active-gaps            Remaining set-detail and source-based set states
  active-appearance      Active Workout stage and rest takeover in Pale
  active-accessibility   Active Workout rest takeover and warm-up ledger at AX5
  keyboards              Every Active Workout tracking type and editable keypad field
  rest                   Running, paused, and ready Rest Between Sets cards
  history                Saved-workout History list and detail
  recommendation         Progression decisions, actions, and recommendation with rest
  performance            Planned-versus-performed save and history feedback
  template-progression   Template progression controls
  workout-form           New Workout creation form with exercise selection
  plan-review            Per-day assignments and plan change review
  program-builder        Custom universal program definition builder
  program-catalog        Built-in program browser, detail, and intake
  plan-calendar          Active program agenda and a scheduled-day detail
  training-calendar      Cross-domain training calendar and its action state
  hidden                 Hidden and archived exercise management
  exercise-insights      Per-exercise history and progression insights
  exercise-form          New Exercise form, muscle picker, and advanced details
  muscle-balance        Estimated weekly muscle-group balance
  rotation               Active rotation detail, controls, Home context, and workout source
  program-path           Plan Path entry, fixed path, reschedule sheet, and rotation path
  weekly-review          Fixed-plan Weekly Review
  t36                    T-36 missing reachability states

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
    brand) echo "testCaptureLaunchBrandScreenshot" ;;
    onboarding) echo "testCaptureOnboardingJourneyScreenshots" ;;
    overview) echo "testCaptureOverviewAndLibraryTourScreenshots testCaptureWave1LightModeScreenshots" ;;
    settings-data-safety) echo "testCaptureSettingsDataSafetyScreenshot testCaptureSettingsCloudFileLinkedScreenshot" ;;
  pages) echo "testCaptureOverviewAndLibraryTourScreenshots testCaptureHomeConflictScreenshot testCaptureTodayCompleteTourScreenshots testCaptureDailyCheckInWeightDueScreenshot testCaptureBodyWeightHistoryScreenshot testCapturePlanActiveRunScreenshots testCaptureNotificationRescheduleScreenshot testCaptureActiveMobilityScreenshot testCaptureNutritionTodayScreenshot testCaptureSettingsImportErrorScreenshot testCaptureSettingsImportPreviewScreenshot testCaptureSettingsShortcutsAndBetaFeedbackScreenshots testCaptureSettingsDataSafetyScreenshot testCaptureBetaFeedbackActiveLoggingScreenshot" ;;
    coach-exchange) echo "testCaptureCoachExchangeScreenshots testCaptureCoachExchangeImportScreenshots" ;;
    journey) echo "testCaptureTrainingJourneyScreenshots" ;;
    weightlifting) echo "testCaptureWeightliftingDashboardScreenshot" ;;
    athlete-intelligence) echo "testCaptureAthleteIntelligenceHubScreenshots" ;;
    progress-analysis) echo "testCaptureProgressTabAnalysisScreenshots testCaptureAthleteIntelligenceHubScreenshots" ;;
    ledger) echo "testCaptureProgressionLedgerScreenshots" ;;
    mixed-workout) echo "testCaptureMixedWorkoutScreenshots" ;;
    mobility) echo "testCaptureTodayCompleteTourScreenshots testCaptureMobilityRoutinePurposeScreenshot testCaptureActiveMobilityScreenshot" ;;
    mobility-assessment) echo "MobilityAssessmentUITests/testCaptureMobilityHubCards MobilityAssessmentUITests/testCaptureAssessmentFlow MobilityAssessmentUITests/testCaptureAssessmentLandingAndHistoryDetail" ;;
    mobility-profile) echo "MobilityAssessmentUITests/testCaptureMobilityAssessmentProfileScreenshot" ;;
    nutrition) echo "testCaptureNutritionTodayScreenshot testCaptureNutritionTargetsEmptyScreenshot testCaptureTodayCompleteTourScreenshots testCaptureRecipeGenerationControlsScreenshot testCaptureRecipeGeneratingScreenshot testCaptureRecipeGeneratedDraftScreenshot testCaptureRecipePartialMatchScreenshot testCaptureRecipeManualFallbackAndCatalogScreenshots testCapturePhotoEstimateReviewScreenshot" ;;
    active) echo "testCaptureExecutionBlockBuilderScreenshot testCaptureActiveWorkoutStatesScreenshots testCaptureDecisionAwareSubstitutionScreenshots testCaptureDurationTimerScreenshots" ;;
    active-panels) echo "testCaptureActiveWorkoutPanelAndGroupingStates testCaptureWorkoutPreparationLargeDetent" ;;
    active-gaps) echo "testCaptureRemainingActiveWorkoutCatalogStates" ;;
    active-appearance) echo "testCaptureActiveWorkoutPaleAppearanceScreenshots" ;;
    active-accessibility) echo "testCaptureActiveWorkoutAccessibilitySizeScreenshots" ;;
    keyboards) echo "testCaptureEveryActiveWorkoutKeypad" ;;
    rest) echo "testCaptureRestScreenshots testCaptureStageTransitionScreenshots testCaptureOlympicRestScreenshot" ;;
    history) echo "testCaptureHistoryScreenshots" ;;
    recommendation) echo "testCaptureIncreaseRecommendationScreenshots testCaptureHoldRecommendationScreenshot testCaptureInsufficientHistoryRecommendationScreenshots testCaptureRecommendationWithRestScreenshots testCaptureProgressionReceiptWhyScreenshot" ;;
    performance) echo "testCapturePerformanceComparisonReviewScreenshot testCapturePerformanceComparisonHistoryScreenshot" ;;
    template-progression) echo "testCaptureTemplateProgressionScreenshot testCaptureTemplateExecutionBlockScreenshot" ;;
    workout-form) echo "testCaptureLibraryFormsScreenshots" ;;
    plan-review) echo "testCapturePlanReviewScreenshot testCapturePlanActiveRunScreenshots" ;;
    program-builder) echo "testCaptureProgramDefinitionAndCatalogScreenshots" ;;
    program-catalog) echo "testCaptureProgramDefinitionAndCatalogScreenshots" ;;
    plan-calendar) echo "testCapturePlanCalendarScreenshots" ;;
    training-calendar) echo "testCaptureTrainingCalendarScreenshots testCaptureTrainingCalendarEmptyScreenshot" ;;
    hidden) echo "testCaptureLibraryFormsScreenshots" ;;
    exercise-insights) echo "testCaptureExerciseInsightsScreenshots" ;;
    exercise-form) echo "testCaptureLibraryFormsScreenshots" ;;
    muscle-balance) echo "testCaptureMuscleBalanceScreenshot" ;;
    rotation) echo "testCaptureRepeatingPlanScreenshots" ;;
    program-path) echo "ProgramPathScreenshotUITests/testCaptureProgramPathFixedScreenshots ProgramPathScreenshotUITests/testCaptureProgramPathRotationScreenshot" ;;
    weekly-review) echo "WeeklyProgramReviewUITests/testCaptureWeeklyProgramReviewScreenshot" ;;
    t36) echo "testCaptureT36MissingStatesScreenshots" ;;
    *) return 1 ;;
  esac
}

files_for_scene() {
  case "$1" in
    brand) echo "overview/00a_Launch_Brand.png" ;;
    onboarding) echo "onboarding/00_Welcome.png onboarding/01_Discipline.png onboarding/02_Goal.png onboarding/03_Experience.png onboarding/03a_Frequency.png onboarding/03b_Equipment.png onboarding/04_Recommendations.png" ;;
    overview) echo "overview/01_Today.png overview/01_Today_Light.png overview/02_Train.png overview/02_Train_Light.png overview/03_Progress_Empty.png overview/03_Progress_Empty_Light.png overview/03a_Progress_Populated.png overview/04_Settings.png overview/04_Settings_Light.png overview/05_Home_With_Active_Workout_Light.png nutrition/20_Nutrition_Today_Light.png" ;;
    settings-data-safety) echo "overview/04g_Settings_Data_Safety.png overview/04h_Backup_Export_Wizard.png overview/04i_Settings_Cloud_File.png" ;;
    pages) echo "overview/01b_Home_Template_Sheet.png overview/01c_Home_Workout_Conflict.png overview/01e_Daily_Check_In.png overview/01h_Daily_Check_In_Weight_Due.png overview/04a_Body_Weight_History.png overview/01f_Today_Reschedule_Workout.png overview/01g_Notification_Reschedule_Workout.png mobility/18_Mobility_Routines.png mobility/19_Active_Mobility.png mobility/19a_Active_Mobility_Safety.png nutrition/20_Nutrition_Today.png overview/02b_Train_Templates.png overview/02c_Train_Plans.png overview/02d_Train_Empty_Search.png overview/04b_Settings_Import_Error.png overview/04c_Settings_Import_Preview.png overview/04d_Settings_Shortcuts.png overview/04e_Settings_Beta_Feedback.png overview/04f_Settings_Beta_Feedback_Active_Logging.png overview/04g_Settings_Data_Safety.png overview/04h_Backup_Export_Wizard.png" ;;
    coach-exchange) echo "coach-exchange/23_Coach_Exchange_Empty.png coach-exchange/23a_Coach_Exchange_Package_Builder.png coach-exchange/23b_Coach_Exchange_Conflict_Preview.png coach-exchange/23c_Coach_Exchange_Import_Complete.png" ;;
    journey) echo "journey/24_Training_Journey_List.png journey/24a_Training_Journey_Timeline.png" ;;
    weightlifting) echo "progress/26_Weightlifting_Populated.png progress/26a_Competition_Day_Active.png" ;;
    athlete-intelligence) echo "overview/03g_Progress_Global_Populated.png overview/03h_Progress_General_Strength_Lens.png" ;;
    progress-analysis) echo "progress/03_Progress_Hub.png progress/03n_Exercise_Early_Comparison.png progress/03i_Training_History.png progress/03j_Records.png progress/03k_Exercise_Trends.png progress/03l_Muscle_Group_Volume.png progress/03m_Supporting_History.png overview/03g_Progress_Global_Populated.png overview/03h_Progress_General_Strength_Lens.png" ;;
    ledger) echo "progression/25_Training_Ledger.png progression/25a_Training_Ledger_Detail.png" ;;
    mixed-workout) echo "mixed-workout/27_Mixed_Eyes_Up_Runtime.png mixed-workout/27a_Mixed_Runtime_Split.png mixed-workout/27b_Mixed_Complex_Component_Evidence.png" ;;
    mobility) echo "mobility/18_Mobility_Routines.png mobility/18b_Mobility_Routine_Purpose.png mobility/19_Active_Mobility.png mobility/19a_Active_Mobility_Safety.png" ;;
    mobility-assessment) echo "mobility/18e_Mobility_Hub_Card_Empty.png mobility/18f_Mobility_Hub_Card_Recorded.png mobility/18g_Mobility_Hub_Card_InProgress.png mobility-assessment/21_Assessment_Landing_Empty.png mobility-assessment/21a_Assessment_Landing_Recorded.png mobility-assessment/21b_Assessment_Selection.png mobility-assessment/21c_Assessment_Instruction.png mobility-assessment/21d_Assessment_Manual_Entry.png mobility-assessment/21e_Assessment_Confirmation.png mobility-assessment/21f_Assessment_Summary.png mobility-assessment/21g_Assessment_History_Detail.png" ;;
    mobility-profile) echo "mobility-assessment/21h_Mobility_Assessment_Profile.png" ;;
    nutrition) echo "nutrition/20_Nutrition_Today.png nutrition/20a_Caffeine_Quick_Log.png nutrition/20b_Nutrition_Targets_Empty.png nutrition/20c_Recipe_Generation_Controls.png nutrition/20d_Recipe_Generating.png nutrition/20e_Recipe_Generated_Draft.png nutrition/20f_Recipe_Partial_Match.png nutrition/20g_Recipe_Manual_Fallback.png nutrition/20h_Food_Picker.png nutrition/20i_Recipe_Detail.png nutrition/20j_Log_Recipe.png nutrition/20k_Food_Intake.png nutrition/20l_Food_Entry.png nutrition/20m_Photo_Estimate_Review.png" ;;
    active) echo "active-workout/05_Active_Workout_Empty.png overview/05_Home_With_Active_Workout.png active-workout/06_Add_Exercise_Sheet.png active-workout/07_Plate_Calculator.png active-workout/07b_Set_Details.png active-workout/07c_Execution_Block_Builder.png active-workout/07d_Execution_Block_Active.png active-workout/07e_Set_Method_Segments.png active-workout/07f_Complex_Component_Results.png active-workout/08j_Exercise_Swap.png active-workout/08o_Substitution_Why.png active-workout/08p_Substitution_Confirmation.png active-workout/08_Active_Workout_With_Set.png active-workout/08k_Active_Superset.png active-workout/08d_Completed_Exercise_Collapsed.png active-workout/08e_Discard_Workout.png active-workout/08f_Duration_Timer_Idle.png active-workout/08g_Duration_Timer_Running.png active-workout/08h_Duration_Timer_Paused.png active-workout/08i_Duration_Timer_Complete.png review/09_Save_Workout.png review/09d_Bodyweight_And_Sport.png" ;;
    active-panels) echo "active-workout/07g_Warmup_Expanded.png active-workout/07h_Warmup_Collapsed.png active-workout/07i_Top_And_Technique_Badges.png active-workout/07j_Complex_Readiness.png active-workout/07k_Complex_Resolver.png active-workout/08q_Warmup_Preparation_Large.png" ;;
    active-gaps) echo "active-workout/07g_Set_Details_More_Types.png active-workout/07h_Set_Details_Recent_Types.png active-workout/08l_Selected_Daily_Maximum.png active-workout/08m_Generated_Back_Off.png" ;;
    active-appearance) echo "active-workout/08_Active_Workout_With_Set_Pale.png active-workout/08_Rest_Countdown_Pale.png" ;;
    active-accessibility) echo "active-workout/08w_Rest_Countdown_AX5.png active-workout/07l_Warmup_Expanded_AX5.png" ;;
    keyboards) echo "keyboards/01_Weight_And_Reps_Reps.png keyboards/02_Weight_And_Reps_Weight.png keyboards/03_Reps_Only.png keyboards/04_Weighted_Bodyweight_Reps.png keyboards/05_Weighted_Bodyweight_Weight.png keyboards/06_Assisted_Bodyweight_Reps.png keyboards/07_Assisted_Bodyweight_Assistance.png keyboards/08_Duration.png keyboards/09_Duration_And_Distance_Duration.png keyboards/10_Duration_And_Distance_Distance.png keyboards/11_Calories.png" ;;
    rest) echo "active-workout/08_Rest_Countdown.png active-workout/08b_Rest_Paused.png active-workout/08c_Rest_Ready.png active-workout/08u_Fresh_Rest_Transition.png active-workout/08v_Stage_Finish_Summary.png active-workout/08z_Olympic_Rest_Quality.png active-workout/08za_Olympic_Completed_Attempt.png" ;;
    history) echo "history/10_History_With_Workout.png history/10b_Expanded_Records.png history/11_History_Detail.png" ;;
    recommendation) echo "progression/10_Previous_Performance.png progression/10b_Progression_Hold.png progression/10c_Progression_Starting_Weight.png progression/10d_Progression_Manual_Edit.png progression/10e_Progression_Applied_Weight.png progression/10f_Progression_With_Rest_Running.png progression/10g_Progression_With_Rest_Paused.png progression/10h_Progression_Receipt.png progression/10g_Progression_Receipt_Why.png" ;;
    t36) echo "overview/00_Welcome.png overview/00b_Storage_Unavailable.png overview/02e_Route_Unavailable.png active-workout/08s_Guided_Source_Error.png active-workout/08t_Mobility_Link_Error.png review/09c_Save_Failure_Alert.png active-workout/08q_Warmup_Preparation_Dialog.png active-workout/08r_Cooldown_Stage.png active-workout/08x_Mid_Workout_Mobility_Picker.png active-workout/08y_Mid_Workout_Mobility_Stage.png history/03b_Progress_Trends_Frequency.png history/03c_Progress_Trends_Exercise_Selected.png nutrition/20b_Food_Library.png nutrition/20c_Meal_Template_Library.png nutrition/20d_Repeat_Meal_Sheet.png overview/02f_Archived_Exercises_Empty.png overview/02g_Workout_Collection_Detail.png" ;;
    performance) echo "review/14_Save_Performance_Comparison.png history/15_History_Performance_Comparison.png" ;;
    template-progression) echo "templates/12_Template_Progression.png templates/12d_Template_Execution_Block.png" ;;
    workout-form) echo "templates/12b_New_Workout_Form.png templates/12c_Exercise_Filters.png" ;;
    plan-review) echo "plans/13_Plan_Day_Assignments.png plans/13c_Program_Equipment.png plans/13d_Plan_Deload_Schedule.png plans/13g_Plan_Exercise_Alternatives.png plans/13h_Plan_Per_Set_Prescription.png plans/13n_Plan_Execution_Block.png plans/13_Plan_Review.png plans/13i_Program_Prescription_Preview.png plans/13a_Train_Current_Plan.png plans/13aa_Weekly_Review_Status.png plans/13b_Plan_Active_Run.png overview/01d_Home_Active_Plan.png" ;;
    program-builder) echo "plans/13j_Program_Definition_Builder.png" ;;
    program-catalog) echo "plans/13k_Program_Catalog.png plans/13ka_Program_Catalog_Filters.png plans/13kb_Program_Catalog_Filtered.png plans/13l_Program_Catalog_Detail.png plans/13m_Program_Intake.png" ;;
    plan-calendar) echo "plans/13e_Plan_Calendar.png plans/13f_Plan_Calendar_Day.png" ;;
    training-calendar) echo "calendar/21_Training_Calendar.png calendar/21b_Training_Calendar_Reschedule.png calendar/21c_Training_Calendar_Empty.png" ;;
    hidden) echo "exercises/16_Hidden_Exercises.png" ;;
    exercise-insights) echo "exercises/17c_Exercise_Detail_Overview.png exercises/17a_Exercise_Detail_Variations.png exercises/17b_Exercise_Relationships.png exercises/17_Exercise_Insights.png" ;;
    exercise-form) echo "exercises/18_New_Exercise_Form.png exercises/18b_New_Exercise_Muscles.png exercises/18c_New_Exercise_Advanced.png" ;;
    muscle-balance) echo "history/16_Muscle_Balance.png" ;;
    rotation) echo "plans/22_Repeating_Plan_Detail.png plans/22a_Repeating_Plan_Choose_Another.png plans/22b_Repeating_Plan_Paused.png plans/22c_Repeating_Plan_Undo.png overview/01i_Home_Active_Rotation.png active-workout/08n_Active_Workout_Rotation_Source.png" ;;
    program-path) echo "overview/01j_Home_Program_Path.png plans/13o_Program_Path_Fixed.png plans/13p_Program_Path_Reschedule.png plans/22d_Repeating_Plan_Path.png" ;;
    weekly-review) echo "plans/13q_Weekly_Program_Review.png" ;;
    *) return 1 ;;
  esac
}

ALL_SCENES="brand onboarding overview pages settings-data-safety coach-exchange journey weightlifting athlete-intelligence progress-analysis ledger mixed-workout mobility mobility-assessment mobility-profile nutrition active active-panels active-gaps active-appearance active-accessibility keyboards rest history recommendation performance template-progression workout-form plan-review program-builder program-catalog plan-calendar training-calendar hidden exercise-insights exercise-form muscle-balance rotation program-path weekly-review t36"
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
    if ! grep -Fq "$basename" "$catalog"; then
      echo "Screenshot runner path is missing from ScreenshotCoverage.md: $filename"
      exit 1
    fi
  done

  while IFS= read -r catalog_path; do
    local basename="${catalog_path##*/}"
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
  done < <(sed -n '/Pending/d; /Not catalogued/d; s/.*`\([^`]*\.png\)`.*/\1/p' "$catalog")
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
xcodebuild -quiet -project "$WORKSPACE_DIR/GymTracker.xcodeproj" -scheme GymTrackerUITEST -destination "platform=iOS Simulator,id=$SIMULATOR_ID" -derivedDataPath "$DERIVED_DATA_PATH" -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 build-for-testing

if [[ "$USE_PARALLEL" == true ]]; then
  echo "=== Building for Simulator 2 ($SIMULATOR_ID_2) ==="
  xcodebuild -quiet -project "$WORKSPACE_DIR/GymTracker.xcodeproj" -scheme GymTrackerUITEST -destination "platform=iOS Simulator,id=$SIMULATOR_ID_2" -derivedDataPath "$DERIVED_DATA_PATH_2" -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 build-for-testing
fi

RAW_TESTS=()
for scene in $SELECTED_SCENES; do
  for test_name in $(tests_for_scene "$scene"); do
    RAW_TESTS+=("$test_name")
  done
done

SELECTED_TESTS=()
for test_name in "${RAW_TESTS[@]}"; do
  if [[ ! " ${SELECTED_TESTS[*]:-} " =~ " ${test_name} " ]]; then
    SELECTED_TESTS+=("$test_name")
  fi
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
  local failed_tests=()

  local xcode_args=(
    -quiet
    -project "$WORKSPACE_DIR/GymTracker.xcodeproj"
    -scheme GymTrackerUITEST
    -destination "platform=iOS Simulator,id=$sim_id"
    -derivedDataPath "$dd_path"
    -parallel-testing-enabled NO
    -maximum-concurrent-test-simulator-destinations 1
  )

  for test_name in "${tests[@]}"; do
    echo "=== [$sim_id] Running test $test_name ==="
    local test_target="$test_name"
    local result_label="${test_name//\//-}"
    if [[ "$test_name" != */* ]]; then
      test_target="ScreenshotUITests/$test_name"
    fi
    # Each method receives a fresh UI-test runner. This prevents a failed app
    # relaunch from cancelling unrelated screenshot states in the same scene.
    # Remove the app container too: fixture launches reset SwiftData in-process,
    # and a just-deleted active workout can otherwise remain visible to the next
    # independently launched method through SwiftData's query cache.
    xcrun simctl terminate "$sim_id" "$APP_BUNDLE_ID" 2>/dev/null || true
    xcrun simctl uninstall "$sim_id" "$APP_BUNDLE_ID" 2>/dev/null || true
    rm -rf "$rb_dir/$CAPTURE_RUN_ID-$result_label.xcresult"
    if ! xcodebuild "${xcode_args[@]}" \
      -resultBundlePath "$rb_dir/$CAPTURE_RUN_ID-$result_label.xcresult" \
      "-only-testing:GymTrackerUITEST/$test_target" \
      test-without-building; then
      if [[ "${CAPTURE_CONTINUE_ON_FAILURE:-false}" == true ]]; then
        failed_tests+=("$test_name")
      else
        return 1
      fi
    fi
  done

  if [[ ${#failed_tests[@]} -gt 0 ]]; then
    echo "=== Screenshot tests failed after remaining scenes were attempted ===" >&2
    printf '  %s\n' "${failed_tests[@]}" >&2
    return 1
  fi
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
