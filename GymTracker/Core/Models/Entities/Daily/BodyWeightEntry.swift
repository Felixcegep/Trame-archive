import Foundation
import SwiftData

enum BodyWeightSource: String, Codable, CaseIterable {
    case settings
    case checkIn
    case healthKit
}

/// One user-authored body-weight observation for a local calendar day.
/// The entered value and unit remain immutable historical evidence unless the
/// user explicitly edits that day's measurement.
@Model
final class BodyWeightEntry {
    var id: UUID
    var dayKey: String
    var value: Float
    var unitRaw: String
    var sourceRaw: String
    var measuredAt: Date
    var createdAt: Date
    var updatedAt: Date

    var unit: WeightType {
        get { WeightType(rawValue: unitRaw) ?? .kg }
        set { unitRaw = newValue.rawValue }
    }

    var source: BodyWeightSource {
        get { BodyWeightSource(rawValue: sourceRaw) ?? .settings }
        set { sourceRaw = newValue.rawValue }
    }

    var kilograms: Float {
        UnitConversion.weight(value, from: unit, to: .kg)
    }

    init(
        day: LocalDay = .today,
        value: Float,
        unit: WeightType,
        source: BodyWeightSource = .settings,
        measuredAt: Date = .now,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        id: UUID = UUID()
    ) {
        self.id = id
        self.dayKey = day.rawValue
        self.value = value
        self.unitRaw = unit.rawValue
        self.sourceRaw = source.rawValue
        self.measuredAt = measuredAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func update(value: Float, unit: WeightType, source: BodyWeightSource, measuredAt: Date) {
        self.value = value
        self.unit = unit
        self.source = source
        self.measuredAt = measuredAt
        updatedAt = .now
    }
}

enum BodyWeightPromptCadence: String, Codable, CaseIterable {
    case off
    case weekly
    case monthly

    func isDue(latest: BodyWeightEntry?, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard self != .off else { return false }
        guard let latest else { return true }
        let component: Calendar.Component = self == .weekly ? .day : .month
        let value = self == .weekly ? 7 : 1
        guard let dueDate = calendar.date(byAdding: component, value: value, to: latest.measuredAt) else { return false }
        return now >= dueDate
    }
}
