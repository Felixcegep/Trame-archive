import Foundation
import SwiftData

/// A stable key for one of the two competition lifts and its three attempts.
/// This is session coordination state, not a second History identity.
struct CompetitionDayAttemptKey: Hashable, Identifiable {
    let lift: CompetitionLift
    let attemptNumber: Int

    var id: String { "\(lift.rawValue)-\(attemptNumber)" }
}

struct CompetitionDayRecordedResult: Equatable, Identifiable {
    let key: CompetitionDayAttemptKey
    let loadKg: Double
    let componentOutcomes: [ComplexComponentOutcome]
    let outcome: OlympicAttemptOutcome
    let liftQuality: LiftQuality?

    var id: String { key.id }
}

struct CompetitionDayAttemptDraft: Equatable, Identifiable {
    let key: CompetitionDayAttemptKey
    let proposedLoadKg: Double?
    let evidence: CompetitionLiftEvidence?
    let expectedComponentCount: Int
    var selectedLoadKg: Double?
    var recordedResult: CompetitionDayRecordedResult?

    var id: String { key.id }
    var isRecorded: Bool { recordedResult != nil }
}

enum CompetitionDayCoordinatorError: Error, Equatable, LocalizedError {
    case invalidAttempt
    case loadRequired
    case invalidLoad
    case componentCountMismatch
    case componentOutcomeRequired
    case attemptAlreadyRecorded

    var errorDescription: String? {
        switch self {
        case .invalidAttempt: "That attempt is not part of this competition day."
        case .loadRequired: "Choose a load before recording the attempt."
        case .invalidLoad: "Load must be a finite value greater than zero."
        case .componentCountMismatch: "Every prescribed component needs an outcome."
        case .componentOutcomeRequired: "Record an outcome for each component."
        case .attemptAlreadyRecorded: "This attempt has already been recorded."
        }
    }
}

/// Coordinates the explicit attempt-by-attempt competition flow while leaving
/// performed truth in the existing Workout/ExerciseSet graph. Attempt 1 may
/// display a rule-backed proposal; attempt 2 and 3 never receive an inferred
/// load and must be entered by the lifter.
struct CompetitionDayCoordinator: Equatable {
    let proposal: CompetitionPreparationProposal
    private(set) var attempts: [CompetitionDayAttemptDraft]

    init(proposal: CompetitionPreparationProposal) {
        self.proposal = proposal
        self.attempts = proposal.attempts
            .sorted {
                if $0.lift != $1.lift { return $0.lift.rawValue < $1.lift.rawValue }
                return $0.attemptNumber < $1.attemptNumber
            }
            .map { attempt in
                CompetitionDayAttemptDraft(
                    key: CompetitionDayAttemptKey(lift: attempt.lift, attemptNumber: attempt.attemptNumber),
                    proposedLoadKg: attempt.loadKg,
                    evidence: attempt.evidence,
                    expectedComponentCount: Self.componentCount(for: attempt.lift),
                    selectedLoadKg: attempt.loadKg,
                    recordedResult: nil
                )
            }
    }

    var recordedResults: [CompetitionDayRecordedResult] {
        attempts.compactMap(\.recordedResult)
    }

    var isComplete: Bool {
        attempts.allSatisfy { $0.isRecorded }
    }

    func attempt(for key: CompetitionDayAttemptKey) -> CompetitionDayAttemptDraft? {
        attempts.first { $0.key == key }
    }

    mutating func chooseLoad(_ loadKg: Double, for key: CompetitionDayAttemptKey) throws {
        guard let index = attempts.firstIndex(where: { $0.key == key }) else {
            throw CompetitionDayCoordinatorError.invalidAttempt
        }
        guard loadKg.isFinite, loadKg > 0 else {
            throw CompetitionDayCoordinatorError.invalidLoad
        }
        guard attempts[index].recordedResult == nil else {
            throw CompetitionDayCoordinatorError.attemptAlreadyRecorded
        }
        attempts[index].selectedLoadKg = loadKg
    }

