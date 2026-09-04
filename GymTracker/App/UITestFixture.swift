import Foundation
import SwiftData

/// Deterministic, persisted data graphs used exclusively by screenshot and
/// state-focused UI tests. Journey tests deliberately do not use these
/// fixtures: they exercise the user actions that create the graph.
enum UITestFixture: String {
    case activeEmpty = "active-empty"
    case activePickerSections = "active-picker-sections"
    case activeInProgress = "active-in-progress"
    case activeCompletedSet = "active-completed-set"
    case activeCompletedExercise = "active-completed-exercise"
    case activePartialSave = "active-partial-save"
    case activeBodyweightSave = "active-bodyweight-save"
    case activeRestRunning = "active-rest-running"
    case activeRestPaused = "active-rest-paused"
    case activeRestReady = "active-rest-ready"
    case activeDraft = "active-draft"
    case activeAllTrackingTypes = "active-all-tracking-types"
    case activeLoadingStyles = "active-loading-styles"
    case activeSuperset = "active-superset"
    case activeExecutionBlock = "active-execution-block"
    case activeAdvancedSet = "active-advanced-set"
    case activeComplexComponents = "active-complex-components"
    case activeComplexUnresolved = "active-complex-unresolved"
    case activeWarmupExpanded = "active-warmup-expanded"
    case activeWarmupCollapsed = "active-warmup-collapsed"
    case activeSetTypeBadges = "active-set-type-badges"
    case activeRecentSetType = "active-recent-set-type"
    case activeDailyMaximum = "active-daily-maximum"
    case activeGeneratedBackoff = "active-generated-backoff"
    case historyBench = "history-bench"
    case weightliftingDashboard = "weightlifting-dashboard"
    case coachExchange = "coach-exchange"
    case exerciseInsights = "exercise-insights"
    case muscleBalance = "muscle-balance"
    case progressionIncrease = "progression-increase"
    case progressionHold = "progression-hold"
    case progressionInsufficientHistory = "progression-insufficient-history"
    case progressionRestRunning = "progression-rest-running"
    case progressionRestPaused = "progression-rest-paused"
    case progressionReceipt = "progression-receipt"
    case performanceComparison = "performance-comparison"
    case performanceHistoryComparison = "performance-history-comparison"
    case homeActiveConflict = "home-active-conflict"
    case planActiveRun = "plan-active-run"
    case planCalendar = "plan-calendar"
    case planRelaunchSchedule = "plan-relaunch-schedule"
    case planPartialSave = "plan-partial-save"
    case programPathFixed = "program-path-fixed"
    case programPathRotation = "program-path-rotation"
    case repeatingPlanActive = "repeating-plan-active"
    case backupImportTarget = "backup-import-target"
    case todayComplete = "today-complete"
    case todayWeightDue = "today-weight-due"
    case bodyWeightHistory = "body-weight-history"
    case mobilityActive = "mobility-active"
    case mobilityAssessmentRecorded = "mobility-assessment-recorded"
    case mobilityAssessmentInProgress = "mobility-assessment-in-progress"
    case mobilityAssessmentHistory = "mobility-assessment-history"
    case mobilityAssessmentHistoryDetail = "mobility-assessment-history-detail"
    case nutritionToday = "nutrition-today"
    case trainingCalendar = "training-calendar"
    case linkedMobilityWorkout = "linked-mobility-workout"
    case midWorkoutMobility = "mid-workout-mobility"

    static var launchFixture: UITestFixture? {
        let arguments = AppLaunchArguments.current
        guard
            let index = arguments.firstIndex(of: "-ui-test-fixture"),
            arguments.indices.contains(index + 1)
        else {
            return nil
        }
        return UITestFixture(rawValue: arguments[index + 1])
    }

    var opensActiveWorkout: Bool {
        switch self {
        case .historyBench, .weightliftingDashboard, .coachExchange, .exerciseInsights, .muscleBalance, .performanceHistoryComparison, .homeActiveConflict, .planActiveRun, .planCalendar, .planRelaunchSchedule, .programPathFixed, .programPathRotation, .repeatingPlanActive, .backupImportTarget, .todayComplete, .todayWeightDue, .bodyWeightHistory, .mobilityActive, .mobilityAssessmentRecorded, .mobilityAssessmentInProgress, .mobilityAssessmentHistory, .mobilityAssessmentHistoryDetail, .nutritionToday, .trainingCalendar, .progressionReceipt, .linkedMobilityWorkout:
            false
        default:
            true
        }
    }

    var showsActiveWorkoutConflict: Bool {
        self == .homeActiveConflict
    }

    var refreshesPlanRunAvailability: Bool {
        self == .planRelaunchSchedule
    }

