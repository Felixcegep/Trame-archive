import Foundation
import SwiftData

// MARK: - Requests carried through the start → warm-up → save → cooldown chain

/// What the user asked to start, before anything has been written. It is held
/// while the start waits on a conflict answer or an optional warm-up, which is
/// why it has to be a value and not a half-created `Workout`.
enum PendingWorkoutStart {
    case template(WorkoutTemplate)
    case planned(PendingPlannedWorkout)
    case repeating(RepeatingPlanRun, RepeatingPlanWorkoutStartCommand)
}

struct PendingPlannedWorkout {
    let planRun: PlanRun
    let progress: PlanWorkoutProgress
    let plannedWorkout: PlannedWorkout
}

/// A start that has cleared the guided-source check, carrying the warm-up the
/// user may still decline. A `nil` routine means there was never one to offer
/// rather than that one was skipped: both reach the same start path, so the
/// distinction is deliberately not preserved past this point.
struct WorkoutPreparationRequest {
    let start: PendingWorkoutStart
    let warmupRoutine: MobilityRoutine?

    init(start: PendingWorkoutStart, warmupRoutine: MobilityRoutine? = nil) {
        self.start = start
        self.warmupRoutine = warmupRoutine
    }
}

struct MobilityRoutineLaunchRequest {
    let routine: MobilityRoutine
    let context: MobilitySessionContext
    let workoutID: UUID
}

struct ProgressionReceiptRequest: Identifiable {
    let planRunID: UUID
    let workoutID: UUID
    var id: UUID { workoutID }
}

// MARK: - Mobility links

enum WorkoutMobilityLinkPhase {
    case warmup
    case cooldown

    func liveRoutine(in template: WorkoutTemplate) -> MobilityRoutine? {
        switch self {
        case .warmup: template.preWorkoutMobilityRoutine
        case .cooldown: template.postWorkoutMobilityRoutine
        }
    }

    func liveRoutine(in slot: RepeatingPlanRunSlot) -> MobilityRoutine? {
        switch self {
        case .warmup: slot.preWorkoutMobilityRoutine
        case .cooldown: slot.postWorkoutMobilityRoutine
        }
    }

    func snapshotID(in slot: RepeatingPlanRunSlot) -> UUID? {
        switch self {
        case .warmup: slot.preWorkoutMobilityRoutineIDSnapshot
        case .cooldown: slot.postWorkoutMobilityRoutineIDSnapshot
        }
    }
}

/// Resolves which mobility routine, if any, a workout is linked to. A rotation
/// slot keeps a snapshot id alongside its live relationship, so a routine that
/// was archived or emptied after the link was made falls back to the snapshot
/// rather than silently offering an unrunnable routine.
enum WorkoutMobilityLinkResolver {
    static func slot(
        in run: RepeatingPlanRun,
        for command: RepeatingPlanWorkoutStartCommand
    ) -> RepeatingPlanRunSlot? {
        let slots = run.orderedSlots
        switch command {
        case .expected:
            guard slots.indices.contains(run.currentSlotIndex) else { return nil }
            return slots[run.currentSlotIndex]
        case .alternate(let slotIndex, _):
            guard slots.indices.contains(slotIndex) else { return nil }
            return slots[slotIndex]
        case .repeatLast:
            guard let occurrence = run.orderedOccurrences.reversed().first(where: {
                $0.status == .completed && $0.kind != .skip && $0.kind != .restart
            }) else { return nil }
            return slot(in: run, for: occurrence)
        }
    }

    static func slot(
        in run: RepeatingPlanRun,
        for occurrence: RepeatingPlanOccurrence
    ) -> RepeatingPlanRunSlot? {
        let slotIndex = occurrence.selectedSlotIndex ?? occurrence.expectedSlotIndex
        let slots = run.orderedSlots
        guard slots.indices.contains(slotIndex) else { return nil }
        return slots[slotIndex]
    }

    /// The routine to offer for a start that has not happened yet. Only a
    /// rotation slot carries a snapshot; a template link is read live, because
    /// there is nothing older to fall back to.
    @MainActor
    static func linkedRoutine(
        for start: PendingWorkoutStart,
        phase: WorkoutMobilityLinkPhase,
        using context: ModelContext
    ) -> MobilityRoutine? {
        switch start {
        case .template(let template):
            return resolved(
                liveRoutine: phase.liveRoutine(in: template),
                snapshotID: nil,
                using: context
            )
        case .planned(let pending):
            return resolved(
                liveRoutine: pending.plannedWorkout.sourceTemplate.flatMap { phase.liveRoutine(in: $0) },
                snapshotID: nil,
                using: context
            )
        case .repeating(let run, let command):
            guard let slot = slot(in: run, for: command) else { return nil }
            return resolved(
                liveRoutine: phase.liveRoutine(in: slot),
                snapshotID: phase.snapshotID(in: slot),
                using: context
            )
        }
    }