    mutating func record(
        _ componentOutcomes: [ComplexComponentOutcome],
        liftQuality: LiftQuality? = nil,
        for key: CompetitionDayAttemptKey
    ) throws {
        guard let index = attempts.firstIndex(where: { $0.key == key }) else {
            throw CompetitionDayCoordinatorError.invalidAttempt
        }
        guard attempts[index].recordedResult == nil else {
            throw CompetitionDayCoordinatorError.attemptAlreadyRecorded
        }
        guard let loadKg = attempts[index].selectedLoadKg else {
            throw CompetitionDayCoordinatorError.loadRequired
        }
        guard loadKg.isFinite, loadKg > 0 else {
            throw CompetitionDayCoordinatorError.invalidLoad
        }
        guard componentOutcomes.count == attempts[index].expectedComponentCount else {
            throw CompetitionDayCoordinatorError.componentCountMismatch
        }
        guard componentOutcomes.allSatisfy({ $0 != .notStarted }) else {
            throw CompetitionDayCoordinatorError.componentOutcomeRequired
        }

        let outcome = CompetitionDayOutcomeAdapter.outcome(for: componentOutcomes)
        attempts[index].recordedResult = CompetitionDayRecordedResult(
            key: key,
            loadKg: loadKg,
            componentOutcomes: componentOutcomes,
            outcome: outcome,
            liftQuality: liftQuality
        )
    }

    private static func componentCount(for lift: CompetitionLift) -> Int {
        switch lift {
        case .snatch: 1
        case .cleanAndJerk: 2
        }
    }
}

/// Uses the persisted ExerciseSet's parent-outcome implementation for a
/// transient draft. This keeps the competition flow aligned with History's
/// component semantics instead of introducing a second outcome engine.
private enum CompetitionDayOutcomeAdapter {
    static func outcome(for componentOutcomes: [ComplexComponentOutcome]) -> OlympicAttemptOutcome {
        let set = ExerciseSet(usedMetric: .metric)
        set.complexComponents = componentOutcomes.enumerated().map { index, outcome in
            ComplexComponentResult(
                orderIndex: index,
                exerciseID: UUID(),
                exerciseNameSnapshot: "Competition component \(index + 1)",
                prescribedRepetitions: 1,
                performedRepetitions: outcome == .completed ? 1 : 0,
                outcome: outcome
            )
        }
        return set.olympicAttemptOutcome ?? .notStarted
    }
}

struct CompetitionDayPreparation {
    let programName: String?
    let proposal: CompetitionPreparationProposal?
    let evidence: [CompetitionLiftEvidence]
    let planStartDate: Date?
}

/// Builds a competition-day review from existing completed snapshots. Lift
/// identity comes only from authored stable exposure keys/IDs; display names
/// and component count are never used to classify a lift.
enum CompetitionDayPreparationService {
    /// Selects the authored definition that supplies competition identity.
    /// The selection is intentionally based on stable program IDs and authored
    /// discipline metadata; display names are never used as an identity key.
    static func selectedProgram(
        workouts: [Workout],
        definitions: [ProgramDefinitionRecord]
    ) -> (record: ProgramDefinitionRecord, payload: ProgramDefinitionPayload)? {
        let candidates = definitions.compactMap { record -> (ProgramDefinitionRecord, ProgramDefinitionPayload)? in
            guard !record.isArchived, let payload = try? record.payload() else { return nil }
            return (record, payload)
        }
        let sourceIDs = Set(workouts.compactMap(\.sourceProgramDefinitionID))
        return candidates.first { sourceIDs.contains($0.0.id) }
            ?? candidates.first { $0.1.competitionDisciplineID == "olympicWeightlifting" }
    }

    static func prepare(
        workouts: [Workout],
        definitions: [ProgramDefinitionRecord],
        planRuns: [PlanRun],
        eventDate: Date,
        asOfDate: Date = .now
    ) -> CompetitionDayPreparation {
        let selected = selectedProgram(workouts: workouts, definitions: definitions)

        let evidence: [CompetitionLiftEvidence] = selected.map {
            buildEvidence(from: workouts, program: $0.1)
        } ?? []
        guard let selected else {
            return CompetitionDayPreparation(
                programName: nil,
                proposal: nil,
                evidence: evidence,
                planStartDate: nil
            )
        }

        let planStartDate = planStartDate(
            for: selected.1.id,
            workouts: workouts,
            planRuns: planRuns
        )
        let proposal = CompetitionPreparationRules.propose(
            CompetitionPreparationRequest(
                eventDate: eventDate,
                asOfDate: asOfDate,
                planStartDate: planStartDate,
                program: selected.1,
                performedEvidence: evidence
            )
        )
        return CompetitionDayPreparation(
            programName: selected.1.name,
            proposal: proposal,
            evidence: evidence,
            planStartDate: planStartDate
        )
    }

