import Foundation
import SwiftData

enum MobilitySeedData {
    static func seedIfNeeded(using context: ModelContext) {
        do {
            try stage(using: context, registry: SystemSeedRegistry(context: context))
            try context.save()
        } catch {
            context.rollback()
            print("Failed to seed mobility data: \(error)")
        }
    }

    static func stage(using context: ModelContext, registry: SystemSeedRegistry) throws {
        var existingFamilies = try context.fetch(FetchDescriptor<MobilityFamily>())
        // MobilityFamily.name lost its @Attribute(.unique) constraint, so two
        // families can now share a name; Dictionary(uniqueKeysWithValues:)
        // would trap (uncatchable) on that collision instead of throwing.
        // Unlike Exercise (isCustom) or MobilityDefinition (isCustom),
        // MobilityFamily has no field to distinguish a system record from a
        // user one, so there's nothing to prefer — keep the first family
        // encountered, deterministic for a given fetch. This is the same
        // "keep first" fallback ExerciseRelationshipSeedData.swift uses for
        // its outer `uniquingKeysWith: { first, _ in first }` after its own
        // system-preference pass.
        var familyMap: [String: MobilityFamily] = Dictionary(
            existingFamilies.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        func family(_ name: String) throws -> MobilityFamily {
            let key = SystemSeedKey.make(namespace: "mobility-family", legacyName: name)
            if let record = try registry.record(for: key, expectedKind: .mobilityFamily) {
                guard let existing = existingFamilies.first(where: { $0.id == record.entityID }) else {
                    throw SystemSeedError.danglingEntity(key: key, entityID: record.entityID)
                }
                existing.name = name
                existing.updatedAt = .now
                familyMap[name] = existing
                return existing
            }
            if let f = familyMap[name] {
                try registry.register(
                    key: key,
                    kind: .mobilityFamily,
                    entityID: f.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: .migratedLegacy
                )
                return f
            }
            let f = MobilityFamily(name: name)
            context.insert(f)
            existingFamilies.append(f)
            familyMap[name] = f
            try registry.register(
                key: key,
                kind: .mobilityFamily,
                entityID: f.id,
                seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                sourceKind: .bundled
            )
            return f
        }

        var existingDefs = try context.fetch(FetchDescriptor<MobilityDefinition>())

        let seedItems: [(name: String, instructions: String, tracking: MobilityTrackingType, duration: Int?, reps: Int?, familyName: String)] = [
            // Hip mobility (20)
            ("90/90 Hip Switch", "Move slowly between internal and external hip rotation positions.", .repetitions, nil, 8, "Hip mobility"),
            ("Couch Stretch", "Keep rear foot against wall, kneel on front leg, keep torso upright.", .duration, 45, nil, "Hip mobility"),
            ("Pigeon Stretch", "Front leg bent 90 degrees, back leg extended straight behind.", .duration, 45, nil, "Hip mobility"),
            ("Frog Stretch", "Place knees wide on mat, hips back toward heels to open adductors.", .duration, 45, nil, "Hip mobility"),
            ("Cossack Squat", "Side-to-side deep lunges keeping heel down on working leg.", .repetitions, nil, 10, "Hip mobility"),
            ("Loaded Cossack Squat", "Hold a light kettlebell or dumbbell at chest height and perform a side-to-side deep lunge under control, keeping the working heel down and the load close to the body.", .repetitions, nil, 5, "Hip mobility"),
            ("Lizard Pose", "Step one foot outside hands, sink hips down into front leg flexor.", .duration, 45, nil, "Hip mobility"),
            ("Hip CARs", "Rotate hip joint through full controlled articular circle.", .repetitions, nil, 6, "Hip mobility"),
            ("Butterfly Stretch", "Soles of feet together, pull heels in, gently press knees down.", .duration, 45, nil, "Hip mobility"),
            ("Single-Leg Hip Hinge", "Balance on one leg, hinge at hip with flat back and soft knee.", .repetitions, nil, 8, "Hip mobility"),
            ("Fire Hydrants", "On hands and knees, lift knee out to side without shifting torso.", .repetitions, nil, 10, "Hip mobility"),
            ("Deep Squat Pry", "Sink into deep squat, use elbows to gently push knees outward.", .duration, 60, nil, "Hip mobility"),
            ("Tactical Frog", "Knees wide, rock hips back and forward into adductor stretch.", .repetitions, nil, 8, "Hip mobility"),
            ("Half-Kneeling Hip-Flexor Stretch", "Kneel with the back knee down and front foot forward, tuck the pelvis under, and shift weight forward until a stretch is felt at the front of the rear hip.", .duration, 30, nil, "Hip mobility"),
            ("90/90 Lift-Off", "From the 90/90 seated position, lift the front shin a few inches off the floor and hold, keeping the hips level and the lower back tall.", .repetitions, nil, 5, "Hip mobility"),
            ("Controlled Hip Rotation", "From a seated or lying support position, slowly rotate the hip through a controlled arc from internal to external rotation without shifting the pelvis.", .repetitions, nil, 3, "Hip mobility"),
            ("Weighted Pancake Hold", "Sit in a wide straddle with a light plate or dumbbell across your thighs, hinge forward with a long spine, and hold the deepest comfortable position.", .duration, 25, nil, "Hip mobility"),
            ("Goblet Deep-Squat Hold", "Hold a light kettlebell or dumbbell at chest height, sink into the bottom of a squat with elbows inside the knees, and hold the position upright.", .duration, 25, nil, "Hip mobility"),
            ("Deep-Squat Transition", "Stand tall, then sit back and down into the bottom of a squat and return to standing, moving through the full range under control.", .repetitions, nil, 8, "Hip mobility"),
            ("Supported Front-Split Hold", "From a front-split stance with the front leg extended forward and the back leg extended behind, lower toward the floor using the chosen support until a controlled stretch is felt, and hold.", .duration, 20, nil, "Hip mobility"),

            // Shoulder mobility (9)
            ("Thoracic Rotation", "Rotate through the upper back without forcing range.", .repetitions, nil, 8, "Shoulder mobility"),
            ("Shoulder Pass-Throughs", "Hold PVC or band wide, pass overhead to back and return smoothly.", .repetitions, nil, 10, "Shoulder mobility"),
            ("Sleeper Stretch", "Lie on side, arm at 90 degrees, gently press wrist toward floor.", .duration, 30, nil, "Shoulder mobility"),
            ("Wall Slides", "Back and arms against wall, slide hands overhead without arching back.", .repetitions, nil, 10, "Shoulder mobility"),
            ("Prone Y-T-W Raises", "Lie face down, lift arms into Y, T, and W positions to activate upper back.", .repetitions, nil, 8, "Shoulder mobility"),
            ("Scapular Pull-Ups", "Hang from bar, depress and retract shoulder blades without bending elbows.", .repetitions, nil, 10, "Shoulder mobility"),
            ("Shoulder CARs", "Move shoulder slowly through max controlled articular circle.", .repetitions, nil, 6, "Shoulder mobility"),
            ("Doorway Chest & Shoulder Opener", "Forearms against doorway frame, step forward to open shoulders.", .duration, 45, nil, "Shoulder mobility"),
            ("Wall Shoulder Flexion Lift-Off", "Support the arm overhead against a wall, lift the hand slightly off the wall and hold without shrugging the shoulder up.", .repetitions, nil, 5, "Shoulder mobility"),

            // Thoracic & Spine mobility (8)
            ("Cat-Cow", "Alternate between arching and rounding the spine slowly with breath.", .repetitions, nil, 10, "Thoracic & Spine mobility"),
            ("Thread the Needle", "On hands and knees, reach arm under torso and rotate upward.", .repetitions, nil, 8, "Thoracic & Spine mobility"),
            ("Puppy Dog Pose", "Hips high over knees, walk hands forward and sink chest to floor.", .duration, 45, nil, "Thoracic & Spine mobility"),
            ("Foam Roller T-Spine Extension", "Support head, roll upper back and extend back over foam roller.", .repetitions, nil, 8, "Thoracic & Spine mobility"),
            ("Scorpion Stretch", "Lie face down, reach foot across behind toward opposite hand.", .repetitions, nil, 8, "Thoracic & Spine mobility"),
            ("Open Book Stretch", "Side-lying knees stacked, sweep top arm in arc behind back.", .repetitions, nil, 8, "Thoracic & Spine mobility"),
            ("Prone Cobra", "Lie face down, lift chest and rotate thumbs up to ceiling.", .duration, 30, nil, "Thoracic & Spine mobility"),
            ("Standing Side Bends", "Reach overhead and bend laterally to stretch obliques and lower back.", .repetitions, nil, 10, "Thoracic & Spine mobility"),

            // Ankle & Calf mobility (7)
            ("Knee-to-Wall Ankle Mobilization", "Foot near wall, drive knee forward past toes without lifting heel.", .repetitions, nil, 10, "Ankle & Calf mobility"),
            ("Standing Calf Stretch", "Back leg straight, heel pressed into floor to stretch gastrocnemius.", .duration, 45, nil, "Ankle & Calf mobility"),
            ("Soleus Wall Stretch", "Back leg slightly bent, press heel down to target lower calf.", .duration, 45, nil, "Ankle & Calf mobility"),
            ("Ankle Circles", "Rotate ankle through full slow circles in both directions.", .repetitions, nil, 12, "Ankle & Calf mobility"),
            ("Elevated Toe Calf Raise Stretch", "Heels hanging off step, let body weight stretch ankles down.", .duration, 45, nil, "Ankle & Calf mobility"),
            ("Tibialis Raise", "Lean back against wall, flex toes up toward shins controlled.", .repetitions, nil, 15, "Ankle & Calf mobility"),
            ("Full-Range Calf Raise", "Stand on the edge of a step, lower the heels fully below the step, then rise onto the balls of the feet through the complete range.", .repetitions, nil, 7, "Ankle & Calf mobility"),

            // Hamstrings & Posterior Chain (8)
            ("World's Greatest Stretch", "Step into lunge, elbow to instep, reach arm up, extend front leg.", .repetitions, nil, 6, "Hamstrings & Posterior Chain"),
            ("Elephant Walks", "Hands toward floor, alternate straightening knees dynamically.", .repetitions, nil, 20, "Hamstrings & Posterior Chain"),
            ("Inchworms", "Walk hands out to plank, then walk feet up toward hands.", .repetitions, nil, 6, "Hamstrings & Posterior Chain"),
            ("Jefferson Curl", "Roll spine down segment-by-segment with bodyweight or light load.", .repetitions, nil, 5, "Hamstrings & Posterior Chain"),
            ("Standing Hamstring Fold", "Hinge at hips, reach for toes with relaxed neck and soft knees.", .duration, 45, nil, "Hamstrings & Posterior Chain"),
            ("Active Straight Leg Raise", "Lie flat, raise one straight leg up controlled while keeping hips down.", .repetitions, nil, 10, "Hamstrings & Posterior Chain"),
            ("Hamstring Strap Stretch", "Loop a strap around the ball of one foot, extend the leg toward the ceiling with a soft knee, and draw the strap gently toward you.", .duration, 30, nil, "Hamstrings & Posterior Chain"),
            ("Active Front-Leg Lift", "From a supported front-split stance, lift the front heel a few inches off the floor using the front leg alone, hold briefly, and lower with control.", .repetitions, nil, 6, "Hamstrings & Posterior Chain"),

            // Chest & Lat mobility (7)
            ("Banded Lat Distraction", "Hold band overhead, step back and sink hips away to stretch lat.", .duration, 45, nil, "Chest & Lat mobility"),
            ("Child's Pose with Side Reach", "Kneel, reach hands diagonally to side to stretch lats.", .duration, 45, nil, "Chest & Lat mobility"),
            ("Lying Pec Stretch", "Prone arm at 90 degrees, roll body away to stretch chest.", .duration, 45, nil, "Chest & Lat mobility"),
            ("Subscapularis Wall Slide", "Elbows against wall, slide upward keeping forearms flush.", .repetitions, nil, 8, "Chest & Lat mobility"),
            ("Overhead Triceps & Lat Stretch", "Pull elbow overhead behind head with opposite hand.", .duration, 30, nil, "Chest & Lat mobility"),
            ("Doorway Chest Stretch", "Place a forearm on a door frame at shoulder height, step forward through the doorway, and turn gently away to open the chest.", .duration, 30, nil, "Chest & Lat mobility"),
            ("Kneeling Lat Stretch", "Kneel in front of a low support, reach both arms forward onto it, and sink the hips back to lengthen the lats.", .duration, 30, nil, "Chest & Lat mobility"),

            // Wrist & Forearm mobility (5)
            ("Quadruped Wrist Rocks", "Hands on floor, gently rock forward and back over wrists.", .repetitions, nil, 10, "Wrist & Forearm mobility"),
            ("Wrist Palm-Up Extension Stretch", "Fingers pointing back toward knees, press palms down.", .duration, 30, nil, "Wrist & Forearm mobility"),
            ("Wrist Back-of-Hand Flexion Stretch", "Back of hands on floor, gently lean back.", .duration, 30, nil, "Wrist & Forearm mobility"),
            ("Wrist Circles", "Interlace fingers, rotate wrists in smooth figure-8 circles.", .repetitions, nil, 12, "Wrist & Forearm mobility"),
            ("First Knuckle Lifts", "Palms flat, lift knuckles up leaving fingertips grounded.", .repetitions, nil, 10, "Wrist & Forearm mobility"),

            // Neck & Upper Traps (4)
            ("Upper Trap Stretch", "Tilt ear toward shoulder, gently apply hand pressure.", .duration, 30, nil, "Neck & Upper Traps"),
            ("Levator Scapulae Stretch", "Turn head 45 degrees down toward armpit, gently pull.", .duration, 30, nil, "Neck & Upper Traps"),
            ("Neck CARs", "Slowly roll head through controlled pain-free perimeter.", .repetitions, nil, 6, "Neck & Upper Traps"),
            ("Chin Tucks", "Draw chin straight back into neck without tilting head.", .repetitions, nil, 10, "Neck & Upper Traps")
        ]

        var didInsert = false
        for item in seedItems {
            let key = SystemSeedKey.make(namespace: "mobility-definition", legacyName: item.name)
            let fam = try family(item.familyName)
            let definition: MobilityDefinition
            if let record = try registry.record(for: key, expectedKind: .mobilityDefinition) {
                guard let existing = existingDefs.first(where: { $0.id == record.entityID }) else {
                    throw SystemSeedError.danglingEntity(key: key, entityID: record.entityID)
                }
                definition = existing
            } else {
                let candidates = existingDefs.filter {
                    !$0.isCustom && $0.name.compare(item.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                }
                guard candidates.count <= 1 else {
                    throw SystemSeedError.ambiguousLegacyMatch(key: key, count: candidates.count)
                }
                if let adopted = candidates.first {
                    definition = adopted
                    try registry.register(
                        key: key,
                        kind: .mobilityDefinition,
                        entityID: adopted.id,
                        seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                        contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                        sourceKind: .migratedLegacy
                    )
                } else {
                    definition = MobilityDefinition(name: item.name, isCustom: false)
                    context.insert(definition)
                    existingDefs.append(definition)
                    try registry.register(
                        key: key,
                        kind: .mobilityDefinition,
                        entityID: definition.id,
                        seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                        contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                        sourceKind: .bundled
                    )
                    didInsert = true
                }
            }
            definition.name = item.name
            definition.instructions = item.instructions
            definition.trackingType = item.tracking
            definition.defaultDurationSeconds = item.duration
            definition.defaultRepetitions = item.reps
            definition.family = fam
            definition.updatedAt = .now
            // isFavorite and isArchived are user-owned.
        }

        struct RoutineSeedSpec {
            let key: String
            let name: String
            let purpose: MobilityRoutinePurpose?
            let items: [(defName: String, reps: Int?, duration: Int?, side: MobilitySide)]
        }

        let routineSpecs: [RoutineSeedSpec] = [
            RoutineSeedSpec(
                key: "mobility-routine.daily-mobility-reset",
                name: "Daily mobility reset",
                purpose: .development,
                items: [
                    ("90/90 Hip Switch", 8, nil, .alternating),
                    ("Couch Stretch", nil, 45, .bilateral),
                    ("Thoracic Rotation", 8, nil, .alternating)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.post-leg-day-reset",
                name: "Post-Leg Day Mobility Reset",
                purpose: .cooldown,
                items: [
                    ("90/90 Hip Switch", 10, nil, .alternating),
                    ("Pigeon Stretch", nil, 60, .bilateral),
                    ("Cossack Squat", 8, nil, .alternating),
                    ("Standing Calf Stretch", nil, 45, .bilateral)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.upper-body-bench-warmup",
                name: "Upper Body Bench Warmup",
                purpose: .preparation,
                items: [
                    ("Shoulder Pass-Throughs", 10, nil, .bilateral),
                    ("Thoracic Rotation", 8, nil, .alternating),
                    ("Doorway Chest & Shoulder Opener", nil, 45, .bilateral),
                    ("Prone Y-T-W Raises", 8, nil, .bilateral)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.lower-back-decompression",
                name: "Lower Back & Hips Decompression",
                purpose: .cooldown,
                items: [
                    ("Cat-Cow", 10, nil, .bilateral),
                    ("Puppy Dog Pose", nil, 45, .bilateral),
                    ("Thread the Needle", 8, nil, .alternating),
                    ("Child's Pose with Side Reach", nil, 45, .bilateral)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.overhead-shoulder-saver",
                name: "Overhead & Shoulder Saver",
                purpose: .development,
                items: [
                    ("Wall Slides", 10, nil, .bilateral),
                    ("Scapular Pull-Ups", 10, nil, .bilateral),
                    ("Banded Lat Distraction", nil, 45, .bilateral),
                    ("Overhead Triceps & Lat Stretch", nil, 30, .bilateral)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.full-body-morning-flow",
                name: "Full Body Morning Flow",
                purpose: .development,
                items: [
                    ("World's Greatest Stretch", 6, nil, .alternating),
                    ("Elephant Walks", 20, nil, .bilateral),
                    ("Inchworms", 6, nil, .bilateral),
                    ("Standing Side Bends", 10, nil, .alternating)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.ankle-foot-mobilization",
                name: "Ankle & Foot Mobilization",
                purpose: .development,
                items: [
                    ("Knee-to-Wall Ankle Mobilization", 10, nil, .alternating),
                    ("Soleus Wall Stretch", nil, 45, .bilateral),
                    ("Tibialis Raise", 15, nil, .bilateral),
                    ("Ankle Circles", 12, nil, .alternating)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.desk-worker-reset",
                name: "Desk Worker Reset",
                purpose: .development,
                items: [
                    ("Chin Tucks", 10, nil, .bilateral),
                    ("Upper Trap Stretch", nil, 30, .bilateral),
                    ("Levator Scapulae Stretch", nil, 30, .bilateral),
                    ("Quadruped Wrist Rocks", 10, nil, .bilateral)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.loaded-mobility-foundations",
                name: "Loaded Mobility Foundations",
                purpose: .development,
                items: [
                    ("Jefferson Curl", 5, nil, .bilateral),
                    ("Cossack Squat", 8, nil, .alternating),
                    ("Knee-to-Wall Ankle Mobilization", 10, nil, .alternating),
                    ("Deep Squat Pry", nil, 30, .bilateral)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.hamstring-contract-relax",
                name: "Hamstring Contract-Relax PNF",
                purpose: .development,
                items: [
                    ("Standing Hamstring Fold", nil, 20, .bilateral)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.squat-preparation",
                name: "Squat Preparation",
                purpose: .preparation,
                items: [
                    ("Knee-to-Wall Ankle Mobilization", 10, nil, .alternating),
                    ("Tactical Frog", 8, nil, .alternating),
                    ("Deep Squat Pry", nil, 60, .bilateral),
                    ("Cossack Squat", 8, nil, .alternating)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.deadlift-preparation",
                name: "Deadlift Preparation",
                purpose: .preparation,
                items: [
                    ("Cat-Cow", 10, nil, .bilateral),
                    ("Single-Leg Hip Hinge", 8, nil, .alternating),
                    ("World's Greatest Stretch", 6, nil, .alternating),
                    ("Butterfly Stretch", nil, 45, .bilateral)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.front-rack-and-wrist-preparation",
                name: "Front-Rack and Wrist Preparation",
                purpose: .preparation,
                items: [
                    ("Quadruped Wrist Rocks", 10, nil, .bilateral),
                    ("Overhead Triceps & Lat Stretch", nil, 30, .bilateral),
                    ("Banded Lat Distraction", nil, 45, .bilateral),
                    ("Thoracic Rotation", 8, nil, .alternating)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.olympic-lifting-preparation",
                name: "Olympic Lifting Preparation",
                purpose: .preparation,
                items: [
                    ("Knee-to-Wall Ankle Mobilization", 10, nil, .alternating),
                    ("Shoulder Pass-Throughs", 10, nil, .bilateral),
                    ("Wall Slides", 10, nil, .bilateral),
                    ("Deep Squat Pry", nil, 60, .bilateral)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.strongman-event-preparation",
                name: "Strongman Event Preparation",
                purpose: .preparation,
                items: [
                    ("Cat-Cow", 10, nil, .bilateral),
                    ("Single-Leg Hip Hinge", 8, nil, .alternating),
                    ("Doorway Chest & Shoulder Opener", nil, 45, .bilateral),
                    ("90/90 Hip Switch", 8, nil, .alternating)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.squat-preparation-v2",
                name: "Squat Preparation v2",
                purpose: .preparation,
                items: [
                    ("Knee-to-Wall Ankle Mobilization", 8, nil, .alternating),
                    ("90/90 Hip Switch", 6, nil, .alternating),
                    ("Tactical Frog", 8, nil, .alternating),
                    ("Deep-Squat Transition", 6, nil, .bilateral)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.bench-preparation-v2",
                name: "Bench Preparation v2",
                purpose: .preparation,
                items: [
                    ("Quadruped Wrist Rocks", 8, nil, .bilateral),
                    ("Thoracic Rotation", 6, nil, .alternating),
                    ("Shoulder Pass-Throughs", 8, nil, .bilateral),
                    ("Wall Slides", 8, nil, .bilateral),
                    ("Scapular Pull-Ups", 8, nil, .bilateral)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.deadlift-preparation-v2",
                name: "Deadlift Preparation v2",
                purpose: .preparation,
                items: [
                    ("Cat-Cow", 8, nil, .bilateral),
                    ("Active Straight Leg Raise", 6, nil, .alternating),
                    ("Single-Leg Hip Hinge", 6, nil, .alternating)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.snatch-preparation-v2",
                name: "Snatch Preparation v2",
                purpose: .preparation,
                items: [
                    ("Knee-to-Wall Ankle Mobilization", 8, nil, .alternating),
                    ("90/90 Hip Switch", 6, nil, .alternating),
                    ("Thoracic Rotation", 6, nil, .alternating),
                    ("Shoulder Pass-Throughs", 10, nil, .bilateral),
                    ("Wall Shoulder Flexion Lift-Off", 5, nil, .bilateral),
                    ("Goblet Deep-Squat Hold", nil, 20, .bilateral)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.clean-and-jerk-preparation-v2",
                name: "Clean & Jerk Preparation v2",
                purpose: .preparation,
                items: [
                    ("Knee-to-Wall Ankle Mobilization", 8, nil, .alternating),
                    ("90/90 Hip Switch", 6, nil, .alternating),
                    ("Thoracic Rotation", 6, nil, .alternating),
                    ("Quadruped Wrist Rocks", 10, nil, .bilateral)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.strongman-overhead-preparation-v2",
                name: "Strongman Overhead Preparation v2",
                purpose: .preparation,
                items: [
                    ("Quadruped Wrist Rocks", 10, nil, .bilateral),
                    ("Thoracic Rotation", 6, nil, .alternating),
                    ("Wall Slides", 8, nil, .bilateral),
                    ("Scapular Pull-Ups", 8, nil, .bilateral)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.strongman-carry-preparation-v2",
                name: "Strongman Carry & Loading Preparation v2",
                purpose: .preparation,
                items: [
                    ("Knee-to-Wall Ankle Mobilization", 8, nil, .alternating),
                    ("Hip CARs", 3, nil, .alternating),
                    ("90/90 Hip Switch", 6, nil, .alternating),
                    ("Deep-Squat Transition", 6, nil, .bilateral)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.fitness-racing-preparation-v2",
                name: "Fitness Racing Preparation v2",
                purpose: .preparation,
                items: [
                    ("Ankle Circles", 8, nil, .alternating),
                    ("Knee-to-Wall Ankle Mobilization", 8, nil, .alternating),
                    ("World's Greatest Stretch", 4, nil, .alternating),
                    ("Cossack Squat", 6, nil, .alternating),
                    ("Thoracic Rotation", 6, nil, .alternating)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.calisthenics-preparation-v2",
                name: "Calisthenics Preparation v2",
                purpose: .preparation,
                items: [
                    ("Wrist Circles", 10, nil, .alternating),
                    ("Quadruped Wrist Rocks", 8, nil, .bilateral),
                    ("First Knuckle Lifts", 8, nil, .bilateral),
                    ("Shoulder CARs", 3, nil, .alternating),
                    ("Scapular Pull-Ups", 8, nil, .bilateral),
                    ("Hollow Body Hold", nil, 15, .bilateral)
                ]
            ),
            RoutineSeedSpec(
                key: "mobility-routine.kettlebell-preparation-v2",
                name: "Kettlebell Preparation v2",
                purpose: .preparation,
                items: [
                    ("Wrist Circles", 10, nil, .alternating),
                    ("Thoracic Rotation", 6, nil, .alternating),
                    ("Single-Leg Hip Hinge", 8, nil, .alternating)
                ]
            )
        ]

        let routines = try context.fetch(FetchDescriptor<MobilityRoutine>())
        let allDefs = try context.fetch(FetchDescriptor<MobilityDefinition>())
        // MobilityDefinition.name lost its @Attribute(.unique) constraint, so
        // two definitions can now share a name; Dictionary(uniqueKeysWithValues:)
        // would trap (uncatchable) on that collision instead of throwing.
        // Prefer the system definition (isCustom == false) over a
        // user-created duplicate, the same preference this file already
        // applies above (~line 156) when adopting a legacy definition by
        // exact-name match, and the same preference
        // Exercise.uniquedByNamePreferringSystem() applies for exercises.
        let defsByName = Dictionary(
            allDefs.map { ($0.name, $0) },
            uniquingKeysWith: { first, second in first.isCustom && !second.isCustom ? second : first }
        )

        for spec in routineSpecs {
            if let record = try registry.record(for: spec.key, expectedKind: .mobilityRoutine) {
                guard let routine = routines.first(where: { $0.id == record.entityID }) else {
                    throw SystemSeedError.danglingEntity(key: spec.key, entityID: record.entityID)
                }
                if record.sourceKind == .bundled,
                   routine.purposeRaw == nil,
                   let purpose = spec.purpose {
                    routine.purpose = purpose
                    routine.updatedAt = .now
                }
            } else {
                let candidates = routines.filter { $0.name == spec.name }
                guard candidates.count <= 1 else {
                    throw SystemSeedError.ambiguousLegacyMatch(key: spec.key, count: candidates.count)
                }
                if let adopted = candidates.first {
                    try registry.register(
                        key: spec.key,
                        kind: .mobilityRoutine,
                        entityID: adopted.id,
                        seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                        contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                        sourceKind: .migratedLegacy
                    )
                } else {
                    let routineItems = spec.items.enumerated().compactMap { idx, itemSpec -> MobilityRoutineItem? in
                        guard let def = defsByName[itemSpec.defName] else { return nil }
                        return MobilityRoutineItem(
                            definition: def,
                            orderIndex: idx,
                            targetDurationSeconds: itemSpec.duration,
                            targetRepetitions: itemSpec.reps,
                            side: itemSpec.side
                        )
                    }
                    if !routineItems.isEmpty {
                        let routine = MobilityRoutine(name: spec.name, purpose: spec.purpose)
                        routine.items = routineItems
                        context.insert(routine)
                        try registry.register(
                            key: spec.key,
                            kind: .mobilityRoutine,
                            entityID: routine.id,
                            seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                            contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                            sourceKind: .bundled
                        )
                        didInsert = true
                    }
                }
            }
        }

        _ = didInsert
    }
}
