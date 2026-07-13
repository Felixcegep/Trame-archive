import Foundation

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

enum PlanRunStatus: String, Codable {
    case active
    case paused
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

enum ExerciseRole: String, Codable, CaseIterable {
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
