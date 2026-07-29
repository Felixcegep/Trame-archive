import Foundation
import SwiftUI
import SwiftData

@Observable
class ActiveWorkoutViewModel {
    var unitSystem: UnitSystem {
        UserDefaults.standard.unitSystem
    }
    
    var workoutVM: WorkoutViewModel
    let modelContext: ModelContext
    private let activeLoggingMetrics: ActiveLoggingMetricsRecorder?
    
    private let restTimer = RestTimerController()
    private var timerTask: Task<Void, Never>?
    private(set) var previousPerformances: [PersistentIdentifier: PreviousExercisePerformance] = [:]

    var isTimerVisible: Bool { restTimer.isVisible }
    var timerPause: Date? { restTimer.endDate }
    
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

    private var restDuration: TimeInterval {
        let defaults = UserDefaults.standard
        let savedDuration = defaults.integer(forKey: DefaultsKey.restTimer)

        guard defaults.object(forKey: DefaultsKey.restTimer) != nil, savedDuration > 0 else {
            return 20
        }

        return TimeInterval(savedDuration)
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
    
    func addExercise(_ template: Exercise) {
        guard let activeWorkout = workoutVM.activeWorkout else { return }

        let newExercise = ExerciseEntry(
            from: template,
            orderIndex: (activeWorkout.orderedExercises.last?.orderIndex ?? -1) + 1,
            usedMetric: unitSystem
        )
        activeWorkout.exercises.append(newExercise)
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
        currentSet.distance = previousSet.distance
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
        currentSet.isUserOverridden = currentSet.prescribedSetType != nil
            || currentSet.prescribedRepetitions != nil
            || currentSet.prescribedRepRangeMinimum != nil
            || currentSet.prescribedRepRangeMaximum != nil
            || currentSet.prescribedSuggestedLoad != nil
            || currentSet.prescribedCalories != nil
            || currentSet.prescriptionDefinitionData != nil
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

    /// Applies the matching prior set only when the active set has not been
    /// completed. Historical units are converted into this set's stored unit.
    func applyPreviousPerformance(to set: ExerciseSet, in exercise: ExerciseEntry, index: Int) {
        guard !set.done,
              let previousSet = previousPerformance(for: exercise)?.set(at: index)
        else {
            return
        }

        if exercise.trackingTypeSnapshot.usesReps {
            set.repetitions = previousSet.repetitions
        }
        if exercise.trackingTypeSnapshot.usesWeight {
            set.weight = UnitConversion.weight(
                previousSet.weight,
                from: previousSet.weightType,
                to: set.weightType
            )
        }
        if exercise.trackingTypeSnapshot.usesDuration {
            set.duration = previousSet.duration
        }
        if exercise.trackingTypeSnapshot.usesDistance, let distance = previousSet.distance {
            set.distance = UnitConversion.distance(
                distance,
                from: previousSet.distanceType,
                to: set.distanceType
            )
        }
        if exercise.trackingTypeSnapshot.usesCalories {
            set.calories = previousSet.calories
        }
        if set.prescribedSetType != nil
            || set.prescribedRepetitions != nil
            || set.prescribedRepRangeMinimum != nil
            || set.prescribedRepRangeMaximum != nil
            || set.prescribedSuggestedLoad != nil
            || set.prescribedCalories != nil
            || set.prescriptionDefinitionData != nil {
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
            set.weight = UnitConversion.weight(load, from: unit, to: set.weightType)
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
            set.weight = UnitConversion.weight(load, from: unit, to: set.weightType)
        }
        persistChanges()
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
            set.duration = parsed
        case .distance:
            set.distance = parsed.map(Float.init)
        case .calories:
            set.calories = parsed
        }

        markUserOverride(on: set)
        persistChanges()
        activeLoggingMetrics?.valueCommitted(for: set.id, field: field)
    }

    /// A typed value replaces a prescription, so the set stops tracking it.
    /// Sets with no prescription have nothing to override.
    private func markUserOverride(on set: ExerciseSet) {
        guard set.prescribedSetType != nil
            || set.prescribedRepetitions != nil
            || set.prescribedRepRangeMinimum != nil
            || set.prescribedRepRangeMaximum != nil
            || set.prescribedSuggestedLoad != nil
            || set.prescribedCalories != nil
            || set.prescriptionDefinitionData != nil
        else { return }
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

        guard set.done || canComplete(set, for: exercise) else {
            return false
        }

        set.done.toggle()
        // Segments are internal evidence for this one performed set, not
        // independently counted top-level work. Their completion follows the
        // parent attempt so an undo restores a coherent in-progress state.
        set.synchronizeSegmentCompletion()
        set.synchronizeComplexCompletion()
        if !set.done {
            // A selected source must remain a completed performed attempt.
            // Derived work falls back to the latest remaining completed
            // maximum until the lifter makes another explicit selection.
            set.isSelectedDailyMaximum = false
        }
        #if !GYMTRACKER_EXTENSION
        if set.done {
            ActiveWorkoutProgressionService.applyAfterCompleting(
                set: set,
                in: exercise,
                workout: workout,
                modelContext: modelContext
            )
        }
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

        for exercise in workout.orderedExercises {
            let shouldRun = exercise.persistentModelID == identifier
                && exercise.orderedSets.contains(where: { !$0.done })
            if shouldRun {
                exercise.startActiveDuration(at: now)
            } else {
                exercise.stopActiveDuration(at: now)
            }
        }
        persistChanges()
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
                defaultSeconds: Int(restDuration)
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
        activeLoggingMetrics?.restStarted()
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
        if workoutVM.activeWorkout?.restEndDate != nil || workoutVM.activeWorkout?.pausedRemainingTime != nil {
            workoutVM.activeWorkout?.restEndDate = nil
            workoutVM.activeWorkout?.pausedRemainingTime = nil
            persistChanges()
        }
        workoutVM.reconcileLiveActivity()
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
            workout.exercises.removeAll { $0 === exerciseEntry }
            modelContext.delete(exerciseEntry)
            workout.normalizeExerciseOrder()
            persistChanges()
        }
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

    func persistChanges() {
        _ = modelContext.saveOrRollback()
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

        copyPreviousSetValue(exerciseEntry: exercise, currentSetIndex: setIndex)
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
        let firstField = fields.first ?? .repetitions

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

        guard switchStateDoneSet(exercise, set) else { return .failed }
        guard isCompleting else {
            activeLoggingMetrics?.completedSetReopened()
            return .reopened
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
        let trackingType = exercise.trackingTypeSnapshot

        if trackingType.usesReps, set.repetitions <= 0 {
            return "Enter reps before completing this set."
        }

        if trackingType.usesDuration, (set.duration ?? 0) <= 0 {
            return "Enter a duration before completing this set."
        }

        if trackingType.usesCalories, (set.calories ?? 0) <= 0 {
            return "Enter calories before completing this set."
        }

        if trackingType.usesDistance, (set.distance ?? 0) <= 0 {
            return "Enter a distance before completing this set."
        }

        return "Enter a value before completing this set."
    }
}