    static func apply(_ fixture: UITestFixture, using context: ModelContext) throws {
        UserDefaults.standard.set(BodyWeightPromptCadence.off.rawValue, forKey: DefaultsKey.bodyWeightPromptCadence)
        switch fixture {
        case .activeEmpty:
            try makeActiveWorkout(exercises: [], using: context)
        case .activePickerSections:
            try makePickerSectionsFixture(using: context)
        case .activeInProgress:
            try makeActiveWorkout(exercises: [inProgressEntry(named: "Bench Press", using: context)], using: context)
        case .activeCompletedSet:
            try makeActiveWorkout(exercises: [completedSetEntry(named: "Bench Press", using: context)], using: context)
        case .activeCompletedExercise:
            let bench = try completedExerciseEntry(named: "Bench Press", orderIndex: 0, using: context)
            let row = try inProgressEntry(named: "Barbell Row", orderIndex: 1, using: context)
            try makeActiveWorkout(exercises: [bench, row], using: context)
        case .activePartialSave:
            try makeActiveWorkout(exercises: [completedSetEntry(named: "Bench Press", using: context)], using: context)
        case .activeBodyweightSave:
            UserDefaults.standard.set(BodyWeightPromptCadence.weekly.rawValue, forKey: DefaultsKey.bodyWeightPromptCadence)
            try makeActiveWorkout(exercises: [completedSetEntry(named: "Push-Up", using: context)], using: context)
        case .activeRestRunning:
            try makeRestWorkout(state: .running, using: context)
        case .activeRestPaused:
            try makeRestWorkout(state: .paused, using: context)
        case .activeRestReady:
            try makeRestWorkout(state: .ready, using: context)
        case .activeDraft:
            try makeActiveDraftWorkout(using: context)
        case .activeAllTrackingTypes:
            try makeAllTrackingTypesWorkout(using: context)
        case .activeLoadingStyles:
            try makeLoadingStyleWorkout(using: context)
        case .activeSuperset:
            try makeSupersetWorkout(using: context)
        case .activeExecutionBlock:
            try makeExecutionBlockWorkout(using: context)
        case .activeAdvancedSet:
            try makeAdvancedSetWorkout(using: context)
        case .activeComplexComponents:
            try makeComplexComponentWorkout(using: context)
        case .activeComplexUnresolved:
            try makeUnresolvedComplexComponentWorkout(using: context)
        case .activeWarmupExpanded:
            try makeWarmupWorkout(completed: false, using: context)
        case .activeWarmupCollapsed:
            try makeWarmupWorkout(completed: true, using: context)
        case .activeSetTypeBadges:
            try makeSetTypeBadgeWorkout(using: context)
        case .activeRecentSetType:
            UserDefaults.standard.set("dailyMaximum,dropSet", forKey: DefaultsKey.recentSetTypes)
            try makeActiveWorkout(exercises: [inProgressEntry(named: "Bench Press", using: context)], using: context)
        case .activeDailyMaximum:
            try makeDailyMaximumWorkout(using: context)
        case .activeGeneratedBackoff:
            try makeGeneratedBackoffWorkout(using: context)
        case .historyBench:
            try makeCompletedBenchHistory(using: context)
        case .weightliftingDashboard:
            try makeWeightliftingDashboard(using: context)
        case .coachExchange:
            let squat = try exercise(named: "Squat", using: context)
            context.insert(WorkoutTemplate(name: "Strength Day", exercises: [squat]))
            try context.save()
        case .exerciseInsights:
            try makeExerciseInsightsHistory(using: context)
        case .muscleBalance:
            try makeMuscleBalanceHistory(using: context)
        case .progressionIncrease:
            try makeProgressionWorkout(decision: .increase, using: context)
        case .progressionHold:
            try makeProgressionWorkout(decision: .hold, using: context)
        case .progressionInsufficientHistory:
            try makeProgressionWorkout(decision: nil, using: context)
        case .progressionRestRunning:
            try makeProgressionAndRestWorkout(restState: .running, using: context)
        case .progressionRestPaused:
            try makeProgressionAndRestWorkout(restState: .paused, using: context)
        case .progressionReceipt:
            try makeProgressionReceipt(using: context)
        case .performanceComparison:
            try makePerformanceComparisonWorkout(using: context)
        case .performanceHistoryComparison:
            try makePerformanceComparisonHistory(using: context)
        case .homeActiveConflict:
            try makeActiveWorkout(exercises: [inProgressEntry(named: "Bench Press", using: context)], using: context)
        case .planActiveRun:
            try makeActivePlanRun(using: context)
        case .planCalendar:
            try makePlanCalendarRun(using: context)
        case .planRelaunchSchedule:
            try makePlanRelaunchSchedule(using: context)
        case .planPartialSave:
            try makePartialPlannedWorkout(using: context)
        case .programPathFixed:
            try makeProgramPathFixed(using: context)
        case .programPathRotation:
            try makeProgramPathRotation(using: context)
        case .repeatingPlanActive:
            try makeActiveRepeatingPlan(using: context)
        case .backupImportTarget:
            try makeBackupImportTarget(using: context)
        case .todayComplete:
            context.insert(DailyLogEntry(
                day: .today,
                sleepQuality: 4,
                energy: 4,
                workoutDifficulty: 3,
                note: "Felt steady today."
            ))
            context.insert(SupplementOccurrence(kind: .creatine, day: .today))
            let coffee = FoodItem(
                name: "Coffee · Brewed",
                referenceAmount: 1,
                referenceUnit: .serving,
                caffeineMilligrams: 145,
                sourceKind: .curated,
                confidence: .estimated,
                preparationState: .cooked
            )
            context.insert(coffee)
            _ = NutritionLoggingService.log(food: coffee, using: context)
            try context.save()
        case .todayWeightDue:
            UserDefaults.standard.set(BodyWeightPromptCadence.weekly.rawValue, forKey: DefaultsKey.bodyWeightPromptCadence)
            try context.save()
        case .bodyWeightHistory:
            let calendar = Calendar.current
            let recent = Date.now.addingTimeInterval(-86_400)
            let prior = calendar.date(byAdding: .month, value: -1, to: recent) ?? recent
            context.insert(BodyWeightEntry(day: LocalDay(date: prior), value: 181.5, unit: .lbs, measuredAt: prior))
            context.insert(BodyWeightEntry(day: LocalDay(date: recent), value: 179.8, unit: .lbs, measuredAt: recent))
            try context.save()
        case .mobilityActive:
            // SwiftData does not promise insertion order for an un-sorted
            // fetch.  This fixture is intentionally a short, deterministic
            // flow: the first movement is repetition-tracked and the second
            // is the 45-second Couch Stretch used by the hold-feedback UI
            // test.  Selecting by its stable seeded name keeps that contract
            // intact as new routines are added to the catalogue.
            let routine = try context.fetch(FetchDescriptor<MobilityRoutine>())
                .first(where: { $0.name == "Daily mobility reset" })
            guard let routine else {
                throw FixtureError.invalidPlan
            }
            guard MobilitySessionService.start(routine: routine, using: context) != nil else {
                throw FixtureError.invalidPlan
            }
        case .mobilityAssessmentRecorded:
            try makeMobilityAssessmentHistory(
                includeEmptySession: false,
                includeIncomparableObservation: false,
                using: context
            )
        case .mobilityAssessmentInProgress:
            let definitions = try assessmentDefinitions(using: context)
            guard let first = definitions.first else { throw FixtureError.invalidPlan }
            let session = MobilityAssessmentSession(
                day: .today,
                selectedDefinitionKeys: [first.catalogueKey, definitions.dropFirst().first?.catalogueKey].compactMap { $0 },
                startedAt: Date.now.addingTimeInterval(-900)
            )
            context.insert(session)
            try context.save()
        case .mobilityAssessmentHistory:
            try makeMobilityAssessmentHistory(
                includeEmptySession: true,
                includeIncomparableObservation: false,
                using: context
            )
        case .mobilityAssessmentHistoryDetail:
            try makeMobilityAssessmentHistory(
                includeEmptySession: false,
                includeIncomparableObservation: true,
                using: context
            )
        case .nutritionToday:
            let foods = try context.fetch(FetchDescriptor<FoodItem>())
            guard let yogurt = foods.first(where: { $0.name == "Greek yogurt" }),
                  let chicken = foods.first(where: { $0.name == "Chicken breast" }) else {
                throw FixtureError.invalidPlan
            }
            guard NutritionLoggingService.log(food: yogurt, using: context) != nil,
                  NutritionLoggingService.log(food: chicken, using: context) != nil else {
                throw FixtureError.invalidPlan
            }
            context.insert(NutritionTarget(
                phase: .maintenance,
                training: NutritionTargetValues(calories: 3_000, protein: 180, carbohydrates: 350, fat: 90),
                rest: NutritionTargetValues(calories: 2_700, protein: 180, carbohydrates: 280, fat: 90)
            ))
            try context.save()
        case .linkedMobilityWorkout:
            try makeLinkedMobilityWorkoutFixture(using: context)
        case .midWorkoutMobility:
            try makeMidWorkoutMobilityFixture(using: context)
        case .trainingCalendar:
            try makeTrainingCalendarFixture(using: context)
        }
    }

    @MainActor
    enum UITestImportPayload {
        static var validData: Data?
    }

    private enum RestState {
        case running
        case paused
        case ready
    }

    private static func makeActiveWorkout(
        exercises: [ExerciseEntry],
        using context: ModelContext
    ) throws {
        let workout = Workout(name: "Today’s workout")
        workout.startTime = Date.now.addingTimeInterval(-47)
        workout.exercises = exercises
        context.insert(workout)
        try context.save()
    }

    private static func assessmentDefinitions(using context: ModelContext) throws -> [MobilityAssessmentDefinition] {
        try MobilityAssessmentCatalogService.definitions(using: context)
    }

    private static func makeMobilityAssessmentHistory(
        includeEmptySession: Bool,
        includeIncomparableObservation: Bool,
        using context: ModelContext
    ) throws {
        let definitions = try assessmentDefinitions(using: context)
        guard let definition = definitions.first else { throw FixtureError.invalidPlan }

        if includeEmptySession {
            let empty = MobilityAssessmentSession(
                day: .today,
                selectedDefinitionKeys: [definition.catalogueKey],
                startedAt: Date.now.addingTimeInterval(-10_800)
            )
            empty.status = .completed
            empty.completedAt = empty.startedAt.addingTimeInterval(60)
            context.insert(empty)
        }

        let first = MobilityAssessmentSession(
            day: .today,
            selectedDefinitionKeys: [definition.catalogueKey],
            startedAt: Date.now.addingTimeInterval(-7_200)
        )
        context.insert(first)
        _ = try MobilityAssessmentSessionService.saveResult(
            in: first,
            definition: definition,
            input: assessmentInput(
                value: 40,
                side: .left,
                definition: definition,
                day: .today,
                isWarm: false
            ),
            now: first.startedAt.addingTimeInterval(30),
            using: context
        )
        try MobilityAssessmentSessionService.complete(
            first,
            completedAt: first.startedAt.addingTimeInterval(60),
            using: context
        )

        guard includeIncomparableObservation else { return }

        let second = MobilityAssessmentSession(
            day: .today,
            selectedDefinitionKeys: [definition.catalogueKey],
            startedAt: Date.now.addingTimeInterval(-3_600)
        )
        context.insert(second)
        _ = try MobilityAssessmentSessionService.saveResult(
            in: second,
            definition: definition,
            input: assessmentInput(
                value: 45,
                side: .left,
                definition: definition,
                day: .today,
                isWarm: false
            ),
            now: second.startedAt.addingTimeInterval(30),
            using: context
        )
        _ = try MobilityAssessmentSessionService.saveResult(
            in: second,
            definition: definition,
            input: assessmentInput(
                value: 35,
                side: .right,
                definition: definition,
                day: .today,
                isWarm: true
            ),
            now: second.startedAt.addingTimeInterval(31),
            using: context
        )
        try MobilityAssessmentSessionService.complete(
            second,
            completedAt: second.startedAt.addingTimeInterval(60),
            using: context
        )
    }

    private static func assessmentInput(
        value: Double,
        side: MobilityAssessmentSide,
        definition: MobilityAssessmentDefinition,
        day: LocalDay,
        isWarm: Bool
    ) -> MobilityAssessmentResultInput {
        MobilityAssessmentResultInput(
            numericValue: value,
            side: side,
            isWarm: isWarm,
            setupKey: definition.defaultSetupKey,
            method: definition.manualMode,
            unit: definition.unit,
            isActiveRange: definition.defaultIsActiveRange,
            day: day
        )
    }

