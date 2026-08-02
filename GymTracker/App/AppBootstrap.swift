import Foundation
import SwiftData

/// The launch-time work that has nothing to do with what is on screen: store
/// reset, orphan cleanup, catalogue seeding, one-time normalization, plan-run
/// availability, and UI-test fixture application. `RootView` owned all of it
/// inline, which is a large part of why that file cannot be read in one sitting.
///
/// Everything here takes a `ModelContext` and returns a value. Nothing here
/// touches view state or the view model. Restoring the active workout in
/// particular stays with the caller: a fixture writes the persisted graph, but
/// the view model owns what is loaded out of it, and collapsing those two would
/// give this type a second job.
@MainActor
enum AppBootstrap {
    /// What a UI-test fixture asked to be true before the first frame. A
    /// fixture is the only kind of launch permitted to open a screen this way.
    struct FixtureOutcome {
        var opensActiveWorkout = false
        var showsActiveWorkoutConflict = false
        var progressionReceipt: ProgressionReceipt?
    }

    struct ProgressionReceipt {
        let planRunID: UUID
        let workoutID: UUID
    }

    /// Clears everything a UI-test launch must not inherit from the previous
    /// run. Only the persisted half: the caller still owns resetting view state
    /// and the view model, so a launch that never resets cannot be reached by
    /// this at all.
    static func resetPersistedDataForUITesting(using context: ModelContext) {
        UserDefaults.standard.set(true, forKey: DefaultsKey.useMetric)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.appearance)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.darkMode)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.lastBackupExportTimestamp)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.lastBackupRestoreTimestamp)
        // Onboarding state is preference-shaped, so clearing the store alone
        // would leave a previous run's half-answered draft behind — and the
        // welcome screenshot lane would open on question four instead of the
        // routing choice it exists to capture.
        UserDefaults.standard.removeObject(forKey: DefaultsKey.onboardingDraft)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.hasDeclinedPersonalization)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.personalizationPromptDeferralCount)

        do {
            try context.clearAllGymData()
        } catch {
            print("Failed to reset UI test data: \(error)")
        }
    }

    static func runDataMaintenance(using context: ModelContext) {
        do {
            _ = try DataMaintenanceService.runOrphanCleanupIfNeeded(using: context)
        } catch {
            print("Failed to clean orphaned workout data: \(error)")
        }
    }

    static func seedSystemCatalog(using context: ModelContext) {
        do {
            guard try SystemSeedCatalogCoordinator.needsInstallation(in: context) else { return }
            _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)
        } catch {
            print("Failed to install bundled system catalogue: \(error)")
        }
    }

    /// Backfills stored shapes that predate the fields they depend on. Guarded
    /// by a version stored in defaults, so it runs at most once per install
    /// generation rather than on every cold launch.
    static func normalizePersistedWorkoutData(using context: ModelContext) {
        let normalizationVersion = 1
        guard UserDefaults.standard.integer(forKey: DefaultsKey.workoutNormalizationVersion) < normalizationVersion else {
            return
        }
        do {
            var didChange = false

            let workouts = try context.fetch(FetchDescriptor<Workout>())
            for workout in workouts {
                let expectedStatus: WorkoutStatus = workout.endTime == nil ? .active : .completed
                if workout.status != expectedStatus {
                    workout.status = expectedStatus
                    didChange = true
                }

                let workoutExercises = workout.exercises
                let hasStableExerciseOrder = Set(workoutExercises.map(\.orderIndex)).count == workoutExercises.count
                let orderedExercises = hasStableExerciseOrder ? workout.orderedExercises : workoutExercises
                for (exerciseIndex, exercise) in orderedExercises.enumerated() {
                    if exercise.orderIndex != exerciseIndex {
                        exercise.orderIndex = exerciseIndex
                        didChange = true
                    }
                    // Rows persisted before `exerciseIDSnapshot` existed derive
                    // it once from their still-live relationship. Later renames
                    // or archival must never overwrite it again.
                    if exercise.exerciseIDSnapshot == nil {
                        exercise.exerciseIDSnapshot = exercise.exercise.id
                        didChange = true
                    }
                    let exerciseSets = exercise.sets
                    let hasStableSetOrder = Set(exerciseSets.map(\.orderIndex)).count == exerciseSets.count
                    let orderedSets = hasStableSetOrder ? exercise.orderedSets : exerciseSets
                    for (setIndex, set) in orderedSets.enumerated() where set.orderIndex != setIndex {
                        set.orderIndex = setIndex
                        didChange = true
                    }
                }
            }

            if didChange {
                try context.save()
            }
            UserDefaults.standard.set(normalizationVersion, forKey: DefaultsKey.workoutNormalizationVersion)
        } catch {
            context.rollback()
            print("Failed to normalize persisted workout data: \(error)")
        }
    }

    /// Re-evaluates active run availability after a cold launch. A session can
    /// be rescheduled while the app is not running, so persisted `.available`
    /// flags must not outrank a newly due session after relaunch.
    static func refreshActivePlanRuns(using context: ModelContext) {
        do {
            let runs = try context.fetch(FetchDescriptor<PlanRun>())
                .filter { $0.status == .active }
            runs.forEach { PlanCoordinator.refreshAvailability(for: $0) }
            try context.save()
        } catch {
            context.rollback()
            print("Failed to refresh plan-run availability: \(error)")
        }
    }

    /// Builds the backup payload the Settings import test imports. It has to be
    /// encoded from a real store, so it cannot be a static file in the bundle.
    static func prepareUITestImportPayloadIfNeeded(
        arguments: [String] = CommandLine.arguments,
        using context: ModelContext
    ) {
        guard arguments.contains("-ui-testing-import-valid") else { return }
        do {
            let backup = try BackupDTO.create(
                from: context,
                restTimer: 120,
                darkMode: true,
                unitSystem: .imperial
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            UITestFixture.UITestImportPayload.validData = try encoder.encode(backup)
        } catch {
            print("Failed to prepare valid UI-test import payload: \(error)")
        }
    }

    /// Writes a fixture's persisted graph and reports what it wants open. A
    /// fixture that throws leaves an empty outcome rather than a half-applied
    /// one: opening a screen against a graph that failed to build produces a
    /// screenshot of the wrong thing, which is worse than not opening it.
    static func applyFixture(_ fixture: UITestFixture, using context: ModelContext) -> FixtureOutcome {
        do {
            try UITestFixture.apply(fixture, using: context)
        } catch {
            print("Failed to prepare UI-test fixture '\(fixture.rawValue)': \(error)")
            return FixtureOutcome()
        }

        var outcome = FixtureOutcome(
            opensActiveWorkout: fixture.opensActiveWorkout,
            showsActiveWorkoutConflict: fixture.showsActiveWorkoutConflict
        )
        if fixture == .progressionReceipt,
           let record = try? context.fetch(FetchDescriptor<PlanProgressionRecommendationRecord>())
            .first(where: { !$0.isResolved }) {
            outcome.progressionReceipt = ProgressionReceipt(
                planRunID: record.planRunID,
                workoutID: record.workoutID
            )
        }
        return outcome
    }
}

