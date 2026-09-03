//
//  Workout.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import Foundation
import SwiftData

/// The mutation boundary shared by every active-workout model. A completed
/// workout is historical truth; attempts to edit its graph are rejected in
/// Release builds as well as Debug builds.
nonisolated enum WorkoutMutationOperation: String, Codable, Equatable, Sendable {
    case addWorkoutEntry
    case removeWorkoutEntry
    case updateWorkoutName
    case updateWorkoutNotes
    case updateWorkoutStartTime
    case normalizeWorkoutOrder
    case addExerciseSet
    case removeExerciseSet
    case updateExerciseComment
    case updateExerciseSnapshot
    case applySubstitutionDecision
    case copyLastSet
    case normalizeExerciseOrder
    case startExerciseDuration
    case stopExerciseDuration
    case applyStrongmanEvidence
    case ensureSetSegments
    case synchronizeSetSegmentCompletion
    case clearSetPrescription
    case ensureComplexComponents
    case synchronizeComplexCompletion
    case normalizeSegmentOrder
    case startExecutionBlock
    case pauseExecutionBlock
    case updateExecutionBlock
    case removeExecutionBlock
    case completeExecutionBlock
    case capExecutionBlock
    case stopExecutionBlock
    case updateExecutionBlockScore
}

nonisolated enum WorkoutMutationError: Error, Equatable, LocalizedError, Sendable {
    case completedWorkoutMutation(WorkoutMutationOperation)

    var errorDescription: String? {
        switch self {
        case .completedWorkoutMutation(let operation):
            return "Cannot perform \(operation.rawValue) on a completed workout."
        }
    }
}

nonisolated enum WorkoutMutationResult: Equatable, Sendable {
    case applied
    case rejected(WorkoutMutationError)

    var isApplied: Bool {
        if case .applied = self { return true }
        return false
    }
}

nonisolated enum WorkoutMutationGuard {
    static func rejectionIfCompleted(
        _ isCompleted: Bool,
        operation: WorkoutMutationOperation
    ) -> WorkoutMutationResult? {
        isCompleted ? .rejected(.completedWorkoutMutation(operation)) : nil
    }
}

