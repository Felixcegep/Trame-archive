import Foundation
import SwiftData

/// Shared write path for today's supplement occurrences. `HomeView`'s daily
/// toggle and `ConfirmCreatineIntent` both funnel through this so a
/// shortcut-confirmed dose and a manually confirmed one update the exact same
/// `occurrenceKey`-unique record instead of racing to create two.
@MainActor
enum SupplementOccurrenceService {
    @discardableResult
    static func setCreatine(taken: Bool, day: LocalDay? = nil, using context: ModelContext) -> SupplementOccurrence? {
        let occurrence = existingOrNewOccurrence(kind: .creatine, day: day ?? .today, using: context)
        occurrence.update(status: taken ? .completed : .skipped)
        return context.saveOrRollback() ? occurrence : nil
    }

    @discardableResult
    static func confirmCreatine(day: LocalDay? = nil, using context: ModelContext) -> SupplementOccurrence? {
        setCreatine(taken: true, day: day ?? .today, using: context)
    }

    private static func existingOrNewOccurrence(kind: SupplementKind, day: LocalDay, using context: ModelContext) -> SupplementOccurrence {
        let occurrenceKey = "\(day.rawValue)|\(kind.rawValue)"
        if let existing = (try? context.fetch(FetchDescriptor<SupplementOccurrence>()))?.first(where: { $0.occurrenceKey == occurrenceKey }) {
            return existing
        }
        let occurrence = SupplementOccurrence(kind: kind, day: day, status: .skipped, completedAt: nil)
        context.insert(occurrence)
        return occurrence
    }
}
