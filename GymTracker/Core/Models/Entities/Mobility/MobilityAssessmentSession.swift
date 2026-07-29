import Foundation
import SwiftData

@Model
final class MobilityAssessmentSession {
    var id: UUID
    var statusRaw: String
    var dayKey: String
    var selectedDefinitionKeys: [String]
    var skippedDefinitionKeys: [String]
    var currentDefinitionIndex: Int
    var startedAt: Date
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \MobilityAssessmentResult.session)
    var results: [MobilityAssessmentResult] = []

    var status: MobilityAssessmentSessionStatus {
        get { MobilityAssessmentSessionStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var day: LocalDay {
        get { LocalDay(rawValue: dayKey) }
        set { dayKey = newValue.rawValue }
    }

    var orderedResults: [MobilityAssessmentResult] {
        results.sorted {
            if $0.orderIndex == $1.orderIndex {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.orderIndex < $1.orderIndex
        }
    }

    init(
        day: LocalDay,
        selectedDefinitionKeys: [String],
        id: UUID = UUID(),
        startedAt: Date = .now,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.statusRaw = MobilityAssessmentSessionStatus.active.rawValue
        self.dayKey = day.rawValue
        self.selectedDefinitionKeys = selectedDefinitionKeys
        self.skippedDefinitionKeys = []
        self.currentDefinitionIndex = 0
        self.startedAt = startedAt
        self.completedAt = nil
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