@Model
class Workout {
    /// Stable cross-process identity for the workout represented by a Live Activity
    /// and for durable prescription evidence.
    var id = UUID()
    var status: WorkoutStatus = WorkoutStatus.active
    var name: String?
    var notes: String?
    /// What kind of training this session was, asked once on the save screen.
    ///
    /// Optional on purpose: saving without answering is allowed, and a `nil`
    /// here means "not answered", never "Other". History and Progress both
    /// treat it as a filter, so an invented value would quietly poison the
    /// split rather than leave a gap.
    var sportRawValue: String?
    /// Whether ``sportRawValue`` came from ``SessionSportDetector`` and was left
    /// untouched. Corrections are the only signal available for tuning the
    /// detector later, and they are only legible next to what was guessed.
    var sportWasAutoDetected: Bool = false
    var startTime: Date
    var endTime: Date?
    var restEndDate: Date?
    var pausedRemainingTime: Double?
    var sourceTemplate: WorkoutTemplate?
    var sourcePlanID: UUID?
    var sourcePlanRunID: UUID?
    var sourcePlanBlockID: UUID?
    var sourcePlanWeekID: UUID?
    var sourcePlannedWorkoutID: UUID?
    var sourcePlanName: String?
    var sourceProgramDefinitionID: UUID?
    var sourceProgramDefinitionVersion: Int?
    var sourceRepeatingPlanID: UUID?
    var sourceRepeatingPlanRunID: UUID?
    var sourceRepeatingPlanOccurrenceID: UUID?
    var sourceRepeatingPlanName: String?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseEntry.workout)
    var exercises: [ExerciseEntry] = []
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExecutionBlock.workout)
    var executionBlocks: [WorkoutExecutionBlock] = []
    @Relationship(deleteRule: .nullify, inverse: \RepeatingPlanOccurrence.completedWorkout)
    var repeatingPlanOccurrences: [RepeatingPlanOccurrence] = []
    
    init(name: String?, endTime: Date? = nil) {
        self.status = endTime == nil ? .active : .completed
        self.name = name
        self.notes = nil
        self.startTime = Date.now
        self.endTime = endTime
        self.restEndDate = nil
        self.pausedRemainingTime = nil
        self.sourceTemplate = nil
        self.sourcePlanID = nil
        self.sourcePlanRunID = nil
        self.sourcePlanBlockID = nil
        self.sourcePlanWeekID = nil
        self.sourcePlannedWorkoutID = nil
        self.sourcePlanName = nil
        self.sourceProgramDefinitionID = nil
        self.sourceProgramDefinitionVersion = nil
        self.sourceRepeatingPlanID = nil
        self.sourceRepeatingPlanRunID = nil
        self.sourceRepeatingPlanOccurrenceID = nil
        self.sourceRepeatingPlanName = nil
        self.executionBlocks = []
    }
    init(template : WorkoutTemplate, unitSystem : UnitSystem){
        self.status = .active
        self.name = template.name
        self.notes = nil
        self.startTime = Date.now
        self.restEndDate = nil
        self.pausedRemainingTime = nil
        self.sourceTemplate = template
        self.sourcePlanID = nil
        self.sourcePlanRunID = nil
        self.sourcePlanBlockID = nil
        self.sourcePlanWeekID = nil
        self.sourcePlannedWorkoutID = nil
        self.sourcePlanName = nil
        self.sourceProgramDefinitionID = nil
        self.sourceProgramDefinitionVersion = nil
        self.sourceRepeatingPlanID = nil
        self.sourceRepeatingPlanRunID = nil
        self.sourceRepeatingPlanOccurrenceID = nil
        self.sourceRepeatingPlanName = nil
        self.exercises = []
        self.executionBlocks = []
        var snapshotGroupIDs: [UUID: UUID] = [:]
        for (index, templateExercise) in template.orderedTemplateExercises.enumerated() {
            let groupID: UUID?
            if let sourceID = templateExercise.supersetGroupID {
                if let existingID = snapshotGroupIDs[sourceID] {
                    groupID = existingID
                } else {
                    let freshID = UUID()
                    snapshotGroupIDs[sourceID] = freshID
                    groupID = freshID
                }
            } else {
                groupID = nil
            }
            exercises.append(
                ExerciseEntry(
                    from: templateExercise,
                    orderIndex: index,
                    usedMetric: unitSystem,
                    supersetGroupID: groupID
                )
            )
        }
        snapshotExecutionBlocks(
            from: template.orderedExecutionBlocks.map { block in
                ExecutionBlockSnapshotSource(
                    id: block.id,
                    orderIndex: block.orderIndex,
                    kind: block.kind,
                    name: block.name,
                    targetRounds: block.targetRounds,
                    isSharedLoad: block.isSharedLoad,
                    restSeconds: block.restSeconds,
                    clockMode: block.clockMode,
                    prescribedDurationSeconds: block.prescribedDurationSeconds,
                    timeCapSeconds: block.timeCapSeconds,
                    intervalSeconds: block.intervalSeconds,
                    scoreKind: block.scoreKind,
                    repetitionScheme: block.repetitionScheme,
                    repetitionStart: block.repetitionStart,
                    repetitionEnd: block.repetitionEnd,
                    repetitionStep: block.repetitionStep,
                    definitionBlockKey: nil,
                    sourceTemplateBlockID: block.id,
                    sourcePlannedBlockID: nil
                )
            },
            sourceMembership: template.orderedTemplateExercises.map {
                ExecutionBlockMembershipSnapshotSource(
                    sourceBlockID: $0.executionBlockID,
                    componentOrder: $0.executionBlockComponentOrder
                )
            }
        )
    }

    @MainActor
    convenience init(plannedWorkout: PlannedWorkout, planRun: PlanRun, unitSystem: UnitSystem) {
        self.init(name: plannedWorkout.name)
        self.sourceTemplate = plannedWorkout.sourceTemplate
        self.sourcePlanID = planRun.sourcePlanID
        self.sourcePlanRunID = planRun.id
        self.sourcePlanBlockID = plannedWorkout.week?.block?.id
        self.sourcePlanWeekID = plannedWorkout.week?.id
        self.sourcePlannedWorkoutID = plannedWorkout.id
        self.sourcePlanName = planRun.sourcePlanName
        self.sourceProgramDefinitionID = plannedWorkout.week?.block?.plan?.sourceProgramDefinitionID
        self.sourceProgramDefinitionVersion = plannedWorkout.week?.block?.plan?.sourceProgramDefinitionVersion

        self.exercises = []
        self.executionBlocks = []
        var snapshotGroupIDs: [UUID: UUID] = [:]
        #if !GYMTRACKER_EXTENSION
        let futureExercises = plannedWorkout.orderedPlannedExercises.filter {
            !PlanProgressionTransitionService.isExerciseEnded($0.progressionKey, in: planRun)
        }
        #else
        let futureExercises = plannedWorkout.orderedPlannedExercises
        #endif
        for (index, plannedExercise) in futureExercises.enumerated() {
            let groupID: UUID?
            if let sourceID = plannedExercise.supersetGroupID {
                if let existingID = snapshotGroupIDs[sourceID] {
                    groupID = existingID
                } else {
                    let freshID = UUID()
                    snapshotGroupIDs[sourceID] = freshID
                    groupID = freshID
                }
            } else {
                groupID = nil
            }
            #if !GYMTRACKER_EXTENSION
            let snapshotExercise = ProgramPrescriptionSnapshotService.resolvedExercise(for: plannedExercise, in: planRun)
            #else
            let snapshotExercise = plannedExercise.exercise
            #endif
            let entry = ExerciseEntry(
                from: plannedExercise,
                exercise: snapshotExercise,
                orderIndex: index,
                usedMetric: unitSystem,
                supersetGroupID: groupID
            )
            if snapshotExercise.id != plannedExercise.exercise.id {
                entry.variationSourceExerciseIDSnapshot = plannedExercise.exercise.id
                entry.variationSelectedExerciseIDSnapshot = snapshotExercise.id
            }
            PlanDeloadService.apply(to: entry, for: plannedWorkout.week?.block)
#if !GYMTRACKER_EXTENSION
            ProgramPrescriptionSnapshotService.apply(
                to: entry,
                plannedExercise: plannedExercise,
                run: planRun,
                unitSystem: unitSystem
            )
#endif
            exercises.append(entry)
        }
        snapshotExecutionBlocks(
            from: plannedWorkout.orderedExecutionBlocks.map { block in
                ExecutionBlockSnapshotSource(
                    id: block.id,
                    orderIndex: block.orderIndex,
                    kind: block.kind,
                    name: block.name,
                    targetRounds: block.targetRounds,
                    isSharedLoad: block.isSharedLoad,
                    restSeconds: block.restSeconds,
                    clockMode: block.clockMode,
                    prescribedDurationSeconds: block.prescribedDurationSeconds,
                    timeCapSeconds: block.timeCapSeconds,
                    intervalSeconds: block.intervalSeconds,
                    scoreKind: block.scoreKind,
                    repetitionScheme: block.repetitionScheme,
                    repetitionStart: block.repetitionStart,
                    repetitionEnd: block.repetitionEnd,
                    repetitionStep: block.repetitionStep,
                    definitionBlockKey: block.definitionBlockKey,
                    sourceTemplateBlockID: block.sourceTemplateBlockID,
                    sourcePlannedBlockID: block.id
                )
            },
            sourceMembership: futureExercises.map {
                ExecutionBlockMembershipSnapshotSource(
                    sourceBlockID: $0.executionBlockID,
                    componentOrder: $0.executionBlockComponentOrder
                )
            }
        )
    }

    /// Single source of truth for whether a workout has been finalized and saved into History.
    var isCompleted: Bool { status == .completed }

    /// Single source of truth for what a workout is called across the save
    /// flow, History list, and History detail: the explicit name when set,
    /// otherwise a title derived from its exercises.
    var displayTitle: String {
        let explicitName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard explicitName.isEmpty else { return explicitName }

        let exerciseNames = orderedExercises.map(\.nameSnapshot)
        switch exerciseNames.count {
        case 0:
            return String(localized: "Workout")
        case 1:
            return exerciseNames[0]
        case 2:
            return "\(exerciseNames[0]) + \(exerciseNames[1])"
        default:
            return "\(exerciseNames[0]) + \(exerciseNames.count - 1) more"
        }
    }

    /// Typed access to the persisted sport. Stored as a raw string so adding a
    /// case later is not a schema migration, and an unrecognised value read back
    /// from an older build degrades to `nil` rather than trapping.
    var sport: SessionSport? {
        get { sportRawValue.flatMap(SessionSport.init(rawValue:)) }
        set {
            sportRawValue = newValue?.rawValue
            if newValue == nil { sportWasAutoDetected = false }
        }
    }

    /// The session's exercises reduced to what ``SessionSportDetector`` reads.
    ///
    /// Only exercises with at least one completed set count: an exercise that
    /// was added and then skipped says nothing about what the session was.
    var sportDetectionInputs: [ExerciseDetectionInput] {
        orderedExercises
            .filter { $0.sets.contains(where: \.done) }
            .map { entry in
                // Category, equipment and resistance are all optional on
                // `Exercise`. An unclassified exercise should contribute no
                // signal rather than a wrong one, and `.other` is the value
                // every rule ignores.
                ExerciseDetectionInput(
                    name: entry.nameSnapshot,
                    category: entry.exercise.category ?? .other,
                    equipment: entry.exercise.equipmentType ?? .other,
                    resistance: entry.exercise.resistanceType ?? .other,
                    tracking: entry.trackingTypeSnapshot,
                    isInsideConditioningBlock: entry.executionBlockID != nil
                )
            }
    }

    /// Whether any completed work in this session was loaded by the lifter's own
    /// body — the condition under which body weight stops being trivia and
    /// starts being the denominator of the set.
    var usesBodyweightLoading: Bool {
        let bodyweightResistances: [ResistanceType] = [.bodyweight, .assistedBodyweight, .weightedBodyweight]
        return orderedExercises.contains { entry in
            guard entry.sets.contains(where: \.done) else { return false }
            guard let resistance = entry.exercise.resistanceType else { return false }
            return bodyweightResistances.contains(resistance)
        }
    }

    var orderedExercises: [ExerciseEntry] {
        exercises.sorted(by: { lhs, rhs in
            if lhs.orderIndex != rhs.orderIndex {
                return lhs.orderIndex < rhs.orderIndex
            }
            if lhs.nameSnapshot != rhs.nameSnapshot {
                return lhs.nameSnapshot.localizedStandardCompare(rhs.nameSnapshot) == .orderedAscending
            }
            return lhs.exercise.id.uuidString < rhs.exercise.id.uuidString
        })
    }

    var orderedExecutionBlocks: [WorkoutExecutionBlock] {
        executionBlocks.sorted(by: { lhs, rhs in
            if lhs.orderIndex != rhs.orderIndex {
                return lhs.orderIndex < rhs.orderIndex
            }
            return lhs.id.uuidString < rhs.id.uuidString
        })
    }

    @discardableResult
    func addEntry(_ entry: ExerciseEntry) -> WorkoutMutationResult {
        if let rejection = WorkoutMutationGuard.rejectionIfCompleted(
            isCompleted,
            operation: .addWorkoutEntry
        ) { return rejection }
        exercises.append(entry)
        _ = normalizeExerciseOrder()
        return .applied
    }

    @discardableResult
    func removeEntry(_ entry: ExerciseEntry) -> WorkoutMutationResult {
        if let rejection = WorkoutMutationGuard.rejectionIfCompleted(
            isCompleted,
            operation: .removeWorkoutEntry
        ) { return rejection }
        exercises.removeAll(where: { $0.id == entry.id })
        _ = normalizeExerciseOrder()
        return .applied
    }

    @discardableResult
    func updateName(_ newName: String?) -> WorkoutMutationResult {
        if let rejection = WorkoutMutationGuard.rejectionIfCompleted(
            isCompleted,
            operation: .updateWorkoutName
        ) { return rejection }
        self.name = newName
        return .applied
    }

    @discardableResult
    func updateNotes(_ newNotes: String?) -> WorkoutMutationResult {
        if let rejection = WorkoutMutationGuard.rejectionIfCompleted(
            isCompleted,
            operation: .updateWorkoutNotes
        ) { return rejection }
        self.notes = newNotes
        return .applied
    }

    /// Elapsed gym time, from start until `endTime` or `date`.
    func elapsedDuration(at date: Date = .now) -> TimeInterval {
        let end = endTime ?? date
        return max(0, end.timeIntervalSince(startTime))
    }

    /// Corrects how long this active session lasted by moving `startTime`.
    /// Completed history cannot be rewritten here; `endTime` is still stamped
    /// by save.
    @discardableResult
    func updateElapsedDuration(_ duration: TimeInterval, at now: Date = .now) -> WorkoutMutationResult {
        if let rejection = WorkoutMutationGuard.rejectionIfCompleted(
            isCompleted,
            operation: .updateWorkoutStartTime
        ) { return rejection }
        let clamped = min(
            Constants.Session.maximumDuration,
            max(Constants.Session.minimumDuration, duration)
        )
        startTime = now.addingTimeInterval(-clamped)
        return .applied
    }

    @discardableResult
    func normalizeExerciseOrder() -> WorkoutMutationResult {
        if let rejection = WorkoutMutationGuard.rejectionIfCompleted(
            isCompleted,
            operation: .normalizeWorkoutOrder
        ) { return rejection }
        for (index, exercise) in orderedExercises.enumerated() {
            exercise.orderIndex = index
            _ = exercise.normalizeSetOrder()
        }
        SupersetGrouping.dissolveInvalidGroups(in: orderedExercises)
        for (index, block) in orderedExecutionBlocks.enumerated() {
            block.orderIndex = index
        }
        return .applied
    }

    private struct ExecutionBlockSnapshotSource {
        let id: UUID
        let orderIndex: Int
        let kind: ExerciseBlockKind
        let name: String?
        let targetRounds: Int?
        let isSharedLoad: Bool
        let restSeconds: Int?
        let clockMode: BlockClockMode
        let prescribedDurationSeconds: Int?
        let timeCapSeconds: Int?
        let intervalSeconds: Int?
        let scoreKind: BlockScoreKind
        let repetitionScheme: BlockRepetitionScheme
        let repetitionStart: Int?
        let repetitionEnd: Int?
        let repetitionStep: Int?
        let definitionBlockKey: String?
        let sourceTemplateBlockID: UUID?
        let sourcePlannedBlockID: UUID?
    }

    private struct ExecutionBlockMembershipSnapshotSource {
        let sourceBlockID: UUID?
        let componentOrder: Int?
    }

    private func snapshotExecutionBlocks(
        from sources: [ExecutionBlockSnapshotSource],
        sourceMembership: [ExecutionBlockMembershipSnapshotSource]
    ) {
        guard !sources.isEmpty else { return }
        var snapshotIDs: [UUID: UUID] = [:]
        executionBlocks = sources.map { source in
            let block = WorkoutExecutionBlock(
                orderIndex: source.orderIndex,
                kind: source.kind,
                name: source.name,
                targetRounds: source.targetRounds,
                isSharedLoad: source.isSharedLoad,
                restSeconds: source.restSeconds,
                clockMode: source.clockMode,
                prescribedDurationSeconds: source.prescribedDurationSeconds,
                timeCapSeconds: source.timeCapSeconds,
                intervalSeconds: source.intervalSeconds,
                scoreKind: source.scoreKind,
                repetitionScheme: source.repetitionScheme,
                repetitionStart: source.repetitionStart,
                repetitionEnd: source.repetitionEnd,
                repetitionStep: source.repetitionStep
            )
            block.sourceTemplateBlockID = source.sourceTemplateBlockID
            block.sourcePlannedBlockID = source.sourcePlannedBlockID
            block.sourceDefinitionBlockKey = source.definitionBlockKey
            snapshotIDs[source.id] = block.id
            return block
        }
        for (index, membership) in sourceMembership.enumerated() {
            guard index < exercises.count,
                  let sourceID = membership.sourceBlockID,
                  let snapshotID = snapshotIDs[sourceID]
            else { continue }
            exercises[index].executionBlockID = snapshotID
            exercises[index].executionBlockComponentOrder = membership.componentOrder ?? index
        }
    }

    var completedSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter(\.done).count }
    }

    var incompleteSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter { !$0.done }.count }
    }

    var totalSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
}
