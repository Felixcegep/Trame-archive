import Foundation

nonisolated enum TrainingStimulus: String, Codable, CaseIterable, Sendable {
    case strength = "Strength"
    case hypertrophy = "Hypertrophy"
    case power = "Power"
    case endurance = "Endurance"
    case mobility = "Mobility"

    var title: String { rawValue }
}

enum PlanGoal: String, Codable, CaseIterable {
    case generalStrength
    case hypertrophy
    case powerlifting
    case generalFitness
}

enum PlanExperienceLevel: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced
}

enum PlanPhaseType: String, Codable, CaseIterable {
    case accumulation
    case hypertrophy
    case strength
    case peaking
    case deload
}

/// Controls how a PlanRun places future sessions on the local calendar.
/// `dayOffset` remains the source-of-truth for fixed-weekday plans; the other
/// modes derive dates from session order without changing the prescription.
enum PlanScheduleMode: String, Codable, CaseIterable, Hashable {
    case fixedWeekdays
    case sequential
    case everyNDays

    var title: String {
        switch self {
        case .fixedWeekdays: return "Fixed weekdays"
        case .sequential: return "Sequential sessions"
        case .everyNDays: return "Every N days"
        }
    }
}

enum PlanRunStatus: String, Codable {
    case active
    case paused
    case testDayAvailable
    case completed
    case archived
}

enum PlanWorkoutStatus: String, Codable {
    case upcoming
    case available
    case inProgress
    case completed
    case skipped
}

nonisolated enum ExerciseRole: String, Codable, CaseIterable, Sendable {
    case preparation
    case main
    case secondary
    case accessory
}

enum ProgressionRule: String, Codable, CaseIterable {
    case none
    case doubleProgression
}

enum DoubleProgressionDecision: String, Codable, Equatable, Sendable {
    case hold
    case increase
}
