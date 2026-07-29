import Foundation

/// A read-only representation of one repeating-plan run. It is deliberately
/// derived from the run's immutable slots and occurrence audit trail rather
/// than persisted as a second rotation record.
struct RotationProgramPathProjection: Equatable {
    let source: ProgramPathSource = .rotation
    let runID: UUID
    let sourcePlanID: UUID
    let title: String
    let runStatus: RepeatingPlanRunStatus
    /// Zero-based persisted cycle position. Use `currentCycleNumber` for copy.
    let currentCycleIndex: Int
    let completedCycleCount: Int
    let currentSlotIndex: Int?
    let slotCount: Int
    let nextWorkout: RotationProgramPathNextWorkout?
    let currentCycleSlots: [RotationProgramPathSlot]
    let history: [RotationProgramPathOccurrence]
    let primaryAction: ProgramPathAction?
    let warnings: [RotationProgramPathWarning]

    var currentCycleNumber: Int { currentCycleIndex + 1 }
    var hasWarnings: Bool { !warnings.isEmpty }
}

struct RotationProgramPathNextWorkout: Equatable {
    let slotID: UUID
    let slotIndex: Int
    let workoutName: String
    let isTemplateAvailable: Bool
}

/// One ordered slot as it appears in the current rotation cycle. A current
/// occurrence is independent from the cursor: an alternate can be in progress
/// while the expected cursor remains on another slot.
struct RotationProgramPathSlot: Identifiable, Equatable {
    let id: UUID
    let slotIndex: Int
    let workoutName: String
    let isTemplateAvailable: Bool
    let isCursor: Bool
    let occurrenceState: RotationProgramPathSlotOccurrenceState?
}

enum RotationProgramPathSlotOccurrenceState: Equatable {
    case inProgress
    case completed
    case skipped
}

/// A direct translation of a persisted occurrence decision. Names are copied
/// from run-slot snapshots so source-plan edits or deletion cannot reinterpret
/// the history.
struct RotationProgramPathOccurrence: Identifiable, Equatable {
    let id: UUID
    /// Zero-based persisted cycle. Use `cycleNumber` for user-facing copy.
    let cycleIndex: Int
    let expectedSlot: RotationProgramPathSlotReference
    let selectedSlot: RotationProgramPathSlotReference?
    let kind: RepeatingPlanOccurrenceKind
    let continuationMode: RepeatingPlanContinuationMode
    let status: RepeatingPlanOccurrenceStatus
    let cursorBefore: Int
    let cursorAfter: Int
    let cycleBefore: Int
    let cycleAfter: Int
    let createdAt: Date
    let startedAt: Date?
    let completedAt: Date?
    let undoneAt: Date?
    let completedWorkoutID: UUID?

    var cycleNumber: Int { cycleIndex + 1 }
    var didAdvance: Bool {
        cursorBefore != cursorAfter || cycleBefore != cycleAfter
    }
}

struct RotationProgramPathSlotReference: Equatable {
    let slotIndex: Int
    let workoutName: String?
    let isValid: Bool
}

enum RotationProgramPathWarning: Equatable {
    case noSlots
    case invalidCursor(currentSlotIndex: Int, slotCount: Int)
    case invalidCompletedCycleCount(Int)
    case duplicateSlotOrder(Int)
    case unavailableTemplate(slotID: UUID, slotIndex: Int, workoutName: String)
    case multipleInProgressOccurrences(count: Int)
    case invalidOccurrence(occurrenceID: UUID)
}
