import Foundation
import SwiftData

enum DailyCheckInStatus: String, Codable, CaseIterable {
    case completed
    case skipped
}

/// One optional user-authored reflection for a local calendar day. It never
/// owns workout, nutrition, or supplement truth.
@Model
final class DailyLogEntry {
    var id: UUID
    var dayKey: String
    var statusRaw: String
    var sleepQuality: Int?
    var energy: Int?
    var workoutDifficulty: Int?
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    var status: DailyCheckInStatus {
        get { DailyCheckInStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }

    init(
        day: LocalDay = .today,
        status: DailyCheckInStatus = .completed,
        sleepQuality: Int? = nil,
        energy: Int? = nil,
        workoutDifficulty: Int? = nil,
        note: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        id: UUID = UUID()
    ) {
        self.id = id
        self.dayKey = day.rawValue
        self.statusRaw = status.rawValue
        self.sleepQuality = sleepQuality
        self.energy = energy
        self.workoutDifficulty = workoutDifficulty
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func update(
        status: DailyCheckInStatus,
        sleepQuality: Int?,
        energy: Int?,
        workoutDifficulty: Int?,
        note: String?
    ) {
        self.status = status
        self.sleepQuality = sleepQuality
        self.energy = energy
        self.workoutDifficulty = workoutDifficulty
        self.note = note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        updatedAt = .now
    }
}

private extension String {
    nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}
