import Foundation
import SwiftData

struct RepeatingPlanSeedDefinition {
    let seedKey: String
    let name: String
    let goal: PlanGoal
    let experienceLevel: PlanExperienceLevel
    let requiredEquipment: [EquipmentType]
    let notes: String?
    let templateSeedKeys: [String]
}

enum RepeatingPlanSeedData {
    static let pplContinuous = RepeatingPlanSeedDefinition(
        seedKey: "repeating-plan.ppl-continuous",
        name: "PPL Continuous",
        goal: .hypertrophy,
        experienceLevel: .intermediate,
        requiredEquipment: [.barbell, .dumbbell, .cable, .machine],
        notes: "Push → Pull → Legs. Continue in order whenever you train.",
        templateSeedKeys: [
            "workout-template.ppl--u2013--push-day--u28-chest-u2c--shoulders-u2c--triceps-u29",
            "workout-template.ppl--u2013--pull-day--u28-back-u2c--rear-delts-u2c--biceps-u29",
            "workout-template.ppl--u2013--leg-day--u28-quads-u2c--hamstrings-u2c--calves-u29"
        ]
    )

    static let beginnerFullBodyAB = RepeatingPlanSeedDefinition(
        seedKey: "repeating-plan.beginner-full-body-a-b",
        name: "Beginner Full Body A/B",
        goal: .generalFitness,
        experienceLevel: .beginner,
        requiredEquipment: [.dumbbell],
        notes: "Alternate two approachable full-body workouts whenever you train.",
        templateSeedKeys: [
            "workout-template.full-body-a--u28-squat--u26--push-focus-u29",
            "workout-template.full-body-b--u28-hinge--u26--pull-focus-u29"
        ]
    )

    static let simpleBarbellStrengthAB = RepeatingPlanSeedDefinition(
        seedKey: "repeating-plan.simple-barbell-strength-ab",
        name: "Simple Barbell Strength A/B",
        goal: .generalStrength,
        experienceLevel: .beginner,
        requiredEquipment: [.barbell, .cable],
        notes: "A simple full-body A/B loop focused on consistent strength practice.",
        templateSeedKeys: [
            "workout-template.simple-barbell-strength-a",
            "workout-template.simple-barbell-strength-b"
        ]
    )

    static let upperLowerContinuous = RepeatingPlanSeedDefinition(
        seedKey: "repeating-plan.upper-lower-continuous",
        name: "Upper/Lower Continuous",
        goal: .generalStrength,
        experienceLevel: .intermediate,
        requiredEquipment: [.barbell, .dumbbell, .cable, .machine],
        notes: "Lower A → Upper A → Lower B → Upper B. Continue in order whenever you train.",
        templateSeedKeys: [
            "workout-template.day-1--u2013--lower-body--u28-squat-focus-u29",
            "workout-template.day-2--u2013--upper-body--u28-push-slash-pull-u29",
            "workout-template.day-3--u2013--lower-body--u28-posterior-chain-u29",
            "workout-template.day-4--u2013--upper-body--u28-vertical-push-slash-pull-u29"
        ]
    )

    static let twoDayExpress = RepeatingPlanSeedDefinition(
        seedKey: "repeating-plan.two-day-express",
        name: "Two-Day Express",
        goal: .generalStrength,
        experienceLevel: .beginner,
        requiredEquipment: [.dumbbell, .cable, .machine],
        notes: "High-efficiency 2-day full-body strength routine for limited schedules.",
        templateSeedKeys: [
            "workout-template.express-a",
            "workout-template.express-b"
        ]
    )

    static let homeDumbbellAB = RepeatingPlanSeedDefinition(
        seedKey: "repeating-plan.home-dumbbell-ab",
        name: "Home/Dumbbell",
        goal: .generalFitness,
        experienceLevel: .beginner,
        requiredEquipment: [.dumbbell],
        notes: "A compact full-body session built around dumbbells.",
        templateSeedKeys: [
            "workout-template.dumbbell-a",
            "workout-template.dumbbell-b"
        ]
    )

    static let homeDumbbell = homeDumbbellAB

    static let machineBeginnerAB = RepeatingPlanSeedDefinition(
        seedKey: "repeating-plan.machine-beginner-ab",
        name: "Machine Beginner A/B",
        goal: .generalFitness,
        experienceLevel: .beginner,
        requiredEquipment: [.machine, .cable],
        notes: "Guided machine training focused on comfortable execution and steady progression.",
        templateSeedKeys: [
            "workout-template.machine-a",
            "workout-template.machine-b"
        ]
    )