    private static func buildEvidence(
        from workouts: [Workout],
        program: ProgramDefinitionPayload
    ) -> [CompetitionLiftEvidence] {
        let identity = liftIdentity(in: program)
        return workouts
            .filter { $0.status == .completed }
            .sorted { $0.startTime < $1.startTime }
            .flatMap { workout -> [CompetitionLiftEvidence] in
                workout.orderedExercises.flatMap { entry -> [CompetitionLiftEvidence] in
                    guard entry.sportDisciplineSnapshotRaw == SportDiscipline.olympicWeightlifting.rawValue else {
                        return []
                    }
                    let lift = entry.progressionKey.flatMap { identity.byExposureKey[$0] }
                        ?? entry.exerciseIDSnapshot.flatMap { identity.byExerciseID[$0] }
                    guard let lift else { return [] }
                    return entry.orderedSets
                        .filter { $0.done && !$0.complexComponents.isEmpty }
                        .map { set in
                            let rawLoad = Double(set.weight)
                            let loadKg = rawLoad.isFinite && rawLoad > 0
                                ? Double(UnitConversion.weight(set.weight, from: set.weightType, to: .kg))
                                : nil
                            return CompetitionLiftEvidence(
                                lift: lift,
                                date: workout.startTime,
                                sourceWorkoutID: workout.id,
                                sourceSetID: set.id,
                                loadKg: loadKg,
                                outcome: set.olympicAttemptOutcome ?? .notStarted,
                                liftQuality: set.liftQuality
                            )
                        }
                }
            }
    }

    private static func liftIdentity(
        in program: ProgramDefinitionPayload
    ) -> (byExposureKey: [String: CompetitionLift], byExerciseID: [UUID: CompetitionLift]) {
        var byExposureKey: [String: CompetitionLift] = [:]
        var byExerciseID: [UUID: CompetitionLift] = [:]
        for exercise in program.blocks.flatMap(\.weeks).flatMap(\.workouts).flatMap(\.plannedExercises) {
            let lift: CompetitionLift?
            switch exercise.exposureKey {
            case "snatch", "snatch-test": lift = .snatch
            case "clean-jerk", "clean-jerk-test": lift = .cleanAndJerk
            default: lift = nil
            }
            guard let lift else { continue }
            byExposureKey[exercise.exposureKey] = lift
            byExerciseID[exercise.exerciseID] = lift
            byExerciseID[exercise.id] = lift
        }
        return (byExposureKey, byExerciseID)
    }

    private static func planStartDate(
        for programID: UUID,
        workouts: [Workout],
        planRuns: [PlanRun]
    ) -> Date? {
        let matchingWorkoutRunIDs = Set(
            workouts
                .filter { $0.sourceProgramDefinitionID == programID }
                .compactMap(\.sourcePlanRunID)
        )
        if let run = planRuns.first(where: { matchingWorkoutRunIDs.contains($0.id) }) {
            return run.startDate
        }
        return planRuns
            .filter { $0.plan?.sourceProgramDefinitionID == programID }
            .sorted { $0.startDate < $1.startDate }
            .first?
            .startDate
    }
}

/// Compiles the explicit competition attempts into the existing active
/// Workout graph. This is a prescription snapshot only: performed outcomes
/// are still entered and finalized by ActiveWorkout/WorkoutViewModel, so the
/// competition flow cannot create a second History truth.
enum CompetitionDayWorkoutBuilder {
    enum Error: Swift.Error, Equatable, LocalizedError {
        case unsupportedProgram
        case missingAuthoredLift(CompetitionLift)
        case missingExercise(UUID)

        var errorDescription: String? {
            switch self {
            case .unsupportedProgram: String(localized: "This program is not authored for Olympic weightlifting.")
            case .missingAuthoredLift(let lift):
                String(format: String(localized: "The authored program is missing the %@ competition lift."), lift.displayName)
            case .missingExercise(let id):
                String(format: String(localized: "The authored program references an unavailable exercise (%@)."), id.uuidString)
            }
        }
    }

