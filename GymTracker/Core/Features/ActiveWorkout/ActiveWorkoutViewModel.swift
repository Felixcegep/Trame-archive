import Foundation
import SwiftUI
import SwiftData

@Observable
@MainActor
class ActiveWorkoutViewModel {
    var unitSystem: UnitSystem {
        UserDefaults.standard.unitSystem
    }
    
    var workoutVM: WorkoutViewModel
    let modelContext: ModelContext
    private let activeLoggingMetrics: ActiveLoggingMetricsRecorder?
    
    private let restTimer = RestTimerController()
    private var timerTask: Task<Void, Never>?
    private var pendingTypedInputSaveTask: Task<Void, Never>?
    private var pendingActiveDurationSaveTask: Task<Void, Never>?
    private var hasPendingTypedInputSave = false
    private var hasPendingActiveDurationSave = false
    private static let typedInputSaveDelay: Duration = .milliseconds(180)
    // Exercise-page changes happen on the pager's gesture path. Give the
    // native page animation a frame budget before touching SwiftData, while
    // keeping the duration timestamp durable shortly after the change.
    private static let activeDurationSaveDelay: Duration = .milliseconds(250)
    private(set) var previousPerformances: [PersistentIdentifier: PreviousExercisePerformance] = [:]

    var isTimerVisible: Bool { restTimer.isVisible }
    var timerPause: Date? { restTimer.endDate }

    /// Increments only when a running countdown actually reaches its deadline
    /// while the lifter is here to notice.
    ///
    /// `restorePersistedRestTimer` also moves the controller to `.ready`, for a
    /// deadline that expired while the app was backgrounded. That is a
    /// restoration, not an event: the rest ended minutes ago, and buzzing on
    /// return would be reporting old news. It deliberately does not increment
    /// this, so nothing observing it can fire on relaunch or on a fixture load.
    private(set) var restCompletionCount = 0

    /// Set when the most recent `persistChanges()` call failed to save and
    /// rolled back — every set/rep/weight edit, exercise add/remove,
    /// substitution, and completion during a live workout goes through that
    /// one path. `ActiveWorkoutView` surfaces this as a small, non-blocking
    /// banner: losing a rep entry must never interrupt a set with a modal.
    /// Cleared the moment a save succeeds again.
    private(set) var lastPersistenceFailure: Error?

    /// How many consecutive `persistChanges()` calls have failed since the
    /// last successful save. Resets to zero on success.
    private(set) var consecutivePersistenceFailureCount = 0

    var hasPersistenceFailure: Bool { lastPersistenceFailure != nil }

    init(
        workoutVM: WorkoutViewModel,
        modelContext: ModelContext,
        activeLoggingMetrics: ActiveLoggingMetricsRecorder? = nil
    ) {
        self.workoutVM = workoutVM
        self.modelContext = modelContext
        self.activeLoggingMetrics = activeLoggingMetrics
    }

    var activeWorkout: Workout? {
        workoutVM.activeWorkout
    }

    /// The rest to offer after this exercise when nothing prescribes one.
    ///
    /// An explicit Settings value wins — the lifter has stated a preference and
    /// it applies everywhere. Zero (or unset) means automatic, and the duration
    /// is derived from what the exercise actually is. The previous behaviour
    /// was a single global 20 seconds, which was shorter than any strength
    /// protocol and taught people to ignore the timer.
    private func restDefaultSeconds(for entry: ExerciseEntry) -> Int {
        let explicit = UserDefaults.standard.integer(forKey: DefaultsKey.restTimer)
        guard explicit <= 0 else { return explicit }
        return WorkoutRestPolicy.defaultSeconds(for: entry)
    }

    func getNextExerciseToDo() -> (exercise: ExerciseEntry, set: ExerciseSet)? {
        guard let workout = workoutVM.workout else {
            return nil
        }

        return WorkoutSetSelector.nextIncompleteSet(in: workout).map {
            (exercise: $0.entry, set: $0.set)
        }
    }

    /// True while at least one set still needs to be performed. Once this is
    /// false the whole workout is complete, so no rest is owed and the rest
    /// card must not be shown.
    var hasIncompleteSet: Bool {
        getNextExerciseToDo() != nil
    }
    
    /// Adds an exercise mid-session, with warm-up sets when the movement is the
    /// kind that wants them.
    ///
    /// Warm-ups used to exist only on exercises that arrived from a template, so
    /// anything added mid-session started at the working weight — the app
    /// quietly had two standards depending on where the exercise came from. The
    /// default follows the movement rather than asking: a loaded compound gets
    /// two ramp-up sets, an accessory gets none, and either can be changed from
    /// the set's own type control afterwards.
    func addExercise(_ template: Exercise) {
        guard let activeWorkout = workoutVM.activeWorkout else { return }

        let newExercise = ExerciseEntry(
            from: template,
            orderIndex: (activeWorkout.orderedExercises.last?.orderIndex ?? -1) + 1,
            usedMetric: unitSystem
        )
        activeWorkout.exercises.append(newExercise)
        addDefaultWarmUpSets(to: newExercise, template: template)
        persistChanges()
        loadPreviousPerformance(for: newExercise)
        workoutVM.reconcileLiveActivity()
    }

    func removeSet(_ exerciseEntry: ExerciseEntry, _ set: ExerciseSet) {
        if let workout = workoutVM.activeWorkout {
            guard let storedExercise = workout.exercises.first(where: { $0.id == exerciseEntry.id }) else { return }
            storedExercise.sets.removeAll(where: { $0.id == set.id })
            modelContext.delete(set)
            exerciseEntry.normalizeSetOrder()
            persistChanges()
        }
    }

