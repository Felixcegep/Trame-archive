import Foundation

enum RepeatingPlanRunStatus: String, Codable, CaseIterable {
    case active
    case paused
    case ended
    case archived
}

enum RepeatingPlanOccurrenceKind: String, Codable, CaseIterable {
    case expected
    case repeatWorkout
    case alternate
    case skip
    case restart
}

enum RepeatingPlanContinuationMode: String, Codable, CaseIterable {
    case keepExpected
    case continueAfterSelected
}

enum RepeatingPlanOccurrenceStatus: String, Codable, CaseIterable {
    case upcoming
    case inProgress
    case completed
    case skipped
    case undone
}

enum RepeatingPlanValidationIssue: Equatable {
    case emptyName
    case noSlots
    case duplicateSlotOrder(Int)
    case unavailableTemplate(UUID)
    case invalidCursor
}

enum RepeatingPlanWorkoutStartCommand: Equatable {
    case expected
    case repeatLast
    case alternate(
        slotIndex: Int,
        continuationMode: RepeatingPlanContinuationMode
    )
}