    static func build(
        program: ProgramDefinitionPayload,
        proposal: CompetitionPreparationProposal,
        exercisesByID: [UUID: Exercise],
        unitSystem: UnitSystem
    ) throws -> Workout {
        guard program.competitionDisciplineID == "olympicWeightlifting" else {
            throw Error.unsupportedProgram
        }

        let authored = authoredLifts(in: program)
        let workout = Workout(name: String(localized: "Competition day"))
        workout.sourceProgramDefinitionID = program.id
        workout.sourceProgramDefinitionVersion = program.templateVersion

        for (index, lift) in CompetitionLift.allCases.enumerated() {
            guard let definition = authored[lift] else { throw Error.missingAuthoredLift(lift) }
            guard let exercise = exercisesByID[definition.exerciseID] else {
                throw Error.missingExercise(definition.exerciseID)
            }
            let entry = ExerciseEntry(exercise: exercise, orderIndex: index, usedMetric: unitSystem)
            entry.progressionKey = definition.exposureKey
            entry.prescribedRole = .main
            entry.prescribedSets = 3
            entry.prescriptionNotes = String(localized: "Competition attempts are recorded as performed history when the workout is saved.")

            let components = authoredComponents(for: definition, exercisesByID: exercisesByID)
            let attempts = proposal.attempts(for: lift)
            for number in 1...3 {
                let authoredAttempt = attempts.first { $0.attemptNumber == number }
                let set = ExerciseSet(
                    repetitions: 1,
                    weight: Float(authoredAttempt?.loadKg ?? 0),
                    orderIndex: number - 1,
                    usedMetric: unitSystem
                )
                set.prescribedSetType = .test
                set.prescribedRepetitions = 1
                set.prescribedSuggestedLoad = authoredAttempt?.loadKg
                set.prescribedSuggestedLoadType = unitSystem == .metric ? .kg : .lbs
                set.prescriptionNotes = number == 1
                    ? String(localized: "Opening attempt proposal; review the linked evidence before lifting.")
                    : String(localized: "Load intentionally left for explicit review.")
                set.complexComponents = components.map { component in
                    ComplexComponentResult(
                        orderIndex: component.orderIndex,
                        exerciseID: component.exerciseID,
                        exerciseNameSnapshot: component.name,
                        prescribedRepetitions: component.repetitions
                    )
                }
                entry.sets.append(set)
            }
            workout.exercises.append(entry)
        }
        return workout
    }

    private struct Component {
        let orderIndex: Int
        let exerciseID: UUID
        let name: String
        let repetitions: Int
    }

    private static func authoredLifts(in program: ProgramDefinitionPayload) -> [CompetitionLift: ProgramExerciseDefinition] {
        let exercises = program.blocks
            .flatMap(\.weeks)
            .flatMap(\.workouts)
            .flatMap(\.plannedExercises)
            .sorted { $0.orderIndex < $1.orderIndex }
        var result: [CompetitionLift: ProgramExerciseDefinition] = [:]
        for exercise in exercises {
            let lift: CompetitionLift?
            switch exercise.exposureKey {
            case "snatch", "snatch-test": lift = .snatch
            case "clean-jerk", "clean-jerk-test": lift = .cleanAndJerk
            default: lift = nil
            }
            if let lift, result[lift] == nil { result[lift] = exercise }
        }
        return result
    }

    private static func authoredComponents(
        for definition: ProgramExerciseDefinition,
        exercisesByID: [UUID: Exercise]
    ) -> [Component] {
        guard let prescription = definition.plannedSets.sorted(by: { $0.orderIndex < $1.orderIndex }).first,
              case .sequence(let sequence) = prescription.repetitions,
              !sequence.isEmpty else {
            let name = exercisesByID[definition.exerciseID]?.name ?? definition.exposureKey
            return [Component(orderIndex: 0, exerciseID: definition.exerciseID, name: name, repetitions: 1)]
        }
        return sequence.enumerated().map { index, component in
            Component(
                orderIndex: index,
                exerciseID: component.exerciseID,
                name: component.exerciseNameSnapshot ?? exercisesByID[component.exerciseID]?.name ?? "Component \(index + 1)",
                repetitions: max(1, component.repetitions)
            )
        }
    }
}

/// Persistence gate for the competition start handoff. Keeping this check
/// beside the builder makes the active-run invariant testable without a view
/// and ensures relaunch restoration sees the same ordinary Workout row.
enum CompetitionDayStartService {
    enum Error: Swift.Error, Equatable {
        case activeWorkoutInProgress
        case persistenceFailed
    }

    @MainActor
    static func persist(_ workout: Workout, using context: ModelContext) throws {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.endTime == nil }
        )
        let existing = try context.fetch(descriptor)
        guard existing.contains(where: { $0.status == .active }) == false else {
            throw Error.activeWorkoutInProgress
        }
        context.insert(workout)
        guard context.saveOrRollback() else {
            throw Error.persistenceFailed
        }
    }
}

extension CompetitionLift {
    nonisolated var displayName: String {
        switch self {
        case .snatch: String(localized: "Snatch")
        case .cleanAndJerk: String(localized: "Clean and jerk")
        }
    }
}