    /// The routine to offer for a workout that already exists. A rotation
    /// workout resolves through the occurrence it came from, so a cooldown
    /// still matches the slot that was actually worked rather than whichever
    /// slot the run has advanced to since.
    @MainActor
    static func linkedRoutine(
        for workout: Workout,
        phase: WorkoutMobilityLinkPhase,
        using context: ModelContext
    ) -> MobilityRoutine? {
        if let runID = workout.sourceRepeatingPlanRunID,
           let occurrenceID = workout.sourceRepeatingPlanOccurrenceID,
           let run = (try? context.fetch(FetchDescriptor<RepeatingPlanRun>()))?.first(where: { $0.id == runID }),
           let occurrence = run.occurrences.first(where: { $0.id == occurrenceID }),
           let slot = slot(in: run, for: occurrence)
        {
            return resolved(
                liveRoutine: phase.liveRoutine(in: slot),
                snapshotID: phase.snapshotID(in: slot),
                using: context
            )
        }
        guard let template = workout.sourceTemplate else { return nil }
        return resolved(
            liveRoutine: phase.liveRoutine(in: template),
            snapshotID: nil,
            using: context
        )
    }

    @MainActor
    private static func resolved(
        liveRoutine: MobilityRoutine?,
        snapshotID: UUID?,
        using context: ModelContext
    ) -> MobilityRoutine? {
        if let liveRoutine, isRunnable(liveRoutine) {
            return liveRoutine
        }
        guard let snapshotID else { return nil }
        return (try? context.fetch(FetchDescriptor<MobilityRoutine>()))?
            .first { $0.id == snapshotID && isRunnable($0) }
    }

    /// An archived or empty routine is a link, not an offer. Presenting it
    /// would open a session with nothing to do in it.
    static func isRunnable(_ routine: MobilityRoutine) -> Bool {
        !routine.isArchived && !routine.orderedItems.isEmpty
    }
}

enum WorkoutMobilityContinuationPolicy {
    static func shouldResumeWorkout(
        sessionContext: MobilitySessionContext,
        sessionWorkoutID: UUID?,
        pendingWarmupWorkoutID: UUID,
        activeWorkoutID: UUID?
    ) -> Bool {
        sessionContext == .warmup
            && sessionWorkoutID == pendingWarmupWorkoutID
            && activeWorkoutID == pendingWarmupWorkoutID
    }
}

// MARK: - Progression receipts

/// Decides whether a just-saved workout owes the lifter a progression receipt.
/// Free workouts and rotation runs have no `sourcePlanRunID` and never do.
@MainActor
enum ProgressionReceiptPolicy {
    static func workout(id: UUID, using context: ModelContext) -> Workout? {
        (try? context.fetch(FetchDescriptor<Workout>()))?.first { $0.id == id }
    }

    /// Whether the saved workout left unresolved recommendation records behind.
    /// Checked at save time, while the workout is still addressable.
    static func owesReceipt(forWorkoutID workoutID: UUID, using context: ModelContext) -> Bool {
        guard let planRunID = workout(id: workoutID, using: context)?.sourcePlanRunID else {
            return false
        }
        let predicate = #Predicate<PlanProgressionRecommendationRecord> { record in
            record.planRunID == planRunID && record.workoutID == workoutID && record.isResolved == false
        }
        var descriptor = FetchDescriptor<PlanProgressionRecommendationRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        return !((try? context.fetch(descriptor)) ?? []).isEmpty
    }

    /// The receipt to present once the workout's own screen is gone. Resolved
    /// again at presentation time rather than captured at save time, because
    /// the run association is what the sheet keys off.
    static func receipt(forWorkoutID workoutID: UUID, using context: ModelContext) -> ProgressionReceiptRequest? {
        guard let planRunID = workout(id: workoutID, using: context)?.sourcePlanRunID else {
            return nil
        }
        return ProgressionReceiptRequest(planRunID: planRunID, workoutID: workoutID)
    }
}
