import Foundation
import SwiftData

struct MobilityResultInput {
    var performedDurationSeconds: Int?
    var performedRepetitions: Int?
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
        using modelContext: ModelContext
    ) -> MobilitySession? {
        guard routine.isArchived == false, routine.orderedItems.isEmpty == false else { return nil }
        guard activeSession(using: modelContext) == nil else { return nil }

        let session = MobilitySession(
            nameSnapshot: routine.name,
            sourceRoutineID: routine.id,
            sourceRoutineName: routine.name,
            workoutID: workoutID,
            context: context
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
            return entry
        }
        begin(entry: session.currentEntry)
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

    private static func begin(entry: MobilityEntry?) {
        guard let entry else { return }
        entry.timerStartedAt = entry.trackingType == .duration ? .now : nil
        for result in entry.results {
            result.status = .inProgress
            result.startedAt = .now
        }
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
