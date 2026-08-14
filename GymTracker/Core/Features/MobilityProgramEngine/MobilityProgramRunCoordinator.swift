import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

/// Conforms the mobility run's session occurrences to the unified scheduling
/// protocol added in Release 8 part 1. `scheduledDay` falls back to
/// `.distantFuture` for the rare unscheduled occurrence (a program whose
/// duration exceeds what a start date can anchor); Today/calendar filter by
/// `scheduledDate != nil` before ever reading this, so the fallback is never
/// actually surfaced.
extension MobilityProgramSessionProgress: ScheduledTrainingOccurrence {
    var occurrenceID: UUID { id }
    var scheduledDay: LocalDay {
        LocalDay(date: scheduledDate ?? originalScheduledDate ?? .distantFuture)
    }
    var displayName: String { sessionNameSnapshot }
    var domain: TrainingDomain { .mobility }
}

/// Lifecycle and scheduling operations for `MobilityProgramRun`, mirroring
/// `PlanCoordinator`'s idiom for `PlanRun` so the two feel like one product.
/// Today/calendar surfaces consume the resulting projections; they never
/// call into this coordinator to decide program lifecycle rules themselves.
@MainActor
enum MobilityProgramRunCoordinator {
    // MARK: - Activation

    /// Snapshots `program` into a fresh run, materializes one
    /// `MobilityProgramSessionProgress` per flattened session and one
    /// `MobilityProgressionState` per `(progressionKey, side)` pair the
    /// program's occurrences declare, and persists all of it as one
    /// transaction.
    @discardableResult
    static func activate(
        program: MobilityProgramDefinitionPayload,
        sourceProgramID: UUID,
        startDate: Date = .now,
        using modelContext: ModelContext
    ) throws -> MobilityProgramRun {
        let issues = MobilityProgramDefinitionValidator.validate(program)
        guard issues.isEmpty else { throw MobilityProgramDefinitionStoreError.invalid(issues) }
        let run = try MobilityProgramRun(program: program, sourceProgramID: sourceProgramID, startDate: startDate)
        populateSessionProgress(for: run, program: program, anchor: startDate)
        seedProgressionStates(for: run, program: program)
        modelContext.insert(run)
        guard save(using: modelContext) else { throw MobilityProgramDefinitionStoreError.persistenceFailed }
        return run
    }

    private static func populateSessionProgress(
        for run: MobilityProgramRun,
        program: MobilityProgramDefinitionPayload,
        anchor: Date
    ) {
        let calendar = Calendar.current
        let firstDay = calendar.startOfDay(for: anchor)
        for session in program.flattenedSessions {
            let dayOffset = (session.weekIndex * 7) + session.dayIndex
            let scheduledDate = calendar.date(byAdding: .day, value: dayOffset, to: firstDay)
            run.sessionProgress.append(
                MobilityProgramSessionProgress(
                    sessionKey: session.sessionKey,
                    weekIndex: session.weekIndex,
                    dayIndex: session.dayIndex,
                    sameDayOrder: session.sameDayOrder,
                    isOptional: session.isOptional,
                    sessionNameSnapshot: session.name,
                    scheduledDate: scheduledDate
                )
            )
        }
    }

    private static func seedProgressionStates(for run: MobilityProgramRun, program: MobilityProgramDefinitionPayload) {
        var seen = Set<String>()
        for occurrence in program.flattenedSessions.flatMap({ $0.recipe.occurrences }) {
            guard let key = occurrence.progressionKey else { continue }
            for side in occurrence.side.resultSides {
                let composite = "\(key)|\(side.rawValue)"
                guard seen.insert(composite).inserted else { continue }
                run.progressionStates.append(MobilityProgressionState(progressionKey: key, side: side))
            }
        }
    }

    // MARK: - Cursor / availability

    static func nextSessionProgress(in run: MobilityProgramRun) -> MobilityProgramSessionProgress? {
        run.orderedSessionProgress.first { $0.status == .pending && $0.mobilitySessionID == nil }
    }

