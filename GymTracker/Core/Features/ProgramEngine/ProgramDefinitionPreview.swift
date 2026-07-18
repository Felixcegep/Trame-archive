import Foundation

#if !GYMTRACKER_EXTENSION

struct ProgramDefinitionPreviewRow: Hashable, Identifiable {
    let id: UUID
    let blockIndex: Int
    let weekIndex: Int
    let workoutName: String
    let exerciseID: UUID
    let exposureKey: String
    let setCount: Int
    let waveCount: Int
    let roles: [ProgramSetRole]
    let repPrescriptions: [RepPrescription]
    let loadReferences: [LoadReferenceKind]
}

enum ProgramDefinitionPreview {
    static func rows(for definition: ProgramDefinitionPayload) throws -> [ProgramDefinitionPreviewRow] {
        let issues = ProgramDefinitionValidator.validate(definition)
        guard issues.isEmpty else { throw ProgramDefinitionCodecError.validation(issues) }
        return definition.blocks
            .sorted { $0.orderIndex < $1.orderIndex }
            .flatMap { block in
                block.weeks.sorted { $0.weekIndex < $1.weekIndex }.flatMap { week in
                    week.workouts.sorted { $0.orderIndex < $1.orderIndex }.flatMap { workout in
                        workout.plannedExercises.sorted { $0.orderIndex < $1.orderIndex }.map { exercise in
                            ProgramDefinitionPreviewRow(
                                id: exercise.id,
                                blockIndex: block.orderIndex,
                                weekIndex: week.weekIndex,
                                workoutName: workout.name,
                                exerciseID: exercise.exerciseID,
                                exposureKey: exercise.exposureKey,
                                setCount: exercise.waves.first?.plannedSets.count ?? exercise.plannedSets.count,
                                waveCount: exercise.waves.count,
                                roles: exercise.plannedSets.sorted { $0.orderIndex < $1.orderIndex }.map(\.role),
                                repPrescriptions: exercise.plannedSets.sorted { $0.orderIndex < $1.orderIndex }.map(\.repetitions),
                                loadReferences: exercise.plannedSets.sorted { $0.orderIndex < $1.orderIndex }.map { $0.load.reference.kind }
                            )
                        }
                    }
                }
            }
    }
}

#endif
