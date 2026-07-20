import SwiftData

enum MobilitySeedData {
    static func seedIfNeeded(using context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<MobilityDefinition>())) ?? []
        let definitions: [MobilityDefinition]
        if existing.isEmpty {
            let hipFamily = MobilityFamily(name: "Hip mobility")
            let shoulderFamily = MobilityFamily(name: "Shoulder mobility")
            definitions = [
                MobilityDefinition(name: "90/90 Hip Switch", instructions: "Move slowly between hip positions.", trackingType: .repetitions, defaultDurationSeconds: nil, defaultRepetitions: 8, isCustom: false, family: hipFamily),
                MobilityDefinition(name: "Couch Stretch", instructions: "Keep your torso tall and breathe steadily.", trackingType: .duration, defaultDurationSeconds: 45, isCustom: false, family: hipFamily),
                MobilityDefinition(name: "Thoracic Rotation", instructions: "Rotate through the upper back without forcing range.", trackingType: .repetitions, defaultDurationSeconds: nil, defaultRepetitions: 8, isCustom: false, family: shoulderFamily)
            ]
            context.insert(hipFamily)
            context.insert(shoulderFamily)
            for definition in definitions { context.insert(definition) }
        } else {
            definitions = existing
        }

        let routines = (try? context.fetch(FetchDescriptor<MobilityRoutine>())) ?? []
        if routines.isEmpty, definitions.count >= 3 {
            let routine = MobilityRoutine(name: "Daily mobility reset")
            routine.items = [
                MobilityRoutineItem(definition: definitions[0], orderIndex: 0, targetRepetitions: 8, side: .alternating),
                MobilityRoutineItem(definition: definitions[1], orderIndex: 1, targetDurationSeconds: 45, side: .bilateral),
                MobilityRoutineItem(definition: definitions[2], orderIndex: 2, targetRepetitions: 8, side: .alternating)
            ]
            context.insert(routine)
        }
        try? context.save()
    }
}