    /// The occurrence currently linked to an active, unfinished
    /// `MobilitySession`, if any.
    static func inProgressSessionProgress(in run: MobilityProgramRun, using modelContext: ModelContext) -> MobilityProgramSessionProgress? {
        let activeIDs = activeMobilitySessionIDs(using: modelContext)
        return run.orderedSessionProgress.first { $0.isInProgress(activeMobilitySessionIDs: activeIDs) }
    }

    private static func activeMobilitySessionIDs(using modelContext: ModelContext) -> Set<UUID> {
        let descriptor = FetchDescriptor<MobilitySession>(predicate: #Predicate { $0.statusRaw == "active" })
        return Set(((try? modelContext.fetch(descriptor)) ?? []).map(\.id))
    }

    static func refreshAvailability(for run: MobilityProgramRun) {
        guard run.status == .active || run.status == .paused else { return }
        let hasUnfinishedWork = run.sessionProgress.contains { $0.status == .pending }
        if let next = nextSessionProgress(in: run) {
            run.currentWeekIndex = next.weekIndex
            run.currentSessionIndex = run.orderedSessionProgress.firstIndex(where: { $0.id == next.id }) ?? run.currentSessionIndex
        } else if hasUnfinishedWork == false, run.status == .active {
            // Nothing pending and nothing in progress: every occurrence
            // reached a terminal status.
            run.status = .completed
            run.endDate = .now
        }
        run.updatedAt = .now
    }

    static func canEditSchedule(_ run: MobilityProgramRun) -> Bool {
        run.status == .active || run.status == .paused
    }

    static func canEditSchedule(_ progress: MobilityProgramSessionProgress, in run: MobilityProgramRun) -> Bool {
        canEditSchedule(run) && progress.status == .pending && progress.mobilitySessionID == nil
    }

    // MARK: - Reschedule

    @discardableResult
    static func reschedule(
        _ progress: MobilityProgramSessionProgress,
        to date: Date,
        in run: MobilityProgramRun,
        using modelContext: ModelContext
    ) -> Bool {
        guard canEditSchedule(progress, in: run) else { return false }
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        if progress.originalScheduledDate == nil {
            progress.originalScheduledDate = progress.scheduledDate.map(calendar.startOfDay(for:)) ?? targetDay
        }
        let existingDay = progress.scheduledDate.map(calendar.startOfDay(for:))
        progress.scheduledDate = targetDay
        if let existingDay, existingDay != targetDay {
            progress.lastRescheduledAt = .now
        }
        refreshAvailability(for: run)
        return save(using: modelContext)
    }

    // MARK: - Session start

    /// Applies this run's progression state to the frozen snapshot, compiles
    /// the requested session, and starts it through the existing
    /// `MobilitySessionService.start` path — never a parallel execution
    /// path. On success the occurrence remains `.pending` (a session in
    /// progress is not yet a terminal outcome) with `mobilitySessionID` set;
    /// `reconcileTerminalSessions` closes the loop once the session ends.
    @discardableResult
    static func startSession(
        _ progress: MobilityProgramSessionProgress,
        in run: MobilityProgramRun,
        mobilityDefinitionsByID: [UUID: MobilityDefinition],
        now: Date = .now,
        using modelContext: ModelContext
    ) throws -> MobilitySession? {
        guard run.status == .active,
              progress.status == .pending,
              progress.mobilitySessionID == nil,
              let program = run.programSnapshot
        else { return nil }

        let adjusted = adjustedProgram(program, for: run)
        let compiled = try MobilityProgramCompiler.compile(
            program: adjusted,
            sessionKey: progress.sessionKey,
            mobilityDefinitionsByID: mobilityDefinitionsByID,
            into: modelContext,
            now: now
        )
        guard let session = MobilitySessionService.start(
            routine: compiled.routine,
            context: .standalone,
            workoutID: nil,
            now: now,
            using: modelContext
        ) else { return nil }

        progress.startedAt = now
        progress.mobilitySessionID = session.id
        run.updatedAt = now
        _ = save(using: modelContext)
        return session
    }

    /// Applies every `(progressionKey, side)`'s current offsets onto the
    /// frozen program snapshot before compiling. A two-sided occurrence
    /// resolves to the more conservative of its two sides' offsets (see
    /// `conservativeCombine`), so neither side is ever asked to perform
    /// beyond what it has independently demonstrated.
    static func adjustedProgram(
        _ program: MobilityProgramDefinitionPayload,
        for run: MobilityProgramRun
    ) -> MobilityProgramDefinitionPayload {
        let statesByKey = Dictionary(grouping: run.progressionStates, by: \.progressionKey)
        guard statesByKey.isEmpty == false else { return program }
        var adjusted = program
        adjusted.blocks = adjusted.blocks.map { block in
            var block = block
            block.weeks = block.weeks.map { week in
                var week = week
                week.sessions = week.sessions.map { session in
                    var session = session
                    session.recipe.occurrences = session.recipe.occurrences.map { occurrence in
                        var occurrence = occurrence
                        guard let key = occurrence.progressionKey, let states = statesByKey[key], states.isEmpty == false else {
                            return occurrence
                        }
                        let relevant = states.filter { occurrence.side.resultSides.contains($0.side) }
                        guard relevant.isEmpty == false else { return occurrence }
                        apply(conservativeCombine(relevant), to: &occurrence)
                        return occurrence
                    }
                    return session
                }
                return week
            }
            return block
        }
        return adjusted
    }

    private static func conservativeCombine(_ states: [MobilityProgressionState]) -> MobilityProgressionProposedState {
        let proposedStates = states.map(\.proposedState)
        guard let first = proposedStates.first else { return MobilityProgressionProposedState() }
        return proposedStates.dropFirst().reduce(first) { combined, next in
            MobilityProgressionProposedState(
                durationOffsetSeconds: min(combined.durationOffsetSeconds, next.durationOffsetSeconds),
                repetitionOffset: min(combined.repetitionOffset, next.repetitionOffset),
                cycleOffset: min(combined.cycleOffset, next.cycleOffset),
                loadOffset: min(combined.loadOffset, next.loadOffset),
                assistanceLevelOffset: max(combined.assistanceLevelOffset, next.assistanceLevelOffset),
                supportLevelStepOffset: max(combined.supportLevelStepOffset, next.supportLevelStepOffset),
                variationStepOffset: abs(combined.variationStepOffset) <= abs(next.variationStepOffset)
                    ? combined.variationStepOffset
                    : next.variationStepOffset
            )
        }
    }

    private static let supportLadder: [MobilitySupportLevel] = [
        .highBlocks, .mediumBlocks, .lowBlocks, .fingertipSupport, .unsupported
    ]

    /// Mutates a copy of the frozen snapshot's occurrence only — this never
    /// touches the live `MobilityProgramDefinitionRecord`.
    private static func apply(_ state: MobilityProgressionProposedState, to occurrence: inout MobilityMovementOccurrenceDefinition) {
        occurrence.targets.durationSeconds = offset(occurrence.targets.durationSeconds, by: state.durationOffsetSeconds)
        occurrence.targets.repetitions = offset(occurrence.targets.repetitions, by: state.repetitionOffset)
        occurrence.targets.load = offset(occurrence.targets.load, by: state.loadOffset)
        if state.cycleOffset != 0 {
            occurrence.cycleCount = max(1, occurrence.cycleCount + state.cycleOffset)
        }
        if state.assistanceLevelOffset != 0, var assistance = occurrence.assistancePrescription, let level = assistance.level {
            assistance.level = max(0, level + state.assistanceLevelOffset)
            occurrence.assistancePrescription = assistance
        }
        if state.supportLevelStepOffset != 0, let support = occurrence.supportLevel,
           let index = supportLadder.firstIndex(of: support) {
            let newIndex = min(max(0, index + state.supportLevelStepOffset), supportLadder.count - 1)
            occurrence.supportLevel = supportLadder[newIndex]
        }
        // `state.variationStepOffset` is intentionally not applied to
        // anything here — see `MobilityProgressionProposedState
        // .variationStepOffset`'s doc comment.
    }

    private static func offset(_ target: MobilityIntTarget?, by amount: Int) -> MobilityIntTarget? {
        guard amount != 0, let target else { return target }
        switch target {
        case .exact(let value): return .exact(max(1, value + amount))
        case .minimum(let value): return .minimum(max(1, value + amount))
        case .maximum(let value): return .maximum(max(1, value + amount))
        case .range(let minimum, let maximum): return .range(max(1, minimum + amount), max(minimum + amount, maximum + amount))
        case .open: return .open
        }
    }

    private static func offset(_ target: MobilityDoubleTarget?, by amount: Double) -> MobilityDoubleTarget? {
        guard amount != 0, let target else { return target }
        switch target {
        case .exact(let value): return .exact(max(0.1, value + amount))
        case .minimum(let value): return .minimum(max(0.1, value + amount))
        case .maximum(let value): return .maximum(max(0.1, value + amount))
        case .range(let minimum, let maximum): return .range(max(0.1, minimum + amount), max(minimum + amount, maximum + amount))
        case .open: return .open
        }
    }

    // MARK: - Reconciliation

    /// Closes the loop between a program-linked `MobilitySession` reaching a
    /// terminal status and its `MobilityProgramSessionProgress`. Called
    /// after any mobility session ends (see the app root's
    /// `fullScreenCover` dismissal), so it must be cheap and idempotent when
    /// there is nothing to reconcile.
    static func reconcileTerminalSessions(using modelContext: ModelContext) {
        let activeStatus = MobilityProgramRunStatus.active.rawValue
        guard let activeRuns = try? modelContext.fetch(FetchDescriptor<MobilityProgramRun>(
            predicate: #Predicate { $0.statusRaw == activeStatus }
        )) else { return }
        guard activeRuns.isEmpty == false else { return }

        var didChange = false
        for run in activeRuns {
            for progress in run.sessionProgress where progress.status == .pending {
                guard let sessionID = progress.mobilitySessionID else { continue }
                var descriptor = FetchDescriptor<MobilitySession>(
                    predicate: #Predicate { $0.id == sessionID }
                )
                descriptor.fetchLimit = 1
                guard let session = try? modelContext.fetch(descriptor).first else { continue }

                switch session.status {
                case .completed:
                    progress.status = .completed
                    progress.completedAt = .now
                    MobilityProgressionRecommendationService.evaluateAfterCompletion(
                        progress: progress,
                        run: run,
                        session: session,
                        using: modelContext
                    )
                    didChange = true
                case .stopped:
                    // A stop signal is not a skip the user chose; leave the
                    // occurrence reattemptable. The stopped session remains
                    // in Mobility History on its own.
                    progress.mobilitySessionID = nil
                    progress.startedAt = nil
                    didChange = true
                case .active:
                    continue
                }
            }
            if didChange { refreshAvailability(for: run) }
        }
        guard didChange else { return }
        _ = save(using: modelContext)
    }

    // MARK: - Skip / miss

    static func skip(_ progress: MobilityProgramSessionProgress, in run: MobilityProgramRun) {
        guard canEditSchedule(progress, in: run) else { return }
        progress.status = .skipped
        progress.completedAt = .now
        refreshAvailability(for: run)
    }

    @discardableResult
    static func skip(_ progress: MobilityProgramSessionProgress, in run: MobilityProgramRun, using modelContext: ModelContext) -> Bool {
        skip(progress, in: run)
        return save(using: modelContext)
    }

    /// Marks a session missed and applies the frozen program's
    /// `missedSessionPolicy`: `.shiftSequence` pushes every later unstarted
    /// occurrence forward by one day so the weekly rhythm is preserved;
    /// `.skipAndContinue` leaves every other date untouched.
    @discardableResult
    static func markMissed(_ progress: MobilityProgramSessionProgress, in run: MobilityProgramRun, using modelContext: ModelContext) -> Bool {
        guard canEditSchedule(progress, in: run) else { return false }
        progress.status = .missed
        progress.completedAt = .now
        if run.programSnapshot?.missedSessionPolicy == .shiftSequence {
            shiftLaterSessions(after: progress, in: run, byDays: 1)
        }
        refreshAvailability(for: run)
        return save(using: modelContext)
    }

    private static func shiftLaterSessions(after progress: MobilityProgramSessionProgress, in run: MobilityProgramRun, byDays days: Int) {
        guard let anchorDate = progress.scheduledDate else { return }
        let calendar = Calendar.current
        for later in run.sessionProgress where later.status == .pending && later.mobilitySessionID == nil {
            guard let date = later.scheduledDate, date >= anchorDate else { continue }
            if let shifted = calendar.date(byAdding: .day, value: days, to: date) {
                later.scheduledDate = calendar.startOfDay(for: shifted)
            }
        }
    }

    // MARK: - Pause / resume

    static func pause(_ run: MobilityProgramRun) {
        guard run.status == .active else { return }
        run.status = .paused
        run.updatedAt = .now
    }

    @discardableResult
    static func pause(_ run: MobilityProgramRun, using modelContext: ModelContext) -> Bool {
        pause(run)
        return save(using: modelContext)
    }

    static func resume(_ run: MobilityProgramRun, at date: Date = .now) {
        guard run.status == .paused else { return }
        run.status = .active
        reanchorUnfinishedSchedule(for: run, from: date)
        refreshAvailability(for: run)
    }

    @discardableResult
    static func resume(_ run: MobilityProgramRun, at date: Date = .now, using modelContext: ModelContext) -> Bool {
        resume(run, at: date)
        return save(using: modelContext)
    }

    private static func reanchorUnfinishedSchedule(for run: MobilityProgramRun, from date: Date) {
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: date)
        let pending = run.orderedSessionProgress.filter { $0.status == .pending && $0.mobilitySessionID == nil }
        guard let first = pending.first else { return }
        let baseWeek = first.weekIndex
        let baseDay = first.dayIndex
        for progress in pending {
            let dayOffset = ((progress.weekIndex - baseWeek) * 7) + (progress.dayIndex - baseDay)
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: anchor) {
                progress.scheduledDate = calendar.startOfDay(for: date)
            }
        }
    }

    // MARK: - Complete / archive / restart

    @discardableResult
    static func complete(_ run: MobilityProgramRun, using modelContext: ModelContext) -> Bool {
        guard run.status == .active || run.status == .paused else { return false }
        run.status = .completed
        run.endDate = .now
        run.updatedAt = .now
        return save(using: modelContext)
    }

    static func archive(_ run: MobilityProgramRun) {
        guard run.status != .completed else { return }
        run.status = .archived
        run.endDate = .now
        run.updatedAt = .now
    }

    @discardableResult
    static func archive(_ run: MobilityProgramRun, using modelContext: ModelContext) -> Bool {
        archive(run)
        return save(using: modelContext)
    }

    /// Restarts a completed or archived run as a brand-new
    /// `MobilityProgramRun`. `carryingState: true` copies every
    /// `(progressionKey, side)`'s current offsets onto the fresh run's
    /// freshly-seeded states; `false` starts every offset back at zero.
    /// Either way this never mutates the source run — its history stays
    /// exactly as it was.
    @discardableResult
    static func restart(
        _ run: MobilityProgramRun,
        carryingState: Bool,
        startDate: Date = .now,
        using modelContext: ModelContext
    ) throws -> MobilityProgramRun? {
        guard run.status == .completed || run.status == .archived, let program = run.programSnapshot else { return nil }
        let newRun = try activate(program: program, sourceProgramID: run.sourceProgramID, startDate: startDate, using: modelContext)
        guard carryingState else { return newRun }

        let statesByKey = Dictionary(
            uniqueKeysWithValues: run.progressionStates.map { ("\($0.progressionKey)|\($0.sideRaw)", $0) }
        )
        for state in newRun.progressionStates {
            guard let source = statesByKey["\(state.progressionKey)|\(state.sideRaw)"] else { continue }
            state.apply(source.proposedState, recommendationID: source.lastAppliedRecommendationID)
            state.consecutiveTargetMetSessionCount = source.consecutiveTargetMetSessionCount
        }
        guard save(using: modelContext) else { return nil }
        return newRun
    }

    // MARK: - Persistence

    private static func save(using modelContext: ModelContext) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            return false
        }
    }
}

#endif
