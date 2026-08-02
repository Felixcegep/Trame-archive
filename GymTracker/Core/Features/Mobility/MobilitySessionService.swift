import Foundation
import SwiftData

struct MobilityResultInput {
    var performedDurationSeconds: Int?
    var performedRepetitions: Int?
    var performedLoadValue: Double?
    var performedLoadUnit: MobilityLoadUnit?
    var perceivedIntensity: Int?
    var discomfortNote: String?
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

    private static func finishCurrent(
        in session: MobilitySession,
        status: MobilityResultStatus,
        resultInputs: [UUID: MobilityResultInput],
        using modelContext: ModelContext
    ) -> Bool {
        guard session.status == .active, let entry = session.currentEntry else { return false }
        // Phase-driven work is intentionally not collapsed into the legacy
        // whole-entry action. PR 13 owns completing one phase and advancing
        // side/cycle/phase cursors.
        guard entry.isPhaseDriven == false else { return false }
        complete(entry: entry, status: status, resultInputs: resultInputs)
        advance(session: session)
        return save(session: session, using: modelContext)
    }

    @discardableResult
    static func stop(_ session: MobilitySession, using modelContext: ModelContext) -> Bool {
        guard session.status == .active else { return false }
        for entry in session.orderedEntries {
            for result in entry.results where result.status == .notStarted || result.status == .inProgress {
                result.status = .stopped
                result.completedAt = .now
            }
            for phaseResult in entry.phaseResults
                where phaseResult.status == .notStarted || phaseResult.status == .inProgress {
                phaseResult.status = .stopped
                phaseResult.completedAt = .now
            }
            entry.timerStartedAt = nil
        }
        session.status = .stopped
        session.endTime = .now
        return save(session: session, using: modelContext)
    }

    static func elapsedSeconds(for entry: MobilityEntry, now: Date = .now) -> Int {
        guard let startedAt = entry.timerStartedAt else { return 0 }
        return max(0, Int(now.timeIntervalSince(startedAt)))
    }

    private static func begin(entry: MobilityEntry?, now: Date = .now) {
        guard let entry else { return }
        guard entry.isPhaseDriven else {
            // Preserve the existing simple duration/repetition start contract.
            entry.timerStartedAt = entry.trackingType == .duration ? now : nil
            for result in entry.results {
                result.status = .inProgress
                result.startedAt = now
            }
            return
        }

        guard let firstPhase = entry.orderedPhaseResults.first else { return }
        entry.currentCycleIndex = firstPhase.cycleIndex
        entry.currentPhaseIndex = 0
        entry.timerStartedAt = now
        firstPhase.status = .inProgress
        firstPhase.startedAt = now
        if let sideResult = entry.results.first(where: { $0.side == firstPhase.side }) {
            sideResult.status = .inProgress
            sideResult.startedAt = now
        }
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

    private static func advance(session: MobilitySession) {
        session.currentEntryIndex += 1
        if session.currentEntry == nil {
            session.status = .completed
            session.endTime = .now
        } else {
            begin(entry: session.currentEntry)
        }
        session.updatedAt = .now
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
