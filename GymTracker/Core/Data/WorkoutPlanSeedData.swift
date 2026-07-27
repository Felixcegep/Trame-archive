import Foundation
import SwiftData

struct WorkoutPlanSeedDefinition {
    let seedKey: String
    let name: String
    let goal: PlanGoal
    let experienceLevel: PlanExperienceLevel
    let requiredEquipment: [EquipmentType]
    let daysPerWeek: Int
    let durationWeeks: Int
    let notes: String
    let makePlan: ([Exercise]) -> WorkoutPlan?
}

enum WorkoutPlanSeedData {
    static func plans(using exercises: [Exercise]) -> [(key: String, plan: WorkoutPlan)] {
        let definitions: [WorkoutPlanSeedDefinition] = [
            hypertrophyBaseEightWeek,
            powerliftingFoundationsEightWeek,
            olympicWeightliftingFoundationsEightWeek,
            strongmanFoundationsSixWeek
        ]
        return definitions.compactMap { def in
            guard let plan = def.makePlan(exercises) else { return nil }
            return (def.seedKey, plan)
        }
    }

    // MARK: - 1. Hypertrophy Base — 8 Weeks
    static let hypertrophyBaseEightWeek = WorkoutPlanSeedDefinition(
        seedKey: "workout-plan.hypertrophy-base-eight-week",
        name: "Hypertrophy Base — 8 Weeks",
        goal: .hypertrophy,
        experienceLevel: .intermediate,
        requiredEquipment: [.barbell, .dumbbell, .cable, .machine],
        daysPerWeek: 4,
        durationWeeks: 8,
        notes: "An 8-week hypertrophy progression split into 3 blocks: Base Volume (Weeks 1–3), Overload (Weeks 4–7), and Deload (Week 8).",
        makePlan: { exercises in
            makeEightWeekHypertrophyPlan(exercises: exercises)
        }
    )

    // MARK: - 2. Powerlifting Foundations — 8 Weeks
    static let powerliftingFoundationsEightWeek = WorkoutPlanSeedDefinition(
        seedKey: "workout-plan.powerlifting-foundations-eight-week",
        name: "Powerlifting Foundations — 8 Weeks",
        goal: .generalStrength,
        experienceLevel: .intermediate,
        requiredEquipment: [.barbell, .dumbbell, .cable],
        daysPerWeek: 3,
        durationWeeks: 8,
        notes: "An 8-week competition lift progression: Accumulation (Weeks 1–4), Intensity Peak (Weeks 5–7), and Deload / 1RM Test (Week 8).",
        makePlan: { exercises in
            makeEightWeekPowerliftingPlan(exercises: exercises)
        }
    )

    // MARK: - 3. Olympic Weightlifting Foundations — 8 Weeks
    static let olympicWeightliftingFoundationsEightWeek = WorkoutPlanSeedDefinition(
        seedKey: "workout-plan.olympic-weightlifting-foundations-eight-week",
        name: "Olympic Weightlifting Foundations — 8 Weeks",
        goal: .generalStrength,
        experienceLevel: .intermediate,
        requiredEquipment: [.barbell],
        daysPerWeek: 3,
        durationWeeks: 8,
        notes: "An 8-week positional weightlifting program: Position & Mobility (Weeks 1–4), Load Acceleration (Weeks 5–7), and Technical Assessment (Week 8).",
        makePlan: { exercises in
            makeEightWeekOlympicPlan(exercises: exercises)
        }
    )

    // MARK: - 4. Strongman Foundations — 6 Weeks
    static let strongmanFoundationsSixWeek = WorkoutPlanSeedDefinition(
        seedKey: "workout-plan.strongman-foundations-six-week",
        name: "Strongman Foundations — 6 Weeks",
        goal: .generalStrength,
        experienceLevel: .intermediate,
        requiredEquipment: [.barbell, .dumbbell, .machine],
        daysPerWeek: 3,
        durationWeeks: 6,
        notes: "A 6-week functional strength & event program: Heavy Base (Weeks 1–3), Event Peak (Weeks 4–5), and Deload Assessment (Week 6).",
        makePlan: { exercises in
            makeSixWeekStrongmanPlan(exercises: exercises)
        }
    )

