import Foundation
import SwiftData

struct MobilityResultInput {
    var performedDurationSeconds: Int?
    var performedRepetitions: Int?
    var performedLoadValue: Double?
    var performedLoadUnit: MobilityLoadUnit?
    var perceivedIntensity: Int?
    var discomfortNote: String?
    var sensation: MobilitySensation?
    var movementQuality: MobilityMovementQuality?
    var compensationKeys: Set<MobilityCompensationKey>

    init(
        performedDurationSeconds: Int? = nil,
        performedRepetitions: Int? = nil,
        performedLoadValue: Double? = nil,
        performedLoadUnit: MobilityLoadUnit? = nil,
        perceivedIntensity: Int? = nil,
        discomfortNote: String? = nil,
        sensation: MobilitySensation? = nil,
        movementQuality: MobilityMovementQuality? = nil,
        compensationKeys: Set<MobilityCompensationKey> = []
    ) {
        self.performedDurationSeconds = performedDurationSeconds
        self.performedRepetitions = performedRepetitions
        self.performedLoadValue = performedLoadValue
        self.performedLoadUnit = performedLoadUnit
        self.perceivedIntensity = perceivedIntensity
        self.discomfortNote = discomfortNote
        self.sensation = sensation
        self.movementQuality = movementQuality
        self.compensationKeys = compensationKeys
    }
}

enum MobilityPhaseCompletionOutcome: Equatable {
    case applied(MobilityTransition)
    case stale(MobilityTransition)
    case invalidPerformedDuration
    case stopSignalRequiresStop
    case persistenceFailure
}

enum MobilityTimerMutationOutcome: Equatable {
    case applied
    case alreadyPaused
    case alreadyRunning
    case stale
    case persistenceFailure
}

enum MobilityUndoOutcome: Equatable {
    case applied
    case nothingToUndo
    case stale
    case persistenceFailure
}

enum MobilitySessionRestorationOutcome {
    case none
    case restored(MobilitySession)
    case repaired(MobilitySession)
    case invalid
    case persistenceFailure
}

@MainActor
enum MobilitySessionService {
    @discardableResult
    static func start(
        routine: MobilityRoutine,
        context: MobilitySessionContext = .standalone,
        workoutID: UUID? = nil,
        now: Date = .now,
        using modelContext: ModelContext
    ) -> MobilitySession? {
        guard routine.isArchived == false, routine.orderedItems.isEmpty == false else { return nil }
        guard activeSession(using: modelContext) == nil else { return nil }
        guard routine.orderedItems.allSatisfy(canSnapshot) else { return nil }

        let session = MobilitySession(
            nameSnapshot: routine.name,
            sourceRoutineID: routine.id,
            sourceRoutineName: routine.name,
            workoutID: workoutID,
            context: context,
            startTime: now,
            createdAt: now,
            updatedAt: now
        )
        let prescriptionEvidence = MobilityEvidenceService.prescriptionEvidence(using: modelContext)
        session.entries = routine.orderedItems.enumerated().map { index, item in
            let entry = MobilityEntry(routineItem: item, orderIndex: index)
            entry.results = item.side.resultSides.map {
                MobilityResult(
                    side: $0,
                    prescribedDurationSeconds: entry.targetDurationSeconds,
                    prescribedRepetitions: entry.targetRepetitions
                )
            }
            entry.phaseResults = phaseSnapshots(for: item)
            let prescription = prescriptionEvidence[item.id]
            for result in entry.results {
                modelContext.insert(
                    MobilityResultEvidence(
                        resultID: result.id,
                        entryIDSnapshot: entry.id,
                        side: result.side,
                        methodSnapshot: prescription?.method,
                        purposeSnapshot: prescription?.purpose,
                        recordedAt: now
                    )
                )
            }
            return entry
        }
        begin(entry: session.currentEntry, now: now)
        modelContext.insert(session)
        do {
            try modelContext.save()
            return session
        } catch {
            modelContext.rollback()
            return nil
        }
    }