/// Where a UI-test launch argument asks the app to open, as a value rather than
/// a run of assignments buried inside `prepareApp`. Splitting it in two matters:
/// tab selection must land before the store work so a slow seed cannot flash
/// the wrong tab, while anything naming a specific record has to wait until the
/// catalogue and fixture graph exist.
///
/// Taking `arguments` explicitly rather than reading `CommandLine` inline is
/// what makes this testable without launching an app.
@MainActor
enum UITestLaunch {
    struct Destination {
        var tab: AppTab?
        var todayPath: [TodayRoute]?
        var trainPath: [LibraryRoute]?
        var progressPath: [ProgressRoute]?
        var guidedSourceError: String?
        var mobilityLinkError: String?
        var planNotification: PlanNotificationDestination?
    }

    /// True when the launch is asking for a clean store — either explicitly or
    /// by naming a fixture, since a fixture graph is only valid on an empty one.
    static func isResettingData(
        arguments: [String] = CommandLine.arguments,
        fixture: UITestFixture?
    ) -> Bool {
        arguments.contains("-reset-data") || fixture != nil
    }

    /// Keeps the completed brand frame visible for deterministic visual
    /// verification. It has no effect outside a launch that explicitly names
    /// the capture-only argument.
    static func holdsLaunchExperience(arguments: [String] = CommandLine.arguments) -> Bool {
        arguments.contains("-ui-testing-hold-launch-experience")
    }

    /// Tab and path arguments that need no seeded data.
    static func initialDestination(arguments: [String] = CommandLine.arguments) -> Destination {
        var destination = Destination()
        if arguments.contains("-ui-testing-open-history") {
            destination.tab = .progress
            destination.progressPath = [.workoutHistory]
        }
        if arguments.contains("-ui-testing-open-library") {
            destination.tab = .train
        }
        if arguments.contains("-ui-testing-open-settings") {
            destination.tab = .today
            destination.todayPath = [.settings]
        }
        return destination
    }

    /// Destinations and alert states that need the seeded catalogue or the
    /// fixture graph to already exist.
    static func seededDestination(
        arguments: [String] = CommandLine.arguments,
        using context: ModelContext
    ) -> Destination {
        var destination = Destination()

        if arguments.contains("-ui-testing-open-exercise-detail") {
            let descriptor = FetchDescriptor<Exercise>(
                predicate: #Predicate { $0.name == "Bench Press" }
            )
            if let benchPress = try? context.fetch(descriptor).first {
                destination.tab = .train
                destination.trainPath = [.exercise(benchPress.id)]
            }
        }

        // A route whose id resolves to nothing, so the "may have been removed
        // or replaced" fallback can be captured once. All seven such routes
        // render the same `ContentUnavailableView` shape; this is the cheapest
        // of them to reach.
        if arguments.contains("-ui-testing-open-missing-route") {
            destination.tab = .train
            destination.trainPath = [.exercise(UUID())]
        }

        // These two alerts are raised from failure branches a UI test cannot
        // provoke — a plan that will not start, a routine deleted between link
        // and launch. Naming the state directly captures the alert without
        // faking the failure that would produce it.
        if arguments.contains("-ui-testing-guided-source-error") {
            destination.guidedSourceError = String(localized: "The workout could not be started. Check the selected plan or rotation and try again.")
        }
        if arguments.contains("-ui-testing-mobility-link-error") {
            destination.mobilityLinkError = String(localized: "This workout's linked routine is no longer available. It may have been deleted.")
        }

        if arguments.contains("-ui-testing-open-plan-reminder-reschedule") {
            destination.planNotification = planRescheduleNotification(using: context)
        }

        return destination
    }

    /// The reschedule reminder a notification would have delivered, resolved
    /// against the seeded run so the test does not depend on a real
    /// notification being scheduled and fired.
    private static func planRescheduleNotification(using context: ModelContext) -> PlanNotificationDestination? {
        guard let run = try? context.fetch(FetchDescriptor<PlanRun>())
            .first(where: { $0.status == .active })
        else {
            return nil
        }
        guard let progress = run.orderedWorkoutProgress.first(where: {
            PlanReminderEligibility.isActionableToday($0, in: run)
        }) else {
            return nil
        }
        return PlanNotificationDestination(
            planID: run.sourcePlanID,
            runID: run.id,
            progressID: progress.id,
            action: .reschedule
        )
    }
}
