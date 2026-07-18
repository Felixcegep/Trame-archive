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
        supportedDaysPerWeek: [Int] = [1],
        scheduleMode: PlanScheduleMode = .fixedWeekdays,
        scheduleIntervalDays: Int = 1
    ) {
        definition = ProgramDefinitionPayload(
            name: name,
            goal: goal,
            experienceLevel: experienceLevel,
            durationWeeks: max(1, durationWeeks),
            supportedDaysPerWeek: supportedDaysPerWeek,
            scheduleMode: scheduleMode,
            scheduleIntervalDays: scheduleIntervalDays,
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

    mutating func moveBlock(from source: Int, to destination: Int) throws {
        guard definition.blocks.indices.contains(source), destination >= 0, destination <= definition.blocks.count else {
            throw ProgramDefinitionBuilderError.invalidIndex
        }
        let block = definition.blocks.remove(at: source)
        definition.blocks.insert(block, at: min(destination, definition.blocks.count))
        normalizeBlockOrder()
    }

    mutating func removeWeek(fromBlock blockIndex: Int, at weekIndex: Int) throws {
        guard definition.blocks.indices.contains(blockIndex), definition.blocks[blockIndex].weeks.indices.contains(weekIndex) else {
            throw ProgramDefinitionBuilderError.invalidIndex
        }
        definition.blocks[blockIndex].weeks.remove(at: weekIndex)
        normalizeWeekOrder(blockIndex: blockIndex)
    }

    mutating func moveWeek(fromBlock blockIndex: Int, from source: Int, to destination: Int) throws {
        guard definition.blocks.indices.contains(blockIndex), definition.blocks[blockIndex].weeks.indices.contains(source), destination >= 0, destination <= definition.blocks[blockIndex].weeks.count else {
            throw ProgramDefinitionBuilderError.invalidIndex
        }
        let week = definition.blocks[blockIndex].weeks.remove(at: source)
        definition.blocks[blockIndex].weeks.insert(week, at: min(destination, definition.blocks[blockIndex].weeks.count))
        normalizeWeekOrder(blockIndex: blockIndex)
    }

    mutating func removeWorkout(fromBlock blockIndex: Int, week weekIndex: Int, at workoutIndex: Int) throws {
        guard definition.blocks.indices.contains(blockIndex), definition.blocks[blockIndex].weeks.indices.contains(weekIndex), definition.blocks[blockIndex].weeks[weekIndex].workouts.indices.contains(workoutIndex) else {
            throw ProgramDefinitionBuilderError.invalidIndex
        }
        definition.blocks[blockIndex].weeks[weekIndex].workouts.remove(at: workoutIndex)
        normalizeWorkoutOrder(blockIndex: blockIndex, weekIndex: weekIndex)
    }

    mutating func moveWorkout(fromBlock blockIndex: Int, week weekIndex: Int, from source: Int, to destination: Int) throws {
        guard definition.blocks.indices.contains(blockIndex), definition.blocks[blockIndex].weeks.indices.contains(weekIndex), definition.blocks[blockIndex].weeks[weekIndex].workouts.indices.contains(source), destination >= 0, destination <= definition.blocks[blockIndex].weeks[weekIndex].workouts.count else {
            throw ProgramDefinitionBuilderError.invalidIndex
        }
        let workout = definition.blocks[blockIndex].weeks[weekIndex].workouts.remove(at: source)
        definition.blocks[blockIndex].weeks[weekIndex].workouts.insert(workout, at: min(destination, definition.blocks[blockIndex].weeks[weekIndex].workouts.count))
        normalizeWorkoutOrder(blockIndex: blockIndex, weekIndex: weekIndex)
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

    mutating func removeSet(fromBlock blockIndex: Int, week weekIndex: Int, workout workoutIndex: Int, exercise exerciseIndex: Int, at setIndex: Int) throws {
        guard definition.blocks.indices.contains(blockIndex), definition.blocks[blockIndex].weeks.indices.contains(weekIndex), definition.blocks[blockIndex].weeks[weekIndex].workouts.indices.contains(workoutIndex), definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises.indices.contains(exerciseIndex), definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[exerciseIndex].plannedSets.indices.contains(setIndex) else {
            throw ProgramDefinitionBuilderError.invalidIndex
        }
        definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[exerciseIndex].plannedSets.remove(at: setIndex)
        normalizeSetOrder(blockIndex: blockIndex, weekIndex: weekIndex, workoutIndex: workoutIndex, exerciseIndex: exerciseIndex)
    }

    mutating func moveSet(fromBlock blockIndex: Int, week weekIndex: Int, workout workoutIndex: Int, exercise exerciseIndex: Int, from source: Int, to destination: Int) throws {
        guard definition.blocks.indices.contains(blockIndex), definition.blocks[blockIndex].weeks.indices.contains(weekIndex), definition.blocks[blockIndex].weeks[weekIndex].workouts.indices.contains(workoutIndex), definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises.indices.contains(exerciseIndex) else {
            throw ProgramDefinitionBuilderError.invalidIndex
        }
        var sets = definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[exerciseIndex].plannedSets
        guard sets.indices.contains(source), destination >= 0, destination <= sets.count else { throw ProgramDefinitionBuilderError.invalidIndex }
        let set = sets.remove(at: source)
        sets.insert(set, at: min(destination, sets.count))
        definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[exerciseIndex].plannedSets = sets
        normalizeSetOrder(blockIndex: blockIndex, weekIndex: weekIndex, workoutIndex: workoutIndex, exerciseIndex: exerciseIndex)
    }

    func build() throws -> ProgramDefinitionPayload {
        let issues = ProgramDefinitionValidator.validate(definition)
        guard issues.isEmpty else { throw ProgramDefinitionBuilderError.validation(issues) }
        return definition
    }

    private mutating func normalizeBlockOrder() {
        for index in definition.blocks.indices { definition.blocks[index].orderIndex = index }
    }

    private mutating func normalizeWeekOrder(blockIndex: Int) {
        for index in definition.blocks[blockIndex].weeks.indices { definition.blocks[blockIndex].weeks[index].weekIndex = index }
    }

    private mutating func normalizeWorkoutOrder(blockIndex: Int, weekIndex: Int) {
        for index in definition.blocks[blockIndex].weeks[weekIndex].workouts.indices { definition.blocks[blockIndex].weeks[weekIndex].workouts[index].orderIndex = index }
    }

    private mutating func normalizeExerciseOrder(blockIndex: Int, weekIndex: Int, workoutIndex: Int) {
        for index in definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises.indices {
            definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[index].orderIndex = index
        }
    }

    private mutating func normalizeSetOrder(blockIndex: Int, weekIndex: Int, workoutIndex: Int, exerciseIndex: Int) {
        for index in definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[exerciseIndex].plannedSets.indices {
            definition.blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[exerciseIndex].plannedSets[index].orderIndex = index
        }
    }
}

#endif
