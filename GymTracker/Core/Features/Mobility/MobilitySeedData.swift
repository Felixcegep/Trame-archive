import SwiftData

enum MobilitySeedData {
    static func seedIfNeeded(using context: ModelContext) {
        let existingFamilies = (try? context.fetch(FetchDescriptor<MobilityFamily>())) ?? []
        var familyMap: [String: MobilityFamily] = Dictionary(uniqueKeysWithValues: existingFamilies.map { ($0.name, $0) })

        func family(_ name: String) -> MobilityFamily {
            if let f = familyMap[name] {
                return f
            }
            let f = MobilityFamily(name: name)
            context.insert(f)
            familyMap[name] = f
            return f
        }

        let existingDefs = (try? context.fetch(FetchDescriptor<MobilityDefinition>())) ?? []
        let existingNames = Set(existingDefs.map { $0.name.lowercased() })

        let seedItems: [(name: String, instructions: String, tracking: MobilityTrackingType, duration: Int?, reps: Int?, familyName: String)] = [
            // Hip mobility (12)
            ("90/90 Hip Switch", "Move slowly between internal and external hip rotation positions.", .repetitions, nil, 8, "Hip mobility"),
            ("Couch Stretch", "Keep rear foot against wall, kneel on front leg, keep torso upright.", .duration, 45, nil, "Hip mobility"),
            ("Pigeon Stretch", "Front leg bent 90 degrees, back leg extended straight behind.", .duration, 45, nil, "Hip mobility"),
            ("Frog Stretch", "Place knees wide on mat, hips back toward heels to open adductors.", .duration, 45, nil, "Hip mobility"),
            ("Cossack Squat", "Side-to-side deep lunges keeping heel down on working leg.", .repetitions, nil, 10, "Hip mobility"),
            ("Lizard Pose", "Step one foot outside hands, sink hips down into front leg flexor.", .duration, 45, nil, "Hip mobility"),
            ("Hip CARs", "Rotate hip joint through full controlled articular circle.", .repetitions, nil, 6, "Hip mobility"),
            ("Butterfly Stretch", "Soles of feet together, pull heels in, gently press knees down.", .duration, 45, nil, "Hip mobility"),
            ("Single-Leg Hip Hinge", "Balance on one leg, hinge at hip with flat back and soft knee.", .repetitions, nil, 8, "Hip mobility"),
            ("Fire Hydrants", "On hands and knees, lift knee out to side without shifting torso.", .repetitions, nil, 10, "Hip mobility"),
            ("Deep Squat Pry", "Sink into deep squat, use elbows to gently push knees outward.", .duration, 60, nil, "Hip mobility"),
            ("Tactical Frog", "Knees wide, rock hips back and forward into adductor stretch.", .repetitions, nil, 8, "Hip mobility"),

            // Shoulder mobility (8)
            ("Thoracic Rotation", "Rotate through the upper back without forcing range.", .repetitions, nil, 8, "Shoulder mobility"),
            ("Shoulder Pass-Throughs", "Hold PVC or band wide, pass overhead to back and return smoothly.", .repetitions, nil, 10, "Shoulder mobility"),
            ("Sleeper Stretch", "Lie on side, arm at 90 degrees, gently press wrist toward floor.", .duration, 30, nil, "Shoulder mobility"),
            ("Wall Slides", "Back and arms against wall, slide hands overhead without arching back.", .repetitions, nil, 10, "Shoulder mobility"),
            ("Prone Y-T-W Raises", "Lie face down, lift arms into Y, T, and W positions to activate upper back.", .repetitions, nil, 8, "Shoulder mobility"),
            ("Scapular Pull-Ups", "Hang from bar, depress and retract shoulder blades without bending elbows.", .repetitions, nil, 10, "Shoulder mobility"),
            ("Shoulder CARs", "Move shoulder slowly through max controlled articular circle.", .repetitions, nil, 6, "Shoulder mobility"),
            ("Doorway Chest & Shoulder Opener", "Forearms against doorway frame, step forward to open shoulders.", .duration, 45, nil, "Shoulder mobility"),

            // Thoracic & Spine mobility (8)
            ("Cat-Cow", "Alternate between arching and rounding the spine slowly with breath.", .repetitions, nil, 10, "Thoracic & Spine mobility"),
            ("Thread the Needle", "On hands and knees, reach arm under torso and rotate upward.", .repetitions, nil, 8, "Thoracic & Spine mobility"),
            ("Puppy Dog Pose", "Hips high over knees, walk hands forward and sink chest to floor.", .duration, 45, nil, "Thoracic & Spine mobility"),
            ("Foam Roller T-Spine Extension", "Support head, roll upper back and extend back over foam roller.", .repetitions, nil, 8, "Thoracic & Spine mobility"),
            ("Scorpion Stretch", "Lie face down, reach foot across behind toward opposite hand.", .repetitions, nil, 8, "Thoracic & Spine mobility"),
            ("Open Book Stretch", "Side-lying knees stacked, sweep top arm in arc behind back.", .repetitions, nil, 8, "Thoracic & Spine mobility"),
            ("Prone Cobra", "Lie face down, lift chest and rotate thumbs up to ceiling.", .duration, 30, nil, "Thoracic & Spine mobility"),
            ("Standing Side Bends", "Reach overhead and bend laterally to stretch obliques and lower back.", .repetitions, nil, 10, "Thoracic & Spine mobility"),

            // Ankle & Calf mobility (6)
            ("Knee-to-Wall Ankle Mobilization", "Foot near wall, drive knee forward past toes without lifting heel.", .repetitions, nil, 10, "Ankle & Calf mobility"),
            ("Standing Calf Stretch", "Back leg straight, heel pressed into floor to stretch gastrocnemius.", .duration, 45, nil, "Ankle & Calf mobility"),
            ("Soleus Wall Stretch", "Back leg slightly bent, press heel down to target lower calf.", .duration, 45, nil, "Ankle & Calf mobility"),
            ("Ankle Circles", "Rotate ankle through full slow circles in both directions.", .repetitions, nil, 12, "Ankle & Calf mobility"),
            ("Elevated Toe Calf Raise Stretch", "Heels hanging off step, let body weight stretch ankles down.", .duration, 45, nil, "Ankle & Calf mobility"),
            ("Tibialis Raise", "Lean back against wall, flex toes up toward shins controlled.", .repetitions, nil, 15, "Ankle & Calf mobility"),

            // Hamstrings & Posterior Chain (6)
            ("World's Greatest Stretch", "Step into lunge, elbow to instep, reach arm up, extend front leg.", .repetitions, nil, 6, "Hamstrings & Posterior Chain"),
            ("Elephant Walks", "Hands toward floor, alternate straightening knees dynamically.", .repetitions, nil, 20, "Hamstrings & Posterior Chain"),
            ("Inchworms", "Walk hands out to plank, then walk feet up toward hands.", .repetitions, nil, 6, "Hamstrings & Posterior Chain"),
            ("Jefferson Curl", "Roll spine down segment-by-segment with bodyweight or light load.", .repetitions, nil, 5, "Hamstrings & Posterior Chain"),
            ("Standing Hamstring Fold", "Hinge at hips, reach for toes with relaxed neck and soft knees.", .duration, 45, nil, "Hamstrings & Posterior Chain"),
            ("Active Straight Leg Raise", "Lie flat, raise one straight leg up controlled while keeping hips down.", .repetitions, nil, 10, "Hamstrings & Posterior Chain"),

            // Chest & Lat mobility (5)
            ("Banded Lat Distraction", "Hold band overhead, step back and sink hips away to stretch lat.", .duration, 45, nil, "Chest & Lat mobility"),
            ("Child's Pose with Side Reach", "Kneel, reach hands diagonally to side to stretch lats.", .duration, 45, nil, "Chest & Lat mobility"),
            ("Lying Pec Stretch", "Prone arm at 90 degrees, roll body away to stretch chest.", .duration, 45, nil, "Chest & Lat mobility"),
            ("Subscapularis Wall Slide", "Elbows against wall, slide upward keeping forearms flush.", .repetitions, nil, 8, "Chest & Lat mobility"),
            ("Overhead Triceps & Lat Stretch", "Pull elbow overhead behind head with opposite hand.", .duration, 30, nil, "Chest & Lat mobility"),

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

        for item in seedItems {
            guard !existingNames.contains(item.name.lowercased()) else { continue }
            let fam = family(item.familyName)
            let def = MobilityDefinition(
                name: item.name,
                instructions: item.instructions,
                trackingType: item.tracking,
                defaultDurationSeconds: item.duration,
                defaultRepetitions: item.reps,
                isCustom: false,
                family: fam
            )
            context.insert(def)
        }

        let routines = (try? context.fetch(FetchDescriptor<MobilityRoutine>())) ?? []
        if routines.isEmpty {
            let allDefs = (try? context.fetch(FetchDescriptor<MobilityDefinition>())) ?? []
            if let hip = allDefs.first(where: { $0.name == "90/90 Hip Switch" }),
               let couch = allDefs.first(where: { $0.name == "Couch Stretch" }),
               let thoracic = allDefs.first(where: { $0.name == "Thoracic Rotation" }) {
                let routine = MobilityRoutine(name: "Daily mobility reset")
                routine.items = [
                    MobilityRoutineItem(definition: hip, orderIndex: 0, targetRepetitions: 8, side: .alternating),
                    MobilityRoutineItem(definition: couch, orderIndex: 1, targetDurationSeconds: 45, side: .bilateral),
                    MobilityRoutineItem(definition: thoracic, orderIndex: 2, targetRepetitions: 8, side: .alternating)
                ]
                context.insert(routine)
            }
        }
        try? context.save()
    }
}