    /// Chooses the completed daily-maximum attempt used by same-session
    /// back-off formulas. Selection is scoped to one exercise entry.
    func selectDailyMaximum(_ selectedSet: ExerciseSet, in exerciseEntry: ExerciseEntry) {
        guard let workout = workoutVM.activeWorkout,
              let exercise = workout.exercises.first(where: { $0.id == exerciseEntry.id }),
              let selected = exercise.sets.first(where: { $0 === selectedSet }),
              selected.done,
              selected.prescribedSetType == .dailyMaximum || selected.setType == .dailyMaximum
        else { return }

        for set in exercise.sets where set.prescribedSetType == .dailyMaximum || set.setType == .dailyMaximum {
            set.isSelectedDailyMaximum = set === selected
        }
        #if !GYMTRACKER_EXTENSION
        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)
        #endif
        persistChanges()
    }
    
    /// Adds a set pre-filled with the last set's values (reps, weight,
    /// duration, distance) so lifters rarely retype; RPE, RIR, lift quality,
    /// and set type reset because they describe one specific effort.
    /// How many ramp-up sets a freshly added exercise should start with.
    ///
    /// Heavy compound patterns are the ones nobody walks up to cold; single-
    /// joint accessory work is the one where a warm-up set is noise. Bodyweight
    /// and cardio movements are excluded because "warm-up" there is a different
    /// activity, not a lighter version of the same one.
    private func defaultWarmUpSetCount(for template: Exercise) -> Int {
        guard template.trackingType.usesWeight else { return 0 }
        guard let equipment = template.equipmentType,
              [EquipmentType.barbell, .dumbbell, .machine, .cable].contains(equipment)
        else { return 0 }

        let compoundPatterns: [MovementPattern] = [
            .squat, .hinge, .horizontalPush, .verticalPush, .horizontalPull, .verticalPull, .lunge
        ]
        guard let pattern = template.movementPattern, compoundPatterns.contains(pattern) else {
            return 0
        }
        return 2
    }

    private func addDefaultWarmUpSets(to entry: ExerciseEntry, template: Exercise) {
        let count = defaultWarmUpSetCount(for: template)
        guard count > 0 else { return }

        // Captured before the append: existing sets have to be renumbered
        // relative to each other, not to a list that already contains the
        // warm-ups. Filtering inside `enumerated()` would keep counting the
        // rows it skipped and scatter the working sets.
        let existing = entry.orderedSets
        for (offset, set) in existing.enumerated() {
            set.orderIndex = count + offset
        }

        for index in 0..<count {
            entry.sets.append(
                ExerciseSet(
                    setType: .warmup,
                    orderIndex: index,
                    usedMetric: unitSystem
                )
            )
        }
    }

    func addSet(_ exerciseEntry: ExerciseEntry) {
        guard
            let workout = workoutVM.activeWorkout,
            let exercise = workout.exercises.first(where: { $0.id == exerciseEntry.id })
        else { return }

        if let lastSet = exercise.orderedSets.last {
            let newSet = lastSet.copy()
            newSet.rpe = nil
            newSet.rir = nil
            newSet.liftQuality = nil
            // Daily technical maximums are open-ended attempts. Preserve the
            // role for a newly appended attempt so the last successful one is
            // available to same-session derived back-off prescriptions.
            let isDailyMaximum = lastSet.prescribedSetType == .dailyMaximum
                || lastSet.setType == .dailyMaximum
            newSet.setType = isDailyMaximum ? .dailyMaximum : .normal
            if isDailyMaximum {
                newSet.prescribedSetType = .dailyMaximum
            } else if lastSet.prescribedSetType != .normal {
                // Top, back-off, AMRAP, and other generated roles are not
                // silently duplicated by an ad-hoc set. Daily maximum is the
                // exception because it represents another open attempt.
                newSet.clearPrescription()
            }
            newSet.orderIndex = lastSet.orderIndex + 1
            exercise.sets.append(newSet)
        } else {
            exercise.addEmptySet()
        }
        persistChanges()
    }

    func copyPreviousSetValue(exerciseEntry: ExerciseEntry, currentSetIndex: Int) {
        let orderedSets = exerciseEntry.orderedSets
        guard currentSetIndex > 0, currentSetIndex < orderedSets.count else { return }

        let previousSet = orderedSets[currentSetIndex - 1]
        let currentSet = orderedSets[currentSetIndex]
        currentSet.repetitions = previousSet.repetitions
        currentSet.weight = previousSet.weight
        currentSet.duration = previousSet.duration
        currentSet.distance = WorkoutDistancePolicy.meters(of: previousSet)
        currentSet.distanceType = .meters
        currentSet.calories = previousSet.calories
        // Performed effort is intentionally exclusive for a new logged set.
        // Legacy history may contain both values, but copying it forward must
        // retain one unambiguous measure.
        if let rir = previousSet.rir {
            currentSet.recordRIR(rir)
        } else {
            currentSet.recordRPE(previousSet.rpe)
        }
        currentSet.liftQuality = previousSet.liftQuality
        currentSet.isUserOverridden = SetRowPreparation.hasPrescription(currentSet)
        persistChanges()
    }

    func loadPreviousPerformances() {
        guard let workout = activeWorkout else { return }
        for exercise in workout.orderedExercises {
            loadPreviousPerformance(for: exercise)
        }
    }

    func previousPerformance(for exercise: ExerciseEntry) -> PreviousExercisePerformance? {
        previousPerformances[exercise.persistentModelID]
    }

    /// Sets already filled from previous performance without being asked.
    ///
    /// In memory only, and keyed by set rather than by row: a lifter who clears
    /// a value and pages away must not find it refilled on the way back, and a
    /// row is rebuilt every time its page scrolls into view. Cleared with the
    /// workout, because the next session's sets are different objects.
    private var autofilledSetIDs: Set<PersistentIdentifier> = []

    /// Commits the previous-performance value the row is already showing.
    ///
    /// The cell renders last session's number in grey as a placeholder
    /// (`SetRowFieldStack.placeholder`), but a placeholder is not a value: until
    /// this runs, "Log set" refuses the set with "Enter reps and a load before
    /// completing this set" while the numbers it wants sit on screen. Committing
    /// them is what makes the displayed suggestion true.
    ///
    /// Refused for a set carrying any prescription of its own — see
    /// `SetRowPreparation.hasPrescription`. Precedence overall is: what the
    /// lifter typed, then the plan's prescription, then last time, then empty.
    ///
    /// - Returns: whether anything was written.
    @discardableResult
    func autofillPreviousPerformanceIfUnfilled(
        _ previousSet: PreviousSetPerformance,
        to set: ExerciseSet,
        in exercise: ExerciseEntry
    ) -> Bool {
        guard !set.done,
              !set.separatesProgramPerformedEvidence,
              !autofilledSetIDs.contains(set.persistentModelID),
              !SetRowPreparation.hasAnyPrescription(set, in: exercise),
              SetRowPreparation.isUnfilled(set, for: exercise.trackingTypeSnapshot)
        else {
            return false
        }
        autofilledSetIDs.insert(set.persistentModelID)
        applyPreviousPerformance(previousSet, to: set, in: exercise)
        return true
    }

    /// Applies the matching prior set only when the active set has not been
    /// completed. Historical units are converted into this set's stored unit.
    ///
    /// Takes the resolved prior set rather than an index. The row already holds
    /// the exact `PreviousSetPerformance` it renders in its PREV column, and
    /// looking it up again here by row index risked writing a different set than
    /// the one on screen: the paged stage addresses rows by their absolute
    /// position in the exercise, while the previous-performance lookup is keyed
    /// on `orderIndex`, and the two diverge once a set is removed.
    func applyPreviousPerformance(
        _ previousSet: PreviousSetPerformance,
        to set: ExerciseSet,
        in exercise: ExerciseEntry
    ) {
        guard !set.done else { return }

        if exercise.trackingTypeSnapshot.usesReps {
            set.repetitions = previousSet.repetitions
        }
        if exercise.trackingTypeSnapshot.usesWeight {
            // Prefills a load the lifter is about to put on the bar, so it is
            // snapped to the equipment when the units differ. The historical
            // set it came from is not touched.
            set.weight = WorkoutLoadRounding.converted(
                previousSet.weight,
                from: previousSet.weightType,
                to: set.weightType,
                for: exercise.exercise
            )
        }
        if exercise.trackingTypeSnapshot.usesDuration {
            set.duration = previousSet.duration
        }
        if exercise.trackingTypeSnapshot.usesDistance, let distance = previousSet.distance {
            set.distance = WorkoutDistancePolicy.meters(
                storedValue: distance,
                storedUnit: previousSet.distanceType
            )
            set.distanceType = .meters
        }
        if exercise.trackingTypeSnapshot.usesCalories {
            set.calories = previousSet.calories
        }
        // Deviating from a prescription is the lifter's decision to record, and
        // this is the path that records it. The automatic fill above never
        // reaches here, because it refuses prescribed sets outright.
        if SetRowPreparation.hasPrescription(set) {
            set.isUserOverridden = true
        }
        persistChanges()
    }

    /// Applies only the suggested load. Reps remain explicit user input (or can
    /// still be filled from previous-performance hints), and completed sets are
    /// never rewritten.
    func applyRecommendation(to exercise: ExerciseEntry) {
        guard
            exercise.trackingTypeSnapshot.usesWeight,
            exercise.recommendedDecision != nil,
            let load = exercise.recommendedLoad,
            let unit = exercise.recommendedUnit
        else {
            return
        }

        for set in exercise.orderedSets where !set.done {
            set.weight = WorkoutLoadRounding.converted(
                load,
                from: unit,
                to: set.weightType,
                for: exercise.exercise
            )
        }
        persistChanges()
    }

    /// Applies the last completed session's load to every incomplete set. This
    /// is intentionally separate from previous-set prefill because the
    /// recommendation card changes load only and leaves reps explicit.
    func applyPriorRecommendationLoad(to exercise: ExerciseEntry) {
        guard
            exercise.trackingTypeSnapshot.usesWeight,
            let load = exercise.recommendationPriorLoad,
            let unit = exercise.recommendedUnit
        else {
            return
        }

        for set in exercise.orderedSets where !set.done {
            set.weight = WorkoutLoadRounding.converted(
                load,
                from: unit,
                to: set.weightType,
                for: exercise.exercise
            )
        }
        persistChanges()
    }

    /// Resolves an active program recommendation through the same persisted
    /// receipt service used after workout completion. The service owns the one
    /// save; Live Activity is reconciled only after that commit succeeds.
    func acceptActiveRecommendation(
        _ recommendation: PlanProgressionRecommendationRecord
    ) throws {
        guard let run = (try? modelContext.fetch(FetchDescriptor<PlanRun>()))?.first(where: {
            $0.id == recommendation.planRunID
        }) else {
            throw ActiveWorkoutRecommendationMutationService.MutationError.activeWorkoutNotFound
        }
        try PlanProgressionRecommendationService.accept(
            recommendation,
            in: run,
            context: modelContext
        )
        workoutVM.reconcileLiveActivity()
    }

    func declineActiveRecommendation(
        _ recommendation: PlanProgressionRecommendationRecord
    ) throws {
        try PlanProgressionRecommendationService.decline(
            recommendation,
            context: modelContext
        )
        workoutVM.reconcileLiveActivity()
    }
    
    /// The single write path for keypad entry. Empty or partial text ("", ".")
    /// clears the value back to "not entered" instead of writing a zero, so an
    /// untouched input keeps presenting as "—" rather than becoming performed
    /// truth the lifter never logged.
    func commitTypedValue(
        _ text: String,
        field: SetInputFocus.Field,
        in set: ExerciseSet
    ) {
        let parsed = DecimalParser.value(from: text).map { max($0, 0) }

        switch field {
        case .repetitions:
            set.repetitions = parsed.map(Float.init) ?? 0
        case .weight:
            set.weight = parsed.map(Float.init) ?? 0
        case .duration:
            // Duration is typed as a clock, not as a count of seconds.
            //
            // A plain numeric field means 1:30 is entered as "90", which is a
            // conversion the lifter has to do in their head, mid-set, for every
            // timed exercise in the app. Digits instead shift in from the right
            // the way every stopwatch and oven timer behaves: 4·5 → 0:45,
            // 1·3·0 → 1:30, 2·0·0 → 2:00. No separator key is needed.
            set.duration = ClockEntry.seconds(fromTypedDigits: text) ?? parsed
        case .distance:
            let meters = WorkoutDistancePolicy.meters(of: set)
            let displayUnit = WorkoutDistancePolicy.preferredDisplayUnit(
                forMeters: meters,
                system: UserDefaults.standard.unitSystem
            )
            WorkoutDistancePolicy.storeDisplayValue(
                parsed.map(Float.init),
                displayUnit: displayUnit,
                on: set
            )
        case .calories:
            set.calories = parsed
        }

        markUserOverride(on: set)
        scheduleTypedInputSave()
        activeLoggingMetrics?.valueCommitted(for: set.id, field: field)
    }

    /// A typed value replaces a prescription, so the set stops tracking it.
    /// Sets with no prescription have nothing to override.
    private func markUserOverride(on set: ExerciseSet) {
        guard SetRowPreparation.hasPrescription(set) else { return }
        set.isUserOverridden = true
    }

    @discardableResult
    func switchStateDoneSet(
        _ selectedExercise: ExerciseEntry,
        _ selectedSet: ExerciseSet
    ) -> Bool {
        guard
            let workout = workoutVM.activeWorkout,
            let exercise = workout.exercises.first(
                where: { $0.id == selectedExercise.id }
            ),
            let set = exercise.sets.first(
                where: { $0.id == selectedSet.id }
            )
        else {
            return false
        }

        if !set.done {
            guard canComplete(set, for: exercise) else { return false }
            guard case .applied = completeSetTransaction(set, in: exercise) else { return false }
            return true
        }

        set.done = false
        // Segments follow the parent completion flag. Complex outcomes remain
        // explicit evidence and survive reopening so Undo cannot erase a
        // partially or fully recorded Olympic sequence.
        set.synchronizeSegmentCompletion()
        set.synchronizeComplexCompletion()
        // A selected source must remain a completed performed attempt.
        // Derived work falls back to the latest remaining completed maximum
        // until the lifter makes another explicit selection.
        set.isSelectedDailyMaximum = false
        #if !GYMTRACKER_EXTENSION
        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)
        #endif
        persistChanges()
        return true
    }

    func canComplete(_ set: ExerciseSet, for exercise: ExerciseEntry) -> Bool {
        ActiveWorkoutMutationService.canComplete(set, for: exercise)
    }

    func trackActiveExercise(with identifier: PersistentIdentifier?) {
        guard let workout = activeWorkout else { return }
        let now = Date.now
        var didChangeDurationState = false

        for exercise in workout.orderedExercises {
            let shouldRun = exercise.persistentModelID == identifier
                && exercise.orderedSets.contains(where: { !$0.done })
            let wasRunning = exercise.activeDurationStartedAt != nil
            if shouldRun {
                exercise.startActiveDuration(at: now)
            } else {
                exercise.stopActiveDuration(at: now)
            }
            didChangeDurationState = didChangeDurationState
                || wasRunning != (exercise.activeDurationStartedAt != nil)
        }

        if didChangeDurationState {
            scheduleActiveDurationSave()
        }
    }
    func getNextSet(in selectedExercise: ExerciseEntry) -> ExerciseSet? {
        guard let workout = workoutVM.activeWorkout,
              let next = WorkoutSetSelector.nextIncompleteSet(in: workout),
              next.entry.id == selectedExercise.id
        else {
            return nil
        }
        return next.set
    }
    
    func markNextSetDone(in selectedExercise: ExerciseEntry) {
        guard let nextSet = getNextSet(in: selectedExercise) else { return }
        _ = switchStateDoneSet(selectedExercise, nextSet)
    }
    

   
    
    func startTime(after exercise: ExerciseEntry? = nil) {
        guard let workout = workoutVM.activeWorkout else { return }
        let restSeconds = exercise.flatMap {
            WorkoutSetSelector.restSeconds(
                afterCompleting: $0,
                in: workout,
                defaultSeconds: restDefaultSeconds(for: $0)
            )
        }

        startRest(seconds: restSeconds)
    }

    func startRest(after block: WorkoutExecutionBlock) {
        startRest(seconds: block.restSeconds)
    }

    private func startRest(seconds: Int?) {
        guard let workout = workoutVM.activeWorkout else { return }

        // There is nothing to rest for after the final set: never start a rest
        // (or leave a stale one running) once every set is complete.
        let hasNextSet = WorkoutSetSelector.nextIncompleteSet(in: workout) != nil

        guard let seconds, seconds > 0, hasNextSet else {
            workout.restEndDate = nil
            workout.pausedRemainingTime = nil
            persistChanges()
            workoutVM.reconcileLiveActivity()
            return
        }
        activeLoggingMetrics?.restExpected()
        let timerEndDate = Date.now.addingTimeInterval(TimeInterval(seconds))

        workout.restEndDate = timerEndDate
        workout.pausedRemainingTime = nil
        persistChanges()
        runRestCountdown(until: timerEndDate)
        // Only a freshly started rest knows its intended length. Restores and
        // resumes inherit whatever is already recorded, which is `nil` after a
        // cold launch — see `RestTimerController.plannedDuration`.
        restTimer.planDuration(TimeInterval(seconds))
        activeLoggingMetrics?.restStarted()
    }

    /// The set the lifter just finished, when its effort is worth asking about.
    ///
    /// Returns `nil` — and so hides the question entirely — unless the exercise
    /// actually prescribed an effort target. Asking after every accessory set
    /// trains people to ignore the control, and an effort log nobody fills in
    /// honestly is worse than no effort log at all.
    ///
    /// Deliberately *not* gated on the value being unset: a lifter who drags the
    /// slider and then changes their mind must be able to drag it back, so the
    /// card stays for the whole rest once it has appeared.
    var lastCompletedSetAwaitingEffort: ExerciseSet? {
        guard let workout = workoutVM.activeWorkout else { return nil }

        let completed = workout.orderedExercises
            .flatMap { entry -> [(ExerciseEntry, ExerciseSet)] in
                entry.orderedSets.filter(\.done).map { (entry, $0) }
            }

        guard let (entry, set) = completed.last else { return nil }
        // The prescription can live on either the set snapshot or the entry,
        // depending on whether it came from a template or a plan.
        let prescribesEffort = set.prescribedRPE != nil
            || set.prescribedRIR != nil
            || entry.prescribedRPE != nil
            || entry.prescribedRIR != nil
        return prescribesEffort ? set : nil
    }

    /// The full length of the rest period now running, when it is known.
    ///
    /// `nil` after a cold launch mid-rest: the deadline survives in SwiftData,
    /// the intended total does not. Callers must degrade to a plain countdown
    /// rather than assuming a denominator.
    var restPlannedDuration: TimeInterval? {
        if let planned = restTimer.plannedDuration { return planned }

        // Fall back to the rest the *programme* asked for.
        //
        // `RestTimerController.plannedDuration` is in-memory only, so a cold
        // launch mid-rest leaves it nil and the takeover drops the ring
        // entirely — which is the state every rest screenshot captured so far
        // shows. The original reasoning was that a ring with an invented
        // denominator is a confident lie, and that is right about *inventing*
        // one. This is not invented: it is the prescribed rest for the exercise
        // being rested after, which is the same number `startRest` would have
        // recorded had it run in this process.
        //
        // Still nil when nothing prescribed a rest — a free workout with no
        // target. There the digits alone remain the honest fallback.
        guard let workout = workoutVM.activeWorkout,
              let next = WorkoutSetSelector.nextIncompleteSet(in: workout),
              let seconds = next.entry.prescribedRestSeconds,
              seconds > 0
        else { return nil }
        return TimeInterval(seconds)
    }

    var isTimerPaused: Bool {
        restTimer.pausedRemaining != nil
    }

    var isRestReady: Bool {
        restTimer.isReady
    }

    var pausedTimeRemaining: TimeInterval {
        restTimer.pausedRemaining ?? 0
    }

    func restorePersistedRestTimer() {
        // A rest timer persisted before the app was backgrounded is stale once
        // every set is complete; clear it instead of resurfacing a rest card
        // for a finished workout.
        if let workout = workoutVM.activeWorkout,
           WorkoutSetSelector.nextIncompleteSet(in: workout) == nil {
            cancelTimer()
            return
        }
        if let timerEndDate = workoutVM.activeWorkout?.restEndDate {
            guard timerEndDate > .now else {
                timerTask?.cancel()
                timerTask = nil
                workoutVM.activeWorkout?.restEndDate = nil
                persistChanges()
                restTimer.ready()
                workoutVM.reconcileLiveActivity()
                return
            }
            runRestCountdown(until: timerEndDate)
        } else if let pausedRemaining = workoutVM.activeWorkout?.pausedRemainingTime {
            timerTask?.cancel()
            timerTask = nil
            restTimer.restore(endDate: nil, pausedRemaining: pausedRemaining)
            workoutVM.reconcileLiveActivity()
        } else if timerTask != nil || restTimer.isVisible {
            // Both persisted fields are nil, yet a local countdown or
            // paused/ready state is still around. That only happens when an
            // external mutation (Siri, the Live Activity, a widget) cleared
            // the persisted rest through a separate `ModelContext` — most
            // commonly a skip — while this countdown kept ticking toward a
            // deadline that no longer exists. `cancelTimer` stops it and
            // reconciles the Live Activity; it is a no-op on the
            // already-nil persisted fields, so it does not loop back into
            // another save or another notification.
            cancelTimer()
        }
    }

    func pauseTimer() {
        guard let timerEndDate = workoutVM.activeWorkout?.restEndDate else { return }

        timerTask?.cancel()
        timerTask = nil

        let remaining = max(0, timerEndDate.timeIntervalSinceNow)
        workoutVM.activeWorkout?.pausedRemainingTime = remaining
        workoutVM.activeWorkout?.restEndDate = nil
        restTimer.pause(remaining: remaining)
        persistChanges()
        cancelPendingRestNotification()
        activeLoggingMetrics?.restPaused()

        workoutVM.reconcileLiveActivity()
    }

    func resumeTimer() {
        guard let pausedRemaining = workoutVM.activeWorkout?.pausedRemainingTime else { return }

        let timerEndDate = Date.now.addingTimeInterval(pausedRemaining)
        workoutVM.activeWorkout?.restEndDate = timerEndDate
        workoutVM.activeWorkout?.pausedRemainingTime = nil
        persistChanges()
        runRestCountdown(until: timerEndDate)
        activeLoggingMetrics?.restResumed()
    }

    func addRestTime(_ seconds: TimeInterval) {
        restTimer.extendPlannedDuration(by: seconds)
        if isTimerPaused {
            if let currentPaused = workoutVM.activeWorkout?.pausedRemainingTime {
                workoutVM.activeWorkout?.pausedRemainingTime = currentPaused + seconds
                restTimer.extendPaused(by: seconds)
                persistChanges()
                activeLoggingMetrics?.restExtended()
            }
        } else if let timerEndDate = workoutVM.activeWorkout?.restEndDate {
            let newEndDate = timerEndDate.addingTimeInterval(seconds)
            workoutVM.activeWorkout?.restEndDate = newEndDate
            persistChanges()
            runRestCountdown(until: newEndDate)
            activeLoggingMetrics?.restExtended()
        }
    }

    func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
        restTimer.cancel()
        // Skipping, finishing, or discarding all land here. A reminder for a
        // rest that no longer exists is worse than none.
        cancelPendingRestNotification()
        if workoutVM.activeWorkout?.restEndDate != nil || workoutVM.activeWorkout?.pausedRemainingTime != nil {
            workoutVM.activeWorkout?.restEndDate = nil
            workoutVM.activeWorkout?.pausedRemainingTime = nil
            persistChanges()
        }
        workoutVM.reconcileLiveActivity()
    }

    /// Drops any reminder scheduled for a rest period that has since been
    /// skipped, paused, or ended. Scheduling happens only on backgrounding
    /// (see `RootView.handleScenePhaseChange`); cancelling happens wherever the
    /// rest stops being true, because those paths can run in either state.
    private func cancelPendingRestNotification() {
        Task { await RestNotificationScheduler.shared.cancel() }
    }

    /// The single countdown path used by a newly started, restored, resumed, or
    /// extended rest period. Persisted state remains the recovery source of truth.
    private func runRestCountdown(until timerEndDate: Date) {
        timerTask?.cancel()
        restTimer.start(until: timerEndDate)

        timerTask = Task {
            await MainActor.run {
                workoutVM.reconcileLiveActivity()
            }

            do {
                try await Task.sleep(for: .seconds(max(0, timerEndDate.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    restTimer.ready()
                    workoutVM.activeWorkout?.restEndDate = nil
                    persistChanges()
                    // The one place a rest period genuinely *ends* in front of
                    // the lifter. Every other path to `.ready` is a restore.
                    restCompletionCount += 1
                }

                await MainActor.run {
                    workoutVM.reconcileLiveActivity()
                }
            } catch {
                return
            }
        }
    }


    
    func removeExercise(_ exerciseEntry: ExerciseEntry) {
        if let workout = workoutVM.activeWorkout {
            let formerBlockID = exerciseEntry.executionBlockID
            workout.exercises.removeAll { $0 === exerciseEntry }
            modelContext.delete(exerciseEntry)
            workout.normalizeExerciseOrder()
            removeExecutionBlockIfEmpty(formerBlockID, in: workout)
            persistChanges()
        }
    }

    /// Deleting the last member of an execution block would otherwise leave a
    /// phantom card: block membership is derived dynamically by
    /// `WorkoutExecutionBlockService.entries`, so an empty block has no
    /// dangling reference and keeps rendering as a live Start/round/score
    /// control for exercises that no longer exist. Mirrors the cleanup
    /// `CompletedWorkoutPreparationService.prepare` performs at save time,
    /// but only the deletion — a block that still has members is left
    /// untouched.
    private func removeExecutionBlockIfEmpty(_ blockID: UUID?, in workout: Workout) {
        guard let blockID,
              let block = workout.orderedExecutionBlocks.first(where: { $0.id == blockID }),
              WorkoutExecutionBlockService.entries(in: block, workout: workout).isEmpty
        else {
            return
        }
        WorkoutExecutionBlockService.remove(block, from: workout)
        modelContext.delete(block)
    }

    func superset(_ exerciseEntry: ExerciseEntry, with otherEntry: ExerciseEntry) {
        guard
            let workout = workoutVM.activeWorkout,
            exerciseEntry.persistentModelID != otherEntry.persistentModelID,
            let first = workout.exercises.first(where: { $0.persistentModelID == exerciseEntry.persistentModelID }),
            let second = workout.exercises.first(where: { $0.persistentModelID == otherEntry.persistentModelID })
        else {
            return
        }

        let groupID = first.supersetGroupID ?? second.supersetGroupID ?? UUID()
        if let mergingGroupID = second.supersetGroupID {
            for entry in workout.exercises where entry.supersetGroupID == mergingGroupID {
                entry.supersetGroupID = groupID
            }
        }
        first.supersetGroupID = groupID
        second.supersetGroupID = groupID
        workout.normalizeExerciseOrder()
        persistChanges()
    }

    func removeFromSuperset(_ exerciseEntry: ExerciseEntry) {
        guard let workout = workoutVM.activeWorkout else { return }
        exerciseEntry.supersetGroupID = nil
        workout.normalizeExerciseOrder()
        persistChanges()
    }

    /// A replacement is intentionally allowed only before the entry has any
    /// completed sets. Completed entries are part of the workout's historical
    /// record and must not be reinterpreted as another exercise.
    ///
    /// The `decision` carries the structured reason, the separate suitability
    /// and comparability verdicts, the explicit progression-transfer policy,
    /// the rule version, and the evidence snapshot. It is applied through
    /// `SubstitutionDecisionService` in one transaction so the persisted
    /// decision can never be half-written.
    @discardableResult
    func swapExercise(
        _ exerciseEntry: ExerciseEntry,
        with replacement: Exercise,
        decision: SubstitutionDecision
    ) -> Bool {
        guard
            let workout = workoutVM.activeWorkout,
            let storedExercise = workout.exercises.first(where: { $0.id == exerciseEntry.id })
        else {
            return false
        }

        do {
            try SubstitutionDecisionService.apply(
                decision: decision,
                replacement: replacement,
                to: storedExercise.persistentModelID,
                in: workout,
                modelContext: modelContext
            )
        } catch {
            return false
        }

        previousPerformances.removeValue(forKey: storedExercise.persistentModelID)
        loadPreviousPerformance(for: storedExercise)
        return true
    }

    /// A swap performed without going through the decision flow — no reason
    /// was stated and no evaluation was run.
    ///
    /// It records exactly that rather than inventing a verdict: the evidence
    /// snapshot is `insufficientInformation` / `unknown` / `insufficient` with
    /// the missing evidence named, and the progression policy is
    /// `.undetermined`, which resolves to *separate* progression. An unknown
    /// substitution must never inherit another exercise's load history.
    @discardableResult
    func swapExercise(_ exerciseEntry: ExerciseEntry, with replacement: Exercise) -> Bool {
        let decision = SubstitutionDecision(
            reason: .notSure,
            scope: .todayOnly,
            progressionPolicy: .undetermined,
            evaluation: SubstitutionEvaluationSnapshot(
                version: SubstitutionEvaluationService.ruleVersion,
                ruleID: SubstitutionEvaluationService.ruleID,
                sourceExerciseID: exerciseEntry.exercise.id,
                candidateExerciseID: replacement.id,
                reason: .notSure,
                suitability: .insufficientInformation,
                comparability: .unknown,
                confidence: .insufficient,
                matchedFactorCodes: [],
                differingFactorCodes: [],
                missingEvidenceCodes: [SubstitutionFactorCode.goal],
                hardFilterFailureCodes: [],
                candidateProvenance: .userAuthored
            )
        )
        return swapExercise(exerciseEntry, with: replacement, decision: decision)
    }

    /// Future-plan scope. Kept separate from `swapExercise` on purpose: this
    /// edits the plan's prescription, which is a different change from logging
    /// today's session, and it is never applied as a side effect of one.
    @discardableResult
    func applyPlanSubstitution(
        _ exerciseEntry: ExerciseEntry,
        with replacement: Exercise
    ) -> Bool {
        guard let plannedExerciseID = exerciseEntry.sourcePlannedExerciseID else { return false }
        let run = activePlanRun()
        do {
            try PlanSubstitutionPreviewService.apply(
                plannedExerciseID: plannedExerciseID,
                replacement: replacement,
                run: run,
                modelContext: modelContext
            )
            return true
        } catch {
            return false
        }
    }

    /// The run this workout was started from, when it came from a plan.
    func activePlanRun() -> PlanRun? {
        guard let runID = workoutVM.activeWorkout?.sourcePlanRunID else { return nil }
        return (try? modelContext.fetch(FetchDescriptor<PlanRun>()))?.first { $0.id == runID }
    }

    /// Today's plan goal, used as substitution context. `nil` for free and
    /// template workouts — the evaluator treats that as weaker evidence rather
    /// than guessing an intent the session never stated.
    func activePlanGoal() -> PlanGoal? {
        activePlanRun()?.plan?.goal
    }

    private func saveNow() -> Bool {
        switch modelContext.saveOrRollbackReportingFailure() {
        case .saved:
            lastPersistenceFailure = nil
            consecutivePersistenceFailureCount = 0
            return true
        case .failed(let error):
            consecutivePersistenceFailureCount += 1
            lastPersistenceFailure = error
            // The raw SwiftData error is diagnostic-only; the banner never
            // shows this text to the lifter.
            print("ActiveWorkoutViewModel: persistChanges failed (\(consecutivePersistenceFailureCount) consecutive): \(error)")
            return false
        }
    }

    /// Saves immediately and absorbs any pending keypad edit into this same
    /// transaction. Non-keypad mutations, lifecycle transitions, and
    /// navigation use this as their durable boundary.
    func persistChanges() {
        pendingTypedInputSaveTask?.cancel()
        pendingTypedInputSaveTask = nil
        hasPendingTypedInputSave = false
        pendingActiveDurationSaveTask?.cancel()
        pendingActiveDurationSaveTask = nil
        hasPendingActiveDurationSave = false
        _ = saveNow()
    }

    private func scheduleTypedInputSave() {
        hasPendingTypedInputSave = true
        pendingTypedInputSaveTask?.cancel()
        pendingTypedInputSaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.typedInputSaveDelay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.flushPendingTypedInputSave()
        }
    }

    /// Flushes the coalesced keypad edit at an explicit durability boundary.
    /// It also flushes a deferred exercise-duration transition. Set completion
    /// intentionally does not call this first: its workflow owns the single
    /// transaction that includes both typed values and completion state.
    @discardableResult
    func flushPendingTypedInputSave() -> Bool {
        pendingTypedInputSaveTask?.cancel()
        pendingTypedInputSaveTask = nil
        pendingActiveDurationSaveTask?.cancel()
        pendingActiveDurationSaveTask = nil
        guard hasPendingTypedInputSave || hasPendingActiveDurationSave else { return true }
        hasPendingTypedInputSave = false
        hasPendingActiveDurationSave = false
        return saveNow()
    }

    private func scheduleActiveDurationSave() {
        hasPendingActiveDurationSave = true
        pendingActiveDurationSaveTask?.cancel()
        pendingActiveDurationSaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.activeDurationSaveDelay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.flushPendingTypedInputSave()
        }
    }

    private func loadPreviousPerformance(for exercise: ExerciseEntry) {
        guard let workout = activeWorkout else { return }

        do {
            if let performance = try ExerciseHistoryService(modelContext: modelContext)
                .mostRecentPerformance(for: exercise.exercise, before: workout.startTime) {
                previousPerformances[exercise.persistentModelID] = performance
            } else {
                previousPerformances.removeValue(forKey: exercise.persistentModelID)
            }
        } catch {
            print("Failed to load previous exercise performance: \(error)")
        }
    }

    func copyValuesForFocusedSet(_ focus: SetInputFocus?) {
        guard
            let focus,
            let exercise = workoutVM.activeWorkout?.orderedExercises.first(where: { $0.persistentModelID == focus.exerciseID }),
            let setIndex = exercise.orderedSets.firstIndex(where: { $0.persistentModelID == focus.setID })
        else {
            return
        }

        activeLoggingMetrics?.toolUsed(.copyLastSet)
        copyPreviousSetValue(exerciseEntry: exercise, currentSetIndex: setIndex)
    }

    /// Forwarded so a surface that owns a mid-entry tool can report reaching for
    /// it without holding the recorder itself. The recorder ignores the report
    /// when no entry is in progress, so a call site never has to check.
    func noteSetEntryTool(_ tool: ActiveLoggingMetricsRecorder.SetEntryTool) {
        activeLoggingMetrics?.toolUsed(tool)
    }

    func canCopyValuesForFocusedSet(_ focus: SetInputFocus?) -> Bool {
        guard
            let focus,
            let exercise = workoutVM.activeWorkout?.orderedExercises.first(where: { $0.persistentModelID == focus.exerciseID }),
            let setIndex = exercise.orderedSets.firstIndex(where: { $0.persistentModelID == focus.setID })
        else {
            return false
        }

        return setIndex > 0
    }

    /// Resolves a focus value back into the models it points at. The set-entry
    /// panel renders outside the row that owns the set, so it only ever holds a
    /// `SetInputFocus` and needs this to read or mutate the underlying set.
    func models(for focus: SetInputFocus?) -> (exercise: ExerciseEntry, set: ExerciseSet)? {
        guard
            let focus,
            let exercise = workoutVM.activeWorkout?.orderedExercises
                .first(where: { $0.persistentModelID == focus.exerciseID }),
            let set = exercise.orderedSets
                .first(where: { $0.persistentModelID == focus.setID })
        else {
            return nil
        }

        return (exercise, set)
    }

    enum SetCompletionOutcome: Equatable {
        /// Required values are missing; the message explains what and the focus
        /// points at the field to fix.
        case blocked(message: String, focus: SetInputFocus)
        /// The set was marked done. `nextFocus` is the next incomplete set in the
        /// same exercise, or `nil` when the exercise is finished.
        case completed(nextFocus: SetInputFocus?)
        /// A completed set was toggled back to incomplete.
        case reopened
        case failed
    }

    /// The single completion path, shared by the row's ○ button and the
    /// set-entry panel's confirm button so both validate, persist, and advance
    /// focus identically.
    func completeSet(_ set: ExerciseSet, in exercise: ExerciseEntry) -> SetCompletionOutcome {
        let isCompleting = !set.done
        let fields = SetInputCoordinator.inputFields(for: exercise.trackingTypeSnapshot)
        let firstField = SetInputCoordinator.firstMissingField(
            in: set,
            for: exercise.trackingTypeSnapshot
        )

        if isCompleting, !canComplete(set, for: exercise) {
            activeLoggingMetrics?.setCompletionBlocked()
            return .blocked(
                message: validationMessage(for: set, in: exercise),
                focus: SetInputFocus(
                    exerciseID: exercise.persistentModelID,
                    setID: set.persistentModelID,
                    field: firstField
                )
            )
        }

        guard isCompleting else {
            guard switchStateDoneSet(exercise, set) else { return .failed }
            activeLoggingMetrics?.completedSetReopened()
            return .reopened
        }

        let outcome = completeSetTransaction(set, in: exercise)
        guard case .applied = outcome else {
            if case .invalid = outcome {
                activeLoggingMetrics?.setCompletionBlocked()
                return .blocked(
                    message: validationMessage(for: set, in: exercise),
                    focus: SetInputFocus(
                        exerciseID: exercise.persistentModelID,
                        setID: set.persistentModelID,
                        field: firstField
                    )
                )
            }
            return .failed
        }

        activeLoggingMetrics?.setCompleted(id: set.id)

        let nextSet = exercise.orderedSets.first(where: { !$0.done })
        return .completed(nextFocus: nextSet.map {
            SetInputFocus(
                exerciseID: exercise.persistentModelID,
                setID: $0.persistentModelID,
                field: firstField
            )
        })
    }

    func validationMessage(for set: ExerciseSet, in exercise: ExerciseEntry) -> String {
        SetRowCompletionValidation.message(
            for: set,
            trackingType: exercise.trackingTypeSnapshot
        )
    }

    private func completeSetTransaction(
        _ set: ExerciseSet,
        in exercise: ExerciseEntry,
        now: Date = .now
    ) -> WorkoutSetCompletionWorkflow.Outcome {
        guard let workout = workoutVM.activeWorkout else { return .unavailable }
        pendingTypedInputSaveTask?.cancel()
        pendingTypedInputSaveTask = nil
        hasPendingTypedInputSave = false
        let outcome = WorkoutSetCompletionWorkflow(modelContext: modelContext).execute(
            .init(
                workoutID: workout.id,
                target: .identified(entryID: exercise.id, setID: set.id),
                fallbackRestSeconds: restDefaultSeconds(for: exercise),
                now: now
            )
        )
        if case .applied(let receipt) = outcome {
            applyCompletionPostCommit(receipt)
        }
        return outcome
    }

    /// Mirrors durable rest state into the foreground countdown only after the
    /// workflow's save succeeds. No model mutation or second save happens here.
    private func applyCompletionPostCommit(_ receipt: WorkoutSetCompletionWorkflow.Receipt) {
        guard let endDate = receipt.restEndDate, endDate > .now else {
            timerTask?.cancel()
            timerTask = nil
            restTimer.cancel()
            cancelPendingRestNotification()
            workoutVM.reconcileLiveActivity()
            return
        }

        activeLoggingMetrics?.restExpected()
        runRestCountdown(until: endDate)
        activeLoggingMetrics?.restStarted()
    }
}
