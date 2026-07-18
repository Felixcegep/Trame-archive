import Foundation

#if !GYMTRACKER_EXTENSION

enum ProgramDefinitionBuilderError: Error, Equatable {
    case invalidIndex
    case invalidExposureKey
    case validation([ProgramValidationIssue])
}

/// Mutation API for a future visual builder. It keeps the recipe as typed data
/// and delegates all final safety checks to the shared validator.
struct ProgramDefinitionBuilder: Codable, Hashable {
    private(set) var definition: ProgramDefinitionPayload

    init(
        name: String,
        goal: PlanGoal = .generalStrength,
        experienceLevel: PlanExperienceLevel = .beginner,
        durationWeeks: Int = 1,
        supportedDaysPerWeek: [Int] = [1]
    ) {
        definition = ProgramDefinitionPayload(
            name: name,
            goal: goal,
            experienceLevel: experienceLevel,
            durationWeeks: max(1, durationWeeks),
            supportedDaysPerWeek: supportedDaysPerWeek,
            blocks: []
        )
    }

    init(definition: ProgramDefinitionPayload) {
        self.definition = definition
    }

    @discardableResult
    mutating func addBlock(name: String, phaseType: PlanPhaseType = .accumulation) -> Int {
        let index = definition.blocks.count
        definition.blocks.append(ProgramBlockDefinition(orderIndex: index, name: name, phaseType: phaseType, weeks: []))
        return index
    }

    @discardableResult
    mutating func addWeek(toBlock blockIndex: Int, name: String? = nil) throws -> Int {
        guard definition.blocks.indices.contains(blockIndex) else { throw ProgramDefinitionBuilderError.invalidIndex }
        let weekIndex = definition.blocks[blockIndex].weeks.count
        definition.blocks[blockIndex].weeks.append(ProgramWeekDefinition(weekIndex: weekIndex, name: name, workouts: []))
        return weekIndex
    }

    @discardableResult
    mutating func addWorkout(toBlock blockIndex: Int, week weekIndex: Int, name: String, dayOffset: Int, role: String = "strength") throws -> Int {
        guard definition.blocks.indices.contains(blockIndex), definition.blocks[blockIndex].weeks.indices.contains(weekIndex) else {
            throw ProgramDefinitionBuilderError.invalidIndex
        }
        let workoutIndex = definition.blocks[blockIndex].weeks[weekIndex].workouts.count
        definition.blocks[blockIndex].weeks[weekIndex].workouts.append(
            ProgramWorkoutDefinition(orderIndex: workoutIndex, name: name, dayOffset: dayOffset, role: role, plannedExercises: [])
        )
        return workoutIndex
    }

    @discardableResult
    mutating func addExercise(
        toBlock blockIndex: Int,
        week weekIndex: Int,
        workout workoutIndex: Int,
        exerciseID: UUID,
        exposureKey: String,
        role: ExerciseRole = .main,
        isOptional: Bool = false
    ) throws -> Int {
        guard !exposureKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProgramDefinitionBuilderError.invalidExposureKey
        }
        guard definition.blocks.indices.contains(blockIndex),
              definition.blocks[blockIndex].weeks.indices.contains(weekIndex),
              definition.blocks[blockIndex].weeks[weekIndex].workouts.indices.contains(workoutIndex)
        else { throw ProgramDefinitionBuilderError.invalidIndex }
        let exercises = definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises
        guard !exercises.contains(where: { $0.exposureKey == exposureKey }) else {
            throw ProgramDefinitionBuilderError.invalidExposureKey
        }
        let index = exercises.count
        definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises.append(
            ProgramExerciseDefinition(exerciseID: exerciseID, exposureKey: exposureKey, orderIndex: index, isOptional: isOptional, plannedSets: [])
        )
        return index
    }

    mutating func addSet(
        toBlock blockIndex: Int,
        week weekIndex: Int,
        workout workoutIndex: Int,
        exercise exerciseIndex: Int,
        prescription: SetPrescriptionDefinition
    ) throws {
        guard definition.blocks.indices.contains(blockIndex),
              definition.blocks[blockIndex].weeks.indices.contains(weekIndex),
              definition.blocks[blockIndex].weeks[weekIndex].workouts.indices.contains(workoutIndex),
              definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises.indices.contains(exerciseIndex)
        else { throw ProgramDefinitionBuilderError.invalidIndex }
        definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[exerciseIndex].plannedSets.append(prescription)
    }

    mutating func removeBlock(at index: Int) throws {
        guard definition.blocks.indices.contains(index) else { throw ProgramDefinitionBuilderError.invalidIndex }
        definition.blocks.remove(at: index)
        normalizeBlockOrder()
    }

    mutating func removeExercise(fromBlock blockIndex: Int, week weekIndex: Int, workout workoutIndex: Int, at exerciseIndex: Int) throws {
        guard definition.blocks.indices.contains(blockIndex),
              definition.blocks[blockIndex].weeks.indices.contains(weekIndex),
              definition.blocks[blockIndex].weeks[weekIndex].workouts.indices.contains(workoutIndex),
              definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises.indices.contains(exerciseIndex)
        else { throw ProgramDefinitionBuilderError.invalidIndex }
        definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises.remove(at: exerciseIndex)
        normalizeExerciseOrder(blockIndex: blockIndex, weekIndex: weekIndex, workoutIndex: workoutIndex)
    }

    mutating func moveExercise(fromBlock blockIndex: Int, week weekIndex: Int, workout workoutIndex: Int, from source: Int, to destination: Int) throws {
        guard definition.blocks.indices.contains(blockIndex),
              definition.blocks[blockIndex].weeks.indices.contains(weekIndex),
              definition.blocks[blockIndex].weeks[weekIndex].workouts.indices.contains(workoutIndex)
        else { throw ProgramDefinitionBuilderError.invalidIndex }
        var exercises = definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises
        guard exercises.indices.contains(source), destination >= 0, destination <= exercises.count else { throw ProgramDefinitionBuilderError.invalidIndex }
        let item = exercises.remove(at: source)
        exercises.insert(item, at: min(destination, exercises.count))
        definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises = exercises
        normalizeExerciseOrder(blockIndex: blockIndex, weekIndex: weekIndex, workoutIndex: workoutIndex)
    }

    func build() throws -> ProgramDefinitionPayload {
        let issues = ProgramDefinitionValidator.validate(definition)
        guard issues.isEmpty else { throw ProgramDefinitionBuilderError.validation(issues) }
        return definition
    }

    private mutating func normalizeBlockOrder() {
        for index in definition.blocks.indices { definition.blocks[index].orderIndex = index }
    }

    private mutating func normalizeExerciseOrder(blockIndex: Int, weekIndex: Int, workoutIndex: Int) {
        for index in definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises.indices {
            definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[index].orderIndex = index
        }
    }
}

#endif