    static let calisthenicsFoundationsAB = RepeatingPlanSeedDefinition(
        seedKey: "repeating-plan.calisthenics-foundations-ab",
        name: "Calisthenics Foundations A/B",
        goal: .generalFitness,
        experienceLevel: .beginner,
        requiredEquipment: [.bodyweight],
        notes: "Bodyweight strength and movement control through repetition and variation ladders.",
        templateSeedKeys: [
            "workout-template.calisthenics-a",
            "workout-template.calisthenics-b"
        ]
    )

    static let definitions = [
        pplContinuous,
        beginnerFullBodyAB,
        simpleBarbellStrengthAB,
        upperLowerContinuous,
        twoDayExpress,
        homeDumbbellAB,
        machineBeginnerAB,
        calisthenicsFoundationsAB
    ]
}

@MainActor
enum RepeatingPlanSystemSeedInstaller {
    static func install(
        in context: ModelContext,
        registry: SystemSeedRegistry,
        seedVersion: Int,
        contentVersion: Int
    ) throws -> SystemSeedInstallReport {
        try install(
            RepeatingPlanSeedData.definitions,
            in: context,
            registry: registry,
            seedVersion: seedVersion,
            contentVersion: contentVersion
        )
    }

    /// Stages seed definitions only. The catalogue coordinator owns the save
    /// and rollback boundary so all seed domains commit together.
    static func install(
        _ desired: [RepeatingPlanSeedDefinition],
        in context: ModelContext,
        registry: SystemSeedRegistry,
        seedVersion: Int,
        contentVersion: Int
    ) throws -> SystemSeedInstallReport {
        try registry.validateUniqueKeys(desired.map(\.seedKey))

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let templatesByID = Dictionary(
            templates.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let resolvedDefinitions = try desired.map { definition in
            (definition, try resolvedTemplates(for: definition, templatesByID: templatesByID, registry: registry))
        }
        var existingPlans = try context.fetch(FetchDescriptor<RepeatingPlan>())
        var existingPlansByID = Dictionary(
            existingPlans.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var report = SystemSeedInstallReport()

        for (definition, slotTemplates) in resolvedDefinitions {

            if let record = try registry.record(for: definition.seedKey, expectedKind: .repeatingPlan) {
                guard let plan = existingPlansByID[record.entityID] else {
                    throw SystemSeedError.danglingEntity(key: definition.seedKey, entityID: record.entityID)
                }
                plan.isBuiltIn = true
                report.unchanged += 1
                continue
            }

            // A manually created duplicate is user-owned and must remain
            // untouched. Only an exact, already-marked built-in graph can be
            // safely adopted as legacy bundled content.
            let candidates = existingPlans.filter {
                $0.isBuiltIn
                    && $0.name == definition.name
                    && $0.orderedSlots.map(\.templateIDSnapshot) == slotTemplates.map(\.id)
            }
            guard candidates.count <= 1 else {
                throw SystemSeedError.ambiguousLegacyMatch(key: definition.seedKey, count: candidates.count)
            }

            let plan: RepeatingPlan
            let sourceKind: SystemSeedSourceKind
            if let adopted = candidates.first {
                plan = adopted
                sourceKind = .migratedLegacy
                report.adopted += 1
            } else {
                let slots = slotTemplates.enumerated().map { index, template in
                    RepeatingPlanSlot(orderIndex: index, workoutTemplate: template)
                }
                plan = RepeatingPlan(
                    name: definition.name,
                    goal: definition.goal,
                    experienceLevel: definition.experienceLevel,
                    requiredEquipment: definition.requiredEquipment,
                    notes: definition.notes,
                    isBuiltIn: true,
                    slots: slots
                )
                context.insert(plan)
                existingPlans.append(plan)
                existingPlansByID[plan.id] = plan
                sourceKind = .bundled
                report.inserted += 1
            }

            try registry.register(
                key: definition.seedKey,
                kind: .repeatingPlan,
                entityID: plan.id,
                seedVersion: seedVersion,
                contentVersion: contentVersion,
                sourceKind: sourceKind
            )
        }

        return report
    }

    private static func resolvedTemplates(
        for definition: RepeatingPlanSeedDefinition,
        templatesByID: [UUID: WorkoutTemplate],
        registry: SystemSeedRegistry
    ) throws -> [WorkoutTemplate] {
        try definition.templateSeedKeys.map { templateKey in
            guard
                let record = try registry.record(for: templateKey, expectedKind: .workoutTemplate),
                let template = templatesByID[record.entityID]
            else {
                throw SystemSeedError.unresolvedDependency(
                    key: definition.seedKey,
                    dependency: templateKey
                )
            }
            return template
        }
    }
}
