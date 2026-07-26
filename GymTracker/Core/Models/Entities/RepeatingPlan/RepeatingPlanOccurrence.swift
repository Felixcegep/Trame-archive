import Foundation
import SwiftData

@Model
final class RepeatingPlanOccurrence {
    var id = UUID()
    var cycleIndex: Int
    var expectedSlotIndex: Int
    var selectedSlotIndex: Int?
    var kind: RepeatingPlanOccurrenceKind
    var continuationMode: RepeatingPlanContinuationMode
    var status: RepeatingPlanOccurrenceStatus
    var cursorBefore: Int
    var cursorAfter: Int
    var cycleBefore: Int
    var cycleAfter: Int
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var undoneAt: Date?
    var run: RepeatingPlanRun?
    var completedWorkout: Workout?

    init(
        cycleIndex: Int,
        expectedSlotIndex: Int,
        selectedSlotIndex: Int? = nil,
        kind: RepeatingPlanOccurrenceKind = .expected,
        continuationMode: RepeatingPlanContinuationMode = .continueAfterSelected,
        status: RepeatingPlanOccurrenceStatus = .upcoming,
        cursorBefore: Int,
        cursorAfter: Int,
        cycleBefore: Int? = nil,
        cycleAfter: Int? = nil,
        createdAt: Date = .now,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        undoneAt: Date? = nil,
        completedWorkout: Workout? = nil
    ) {
        self.cycleIndex = cycleIndex
        self.expectedSlotIndex = expectedSlotIndex
        self.selectedSlotIndex = selectedSlotIndex
        self.kind = kind
        self.continuationMode = continuationMode
        self.status = status
        self.cursorBefore = cursorBefore
        self.cursorAfter = cursorAfter
        self.cycleBefore = cycleBefore ?? cycleIndex
        self.cycleAfter = cycleAfter ?? cycleIndex
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.undoneAt = undoneAt
        self.completedWorkout = completedWorkout
    }
}
