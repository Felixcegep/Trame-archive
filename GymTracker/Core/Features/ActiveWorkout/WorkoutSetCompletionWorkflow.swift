import Foundation
import SwiftData

/// The durable mutation boundary for completing one performed workout set.
///
/// All callers supply intent (which set, and optional shortcut-entered values)
/// while this workflow owns validation, nested evidence synchronization,
/// progression, flow/rest resolution, and the single save. Presentation and
/// other platform effects consume the returned receipt only after that save
/// succeeds.
@MainActor
struct WorkoutSetCompletionWorkflow {
    struct Log: Equatable {
        var repetitions: Int?
        var weight: Double?
        var rpe: Double?
        var rir: Int?

        init(
            repetitions: Int? = nil,
            weight: Double? = nil,
            rpe: Double? = nil,
            rir: Int? = nil
        ) {
            self.repetitions = repetitions
            self.weight = weight
            self.rpe = rpe
            self.rir = rir
        }
    }

    enum Target: Equatable {
        /// Resolves whatever the shared flow selector currently owns.
        case current
        /// Resolves the current set and rejects an external action whose
        /// display indices no longer describe it.
        case expectedCurrent(exerciseOrderIndex: Int, setOrderIndex: Int)
        /// The foreground UI intentionally permits work out of document order.
        case identified(entryID: UUID, setID: UUID)
    }

    struct Command: Equatable {
        let workoutID: UUID
        let target: Target
        let log: Log?
        let fallbackRestSeconds: Int
        let now: Date

        init(
            workoutID: UUID,
            target: Target,
            log: Log? = nil,
            fallbackRestSeconds: Int,
            now: Date = .now
        ) {
            self.workoutID = workoutID
            self.target = target
            self.log = log
            self.fallbackRestSeconds = max(0, fallbackRestSeconds)
            self.now = now
        }
    }

    enum LogValidationFailure: Equatable {
        case conflictingEffortMeasures
        case invalidRepetitions
        case invalidWeight
        case invalidRPE
        case invalidRIR
    }

    enum ValidationFailure: Equatable {
        case log(LogValidationFailure)
        case completion([WorkoutSetCompletionValidator.InvalidReason])
    }

    struct Receipt: Equatable {
        let workoutID: UUID
        let completedEntryID: UUID
        let completedSetID: UUID
        let transition: WorkoutTransition
        let restEndDate: Date?
        let projection: LiveActivityProjection
    }

    struct PersistenceFailure: Equatable {
        let workoutID: UUID
        let message: String
        let projectionAfterRollback: LiveActivityProjection?
    }

    enum Outcome: Equatable {
        case applied(Receipt)
        case stale(LiveActivityProjection?)
        case invalid(ValidationFailure, LiveActivityProjection)
        case unavailable
        case persistenceFailure(PersistenceFailure)
    }

    let modelContext: ModelContext

    func execute(_ command: Command) -> Outcome {
        let workout: Workout
        do {
            guard let active = try modelContext.fetch(FetchDescriptor<Workout>())
                .first(where: { $0.id == command.workoutID && $0.status == .active })
            else { return .unavailable }
            workout = active
        } catch {
            return .persistenceFailure(.init(
                workoutID: command.workoutID,
                message: String(describing: error),
                projectionAfterRollback: nil
            ))
        }

        guard let resolved = resolve(command.target, in: workout) else {
            return .stale(LiveActivityProjection(workout: workout, now: command.now))
        }
        let entry = resolved.entry
        let set = resolved.set
        guard !set.done else {
            return .stale(LiveActivityProjection(workout: workout, now: command.now))
        }

        if let logFailure = command.log.flatMap(validate) {
            return .invalid(
                .log(logFailure),
                LiveActivityProjection(workout: workout, now: command.now)
            )
        }

        let priorLogValues = LoggedValueSnapshot(set: set)
        if let log = command.log {
            apply(log, to: set)
        }

        let validation = WorkoutSetCompletionValidator.validate(
            .init(set: set, trackingType: entry.trackingTypeSnapshot)
        )
        guard case .valid = validation else {
            priorLogValues.restore(on: set)
            let reasons: [WorkoutSetCompletionValidator.InvalidReason]
            if case .invalid(let invalidReasons) = validation {
                reasons = invalidReasons
            } else {
                reasons = []
            }
            return .invalid(
                .completion(reasons),
                LiveActivityProjection(workout: workout, now: command.now)
            )
        }

        set.done = true
        set.synchronizeSegmentCompletion()
        set.synchronizeComplexCompletion()

        #if !GYMTRACKER_EXTENSION
        ActiveWorkoutProgressionService.applyAfterCompleting(
            set: set,
            in: entry,
            workout: workout,
            modelContext: modelContext
        )
        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)
        #endif