    // MARK: - Plan Construction Helpers

    private static func makeEightWeekHypertrophyPlan(exercises: [Exercise]) -> WorkoutPlan? {
        let byName = Dictionary(
            exercises.uniquedByNamePreferringSystem().map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let day1Ex: [(String, Int, Int, Int, Double, Int)] = [
            ("Goblet Stiletto Squat", 3, 8, 10, 7.5, 120),
            ("Bulgarian Split Squat", 3, 8, 10, 8.0, 120),
            ("Leg Extension", 3, 12, 15, 8.5, 90),
            ("Copenhagen Plank", 3, 20, 30, 7.0, 60)
        ]
        let day2Ex: [(String, Int, Int, Int, Double, Int)] = [
            ("Bench Press", 3, 6, 8, 8.0, 120),
            ("Barbell Row", 3, 6, 8, 8.0, 120),
            ("Dumbbell Incline Press", 3, 8, 10, 8.0, 90),
            ("Lat Pulldown", 3, 8, 10, 8.0, 90),
            ("Face Pull", 3, 12, 15, 7.5, 60)
        ]
        let day3Ex: [(String, Int, Int, Int, Double, Int)] = [
            ("B-Stance RDL", 3, 8, 10, 8.0, 120),
            ("45-Degree Back Extension", 3, 12, 15, 8.0, 90),
            ("Seated Leg Curl", 3, 10, 12, 8.5, 90),
            ("Standing Calf Raise", 3, 12, 15, 8.0, 60)
        ]
        let day4Ex: [(String, Int, Int, Int, Double, Int)] = [
            ("Overhead Press", 3, 6, 8, 8.0, 120),
            ("Pull-Up", 3, 6, 8, 8.0, 120),
            ("Dumbbell Bench Press", 3, 10, 10, 8.0, 90),
            ("Chest-Supported Row", 3, 10, 10, 8.0, 90),
            ("Lateral Raise", 3, 12, 15, 8.5, 60)
        ]

        let makeWorkout = { (name: String, offset: Int, exData: [(String, Int, Int, Int, Double, Int)]) -> PlannedWorkout in
            PlannedWorkout(
                name: name,
                orderIndex: offset,
                dayOffset: offset,
                estimatedDurationSeconds: 3600,
                plannedExercises: exData.enumerated().compactMap { idx, item -> PlannedExercise? in
                    guard let ex = byName[item.0] else { return nil }
                    return PlannedExercise(
                        exercise: ex,
                        orderIndex: idx,
                        role: idx == 0 ? .main : .secondary,
                        targetSets: item.1,
                        repRangeMinimum: item.2,
                        repRangeMaximum: item.3,
                        restSeconds: item.5,
                        targetRPE: item.4
                    )
                }
            )
        }

        let buildWeek = { (weekIdx: Int) -> PlanWeek in
            PlanWeek(
                weekIndex: weekIdx,
                name: "Week \(weekIdx + 1)",
                plannedWorkouts: [
                    makeWorkout("Lower Body A (Squat Focus)", 0, day1Ex),
                    makeWorkout("Upper Body A (Push/Pull)", 1, day2Ex),
                    makeWorkout("Lower Body B (Posterior Chain)", 3, day3Ex),
                    makeWorkout("Upper Body B (Vertical Push/Pull)", 4, day4Ex)
                ]
            )
        }

        let weeks = (0..<8).map { buildWeek($0) }
        return WorkoutPlan(
            name: "Hypertrophy Base — 8 Weeks",
            goal: .hypertrophy,
            experienceLevel: .intermediate,
            requiredEquipment: [.barbell, .dumbbell, .cable, .machine],
            daysPerWeek: 4,
            durationWeeks: 8,
            notes: "An 8-week hypertrophy progression: Base Volume (Weeks 1–3), Overload (Weeks 4–7), and Deload (Week 8).",
            blocks: [
                PlanBlock(name: "Base Volume", phaseType: .hypertrophy, orderIndex: 0, goal: "Establish volume baseline", weeks: Array(weeks[0...2])),
                PlanBlock(name: "Progressive Overload", phaseType: .hypertrophy, orderIndex: 1, goal: "Increase intensity & set volume", weeks: Array(weeks[3...6])),
                PlanBlock(name: "Deload", phaseType: .deload, orderIndex: 2, goal: "Consolidate recovery", deloadIntensityReductionPercent: 30, weeks: [weeks[7]])
            ]
        )
    }

    private static func makeEightWeekPowerliftingPlan(exercises: [Exercise]) -> WorkoutPlan? {
        let byName = Dictionary(
            exercises.uniquedByNamePreferringSystem().map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let day1Ex: [(String, Int, Int, Int, Double, Int)] = [
            ("Back Squat", 4, 5, 5, 7.5, 180),
            ("Bench Press", 4, 6, 6, 7.5, 180),
            ("Romanian Deadlift", 3, 8, 8, 7.5, 150),
            ("Chest-Supported Row", 3, 8, 12, 8.0, 90)
        ]
        let day2Ex: [(String, Int, Int, Int, Double, Int)] = [
            ("Bench Press", 4, 5, 5, 7.5, 180),
            ("Pause Squat", 3, 5, 5, 7.0, 180),
            ("Overhead Press", 3, 6, 10, 8.0, 120),
            ("Lat Pulldown", 3, 8, 12, 8.0, 90)
        ]
        let day3Ex: [(String, Int, Int, Int, Double, Int)] = [
            ("Deadlift", 4, 4, 5, 7.5, 180),
            ("Pause Bench Press", 4, 5, 5, 7.0, 180),
            ("Bulgarian Split Squat", 3, 8, 8, 8.0, 120),
            ("Barbell Row", 3, 8, 12, 8.0, 120)
        ]

        let makeWorkout = { (name: String, offset: Int, exData: [(String, Int, Int, Int, Double, Int)]) -> PlannedWorkout in
            PlannedWorkout(
                name: name,
                orderIndex: offset,
                dayOffset: offset,
                estimatedDurationSeconds: 3600,
                plannedExercises: exData.enumerated().compactMap { idx, item -> PlannedExercise? in
                    guard let ex = byName[item.0] else { return nil }
                    return PlannedExercise(
                        exercise: ex,
                        orderIndex: idx,
                        role: idx == 0 ? .main : .secondary,
                        targetSets: item.1,
                        repRangeMinimum: item.2,
                        repRangeMaximum: item.3,
                        restSeconds: item.5,
                        targetRPE: item.4
                    )
                }
            )
        }

        let buildWeek = { (weekIdx: Int) -> PlanWeek in
            PlanWeek(
                weekIndex: weekIdx,
                name: "Week \(weekIdx + 1)",
                plannedWorkouts: [
                    makeWorkout("Day 1 — Squat Priority", 0, day1Ex),
                    makeWorkout("Day 2 — Bench Priority", 2, day2Ex),
                    makeWorkout("Day 3 — Deadlift Priority", 4, day3Ex)
                ]
            )
        }

        let weeks = (0..<8).map { buildWeek($0) }
        return WorkoutPlan(
            name: "Powerlifting Foundations — 8 Weeks",
            goal: .generalStrength,
            experienceLevel: .intermediate,
            requiredEquipment: [.barbell, .dumbbell, .cable],
            daysPerWeek: 3,
            durationWeeks: 8,
            notes: "An 8-week powerlifting program: Accumulation (Weeks 1–4), Intensity Peak (Weeks 5–7), and Deload / 1RM Test (Week 8).",
            blocks: [
                PlanBlock(name: "Accumulation", phaseType: .strength, orderIndex: 0, goal: "Technical mastery and strength volume", weeks: Array(weeks[0...3])),
                PlanBlock(name: "Intensity Peak", phaseType: .strength, orderIndex: 1, goal: "Peak force production and heavy singles", weeks: Array(weeks[4...6])),
                PlanBlock(name: "Deload & Test", phaseType: .deload, orderIndex: 2, goal: "Consolidate and test 1RM baseline", deloadIntensityReductionPercent: 25, weeks: [weeks[7]])
            ]
        )
    }

    private static func makeEightWeekOlympicPlan(exercises: [Exercise]) -> WorkoutPlan? {
        let byName = Dictionary(
            exercises.uniquedByNamePreferringSystem().map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let day1Ex: [(String, Int, Int, Int, Double, Int)] = [
            ("Muscle Snatch", 3, 3, 3, 6.0, 90),
            ("Hang Snatch", 5, 2, 2, 6.5, 120),
            ("Overhead Squat", 3, 3, 3, 6.5, 120),
            ("Front Squat", 3, 5, 5, 7.0, 150)
        ]
        let day2Ex: [(String, Int, Int, Int, Double, Int)] = [
            ("Hang Clean", 5, 2, 2, 6.5, 120),
            ("Split Jerk", 5, 2, 2, 6.5, 120),
            ("Snatch Pull", 3, 3, 3, 7.0, 150),
            ("Bulgarian Split Squat", 3, 8, 8, 7.5, 90)
        ]
        let day3Ex: [(String, Int, Int, Int, Double, Int)] = [
            ("Snatch", 5, 2, 2, 7.0, 150),
            ("Clean and Jerk", 5, 2, 2, 7.0, 180),
            ("Back Squat", 4, 5, 5, 7.0, 180),
            ("Barbell Row", 3, 8, 10, 8.0, 120)
        ]

        let makeWorkout = { (name: String, offset: Int, exData: [(String, Int, Int, Int, Double, Int)]) -> PlannedWorkout in
            PlannedWorkout(
                name: name,
                orderIndex: offset,
                dayOffset: offset,
                estimatedDurationSeconds: 3600,
                plannedExercises: exData.enumerated().compactMap { idx, item -> PlannedExercise? in
                    guard let ex = byName[item.0] else { return nil }
                    return PlannedExercise(
                        exercise: ex,
                        orderIndex: idx,
                        role: idx == 0 ? .main : .secondary,
                        targetSets: item.1,
                        repRangeMinimum: item.2,
                        repRangeMaximum: item.3,
                        restSeconds: item.5,
                        targetRPE: item.4
                    )
                }
            )
        }

        let buildWeek = { (weekIdx: Int) -> PlanWeek in
            PlanWeek(
                weekIndex: weekIdx,
                name: "Week \(weekIdx + 1)",
                plannedWorkouts: [
                    makeWorkout("Day 1 — Snatch Positions", 0, day1Ex),
                    makeWorkout("Day 2 — Clean & Jerk Positions", 2, day2Ex),
                    makeWorkout("Day 3 — Lift Integration", 4, day3Ex)
                ]
            )
        }

        let weeks = (0..<8).map { buildWeek($0) }
        return WorkoutPlan(
            name: "Olympic Weightlifting Foundations — 8 Weeks",
            goal: .generalStrength,
            experienceLevel: .intermediate,
            requiredEquipment: [.barbell],
            daysPerWeek: 3,
            durationWeeks: 8,
            notes: "An 8-week weightlifting program: Position & Mobility (Weeks 1–4), Load Acceleration (Weeks 5–7), and Technical Assessment (Week 8).",
            blocks: [
                PlanBlock(name: "Positions & Technique", phaseType: .accumulation, orderIndex: 0, goal: "Hang positions, overhead stability, rack positions", weeks: Array(weeks[0...3])),
                PlanBlock(name: "Load Acceleration", phaseType: .strength, orderIndex: 1, goal: "Heavy doubles and position transfer", weeks: Array(weeks[4...6])),
                PlanBlock(name: "Technical Assessment", phaseType: .peaking, orderIndex: 2, goal: "Assess technical maximums cleanly", deloadIntensityReductionPercent: 20, weeks: [weeks[7]])
            ]
        )
    }

    private static func makeSixWeekStrongmanPlan(exercises: [Exercise]) -> WorkoutPlan? {
        let byName = Dictionary(
            exercises.uniquedByNamePreferringSystem().map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let day1Ex: [(String, Int, Int, Int, Double, Int)] = [
            ("Overhead Press", 4, 5, 5, 7.0, 180),
            ("Close-Grip Bench Press", 3, 6, 8, 8.0, 120),
            ("Chest-Supported Row", 4, 8, 12, 8.0, 90),
            ("Dip", 3, 10, 15, 8.0, 90),
            ("Farmer's Carry", 4, 20, 20, 7.5, 120)
        ]
        let day2Ex: [(String, Int, Int, Int, Double, Int)] = [
            ("Deadlift", 4, 4, 4, 7.0, 180),
            ("Front Squat", 3, 5, 8, 7.5, 150),
            ("Romanian Deadlift", 3, 8, 8, 7.5, 120),
            ("Seated Leg Curl", 3, 10, 15, 8.0, 90)
        ]
        let day3Ex: [(String, Int, Int, Int, Double, Int)] = [
            ("Farmer's Carry", 4, 25, 30, 8.0, 150),
            ("Power Clean", 5, 3, 3, 7.5, 120),
            ("Single-Arm Dumbbell Row", 3, 8, 12, 8.0, 90),
            ("Plank", 3, 30, 45, 7.0, 60)
        ]

        let makeWorkout = { (name: String, offset: Int, exData: [(String, Int, Int, Int, Double, Int)]) -> PlannedWorkout in
            PlannedWorkout(
                name: name,
                orderIndex: offset,
                dayOffset: offset,
                estimatedDurationSeconds: 3600,
                plannedExercises: exData.enumerated().compactMap { idx, item -> PlannedExercise? in
                    guard let ex = byName[item.0] else { return nil }
                    return PlannedExercise(
                        exercise: ex,
                        orderIndex: idx,
                        role: idx == 0 ? .main : .secondary,
                        targetSets: item.1,
                        repRangeMinimum: item.2,
                        repRangeMaximum: item.3,
                        restSeconds: item.5,
                        targetRPE: item.4
                    )
                }
            )
        }

        let buildWeek = { (weekIdx: Int) -> PlanWeek in
            PlanWeek(
                weekIndex: weekIdx,
                name: "Week \(weekIdx + 1)",
                plannedWorkouts: [
                    makeWorkout("Day 1 — Overhead Strength", 0, day1Ex),
                    makeWorkout("Day 2 — Deadlift & Lower Body", 2, day2Ex),
                    makeWorkout("Day 3 — Events & Conditioning", 4, day3Ex)
                ]
            )
        }

        let weeks = (0..<6).map { buildWeek($0) }
        return WorkoutPlan(
            name: "Strongman Foundations — 6 Weeks",
            goal: .generalStrength,
            experienceLevel: .intermediate,
            requiredEquipment: [.barbell, .dumbbell, .machine],
            daysPerWeek: 3,
            durationWeeks: 6,
            notes: "A 6-week strongman program: Heavy Base (Weeks 1–3), Event Peak (Weeks 4–5), and Deload Assessment (Week 6).",
            blocks: [
                PlanBlock(name: "Heavy Base & Carrying", phaseType: .strength, orderIndex: 0, goal: "Pressing, deadlift, carrying volume", weeks: Array(weeks[0...2])),
                PlanBlock(name: "Event Peak", phaseType: .strength, orderIndex: 1, goal: "Heavy loaded carries and overhead peak", weeks: Array(weeks[3...4])),
                PlanBlock(name: "Deload & Event Assessment", phaseType: .deload, orderIndex: 2, goal: "Consolidate and test peak capacity", deloadIntensityReductionPercent: 25, weeks: [weeks[5]])
            ]
        )
    }
}