    static func activeSession(using modelContext: ModelContext) -> MobilitySession? {
        (try? modelContext.fetch(FetchDescriptor<MobilitySession>()))?
            .filter { $0.status == .active }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    /// Restores one active session only when its performed-evidence graph has
    /// one unambiguous current execution node. Narrow legacy cursor/status
    /// mismatches are repaired in one save; ambiguous graphs remain untouched.
    static func restoreActiveSession(
        now: Date = .now,
        using modelContext: ModelContext
    ) -> MobilitySessionRestorationOutcome {
        let sessions: [MobilitySession]
        do {
            sessions = try modelContext.fetch(FetchDescriptor<MobilitySession>())
        } catch {
            return .invalid
        }
        let activeSessions = sessions.filter { $0.status == .active }
        guard activeSessions.isEmpty == false else { return .none }
        guard activeSessions.count == 1, let session = activeSessions.first else { return .invalid }

        switch reconciliationPlan(for: session) {
        case .valid:
            return .restored(session)
        case .repair(let entry, let phase, let repairSideResult):
            session.currentEntryIndex = entry.orderIndex
            if let phase {
                entry.currentCycleIndex = phase.cycleIndex
                entry.currentPhaseIndex = phaseIndex(of: phase, in: entry)
                if repairSideResult,
                   let result = entry.results.first(where: { $0.side == phase.side }) {
                    result.status = .inProgress
                    result.startedAt = result.startedAt ?? phase.startedAt ?? now
                    result.completedAt = nil
                }
            }
            session.endTime = nil
            session.updatedAt = now
            do {
                try modelContext.save()
                return .repaired(session)
            } catch {
                modelContext.rollback()
                return .persistenceFailure
            }
        case .invalid:
            return .invalid
        }
    }

    @discardableResult
    static func completeCurrent(
        in session: MobilitySession,
        performedDurationSeconds: Int? = nil,
        performedRepetitions: Int? = nil,
        perceivedIntensity: Int? = nil,
        discomfortNote: String? = nil,
        using modelContext: ModelContext
    ) -> Bool {
        let input = MobilityResultInput(
            performedDurationSeconds: performedDurationSeconds,
            performedRepetitions: performedRepetitions,
            perceivedIntensity: perceivedIntensity,
            discomfortNote: discomfortNote
        )
        return completeCurrent(
            in: session,
            resultInputs: Dictionary(uniqueKeysWithValues: (session.currentEntry?.results ?? []).map { ($0.id, input) }),
            using: modelContext
        )
    }

    @discardableResult
    static func completeCurrent(
        in session: MobilitySession,
        resultInputs: [UUID: MobilityResultInput],
        using modelContext: ModelContext
    ) -> Bool {
        finishCurrent(in: session, status: .completed, resultInputs: resultInputs, using: modelContext)
    }

    @discardableResult
    static func skipCurrent(in session: MobilitySession, using modelContext: ModelContext) -> Bool {
        finishCurrent(in: session, status: .skipped, resultInputs: [:], using: modelContext)
    }

    @discardableResult
    static func savePartialCurrent(
        in session: MobilitySession,
        performedDurationSeconds: Int? = nil,
        performedRepetitions: Int? = nil,
        perceivedIntensity: Int? = nil,
        discomfortNote: String? = nil,
        using modelContext: ModelContext
    ) -> Bool {
        let input = MobilityResultInput(
            performedDurationSeconds: performedDurationSeconds,
            performedRepetitions: performedRepetitions,
            perceivedIntensity: perceivedIntensity,
            discomfortNote: discomfortNote
        )
        return savePartialCurrent(
            in: session,
            resultInputs: Dictionary(uniqueKeysWithValues: (session.currentEntry?.results ?? []).map { ($0.id, input) }),
            using: modelContext
        )
    }

    @discardableResult
    static func savePartialCurrent(
        in session: MobilitySession,
        resultInputs: [UUID: MobilityResultInput],
        using modelContext: ModelContext
    ) -> Bool {
        finishCurrent(in: session, status: .partial, resultInputs: resultInputs, using: modelContext)
    }

    /// Completes exactly the durable current phase and applies the pure
    /// side/cycle/phase transition in one SwiftData commit.
    @discardableResult
    static func completeCurrentPhase(
        in session: MobilitySession,
        performedDurationSeconds: Int? = nil,
        performedIntensity: ContractionIntensity? = nil,
        sensation: MobilitySensation? = nil,
        movementQuality: MobilityMovementQuality? = nil,
        compensationKeys: Set<MobilityCompensationKey> = [],
        now: Date = .now,
        using modelContext: ModelContext
    ) -> MobilityPhaseCompletionOutcome {
        finishCurrentPhase(
            in: session,
            status: .completed,
            performedDurationSeconds: performedDurationSeconds,
            performedIntensity: performedIntensity,
            sensation: sensation,
            movementQuality: movementQuality,
            compensationKeys: compensationKeys,
            now: now,
            using: modelContext
        )
    }

    @discardableResult
    static func savePartialCurrentPhase(
        in session: MobilitySession,
        performedDurationSeconds: Int? = nil,
        performedIntensity: ContractionIntensity? = nil,
        sensation: MobilitySensation? = nil,
        movementQuality: MobilityMovementQuality? = nil,
        compensationKeys: Set<MobilityCompensationKey> = [],
        now: Date = .now,
        using modelContext: ModelContext
    ) -> MobilityPhaseCompletionOutcome {
        finishCurrentPhase(
            in: session,
            status: .partial,
            performedDurationSeconds: performedDurationSeconds,
            performedIntensity: performedIntensity,
            sensation: sensation,
            movementQuality: movementQuality,
            compensationKeys: compensationKeys,
            now: now,
            using: modelContext
        )
    }

    @discardableResult
    static func skipCurrentPhase(
        in session: MobilitySession,
        now: Date = .now,
        using modelContext: ModelContext
    ) -> MobilityPhaseCompletionOutcome {
        finishCurrentPhase(
            in: session,
            status: .skipped,
            performedDurationSeconds: nil,
            performedIntensity: nil,
            sensation: nil,
            movementQuality: nil,
            compensationKeys: [],
            now: now,
            using: modelContext
        )
    }

    private static func finishCurrentPhase(
        in session: MobilitySession,
        status: MobilityResultStatus,
        performedDurationSeconds: Int?,
        performedIntensity: ContractionIntensity?,
        sensation: MobilitySensation?,
        movementQuality: MobilityMovementQuality?,
        compensationKeys: Set<MobilityCompensationKey>,
        now: Date,
        using modelContext: ModelContext
    ) -> MobilityPhaseCompletionOutcome {
        guard sensation?.isStopSignal != true else { return .stopSignalRequiresStop }
        guard performedDurationSeconds.map({ $0 >= 0 }) ?? true else {
            return .invalidPerformedDuration
        }
        let snapshot = flowSnapshot(for: session)
        guard session.status == .active,
              let entry = session.currentEntry,
              let currentPhase = entry.currentPhaseResult,
              session.entries.flatMap(\.phaseResults).filter({ $0.status == .inProgress }).count == 1,
              entry.results.first(where: { $0.side == currentPhase.side })?.status == .inProgress
        else {
            return .stale(staleTransition(for: snapshot, entryID: session.currentEntry?.id))
        }

        let transition = MobilityFlowResolver.resolve(
            MobilityFlowContext(
                session: snapshot,
                completedEntryID: entry.id,
                completedPhaseResultID: currentPhase.id
            )
        )
        guard transition.stale == false else { return .stale(transition) }

        if let sideResult = entry.results.first(where: { $0.side == currentPhase.side }) {
            MobilityEvidenceService.apply(
                MobilityResultInput(
                    sensation: sensation,
                    movementQuality: movementQuality,
                    compensationKeys: compensationKeys
                ),
                to: sideResult,
                using: modelContext
            )
        }

        currentPhase.performedDurationSeconds = status == .skipped
            ? nil
            : performedDurationSeconds ?? elapsedSeconds(for: entry, now: now)
        currentPhase.performedIntensity = status == .skipped ? nil : performedIntensity
        currentPhase.status = status
        currentPhase.completedAt = now
        reconcileSideStatus(currentPhase.side, in: entry, now: now)
        apply(transition, afterCompletingPhaseIn: entry, session: session, now: now)
        session.updatedAt = now

        do {
            try modelContext.save()
            return .applied(transition)
        } catch {
            modelContext.rollback()
            return .persistenceFailure
        }
    }

    @discardableResult
    static func pause(
        _ session: MobilitySession,
        now: Date = .now,
        using modelContext: ModelContext
    ) -> MobilityTimerMutationOutcome {
        guard session.status == .active,
              let entry = session.currentEntry,
              hasValidCurrentEvidence(in: entry),
              let startedAt = entry.timerStartedAt else {
            if session.status == .active, session.currentEntry?.isTimerPaused == true {
                return .alreadyPaused
            }
            return .stale
        }
        entry.pausedElapsedSeconds += max(0, Int(now.timeIntervalSince(startedAt)))
        entry.timerStartedAt = nil
        session.updatedAt = now
        do {
            try modelContext.save()
            return .applied
        } catch {
            modelContext.rollback()
            return .persistenceFailure
        }
    }

    @discardableResult
    static func resume(
        _ session: MobilitySession,
        now: Date = .now,
        using modelContext: ModelContext
    ) -> MobilityTimerMutationOutcome {
        guard session.status == .active,
              let entry = session.currentEntry,
              hasValidCurrentEvidence(in: entry) else { return .stale }
        guard entry.timerStartedAt == nil else { return .alreadyRunning }
        entry.timerStartedAt = now
        session.updatedAt = now
        do {
            try modelContext.save()
            return .applied
        } catch {
            modelContext.rollback()
            return .persistenceFailure
        }
    }

    @discardableResult
    static func undoLatestCompletion(
        in session: MobilitySession,
        now: Date = .now,
        using modelContext: ModelContext
    ) -> MobilityUndoOutcome {
        guard session.status == .active || session.status == .completed else { return .stale }
        if session.status == .active {
            guard case .valid = reconciliationPlan(for: session) else { return .stale }
        } else {
            guard isCompletedGraphValid(session) else { return .stale }
        }
        let undo = MobilityFlowResolver.resolveUndo(in: flowSnapshot(for: session))
        guard undo.stale == false else { return .stale }
        guard let target = undo.target,
              let targetEntry = session.entries.first(where: { $0.id == target.entryID })
        else { return .nothingToUndo }

        if let successor = undo.successor {
            guard resetStartedSuccessor(successor, in: session) else { return .stale }
        }

        let restoredElapsed: Int
        if let phaseID = target.phaseResultID {
            guard let phase = targetEntry.phaseResults.first(where: { $0.id == phaseID }),
                  isTerminal(phase.status) else { return .stale }
            restoredElapsed = max(0, phase.performedDurationSeconds ?? 0)
            phase.status = .inProgress
            phase.completedAt = nil
            phase.startedAt = now
            targetEntry.currentCycleIndex = phase.cycleIndex
            targetEntry.currentPhaseIndex = phaseIndex(of: phase, in: targetEntry)
            if let sideResult = targetEntry.results.first(where: { $0.side == phase.side }) {
                sideResult.status = .inProgress
                sideResult.completedAt = nil
                sideResult.startedAt = sideResult.startedAt ?? now
            }
        } else {
            guard targetEntry.isPhaseDriven == false,
                  targetEntry.results.isEmpty == false,
                  targetEntry.results.allSatisfy({ isTerminal($0.status) }) else { return .stale }
            restoredElapsed = max(
                0,
                targetEntry.results.compactMap(\.performedDurationSeconds).max() ?? 0
            )
            for result in targetEntry.results {
                result.status = .inProgress
                result.completedAt = nil
                result.startedAt = result.startedAt ?? now
            }
        }

        targetEntry.pausedElapsedSeconds = restoredElapsed
        targetEntry.timerStartedAt = now
        session.currentEntryIndex = targetEntry.orderIndex
        session.status = .active
        session.endTime = nil
        session.updatedAt = now
        do {
            try modelContext.save()
            return .applied
        } catch {
            modelContext.rollback()
            return .persistenceFailure
        }
    }

    static func canUndo(in session: MobilitySession) -> Bool {
        guard session.status == .active || session.status == .completed else { return false }
        if session.status == .active {
            guard case .valid = reconciliationPlan(for: session) else { return false }
        } else if isCompletedGraphValid(session) == false {
            return false
        }
        let transition = MobilityFlowResolver.resolveUndo(in: flowSnapshot(for: session))
        return transition.stale == false && transition.target != nil
    }

    private static func finishCurrent(
        in session: MobilitySession,
        status: MobilityResultStatus,
        resultInputs: [UUID: MobilityResultInput],
        using modelContext: ModelContext
    ) -> Bool {
        guard resultInputs.values.allSatisfy({ $0.sensation?.isStopSignal != true }) else { return false }
        guard session.status == .active, let entry = session.currentEntry else { return false }
        // Phase-driven work is intentionally not collapsed into the legacy
        // whole-entry action. `completeCurrentPhase` owns one-node evidence
        // and side/cycle/phase advancement.
        guard entry.isPhaseDriven == false else { return false }
        let transition = MobilityFlowResolver.resolve(
            MobilityFlowContext(
                session: flowSnapshot(for: session),
                completedEntryID: entry.id,
                completedPhaseResultID: nil
            )
        )
        guard transition.stale == false else { return false }
        for result in entry.results {
            if let input = resultInputs[result.id] {
                MobilityEvidenceService.apply(input, to: result, using: modelContext)
            } else if status == .skipped {
                MobilityEvidenceService.apply(MobilityResultInput(), to: result, using: modelContext)
            }
        }
        complete(entry: entry, status: status, resultInputs: resultInputs)
        apply(transition, afterCompletingPhaseIn: nil, session: session, now: .now)
        return save(session: session, using: modelContext)
    }

    @discardableResult
    static func stop(_ session: MobilitySession, using modelContext: ModelContext) -> Bool {
        guard session.status == .active else { return false }
        let now = Date.now
        if let currentEntry = session.currentEntry {
            let elapsed = elapsedSeconds(for: currentEntry, now: now)
            currentEntry.currentPhaseResult?.performedDurationSeconds = elapsed
            if currentEntry.isPhaseDriven == false, currentEntry.trackingType == .duration {
                for result in currentEntry.results where result.status == .inProgress {
                    result.performedDurationSeconds = elapsed
                }
            }
        }
        for entry in session.orderedEntries {
            for result in entry.results where result.status == .notStarted || result.status == .inProgress {
                result.status = .stopped
                result.completedAt = now
            }
            for phaseResult in entry.phaseResults
                where phaseResult.status == .notStarted || phaseResult.status == .inProgress {
                phaseResult.status = .stopped
                phaseResult.completedAt = now
            }
            entry.timerStartedAt = nil
            entry.pausedElapsedSeconds = 0
        }
        session.status = .stopped
        session.endTime = now
        return save(session: session, using: modelContext)
    }

    /// Records a user-observed stop signal and terminates the session in the
    /// same persistence transaction. This is an observation, not a diagnosis,
    /// and untouched later work remains stopped rather than falsely completed.
    @discardableResult
    static func stopDueToSensation(
        _ sensation: MobilitySensation,
        resultID: UUID,
        movementQuality: MobilityMovementQuality? = nil,
        compensationKeys: Set<MobilityCompensationKey> = [],
        in session: MobilitySession,
        using modelContext: ModelContext
    ) -> Bool {
        guard sensation.isStopSignal,
              session.status == .active,
              let result = session.currentEntry?.results.first(where: { $0.id == resultID })
        else { return false }
        MobilityEvidenceService.apply(
            MobilityResultInput(
                sensation: sensation,
                movementQuality: movementQuality,
                compensationKeys: compensationKeys
            ),
            to: result,
            using: modelContext
        )
        return stop(session, using: modelContext)
    }

    static func elapsedSeconds(for entry: MobilityEntry, now: Date = .now) -> Int {
        let runningElapsed = entry.timerStartedAt.map {
            max(0, Int(now.timeIntervalSince($0)))
        } ?? 0
        return max(0, entry.pausedElapsedSeconds) + runningElapsed
    }

    private static func begin(entry: MobilityEntry?, now: Date = .now) {
        guard let entry else { return }
        entry.pausedElapsedSeconds = 0
        guard entry.isPhaseDriven else {
            // Simple duration and repetition work share one operational timer
            // so either can pause/resume; only duration completion consumes it.
            entry.timerStartedAt = now
            for result in entry.results {
                result.status = .inProgress
                result.startedAt = now
            }
            return
        }

        guard let firstPhase = entry.orderedPhaseResults.first else { return }
        begin(phase: firstPhase, phaseIndex: 0, in: entry, now: now)
    }

    private static func phaseSnapshots(
        for item: MobilityRoutineItem
    ) -> [MobilityPhaseResult] {
        guard item.orderedPhases.isEmpty == false else { return [] }
        return item.side.resultSides.flatMap { side in
            (0..<item.cycleCount).flatMap { cycleIndex in
                item.orderedPhases.map { phase in
                    MobilityPhaseResult(
                        orderIndex: phase.orderIndex,
                        phaseType: phase.phaseType,
                        prescribedDurationSeconds: phase.durationSeconds,
                        cycleIndex: cycleIndex,
                        side: side,
                        prescribedIntensity: phase.contractionIntensity
                    )
                }
            }
        }
    }

    private static func canSnapshot(_ item: MobilityRoutineItem) -> Bool {
        guard item.orderedPhases.isEmpty == false else { return true }
        let order = item.orderedPhases.map(\.orderIndex)
        let identifiers = item.orderedPhases.map(\.id)
        return item.cycleCount > 0
            && Set(order).count == order.count
            && Set(identifiers).count == identifiers.count
            && item.orderedPhases.allSatisfy { $0.orderIndex >= 0 && $0.durationSeconds > 0 }
    }

    private static func complete(
        entry: MobilityEntry,
        status: MobilityResultStatus,
        resultInputs: [UUID: MobilityResultInput]
    ) {
        let elapsed = elapsedSeconds(for: entry)
        for result in entry.results {
            let input = resultInputs[result.id]
            result.status = status
            result.performedDurationSeconds = input?.performedDurationSeconds ?? (entry.trackingType == .duration ? elapsed : nil)
            result.performedRepetitions = input?.performedRepetitions
            result.performedLoadValue = input?.performedLoadValue ?? entry.prescribedLoadValue
            result.performedLoadUnit = input?.performedLoadUnit ?? entry.prescribedLoadUnit
            result.perceivedIntensity = input?.perceivedIntensity
            result.discomfortNote = input?.discomfortNote?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            result.completedAt = .now
        }
        entry.timerStartedAt = nil
    }

    private static func reconcileSideStatus(
        _ side: MobilitySide,
        in entry: MobilityEntry,
        now: Date
    ) {
        let hasUnfinishedPhase = entry.phaseResults.contains {
            $0.side == side && ($0.status == .notStarted || $0.status == .inProgress)
        }
        guard hasUnfinishedPhase == false,
              let result = entry.results.first(where: { $0.side == side })
        else { return }
        let sidePhases = entry.phaseResults.filter { $0.side == side }
        if sidePhases.allSatisfy({ $0.status == .skipped }) {
            result.status = .skipped
        } else if sidePhases.allSatisfy({ $0.status == .completed }) {
            result.status = .completed
        } else {
            result.status = .partial
        }
        result.completedAt = now
    }

    private static func apply(
        _ transition: MobilityTransition,
        afterCompletingPhaseIn completedEntry: MobilityEntry?,
        session: MobilitySession,
        now: Date
    ) {
        completedEntry?.timerStartedAt = nil
        guard transition.sessionCompleted == false,
              let nextEntryID = transition.nextEntryID,
              let nextEntry = session.entries.first(where: { $0.id == nextEntryID })
        else {
            session.status = .completed
            session.endTime = now
            session.updatedAt = now
            return
        }

        session.currentEntryIndex = nextEntry.orderIndex
        if let nextPhaseResultID = transition.nextPhaseResultID,
           let nextPhase = nextEntry.phaseResults.first(where: { $0.id == nextPhaseResultID }),
           let nextPhaseIndex = transition.nextPhaseIndex {
            begin(phase: nextPhase, phaseIndex: nextPhaseIndex, in: nextEntry, now: now)
        } else {
            begin(entry: nextEntry, now: now)
        }
        session.updatedAt = now
    }

    private static func begin(
        phase: MobilityPhaseResult,
        phaseIndex: Int,
        in entry: MobilityEntry,
        now: Date
    ) {
        entry.currentCycleIndex = phase.cycleIndex
        entry.currentPhaseIndex = phaseIndex
        entry.pausedElapsedSeconds = 0
        entry.timerStartedAt = now
        phase.status = .inProgress
        phase.startedAt = now
        if let sideResult = entry.results.first(where: { $0.side == phase.side }),
           sideResult.status == .notStarted {
            sideResult.status = .inProgress
            sideResult.startedAt = now
        }
    }

    private static func staleTransition(
        for snapshot: MobilityFlowSnapshot,
        entryID: UUID?
    ) -> MobilityTransition {
        guard let entryID else {
            return MobilityTransition(
                semantics: .sequential,
                nextEntryID: nil,
                nextPhaseResultID: nil,
                nextSide: nil,
                nextCycleIndex: nil,
                nextPhaseIndex: nil,
                restDirective: .none,
                sessionCompleted: false,
                stale: true
            )
        }
        return MobilityFlowResolver.resolve(
            MobilityFlowContext(
                session: snapshot,
                completedEntryID: entryID,
                completedPhaseResultID: UUID()
            )
        )
    }

    private enum ReconciliationPlan {
        case valid
        case repair(entry: MobilityEntry, phase: MobilityPhaseResult?, repairSideResult: Bool)
        case invalid
    }

    private static func reconciliationPlan(for session: MobilitySession) -> ReconciliationPlan {
        guard session.status == .active,
              session.endTime == nil,
              session.entries.isEmpty == false,
              Set(session.entries.map(\.id)).count == session.entries.count,
              Set(session.entries.map(\.orderIndex)).count == session.entries.count,
              session.entries.allSatisfy({ $0.pausedElapsedSeconds >= 0 })
        else { return .invalid }

        let orderedEntries = session.orderedEntries
        let inProgressPhases = orderedEntries.flatMap(\.phaseResults).filter { $0.status == .inProgress }
        if inProgressPhases.isEmpty == false {
            guard inProgressPhases.count == 1,
                  let phase = inProgressPhases.first,
                  let entry = phase.entry ?? orderedEntries.first(where: { $0.phaseResults.contains(where: { $0.id == phase.id }) }),
                  entry.isPhaseDriven,
                  phase.performedDurationSeconds == nil,
                  phase.performedIntensity == nil,
                  isOrderedPhaseGraphValid(entry, currentPhase: phase),
                  isEntryOrderValid(orderedEntries, currentEntry: entry),
                  entry.results.filter({ $0.side == phase.side }).count == 1,
                  entry.results.filter({ $0.status == .inProgress }).count <= 1,
                  orderedEntries.filter({ $0.timerStartedAt != nil }).allSatisfy({ $0.id == entry.id })
            else { return .invalid }

            guard let sideResult = entry.results.first(where: { $0.side == phase.side }),
                  sideResult.status == .inProgress || sideResult.status == .notStarted
            else { return .invalid }
            let cursorMatches = session.currentEntryIndex == entry.orderIndex
                && entry.currentCycleIndex == phase.cycleIndex
                && entry.currentPhaseIndex == phaseIndex(of: phase, in: entry)
            if cursorMatches && sideResult.status == .inProgress {
                return .valid
            }
            return .repair(
                entry: entry,
                phase: phase,
                repairSideResult: sideResult.status == .notStarted
            )
        }

        let simpleCandidates = orderedEntries.filter { entry in
            entry.isPhaseDriven == false
                && entry.results.isEmpty == false
                && entry.results.allSatisfy({ $0.status == .inProgress })
        }
        guard simpleCandidates.count == 1,
              let currentEntry = simpleCandidates.first,
              isEntryOrderValid(orderedEntries, currentEntry: currentEntry),
              orderedEntries.flatMap(\.phaseResults).allSatisfy({ $0.status != .inProgress }),
              orderedEntries.filter({ $0.timerStartedAt != nil }).allSatisfy({ $0.id == currentEntry.id })
        else { return .invalid }
        return session.currentEntryIndex == currentEntry.orderIndex
            ? .valid
            : .repair(entry: currentEntry, phase: nil, repairSideResult: false)
    }

    private static func isOrderedPhaseGraphValid(
        _ entry: MobilityEntry,
        currentPhase: MobilityPhaseResult
    ) -> Bool {
        let nodes = entry.orderedPhaseResults
        guard nodes.isEmpty == false,
              Set(nodes.map(\.id)).count == nodes.count,
              let index = nodes.firstIndex(where: { $0.id == currentPhase.id })
        else { return false }
        return nodes.prefix(index).allSatisfy { isTerminal($0.status) }
            && nodes.dropFirst(index + 1).allSatisfy { $0.status == .notStarted }
    }

    private static func isEntryOrderValid(
        _ entries: [MobilityEntry],
        currentEntry: MobilityEntry
    ) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == currentEntry.id }) else { return false }
        let earlierValid = entries.prefix(index).allSatisfy { entry in
            entry.results.isEmpty == false
                && entry.results.allSatisfy { isTerminal($0.status) }
                && entry.phaseResults.allSatisfy { isTerminal($0.status) }
        }
        let laterValid = entries.dropFirst(index + 1).allSatisfy { entry in
            entry.results.allSatisfy { $0.status == .notStarted }
                && entry.phaseResults.allSatisfy { $0.status == .notStarted }
                && entry.timerStartedAt == nil
        }
        return earlierValid && laterValid
    }

    private static func hasValidCurrentEvidence(in entry: MobilityEntry) -> Bool {
        if entry.isPhaseDriven {
            return entry.phaseResults.filter({ $0.status == .inProgress }).count == 1
                && entry.currentPhaseResult != nil
        }
        return entry.results.isEmpty == false
            && entry.results.allSatisfy { $0.status == .inProgress }
    }

    private static func isCompletedGraphValid(_ session: MobilitySession) -> Bool {
        session.status == .completed
            && session.endTime != nil
            && session.entries.isEmpty == false
            && session.entries.allSatisfy { entry in
                entry.timerStartedAt == nil
                    && entry.results.isEmpty == false
                    && entry.results.allSatisfy { isTerminal($0.status) }
                    && entry.phaseResults.allSatisfy { isTerminal($0.status) }
            }
    }

    private static func resetStartedSuccessor(
        _ successor: MobilityFlowTarget,
        in session: MobilitySession
    ) -> Bool {
        guard let entry = session.entries.first(where: { $0.id == successor.entryID }) else { return false }
        if let phaseID = successor.phaseResultID {
            guard let phase = entry.phaseResults.first(where: { $0.id == phaseID }),
                  phase.status == .inProgress,
                  phase.performedDurationSeconds == nil,
                  phase.performedIntensity == nil,
                  phase.completedAt == nil else { return false }
            phase.status = .notStarted
            phase.startedAt = nil
            let sidePhases = entry.phaseResults.filter { $0.side == phase.side && $0.id != phase.id }
            if let sideResult = entry.results.first(where: { $0.side == phase.side }) {
                let hasPriorEvidence = sidePhases.contains { isTerminal($0.status) }
                sideResult.status = hasPriorEvidence ? .inProgress : .notStarted
                sideResult.completedAt = nil
                if hasPriorEvidence == false { sideResult.startedAt = nil }
            }
        } else {
            guard entry.isPhaseDriven == false,
                  entry.results.isEmpty == false,
                  entry.results.allSatisfy({ $0.status == .inProgress && $0.completedAt == nil })
            else { return false }
            for result in entry.results {
                result.status = .notStarted
                result.performedDurationSeconds = nil
                result.performedRepetitions = nil
                result.performedLoadValue = nil
                result.performedLoadUnit = nil
                result.perceivedIntensity = nil
                result.discomfortNote = nil
                result.startedAt = nil
            }
        }
        entry.timerStartedAt = nil
        entry.pausedElapsedSeconds = 0
        return true
    }

    private static func phaseIndex(
        of phase: MobilityPhaseResult,
        in entry: MobilityEntry
    ) -> Int {
        entry.orderedPhaseResults
            .filter { $0.side == phase.side && $0.cycleIndex == phase.cycleIndex }
            .firstIndex(where: { $0.id == phase.id }) ?? 0
    }

    private static func isTerminal(_ status: MobilityResultStatus) -> Bool {
        switch status {
        case .notStarted, .inProgress: false
        case .completed, .partial, .skipped, .stopped: true
        }
    }

    private static func flowSnapshot(for session: MobilitySession) -> MobilityFlowSnapshot {
        MobilityFlowSnapshot(
            currentEntryIndex: session.currentEntryIndex,
            entries: session.orderedEntries.map { entry in
                var phaseIndexByGroup: [String: Int] = [:]
                let nodes = entry.orderedPhaseResults.map { phase -> MobilityFlowNodeSnapshot in
                    let groupKey = "\(phase.side.rawValue)|\(phase.cycleIndex)"
                    let phaseIndex = phaseIndexByGroup[groupKey, default: 0]
                    phaseIndexByGroup[groupKey] = phaseIndex + 1
                    return MobilityFlowNodeSnapshot(
                        id: phase.id,
                        orderIndex: phase.orderIndex,
                        phaseIndex: phaseIndex,
                        cycleIndex: phase.cycleIndex,
                        side: phase.side,
                        sideOrder: sideOrder(phase.side),
                        phaseType: phase.phaseType,
                        prescribedDurationSeconds: phase.prescribedDurationSeconds,
                        status: phase.status
                    )
                }
                return MobilityFlowEntrySnapshot(
                    id: entry.id,
                    orderIndex: entry.orderIndex,
                    currentCycleIndex: entry.currentCycleIndex,
                    currentPhaseIndex: entry.currentPhaseIndex,
                    restSeconds: entry.restSeconds,
                    resultStatuses: entry.orderedResults.map(\.status),
                    phaseNodes: nodes
                )
            }
        )
    }

    private static func sideOrder(_ side: MobilitySide) -> Int {
        switch side {
        case .none: 0
        case .left: 1
        case .right: 2
        case .bilateral: 3
        case .alternating: 4
        }
    }

    private static func save(session: MobilitySession, using modelContext: ModelContext) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            return false
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