    private static func makeProgressionReceipt(using context: ModelContext) throws {
        let exercise = try exercise(named: "Bench Press", using: context)
        let plannedExercise = PlannedExercise(
            exercise: exercise,
            orderIndex: 0,
            suggestedLoad: 60,
            suggestedLoadType: .kg,
            plannedSets: [PlannedSet(orderIndex: 0, repetitions: 5)]
        )
        let plannedWorkout = PlannedWorkout(
            name: "Receipt Day",
            orderIndex: 0,
            dayOffset: 0,
            plannedExercises: [plannedExercise]
        )
        let plan = WorkoutPlan(
            name: "Receipt Fixture",
            daysPerWeek: 1,
            durationWeeks: 1,
            blocks: [PlanBlock(
                name: "Build",
                phaseType: .strength,
                orderIndex: 0,
                weeks: [PlanWeek(weekIndex: 0, plannedWorkouts: [plannedWorkout])]
            )]
        )
        context.insert(plan)
        guard let run = PlanCoordinator.startRun(for: plan, using: context) else {
            throw FixtureError.invalidPlan
        }
        let workout = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .metric)
        workout.status = .completed
        workout.endTime = .now
        context.insert(workout)

        let record = try PlanProgressionRecommendationRecord(
            recommendation: ProgressionRecommendation(
                id: UUID(),
                ruleID: UUID(),
                action: .addLoad(2.5),
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                reason: "Every required set reached the upper rep bound.",
                reasonKey: "progression.receipt.reason.triggerSatisfied",
                applicationMode: .recommendation,
                proposedState: ProgressionEvaluationState(currentLoad: 62.5),
                performance: ProgressionPerformance(
                    requiredSets: 3,
                    completedSets: 3,
                    requiredRepetitions: 30,
                    completedRepetitions: 30
                ),
                ruleVersion: 2
            ),
            planRunID: run.id,
            workoutID: workout.id,
            proposedLoadUnit: .kg
        )
        record.progressionKey = plannedExercise.progressionKey
        context.insert(record)
        try context.save()
    }

    private static func makeActiveRepeatingPlan(using context: ModelContext) throws {
        let benchPress = try exercise(named: "Bench Press", using: context)
        let squat = try exercise(named: "Back Squat", using: context)
        let firstWorkout = WorkoutTemplate(
            name: "Rotation Screenshot Strength",
            exercises: [benchPress]
        )
        let alternateWorkout = WorkoutTemplate(
            name: "Rotation Screenshot Squat",
            exercises: [squat]
        )
        context.insert(firstWorkout)
        context.insert(alternateWorkout)

        let plan = RepeatingPlan(
            name: "Rotation Screenshot Fixture",
            goal: .generalStrength,
            experienceLevel: .intermediate,
            notes: "A deterministic active rotation for Home, detail, and workout-source captures.",
            slots: [
                RepeatingPlanSlot(orderIndex: 0, workoutTemplate: firstWorkout),
                RepeatingPlanSlot(orderIndex: 1, workoutTemplate: alternateWorkout)
            ]
        )
        context.insert(plan)

        let run = RepeatingPlanRun(plan: plan, startedAt: Date.now.addingTimeInterval(-86_400))
        run.currentSlotIndex = 0
        run.completedCycleCount = 1
        run.updatedAt = .now
        run.occurrences = [
            RepeatingPlanOccurrence(
                cycleIndex: 0,
                expectedSlotIndex: 1,
                kind: .expected,
                status: .skipped,
                cursorBefore: 1,
                cursorAfter: 0,
                cycleBefore: 0,
                cycleAfter: 1,
                createdAt: Date.now.addingTimeInterval(-3_600),
                completedAt: Date.now.addingTimeInterval(-3_600)
            )
        ]
        context.insert(run)
        try context.save()
    }

    private static func makeRestWorkout(
        state: RestState,
        using context: ModelContext
    ) throws {
        let entry = try completedSetEntry(named: "Bench Press", using: context)
        let workout = Workout(name: "Today’s workout")
        workout.startTime = Date.now.addingTimeInterval(-47)
        workout.exercises = [entry]

        switch state {
        case .running:
            workout.restEndDate = Date.now.addingTimeInterval(45)
        case .paused:
            workout.pausedRemainingTime = 45
        case .ready:
            // Restoring an expired persisted end date intentionally enters the
            // visible ready state instead of silently removing the card.
            workout.restEndDate = Date.now.addingTimeInterval(-1)
        }

        context.insert(workout)
        try context.save()
    }

    private static func makeLoadingStyleWorkout(using context: ModelContext) throws {
        let entries = [
            try inProgressEntry(named: "Bench Press", orderIndex: 0, using: context),
            try inProgressEntry(named: "Dumbbell Bench Press", orderIndex: 1, using: context)
        ]
        try makeActiveWorkout(exercises: entries, using: context)
    }

    private static func makeSupersetWorkout(using context: ModelContext) throws {
        let groupID = UUID()
        let bench = try inProgressEntry(named: "Bench Press", orderIndex: 0, using: context)
        let row = try inProgressEntry(named: "Barbell Row", orderIndex: 1, using: context)
        bench.supersetGroupID = groupID
        row.supersetGroupID = groupID
        row.prescribedRestSeconds = 90
        try makeActiveWorkout(exercises: [bench, row], using: context)
    }

    private static func makeExecutionBlockWorkout(using context: ModelContext) throws {
        let bench = try inProgressEntry(named: "Bench Press", orderIndex: 0, using: context)
        let row = try inProgressEntry(named: "Barbell Row", orderIndex: 1, using: context)
        let workout = Workout(name: "Power Circuit")
        workout.startTime = Date.now.addingTimeInterval(-135)
        workout.exercises = [bench, row]

        let block = WorkoutExecutionBlock(
            orderIndex: 0,
            kind: .circuit,
            name: "Power circuit",
            targetRounds: 3,
            restSeconds: 90,
            clockMode: .countUp,
            timeCapSeconds: 600,
            scoreKind: .roundsAndRepetitions
        )
        block.status = .inProgress
        block.elapsedStartedAt = workout.startTime
        block.completedRounds = 1
        block.additionalRepetitions = 6
        workout.executionBlocks = [block]
        bench.executionBlockID = block.id
        bench.executionBlockComponentOrder = 0
        row.executionBlockID = block.id
        row.executionBlockComponentOrder = 1
        context.insert(workout)
        try context.save()
    }

    private static func makeAdvancedSetWorkout(using context: ModelContext) throws {
        let entry = try inProgressEntry(named: "Bench Press", using: context)
        guard let set = entry.orderedSets.first else { throw FixtureError.invalidPlan }
        set.setType = .dropSet
        set.setMethod = .dropSet
        set.meanVelocity = 0.56
        set.peakVelocity = 0.71
        set.velocityMeasurementSource = .device
        set.specializedMetricKind = .jumpHeight
        set.jumpHeightMeters = 0.48
        set.specializedMetricMeasurementSource = .device
        set.segments = [
            ExerciseSetSegment(orderIndex: 0, repetitions: 8, weight: 50, done: false),
            ExerciseSetSegment(orderIndex: 1, repetitions: 6, weight: 40, restAfterSeconds: 0, done: false)
        ]
        try makeActiveWorkout(exercises: [entry], using: context)
    }

    private static func makeComplexComponentWorkout(using context: ModelContext) throws {
        let entry = try inProgressEntry(named: "Three-Position Snatch", using: context)
        guard let set = entry.orderedSets.first else { throw FixtureError.invalidPlan }
        set.prescribedRepetitions = 3
        set.weight = 60
        set.ensureComplexComponents(for: [
            ComplexComponentSnapshot(
                exerciseID: try exercise(named: "High-Hang Snatch", using: context).id,
                exerciseNameSnapshot: "High-Hang Snatch",
                prescribedRepetitions: 1
            ),
            ComplexComponentSnapshot(
                exerciseID: try exercise(named: "Hang Snatch", using: context).id,
                exerciseNameSnapshot: "Hang Snatch",
                prescribedRepetitions: 1
            ),
            ComplexComponentSnapshot(
                exerciseID: try exercise(named: "Snatch", using: context).id,
                exerciseNameSnapshot: "Snatch",
                prescribedRepetitions: 1
            )
        ])
        guard set.complexComponents.count == 3 else { throw FixtureError.invalidPlan }
        set.complexComponents[0].outcome = .completed
        set.complexComponents[0].performedRepetitions = 1
        set.complexComponents[1].outcome = .partial
        set.complexComponents[1].performedRepetitions = 0
        set.complexComponents[2].outcome = .missed

        try makeActiveWorkout(exercises: [entry], using: context)
    }

    private static func makeUnresolvedComplexComponentWorkout(using context: ModelContext) throws {
        let entry = try inProgressEntry(named: "Three-Position Snatch", using: context)
        guard let set = entry.orderedSets.first else { throw FixtureError.invalidPlan }
        set.prescribedRepetitions = 3
        set.weight = 60
        set.ensureComplexComponents(for: [
            ComplexComponentSnapshot(
                exerciseID: try exercise(named: "High-Hang Snatch", using: context).id,
                exerciseNameSnapshot: "High-Hang Snatch",
                prescribedRepetitions: 1
            ),
            ComplexComponentSnapshot(
                exerciseID: try exercise(named: "Hang Snatch", using: context).id,
                exerciseNameSnapshot: "Hang Snatch",
                prescribedRepetitions: 1
            ),
            ComplexComponentSnapshot(
                exerciseID: try exercise(named: "Snatch", using: context).id,
                exerciseNameSnapshot: "Snatch",
                prescribedRepetitions: 1
            )
        ])
        try makeActiveWorkout(exercises: [entry], using: context)
    }

    private static func makeWarmupWorkout(completed: Bool, using context: ModelContext) throws {
        let entry = try inProgressEntry(named: "Bench Press", using: context)
        guard entry.orderedSets.count >= 3 else { throw FixtureError.invalidPlan }
        entry.orderedSets[0].setType = .warmup
        entry.orderedSets[0].weight = 20
        entry.orderedSets[1].setType = .warmup
        entry.orderedSets[1].weight = 35
        if completed {
            entry.orderedSets[0].done = true
            entry.orderedSets[1].done = true
        }
        try makeActiveWorkout(exercises: [entry], using: context)
    }

    private static func makeSetTypeBadgeWorkout(using context: ModelContext) throws {
        let entry = try inProgressEntry(named: "Bench Press", using: context)
        guard entry.orderedSets.count >= 2 else { throw FixtureError.invalidPlan }
        entry.orderedSets[0].setType = .topSet
        entry.orderedSets[1].setType = .technique
        try makeActiveWorkout(exercises: [entry], using: context)
    }

    private static func makeDailyMaximumWorkout(using context: ModelContext) throws {
        let entry = try inProgressEntry(named: "Bench Press", using: context)
        guard let attempt = entry.orderedSets.first else { throw FixtureError.invalidPlan }
        attempt.repetitions = 1
        attempt.weight = 120
        attempt.done = true
        attempt.setType = .dailyMaximum
        attempt.prescribedSetType = .dailyMaximum
        attempt.isSelectedDailyMaximum = true
        try makeActiveWorkout(exercises: [entry], using: context)
    }

    private static func makeGeneratedBackoffWorkout(using context: ModelContext) throws {
        let exercise = try exercise(named: "Bench Press", using: context)
        let top = ExerciseSet(
            repetitions: 5,
            weight: 100,
            done: true,
            setType: .topSet,
            orderIndex: 0,
            usedMetric: .metric
        )
        top.prescribedSetType = .topSet
        let generated = ExerciseSet(
            repetitions: 0,
            weight: 0,
            done: false,
            setType: .backoff,
            orderIndex: 1,
            usedMetric: .metric
        )
        generated.prescribedSetType = .backoff
        generated.prescribedRepetitions = 5
        generated.prescribedSuggestedLoad = 90
        generated.prescribedSuggestedLoadType = .kg
        generated.generatedBackOffDefinitionID = UUID()
        let entry = ExerciseEntry(exercise: exercise, sets: [top, generated], usedMetric: .metric)
        try makeActiveWorkout(exercises: [entry], using: context)
    }

    private static func makeActiveDraftWorkout(using context: ModelContext) throws {
        let benchPress = try exercise(named: "Bench Press", using: context)
        let alternative = try exercise(named: "Dumbbell Bench Press", using: context)
        let entry = ExerciseEntry(from: benchPress, orderIndex: 0, usedMetric: .metric)
        context.insert(ExerciseRelationship(
            sourceExercise: benchPress,
            targetExercise: alternative,
            type: .substitution
        ))
        // Persist the relationship before presenting the active workout. The
        // swap sheet owns an @Query and must observe the relationship as a
        // committed fixture record, just as it would after a user creates one
        // in the exercise library.
        try context.save()
        context.processPendingChanges()
        try makeActiveWorkout(exercises: [entry], using: context)
    }

    /// One exercise per `TrackingType`, each with its default empty sets, so
    /// every keypad configuration (reps, weight, duration, distance, calories,
    /// and their bodyweight variants) is reachable in a single manual pass
    /// without hunting through the exercise library for a matching exercise.
    private static func makeAllTrackingTypesWorkout(using context: ModelContext) throws {
        let exerciseNames = [
            "Bench Press",       // weightAndReps
            "Push-Up",           // repsOnly
            "Weighted Pull-Up",  // weightedBodyweight
            // "Assisted Pull Up" (unpunctuated): the legacy seed spelling.
            // ExerciseSeedData.templates() no longer seeds the catalog's
            // hyphenated "Assisted Pull-Up" as a separate exercise (see its
            // dedupe comment), and the legacy entry already carries the
            // same .assistedBodyweight tracking type this fixture needs.
            "Assisted Pull Up",  // assistedBodyweight
            "Plank",             // duration
            "Treadmill Run",     // durationAndDistance
            "Stationary Bike"    // calories
        ]
        let entries = try exerciseNames.enumerated().map { orderIndex, name in
            let entry = ExerciseEntry(
                exercise: try exercise(named: name, using: context),
                orderIndex: orderIndex,
                usedMetric: .metric
            )
            entry.addDefaultSets(count: 2)
            return entry
        }
        try makeActiveWorkout(exercises: entries, using: context)
    }

    private static func makeCompletedBenchHistory(using context: ModelContext) throws {
        let entry = try completedExerciseEntry(named: "Bench Press", using: context)
        let workout = Workout(name: "Upper Body", endTime: Date.now.addingTimeInterval(-3_600))
        workout.startTime = Date.now.addingTimeInterval(-7_200)
        workout.exercises = [entry]
        let block = WorkoutExecutionBlock(
            orderIndex: 0,
            kind: .forTime,
            name: "Upper benchmark",
            clockMode: .countUp,
            timeCapSeconds: 900,
            scoreKind: .duration
        )
        block.status = .completed
        block.scoreValue = 423
        workout.executionBlocks = [block]
        entry.executionBlockID = block.id
        entry.executionBlockComponentOrder = 0
        context.insert(workout)
        try context.save()
    }

    /// Picker-specific graph: one completed recent exercise and one distinct
    /// favorite, with an empty active workout as the destination for adding.
    /// Keeping this state in a fixture avoids navigating through exercise
    /// details merely to seed a favorite during a picker UI test.
    private static func makePickerSectionsFixture(using context: ModelContext) throws {
        let recentEntry = try completedExerciseEntry(named: "Bench Press", using: context)
        let workout = Workout(name: "Recent picker session", endTime: Date.now.addingTimeInterval(-3_600))
        workout.startTime = Date.now.addingTimeInterval(-7_200)
        workout.exercises = [recentEntry]
        context.insert(workout)

        let favorite = try exercise(named: "Arnold Press", using: context)
        favorite.isFavorite = true
        try makeActiveWorkout(exercises: [], using: context)
    }

    /// Completed Olympic-lifting snapshots for the CE-06 dashboard. The
    /// component roles intentionally remain unclassified: the production
    /// dashboard has no authored role configuration at this route, so the
    /// fixture proves that full-lift and component evidence remain visible
    /// without inferring clean/jerk roles from display names.
    private static func makeWeightliftingDashboard(using context: ModelContext) throws {
        let fullLiftExercise = try exercise(named: "Clean and Jerk", using: context)
        let snatch = try exercise(named: "Snatch", using: context)
        // The bundled catalogue currently exposes the combined lift and jerk,
        // but not a standalone clean row. Preserve authored component identity
        // without inventing or matching a display-name-only exercise.
        let clean = fullLiftExercise
        let jerk = try exercise(named: "Jerk", using: context)
        let sportRaw = SportDiscipline.olympicWeightlifting.rawValue
        let componentIDs = [clean.id, jerk.id]
        let attempts: [(daysAgo: Int, weight: Float, outcomes: [ComplexComponentOutcome], quality: LiftQuality)] = [
            (14, 90, [.completed, .completed], .excellent),
            (7, 95, [.completed, .partial], .technicallyPoor),
            (2, 85, [.completed, .missed], .missed)
        ]

        let competitionProgram = ProgramDefinitionPayload(
            programKey: "ui-test-olympic-competition",
            name: "Olympic competition preparation",
            goal: .generalStrength,
            experienceLevel: .intermediate,
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            requiredEquipment: [.barbell],
            competitionDisciplineID: "olympicWeightlifting",
            blocks: [
                ProgramBlockDefinition(
                    orderIndex: 0,
                    name: "Competition week",
                    phaseType: .peaking,
                    weeks: [
                        ProgramWeekDefinition(
                            weekIndex: 0,
                            name: "Competition",
                            workouts: [
                                ProgramWorkoutDefinition(
                                    orderIndex: 0,
                                    name: "Competition day",
                                    dayOffset: 0,
                                    role: "test",
                                    plannedExercises: [
                                        ProgramExerciseDefinition(
                                            exerciseID: snatch.id,
                                            exposureKey: "snatch",
                                            role: .main,
                                            orderIndex: 0,
                                            plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(1))]
                                        ),
                                        ProgramExerciseDefinition(
                                            exerciseID: fullLiftExercise.id,
                                            exposureKey: "clean-jerk",
                                            role: .main,
                                            orderIndex: 1,
                                            plannedSets: [
                                                SetPrescriptionDefinition(
                                                    orderIndex: 0,
                                                    repetitions: .sequence([
                                                        RepComponent(exerciseID: clean.id, repetitions: 1),
                                                        RepComponent(exerciseID: jerk.id, repetitions: 1)
                                                    ])
                                                )
                                            ]
                                        )
                                    ]
                                )
                            ]
                        )
                    ]
                )
            ]
        )
        context.insert(try ProgramDefinitionRecord(payload: competitionProgram))

        for (index, attempt) in attempts.enumerated() {
            let snatchEntry = try inProgressEntry(named: snatch.name, orderIndex: 0, using: context)
            snatchEntry.sportDisciplineSnapshotRaw = sportRaw
            snatchEntry.progressionKey = "snatch"
            guard let snatchSet = snatchEntry.orderedSets.first else { throw FixtureError.invalidPlan }
            snatchSet.done = true
            snatchSet.weight = attempt.weight - 15
            snatchSet.repetitions = 1
            snatchSet.liftQuality = attempt.quality
            snatchSet.complexComponents = [
                ComplexComponentResult(
                    orderIndex: 0,
                    exerciseID: snatch.id,
                    exerciseNameSnapshot: snatch.name,
                    prescribedRepetitions: 1,
                    performedRepetitions: attempt.outcomes.allSatisfy { $0 == .completed } ? 1 : 0,
                    outcome: attempt.outcomes.allSatisfy { $0 == .completed } ? .completed : .missed,
                    liftQuality: attempt.quality
                )
            ]

            let cleanAndJerkEntry = try inProgressEntry(named: fullLiftExercise.name, orderIndex: 1, using: context)
            cleanAndJerkEntry.sportDisciplineSnapshotRaw = sportRaw
            cleanAndJerkEntry.progressionKey = "clean-jerk"
            guard let set = cleanAndJerkEntry.orderedSets.first else { throw FixtureError.invalidPlan }
            set.done = true
            set.weight = attempt.weight
            set.repetitions = 2
            set.liftQuality = attempt.quality
            set.complexComponents = attempt.outcomes.enumerated().map { componentIndex, outcome in
                ComplexComponentResult(
                    orderIndex: componentIndex,
                    exerciseID: componentIDs[componentIndex],
                    exerciseNameSnapshot: componentIndex == 0 ? "Clean" : "Jerk",
                    prescribedRepetitions: 1,
                    performedRepetitions: outcome == .completed ? 1 : 0,
                    outcome: outcome,
                    liftQuality: outcome == .completed ? .acceptable : .missed
                )
            }

            let start = Date.now.addingTimeInterval(TimeInterval(-attempt.daysAgo * 86_400))
            let workout = Workout(
                name: "Olympic Evidence \(index + 1)",
                endTime: start.addingTimeInterval(1_200)
            )
            workout.startTime = start
            workout.status = .completed
            workout.exercises = [snatchEntry, cleanAndJerkEntry]
            context.insert(workout)
        }
        try context.save()
    }

    private static func makeExerciseInsightsHistory(using context: ModelContext) throws {
        let olderDate = Date.now.addingTimeInterval(-14 * 86_400)
        let recentDate = Date.now.addingTimeInterval(-3 * 86_400)

        let olderEntry = try completedExerciseEntry(named: "Bench Press", using: context)
        olderEntry.comment = "Paused the last rep and kept the bar path steady."
        for (index, set) in olderEntry.orderedSets.enumerated() {
            set.weight = 45
            set.repetitions = Float(8 + min(index, 1))
        }
        let olderWorkout = Workout(name: "Older Bench Session", endTime: olderDate.addingTimeInterval(3_600))
        olderWorkout.startTime = olderDate
        olderWorkout.exercises = [olderEntry]

        let recentEntry = try completedExerciseEntry(named: "Bench Press", using: context)
        recentEntry.comment = "Add a small amount next time if all sets reach 10 reps."
        for (index, set) in recentEntry.orderedSets.enumerated() {
            set.weight = 50
            set.repetitions = Float(8 - min(index, 1))
        }
        let recentWorkout = Workout(name: "Recent Bench Session", endTime: recentDate.addingTimeInterval(3_600))
        recentWorkout.startTime = recentDate
        recentWorkout.exercises = [recentEntry]

        let benchPress = try exercise(named: "Bench Press", using: context)
        let dumbbellBenchPress = try exercise(named: "Dumbbell Bench Press", using: context)
        context.insert(ExerciseRelationship(
            sourceExercise: benchPress,
            targetExercise: dumbbellBenchPress,
            type: .substitution
        ))

        context.insert(olderWorkout)
        context.insert(recentWorkout)
        try context.save()
    }

    private static func makeMuscleBalanceHistory(using context: ModelContext) throws {
        let previousWorkouts = [-48, -41, -34, -27].map { dayOffset in
            let startTime = Date.now.addingTimeInterval(TimeInterval(dayOffset) * 86_400)
            let workout = Workout(name: "Lower Balance", endTime: startTime.addingTimeInterval(3_600))
            workout.startTime = startTime
            return workout
        }
        for workout in previousWorkouts {
            workout.exercises = [try completedExerciseEntry(named: "Deadlift", using: context)]
        }

        let recentWorkout = Workout(name: "Upper Balance", endTime: Date.now.addingTimeInterval(-14 * 86_400))
        recentWorkout.startTime = Date.now.addingTimeInterval(-15 * 86_400)
        recentWorkout.exercises = [
            try completedExerciseEntry(named: "Bench Press", using: context),
            try completedExerciseEntry(named: "Back Squat", using: context)
        ]

        let latestWorkout = Workout(name: "Upper Balance", endTime: Date.now.addingTimeInterval(-3 * 86_400))
        latestWorkout.startTime = Date.now.addingTimeInterval(-4 * 86_400)
        latestWorkout.exercises = [try completedExerciseEntry(named: "Bench Press", using: context)]

        previousWorkouts.forEach(context.insert)
        context.insert(recentWorkout)
        context.insert(latestWorkout)
        try context.save()
    }

    private static func makeProgressionWorkout(
        decision: DoubleProgressionDecision?,
        using context: ModelContext
    ) throws {
        try makeCompletedBenchHistory(using: context)
        let entry = try progressionEntry(named: "Bench Press", decision: decision, orderIndex: 0, using: context)
        try makeActiveWorkout(exercises: [entry], using: context)
    }

    private static func makeProgressionAndRestWorkout(
        restState: RestState,
        using context: ModelContext
    ) throws {
        try makeCompletedBenchHistory(using: context)
        let completed = try completedSetEntry(named: "Barbell Row", orderIndex: 0, using: context)
        let recommended = try progressionEntry(named: "Bench Press", decision: .increase, orderIndex: 1, using: context)
        let workout = Workout(name: "Upper Body Progression")
        workout.startTime = Date.now.addingTimeInterval(-47)
        workout.exercises = [completed, recommended]

        switch restState {
        case .running:
            workout.restEndDate = Date.now.addingTimeInterval(45)
        case .paused:
            workout.pausedRemainingTime = 45
        case .ready:
            workout.restEndDate = Date.now.addingTimeInterval(-1)
        }

        context.insert(workout)
        try context.save()
    }

    private static func makePerformanceComparisonWorkout(using context: ModelContext) throws {
        try makeCompletedBenchHistory(using: context)
        let entry = try progressionEntry(named: "Bench Press", decision: .increase, orderIndex: 0, using: context)
        for set in entry.orderedSets {
            set.done = true
            set.repetitions = 8
            set.weight = 52.5
        }
        try makeActiveWorkout(exercises: [entry], using: context)
    }

    private static func makePerformanceComparisonHistory(using context: ModelContext) throws {
        try makeCompletedBenchHistory(using: context)
        let entry = try progressionEntry(named: "Bench Press", decision: .increase, orderIndex: 0, using: context)
        for set in entry.orderedSets {
            set.done = true
            set.repetitions = 8
            set.weight = 52.5
        }

        let workout = Workout(name: "Upper Body", endTime: Date.now.addingTimeInterval(-900))
        workout.startTime = Date.now.addingTimeInterval(-2_700)
        workout.exercises = [entry]
        context.insert(workout)
        try context.save()
    }

    private static func makeActivePlanRun(using context: ModelContext) throws {
        let template = try workoutTemplate(named: "Day 1 – Lower Body (Squat Focus)", using: context)
        let plan = PlanCoordinator.createRepeatedPlan(
            name: "Screenshot Plan Run",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            template: template,
            dayOffsets: [0]
        )
        context.insert(plan)
        guard let run = PlanCoordinator.startRun(for: plan) else {
            throw FixtureError.invalidPlan
        }
        context.insert(run)
        try context.save()
    }

    private static func makeTrainingCalendarFixture(using context: ModelContext) throws {
        let plan = WorkoutPlan(name: "Calendar Strength", daysPerWeek: 2, durationWeeks: 1)
        let run = PlanRun(plan: plan)
        let today = Calendar.current.startOfDay(for: .now)
        let ready = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Today Strength",
            weekIndex: 0,
            workoutIndex: 0,
            scheduledDate: today
        )
        ready.status = .available
        let completed = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Completed Strength",
            weekIndex: 0,
            workoutIndex: 1,
            scheduledDate: today
        )
        completed.status = .completed
        completed.completedAt = Date.now.addingTimeInterval(-3_600)
        let completedWorkout = Workout(name: "Completed Strength", endTime: Date.now.addingTimeInterval(-3_600))
        completedWorkout.startTime = Date.now.addingTimeInterval(-7_200)
        completed.completedWorkout = completedWorkout
        run.workoutProgress = [ready, completed]
        plan.runs = [run]

        // Keep this completed workout on the selected local day even when the
        // fixture launches shortly after midnight. Subtracting a fixed offset
        // from `Date.now` made the row belong to yesterday for the first
        // 45 minutes of each day, so the Today agenda correctly omitted it.
        let fixtureNow = Date.now
        let freeWorkout = Workout(name: "Accessory Work", endTime: fixtureNow)
        freeWorkout.startTime = max(today, fixtureNow.addingTimeInterval(-900))
        let midday = Calendar.current.date(
            bySettingHour: 12,
            minute: 0,
            second: 0,
            of: today
        ) ?? today
        let mobility = MobilitySession(nameSnapshot: "Hip Mobility", startTime: midday)
        mobility.status = .completed
        let meal = LoggedMeal(day: .today, nameSnapshot: "Calendar Lunch")
        meal.items = [LoggedMealItem(
            sourceFoodID: nil,
            foodNameSnapshot: "Chicken and rice",
            servingNameSnapshot: "Bowl",
            quantity: 1,
            portionAmountSnapshot: 1,
            portionUnit: .serving,
            caloriesSnapshot: 720,
            proteinGramsSnapshot: 52,
            carbohydrateGramsSnapshot: 78,
            fatGramsSnapshot: 18,
            sourceKind: .userCreated,
            confidence: .userProvided,
            preparationState: .cooked,
            orderIndex: 0
        )]
        let checkIn = DailyLogEntry(day: .today, status: .completed, sleepQuality: 4, energy: 4)
        let creatine = SupplementOccurrence(kind: .creatine, day: .today, status: .completed)

        context.insert(plan)
        context.insert(run)
        context.insert(completedWorkout)
        context.insert(freeWorkout)
        context.insert(mobility)
        context.insert(meal)
        context.insert(checkIn)
        context.insert(creatine)
        try context.save()
    }

    private static func makePlanCalendarRun(using context: ModelContext) throws {
        let template = try workoutTemplate(named: "Day 1 – Lower Body (Squat Focus)", using: context)
        let plan = PlanCoordinator.createRepeatedPlan(
            name: "Calendar Fixture Plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 3,
            template: template,
            dayOffsets: [0, 3]
        )
        context.insert(plan)

        let startDate = Calendar.current.date(byAdding: .day, value: -10, to: .now) ?? .now
        guard let run = PlanCoordinator.startRun(for: plan, startDate: startDate) else {
            throw FixtureError.invalidPlan
        }

        // This fixture intentionally sets states after run creation so the
        // agenda can show every display outcome together. A normal run always
        // promotes the earliest unfinished session instead.
        let progress = run.orderedWorkoutProgress
        guard progress.count == 6 else { throw FixtureError.invalidPlan }
        progress[0].status = .completed
        progress[1].status = .skipped
        progress[2].status = .upcoming
        progress[3].status = .inProgress
        progress[4].status = .available
        progress[5].status = .upcoming

        context.insert(run)
        try context.save()
    }

    /// A deliberately complete Program Path graph. It keeps every session's
    /// authored order while exposing the calendar lifecycle states a path needs
    /// to render: completed, skipped, derived-missed, in-progress, available,
    /// rescheduled, upcoming, and unscheduled. The final block is an authored
    /// deload so the UI never needs to infer a phase from a workout name.
    private static func makeProgramPathFixed(using context: ModelContext) throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }

        let foundationWeek = PlanWeek(
            weekIndex: 0,
            name: "Foundation",
            plannedWorkouts: [
                PlannedWorkout(name: "Path Squat Strength", orderIndex: 0, dayOffset: 0),
                PlannedWorkout(name: "Path Bench Volume", orderIndex: 1, dayOffset: 3)
            ]
        )
        let buildWeek = PlanWeek(
            weekIndex: 1,
            name: "Build",
            plannedWorkouts: [
                PlannedWorkout(name: "Path Deadlift Strength", orderIndex: 0, dayOffset: 0),
                PlannedWorkout(name: "Path Row Accessory", orderIndex: 1, dayOffset: 3)
            ]
        )
        let peakWeek = PlanWeek(
            weekIndex: 2,
            name: "Peak",
            plannedWorkouts: [
                PlannedWorkout(name: "Path Press Strength", orderIndex: 0, dayOffset: 0),
                PlannedWorkout(name: "Path Pull Volume", orderIndex: 1, dayOffset: 3)
            ]
        )
        let deloadWeek = PlanWeek(
            weekIndex: 3,
            name: "Deload",
            plannedWorkouts: [
                PlannedWorkout(name: "Path Deload Lower", orderIndex: 0, dayOffset: 0),
                PlannedWorkout(name: "Path Deload Upper", orderIndex: 1, dayOffset: 3)
            ]
        )
        let plan = WorkoutPlan(
            name: "Program Path Fixed Fixture",
            goal: .generalStrength,
            experienceLevel: .intermediate,
            daysPerWeek: 2,
            durationWeeks: 4,
            blocks: [
                PlanBlock(name: "Foundation", phaseType: .accumulation, orderIndex: 0, weeks: [foundationWeek]),
                PlanBlock(name: "Build", phaseType: .strength, orderIndex: 1, weeks: [buildWeek]),
                PlanBlock(name: "Peak", phaseType: .peaking, orderIndex: 2, weeks: [peakWeek]),
                PlanBlock(
                    name: "Planned Deload",
                    phaseType: .deload,
                    orderIndex: 3,
                    deloadVolumeReductionPercent: 50,
                    deloadIntensityReductionPercent: 10,
                    weeks: [deloadWeek]
                )
            ]
        )
        let run = PlanRun(plan: plan, startDate: day(-21))
        let plannedWorkouts = plan.orderedWeeks.flatMap(\.orderedPlannedWorkouts)
        guard plannedWorkouts.count == 8 else { throw FixtureError.invalidPlan }

        let completedWorkout = Workout(name: "Path Squat Strength", endTime: day(-20).addingTimeInterval(3_600))
        completedWorkout.startTime = day(-20).addingTimeInterval(900)
        let progress = [
            PlanWorkoutProgress(
                plannedWorkoutID: plannedWorkouts[0].id,
                plannedWorkoutName: plannedWorkouts[0].name,
                weekIndex: 0,
                sourceWeekIndex: 0,
                workoutIndex: 0,
                scheduledDate: day(-21)
            ),
            PlanWorkoutProgress(
                plannedWorkoutID: plannedWorkouts[1].id,
                plannedWorkoutName: plannedWorkouts[1].name,
                weekIndex: 0,
                sourceWeekIndex: 0,
                workoutIndex: 1,
                scheduledDate: day(-18)
            ),
            PlanWorkoutProgress(
                plannedWorkoutID: plannedWorkouts[2].id,
                plannedWorkoutName: plannedWorkouts[2].name,
                weekIndex: 1,
                sourceWeekIndex: 1,
                workoutIndex: 0,
                scheduledDate: day(-4)
            ),
            PlanWorkoutProgress(
                plannedWorkoutID: plannedWorkouts[3].id,
                plannedWorkoutName: plannedWorkouts[3].name,
                weekIndex: 1,
                sourceWeekIndex: 1,
                workoutIndex: 1,
                scheduledDate: day(-1)
            ),
            PlanWorkoutProgress(
                plannedWorkoutID: plannedWorkouts[4].id,
                plannedWorkoutName: plannedWorkouts[4].name,
                weekIndex: 2,
                sourceWeekIndex: 2,
                workoutIndex: 0,
                scheduledDate: day(4)
            ),
            PlanWorkoutProgress(
                plannedWorkoutID: plannedWorkouts[5].id,
                plannedWorkoutName: plannedWorkouts[5].name,
                weekIndex: 2,
                sourceWeekIndex: 2,
                workoutIndex: 1,
                scheduledDate: nil
            ),
            PlanWorkoutProgress(
                plannedWorkoutID: plannedWorkouts[6].id,
                plannedWorkoutName: plannedWorkouts[6].name,
                weekIndex: 3,
                sourceWeekIndex: 3,
                workoutIndex: 0,
                scheduledDate: day(7)
            ),
            PlanWorkoutProgress(
                plannedWorkoutID: plannedWorkouts[7].id,
                plannedWorkoutName: plannedWorkouts[7].name,
                weekIndex: 3,
                sourceWeekIndex: 3,
                workoutIndex: 1,
                scheduledDate: day(10)
            )
        ]

        progress[0].status = .completed
        progress[0].completedAt = completedWorkout.endTime
        progress[0].completedWorkout = completedWorkout
        progress[1].status = .skipped
        // `.upcoming` on a past local day is the intentionally derived missed
        // state. It is not persisted as a distinct lifecycle value.
        progress[2].status = .upcoming
        progress[3].status = .inProgress
        progress[3].startedAt = Date.now.addingTimeInterval(-1_800)
        progress[4].status = .available
        progress[4].originalScheduledDate = day(1)
        progress[4].lastRescheduledAt = Date.now.addingTimeInterval(-600)
        progress[5].status = .upcoming
        progress[6].status = .upcoming
        progress[7].status = .upcoming

        run.currentWeekIndex = 1
        run.currentWorkoutIndex = 1
        run.workoutProgress = progress
        plan.runs = [run]

        context.insert(plan)
        context.insert(run)
        context.insert(completedWorkout)
        try context.save()
    }

    /// A rotation history with the distinct persisted events Program Path must
    /// explain: expected completion, alternate/keep-expected, repeat,
    /// alternate/continue-after-selected, skip, and undo. The current cursor
    /// is deliberately in the middle of the third cycle, so the view can show
    /// history beside an actionable next slot without inventing a finite total.
    private static func makeProgramPathRotation(using context: ModelContext) throws {
        let benchPress = try exercise(named: "Bench Press", using: context)
        let backSquat = try exercise(named: "Back Squat", using: context)
        let barbellRow = try exercise(named: "Barbell Row", using: context)
        let bench = WorkoutTemplate(name: "Path Rotation Bench", exercises: [benchPress])
        let squat = WorkoutTemplate(name: "Path Rotation Squat", exercises: [backSquat])
        let row = WorkoutTemplate(name: "Path Rotation Row", exercises: [barbellRow])
        context.insert(bench)
        context.insert(squat)
        context.insert(row)

        let plan = RepeatingPlan(
            name: "Program Path Rotation Fixture",
            goal: .generalStrength,
            experienceLevel: .intermediate,
            notes: "Deterministic occurrence history for Program Path presentation.",
            slots: [
                RepeatingPlanSlot(orderIndex: 0, workoutTemplate: bench),
                RepeatingPlanSlot(orderIndex: 1, workoutTemplate: squat),
                RepeatingPlanSlot(orderIndex: 2, workoutTemplate: row)
            ]
        )
        let run = RepeatingPlanRun(plan: plan, startedAt: Date.now.addingTimeInterval(-30 * 86_400))
        run.currentSlotIndex = 1
        run.completedCycleCount = 2
        run.updatedAt = .now

        func completedWorkout(named name: String, hoursAgo: TimeInterval) -> Workout {
            let end = Date.now.addingTimeInterval(-hoursAgo * 3_600)
            let workout = Workout(name: name, endTime: end)
            workout.startTime = end.addingTimeInterval(-3_600)
            return workout
        }

        let expectedWorkout = completedWorkout(named: "Path Rotation Bench", hoursAgo: 144)
        let alternateKeepExpectedWorkout = completedWorkout(named: "Path Rotation Row", hoursAgo: 132)
        let repeatedWorkout = completedWorkout(named: "Path Rotation Row", hoursAgo: 120)
        let alternateContinueWorkout = completedWorkout(named: "Path Rotation Row", hoursAgo: 96)
        let currentCycleWorkout = completedWorkout(named: "Path Rotation Bench", hoursAgo: 24)
        let occurrences = [
            RepeatingPlanOccurrence(
                cycleIndex: 0,
                expectedSlotIndex: 0,
                selectedSlotIndex: 0,
                kind: .expected,
                status: .completed,
                cursorBefore: 0,
                cursorAfter: 1,
                cycleBefore: 0,
                cycleAfter: 0,
                createdAt: Date.now.addingTimeInterval(-144 * 3_600),
                completedAt: expectedWorkout.endTime,
                completedWorkout: expectedWorkout
            ),
            RepeatingPlanOccurrence(
                cycleIndex: 0,
                expectedSlotIndex: 1,
                selectedSlotIndex: 2,
                kind: .alternate,
                continuationMode: .keepExpected,
                status: .completed,
                cursorBefore: 1,
                cursorAfter: 1,
                cycleBefore: 0,
                cycleAfter: 0,
                createdAt: Date.now.addingTimeInterval(-132 * 3_600),
                completedAt: alternateKeepExpectedWorkout.endTime,
                completedWorkout: alternateKeepExpectedWorkout
            ),
            RepeatingPlanOccurrence(
                cycleIndex: 0,
                expectedSlotIndex: 1,
                selectedSlotIndex: 2,
                kind: .repeatWorkout,
                continuationMode: .keepExpected,
                status: .completed,
                cursorBefore: 1,
                cursorAfter: 1,
                cycleBefore: 0,
                cycleAfter: 0,
                createdAt: Date.now.addingTimeInterval(-120 * 3_600),
                completedAt: repeatedWorkout.endTime,
                completedWorkout: repeatedWorkout
            ),
            RepeatingPlanOccurrence(
                cycleIndex: 0,
                expectedSlotIndex: 1,
                kind: .skip,
                status: .skipped,
                cursorBefore: 1,
                cursorAfter: 2,
                cycleBefore: 0,
                cycleAfter: 0,
                createdAt: Date.now.addingTimeInterval(-108 * 3_600),
                completedAt: Date.now.addingTimeInterval(-108 * 3_600)
            ),
            RepeatingPlanOccurrence(
                cycleIndex: 0,
                expectedSlotIndex: 2,
                selectedSlotIndex: 2,
                kind: .expected,
                status: .completed,
                cursorBefore: 2,
                cursorAfter: 0,
                cycleBefore: 0,
                cycleAfter: 1,
                createdAt: Date.now.addingTimeInterval(-102 * 3_600),
                completedAt: Date.now.addingTimeInterval(-102 * 3_600)
            ),
            RepeatingPlanOccurrence(
                cycleIndex: 1,
                expectedSlotIndex: 0,
                selectedSlotIndex: 2,
                kind: .alternate,
                continuationMode: .continueAfterSelected,
                status: .completed,
                cursorBefore: 0,
                cursorAfter: 0,
                cycleBefore: 1,
                cycleAfter: 2,
                createdAt: Date.now.addingTimeInterval(-96 * 3_600),
                completedAt: alternateContinueWorkout.endTime,
                completedWorkout: alternateContinueWorkout
            ),
            RepeatingPlanOccurrence(
                cycleIndex: 2,
                expectedSlotIndex: 0,
                selectedSlotIndex: 0,
                kind: .expected,
                status: .completed,
                cursorBefore: 0,
                cursorAfter: 1,
                cycleBefore: 2,
                cycleAfter: 2,
                createdAt: Date.now.addingTimeInterval(-24 * 3_600),
                completedAt: currentCycleWorkout.endTime,
                completedWorkout: currentCycleWorkout
            ),
            RepeatingPlanOccurrence(
                cycleIndex: 2,
                expectedSlotIndex: 1,
                selectedSlotIndex: 0,
                kind: .alternate,
                continuationMode: .keepExpected,
                status: .undone,
                cursorBefore: 1,
                cursorAfter: 1,
                cycleBefore: 2,
                cycleAfter: 2,
                createdAt: Date.now.addingTimeInterval(-12 * 3_600),
                undoneAt: Date.now.addingTimeInterval(-11 * 3_600)
            )
        ]

        run.occurrences = occurrences
        plan.runs = [run]
        context.insert(plan)
        context.insert(run)
        [expectedWorkout, alternateKeepExpectedWorkout, repeatedWorkout, alternateContinueWorkout, currentCycleWorkout]
            .forEach { context.insert($0) }
        try context.save()
    }

    private static func makePlanRelaunchSchedule(using context: ModelContext) throws {
        let template = try workoutTemplate(named: "Day 1 – Lower Body (Squat Focus)", using: context)
        let plan = PlanCoordinator.createRepeatedPlan(
            name: "Relaunch Schedule Plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            template: template,
            dayOffsets: [0, 2]
        )
        let plannedWorkouts = plan.orderedWeeks.flatMap(\.orderedPlannedWorkouts)
        guard plannedWorkouts.count == 2 else { throw FixtureError.invalidPlan }
        plannedWorkouts[0].name = "Tomorrow Fixture Workout"
        plannedWorkouts[1].name = "Today Fixture Workout"
        context.insert(plan)

        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)
        guard let tomorrow else { throw FixtureError.invalidPlan }
        guard let run = PlanCoordinator.startRun(for: plan, startDate: today) else {
            throw FixtureError.invalidPlan
        }
        let progress = run.orderedWorkoutProgress
        guard progress.count == 2 else { throw FixtureError.invalidPlan }

        // Persist a deliberately stale availability assignment. A normal app
        // launch must recompute this and promote today's session.
        progress[0].scheduledDate = tomorrow
        progress[0].status = .available
        progress[1].scheduledDate = today
        progress[1].status = .upcoming

        context.insert(run)
        try context.save()
    }

    private static func makePartialPlannedWorkout(using context: ModelContext) throws {
        let template = try workoutTemplate(named: "Day 1 – Lower Body (Squat Focus)", using: context)
        let plan = PlanCoordinator.createRepeatedPlan(
            name: "Integration Fixture Plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            template: template,
            dayOffsets: [0, 2]
        )

        // Give the two sessions stable, distinguishable titles for UI assertions.
        let plannedWorkouts = plan.orderedWeeks.flatMap(\.orderedPlannedWorkouts)
        plannedWorkouts.first?.name = "Fixture Day 1"
        plannedWorkouts.dropFirst().first?.name = "Fixture Day 2"

        context.insert(plan)
        guard
            let run = PlanCoordinator.startRun(for: plan),
            let progress = run.orderedWorkoutProgress.first,
            let plannedWorkout = PlanCoordinator.plannedWorkout(for: progress, in: run)
        else {
            throw FixtureError.invalidPlan
        }

        let workout = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .metric)
        workout.startTime = Date.now.addingTimeInterval(-47)
        progress.status = .inProgress
        progress.startedAt = workout.startTime

        // One completed set is enough for a valid partial save. All remaining
        // sets and exercises stay incomplete so the Review warning and pruning
        // behavior are exercised in one deterministic journey.
        if let firstExercise = workout.orderedExercises.first,
           let firstSet = firstExercise.orderedSets.first {
            firstSet.repetitions = 8
            firstSet.weight = 50
            firstSet.done = true
        }

        context.insert(run)
        context.insert(workout)
        try context.save()
    }

    private static func makeBackupImportTarget(using context: ModelContext) throws {
        let exercise = Exercise(
            name: "Sentinel Exercise",
            primaryMuscles: [.upperChest],
            equipmentType: .dumbbell,
            resistanceType: .externalWeight,
            movementPattern: .horizontalPush,
            isCustom: true
        )
        context.insert(exercise)

        let entry = ExerciseEntry(from: exercise, orderIndex: 0, usedMetric: .metric)
        if let set = entry.orderedSets.first {
            set.repetitions = 8
            set.weight = 25
            set.done = true
        }
        let workout = Workout(name: "Sentinel Workout", endTime: Date.now.addingTimeInterval(-300))
        workout.startTime = Date.now.addingTimeInterval(-900)
        workout.exercises = [entry]
        context.insert(workout)
        try context.save()
    }

    private static func inProgressEntry(
        named name: String,
        orderIndex: Int = 0,
        using context: ModelContext
    ) throws -> ExerciseEntry {
        let entry = ExerciseEntry(from: try exercise(named: name, using: context), orderIndex: orderIndex, usedMetric: .metric)
        for set in entry.orderedSets {
            set.repetitions = 8
            set.weight = 50
            set.weightType = .kg
        }
        return entry
    }

    private static func completedSetEntry(
        named name: String,
        orderIndex: Int = 0,
        using context: ModelContext
    ) throws -> ExerciseEntry {
        let entry = try inProgressEntry(named: name, orderIndex: orderIndex, using: context)
        if let first = entry.orderedSets.first {
            first.done = true
            first.rpe = 8
        }
        return entry
    }

    private static func completedExerciseEntry(
        named name: String,
        orderIndex: Int = 0,
        using context: ModelContext
    ) throws -> ExerciseEntry {
        let entry = try inProgressEntry(named: name, orderIndex: orderIndex, using: context)
        for set in entry.orderedSets {
            set.done = true
            set.rpe = 8
        }
        return entry
    }

    private static func progressionEntry(
        named name: String,
        decision: DoubleProgressionDecision?,
        orderIndex: Int,
        using context: ModelContext
    ) throws -> ExerciseEntry {
        let entry = try inProgressEntry(named: name, orderIndex: orderIndex, using: context)
        entry.prescribedSets = 3
        entry.prescribedRepRangeMinimum = 6
        entry.prescribedRepRangeMaximum = 8
        entry.prescribedProgressionRule = .doubleProgression

        if let decision {
            entry.recommendedDecision = decision
            entry.recommendedLoad = decision == .increase ? 52.5 : 50
            entry.recommendedUnit = .kg
            entry.recommendationPriorLoad = 50
            entry.recommendationRequiredSets = 3
            entry.recommendationRepCeiling = 8
            entry.recommendationCompletedSets = decision == .increase ? 3 : 2
            entry.recommendationPriorWorkoutDate = Date.now.addingTimeInterval(-86_400)
        }
        return entry
    }

    /// Active strength draft plus an in-progress mid-session mobility stage so
    /// the unified Active Workout cover can capture `duringWorkout` chrome
    /// without driving the Add → start path in the screenshot lane.
    private static func makeMidWorkoutMobilityFixture(using context: ModelContext) throws {
        let entry = try inProgressEntry(named: "Bench Press", using: context)
        try makeActiveWorkout(exercises: [entry], using: context)
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        guard let workout = workouts.first(where: { $0.endTime == nil }) else {
            throw FixtureError.invalidPlan
        }
        // Prefer a single catalogue movement so the stage chrome reads MOVEMENT,
        // matching the primary Add-mobility path (not a multi-item routine).
        let definitions = try context.fetch(FetchDescriptor<MobilityDefinition>())
            .filter { $0.isArchived == false }
            .sorted { $0.name < $1.name }
        guard let definition = definitions.first else { throw FixtureError.invalidPlan }
        guard MobilitySessionService.start(
            definition: definition,
            context: .duringWorkout,
            workoutID: workout.id,
            using: context
        ) != nil else {
            throw FixtureError.invalidPlan
        }
    }

    /// A template carrying both mobility links, so the two `RootView`-owned
    /// confirmation dialogs — "Optional preparation" on start and "Add a
    /// cooldown?" after save — are reachable from one start-and-save pass.
    /// Nothing in the seeded catalogue links a routine to a template, so
    /// neither dialog can be captured without this.
    private static func makeLinkedMobilityWorkoutFixture(using context: ModelContext) throws {
        let routines = try context.fetch(FetchDescriptor<MobilityRoutine>())
            .sorted { $0.name < $1.name }
        guard let warmup = routines.first else { throw FixtureError.invalidPlan }
        let benchPress = try exercise(named: "Bench Press", using: context)
        let template = WorkoutTemplate(
            name: "Linked Mobility Screenshot",
            exercises: [benchPress],
            preWorkoutMobilityRoutine: warmup,
            postWorkoutMobilityRoutine: routines.dropFirst().first ?? warmup
        )
        context.insert(template)
        try context.save()
    }

    private static func exercise(named name: String, using context: ModelContext) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        guard let exercise = try context.fetch(descriptor).first else {
            throw FixtureError.missingSeededExercise(name)
        }
        return exercise
    }

    private static func workoutTemplate(named name: String, using context: ModelContext) throws -> WorkoutTemplate {
        let descriptor = FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.name == name })
        guard let template = try context.fetch(descriptor).first else {
            throw FixtureError.missingSeededWorkoutTemplate(name)
        }
        return template
    }

    private enum FixtureError: LocalizedError {
        case missingSeededExercise(String)
        case missingSeededWorkoutTemplate(String)
        case invalidPlan

        var errorDescription: String? {
            switch self {
            case let .missingSeededExercise(name):
                return "UI-test fixture requires seeded exercise: \(name)"
            case let .missingSeededWorkoutTemplate(name):
                return "UI-test fixture requires seeded workout template: \(name)"
            case .invalidPlan:
                return "UI-test fixture could not start its seeded plan run."
            }
        }
    }
}