        guard let transition = WorkoutSetSelector.transition(
            afterCompleting: set,
            in: entry,
            workout: workout,
            defaultSeconds: command.fallbackRestSeconds
        ) else {
            modelContext.rollback()
            return .stale(LiveActivityProjection(workout: workout, now: command.now))
        }

        let restEndDate: Date?
        if case .rest(let seconds) = transition.restDirective, seconds > 0 {
            restEndDate = command.now.addingTimeInterval(TimeInterval(seconds))
        } else {
            restEndDate = nil
        }
        workout.restEndDate = restEndDate
        workout.pausedRemainingTime = nil

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            return .persistenceFailure(.init(
                workoutID: workout.id,
                message: String(describing: error),
                projectionAfterRollback: LiveActivityProjection(workout: workout, now: command.now)
            ))
        }

        return .applied(.init(
            workoutID: workout.id,
            completedEntryID: entry.id,
            completedSetID: set.id,
            transition: transition,
            restEndDate: restEndDate,
            projection: LiveActivityProjection(workout: workout, now: command.now)
        ))
    }

    private func resolve(
        _ target: Target,
        in workout: Workout
    ) -> (entry: ExerciseEntry, set: ExerciseSet)? {
        switch target {
        case .current:
            return WorkoutSetSelector.nextIncompleteSet(in: workout)
        case .expectedCurrent(let exerciseOrderIndex, let setOrderIndex):
            guard let current = WorkoutSetSelector.nextIncompleteSet(in: workout),
                  current.entry.orderIndex == exerciseOrderIndex,
                  current.set.orderIndex == setOrderIndex
            else { return nil }
            return current
        case .identified(let entryID, let setID):
            guard let entry = workout.exercises.first(where: { $0.id == entryID }),
                  let set = entry.sets.first(where: { $0.id == setID })
            else { return nil }
            return (entry, set)
        }
    }

    private func validate(_ log: Log) -> LogValidationFailure? {
        if log.rpe != nil, log.rir != nil { return .conflictingEffortMeasures }
        if log.repetitions.map({ $0 <= 0 }) == true { return .invalidRepetitions }
        if log.weight.map({ $0 < 0 }) == true { return .invalidWeight }
        if log.rpe.map({ !(1.0...10.0).contains($0) }) == true { return .invalidRPE }
        if log.rir.map({ !(0...6).contains($0) }) == true { return .invalidRIR }
        return nil
    }

    private func apply(_ log: Log, to set: ExerciseSet) {
        if let repetitions = log.repetitions { set.repetitions = Float(repetitions) }
        if let weight = log.weight { set.weight = Float(weight) }
        if let rpe = log.rpe { set.recordRPE(rpe) }
        if let rir = log.rir { set.recordRIR(rir) }
    }

    private struct LoggedValueSnapshot {
        let repetitions: Float
        let weight: Float
        let rpe: Double?
        let rir: Int?

        init(set: ExerciseSet) {
            repetitions = set.repetitions
            weight = set.weight
            rpe = set.rpe
            rir = set.rir
        }

        func restore(on set: ExerciseSet) {
            set.repetitions = repetitions
            set.weight = weight
            set.rpe = rpe
            set.rir = rir
        }
    }
}
