import Foundation

#if !GYMTRACKER_EXTENSION

enum ProgramPrescriptionSnapshotService {
    static func resolvedExercise(for plannedExercise: PlannedExercise, in run: PlanRun) -> Exercise {
        guard let state = PlanProgressionStateService.effectiveState(for: plannedExercise, in: run),
              let selectedID = state.currentVariationExerciseID,
              selectedID != plannedExercise.exercise.id else {
            return plannedExercise.exercise
        }
        return plannedExercise.alternatives.first(where: { $0.exercise.id == selectedID })?.exercise
            ?? plannedExercise.exercise
    }

    /// Re-resolves only incomplete derived sets after a source set (for
    /// example a top set or daily maximum) is completed. Performed values are
    /// never rewritten.
    static func refreshDerivedLoads(for workout: Workout) {
        let decoder = JSONDecoder()
        var context = LoadResolutionContext()
        for entry in workout.orderedExercises {
            guard let key = entry.progressionKey else { continue }
            let completedDailyMaximums = entry.orderedSets.filter { set in
                let definition = set.prescriptionDefinitionData.flatMap {
                    try? decoder.decode(SetPrescriptionDefinition.self, from: $0)
                }
                return set.done && (
                    definition?.role == .dailyMaximum
                        || set.prescribedSetType == .dailyMaximum
                        || set.setType == .dailyMaximum
                )
            }
            if let selectedMaximum = completedDailyMaximums.last(where: \.isSelectedDailyMaximum)
                ?? completedDailyMaximums.last {
                context.dailyMaximumByExposure[key] = Double(
                    UnitConversion.weight(
                        selectedMaximum.weight,
                        from: selectedMaximum.weightType,
                        to: .kg
                    )
                )
            }
            for set in entry.orderedSets {
                let definition = set.prescriptionDefinitionData.flatMap { try? decoder.decode(SetPrescriptionDefinition.self, from: $0) }
                let isTopSet = definition?.role == .topSet || set.prescribedSetType == .topSet || set.setType == .topSet
                if isTopSet, set.done {
                    context.completedTopSetByExposure[key] = Double(
                        UnitConversion.weight(set.weight, from: set.weightType, to: .kg)
                    )
                }
            }
        }
        for entry in workout.orderedExercises {
            refreshGeneratedBackOffs(in: entry, context: context, decoder: decoder)
        }
        guard !context.completedTopSetByExposure.isEmpty || !context.dailyMaximumByExposure.isEmpty else { return }
        for entry in workout.orderedExercises {
            guard entry.progressionKey != nil else { continue }
            for set in entry.orderedSets where !set.done {
                guard let data = set.prescriptionDefinitionData,
                      let definition = try? decoder.decode(SetPrescriptionDefinition.self, from: data) else { continue }
                guard let resolution = try? ProgramLoadResolver.resolve(definition.load, context: context),
                      let load = resolution.prescribedLoad else { continue }
                let targetType: WeightType = entry.usedMetric == .metric ? .kg : .lbs
                let converted = Double(UnitConversion.weight(Float(load), from: .kg, to: targetType))
                let unrounded = resolution.unroundedLoad.map {
                    Double(UnitConversion.weight(Float($0), from: .kg, to: targetType))
                } ?? converted
                let equipmentRounding = definition.load.rounding == .none
                    ? EquipmentLoadRounding.round(
                        unrounded,
                        equipment: entry.exercise.equipmentType,
                        resistance: entry.exercise.resistanceType,
                        isPlateLoaded: entry.exercise.isPlateLoaded,
                        unit: targetType
                    )
                    : nil
                set.prescribedSuggestedLoad = equipmentRounding?.prescribedLoad ?? converted
                set.prescribedSuggestedLoadType = targetType
                set.prescribedUnroundedLoad = unrounded
                set.prescribedReferenceValue = resolution.referenceValue
                set.prescriptionLoadExplanation = equipmentRounding.map {
                    "\(resolution.explanation) Equipment rounding: nearest \($0.increment.formatted(.number.precision(.fractionLength(0...2)))) \(targetType.rawValue)."
                } ?? resolution.explanation
                if entry.prescribedSuggestedLoad == nil {
                    entry.prescribedSuggestedLoad = set.prescribedSuggestedLoad
                    entry.prescribedSuggestedLoadType = targetType
                }
            }
        }
    }

    static func apply(
        to entry: ExerciseEntry,
        plannedExercise: PlannedExercise,
        run: PlanRun,
        unitSystem: UnitSystem,
        preservingCompletedSets: Bool = false
    ) {
        let decoder = JSONDecoder()
        _ = PlanProgressionTransitionService.applyDuePendingTransitions(in: run)
        _ = PlanProgressionCadenceService.applyDueStates(in: run, decoder: decoder)
        let persistedState = PlanProgressionStateService.effectiveState(
            for: plannedExercise,
            in: run
        )
        let state = persistedState.map { persisted in
            PlanProgressionCadenceService.state(from: persisted)
        }
        let inheritedOverrides = latestFutureOverrides(
            for: plannedExercise.progressionKey,
            in: run
        )
        var context = LoadResolutionContext()
        let allPlannedExercises = run.plan?.orderedWeeks
            .flatMap(\.orderedPlannedWorkouts)
            .flatMap(\.orderedPlannedExercises) ?? []
        let effectiveStates = allPlannedExercises.reduce(into: [String: PlanExerciseProgressionState]()) { result, planned in
            if let state = PlanProgressionStateService.effectiveState(for: planned, in: run) {
                result[planned.progressionKey] = state
            }
        }
        for progressionState in effectiveStates.values {
            let resolvedState = PlanProgressionCadenceService.state(from: progressionState)
            if let value = resolvedState.trainingMax { context.trainingMaxByExposure[progressionState.progressionKey] = value }
            if let value = resolvedState.estimatedOneRepMax { context.estimatedOneRepMaxByExposure[progressionState.progressionKey] = value }
            if let value = resolvedState.actualOneRepMax { context.actualOneRepMaxByExposure[progressionState.progressionKey] = value }
            if let value = resolvedState.currentLoad {
                context.previousOccurrenceByExposure[progressionState.progressionKey] = value
                context.previousWorkoutByExposure[progressionState.progressionKey] = value
                context.anotherPlannedExerciseByExposure[progressionState.progressionKey] = value
            }
            if let value = progressionState.lastSuccessfulLoad {
                context.previousSuccessfulSetByExposure[progressionState.progressionKey] = value
            }
        }
        for planned in allPlannedExercises {
            guard let persisted = effectiveStates[planned.progressionKey] else { continue }
            let state = PlanProgressionCadenceService.state(from: persisted)
            if let value = state.actualOneRepMax ?? state.trainingMax ?? state.estimatedOneRepMax ?? state.currentLoad {
                context.exerciseOneRepMaxByID[planned.exercise.id] = value
                context.referenceValuesByExerciseID[planned.exercise.id] = value
            }
        }

        let stageConfiguration = plannedExercise.progressionStagesData
            .flatMap { try? decoder.decode(ProgramStageConfiguration.self, from: $0) }
        let selectedStage = stageConfiguration?.stages.first {
            $0.stageID == (state?.currentStageID ?? stageConfiguration?.initialStageID)
        }
        let waveDefinitions: [ProgramWaveDefinition] = plannedExercise.progressionWavesData
            .flatMap { try? decoder.decode([ProgramWaveDefinition].self, from: $0) } ?? []
        let selectedWave = waveDefinitions
            .sorted { $0.orderIndex < $1.orderIndex }
            .dropFirst(min(max(0, state?.currentWaveIndex ?? 0), max(0, waveDefinitions.count - 1)))
            .first
        let prescriptions: [(definition: SetPrescriptionDefinition, data: Data)]
        if let selectedStage {
            prescriptions = selectedStage.plannedSets
                .sorted { $0.orderIndex < $1.orderIndex }
                .compactMap { definition in
                    guard let data = try? JSONEncoder().encode(definition) else { return nil }
                    return (definition, data)
                }
        } else if let selectedWave {
            prescriptions = selectedWave.plannedSets
                .sorted { $0.orderIndex < $1.orderIndex }
                .compactMap { definition in
                    guard let data = try? JSONEncoder().encode(definition) else { return nil }
                    return (definition, data)
                }
        } else {
            prescriptions = plannedExercise.orderedPlannedSets.compactMap { plannedSet in
                guard let data = plannedSet.definitionData,
                      let definition = try? decoder.decode(SetPrescriptionDefinition.self, from: data) else { return nil }
                return (definition, data)
            }
        }
        let deferredBackOffs = prescriptions.filter {
            $0.definition.role == .backOff && $0.definition.generatesAfterSourceCompletion
        }
        if !deferredBackOffs.isEmpty {
            entry.deferredBackOffDefinitionsData = try? JSONEncoder().encode(deferredBackOffs.map(\.definition))
        } else {
            entry.deferredBackOffDefinitionsData = nil
        }
        let deferredBackOffIDs = Set(deferredBackOffs.map(\.definition.id))
        let immediatePrescriptions = prescriptions.filter {
            !deferredBackOffIDs.contains($0.definition.id)
        }
        if !prescriptions.isEmpty {
            reconcileStructuredSetCount(
                in: entry,
                targetCount: immediatePrescriptions.count,
                preservingCompletedSets: preservingCompletedSets
            )
        }
        // Legacy plans have no encoded set definitions. Their ExerciseEntry
        // initializer has already snapshotted targetSets into concrete sets,
        // so an empty structured prescription must not erase those sets.
        if !prescriptions.isEmpty { entry.prescribedSets = immediatePrescriptions.count }

        // Prescriptions are paired to rows by position, so rows this service
        // generated itself (warm-up scheme rows) must never be pairing
        // targets — a repeated apply would shift the first prescription onto
        // a warm-up. Explicitly prescribed warmup-role rows have to stay:
        // they are backed by a prescription, and dropping them would shift
        // every later prescription instead.
        let targetSets = entry.orderedSets.filter { !ProgramWarmupSnapshotter.isGeneratedWarmup($0) }
        for (index, prescription) in immediatePrescriptions.enumerated() {
            guard index < targetSets.count else { continue }
            let definition = prescription.definition
            let data = prescription.data
            let set = targetSets[index]
            if preservingCompletedSets && set.done {
                continue
            }
            set.prescriptionDefinitionData = data
            switch definition.role {
            case .warmup: set.prescribedSetType = .warmup
            case .dropSet: set.prescribedSetType = .dropSet
            case .backOff: set.prescribedSetType = .backoff
            case .topSet: set.prescribedSetType = .topSet
            case .amrap: set.prescribedSetType = .amrap
            case .technique: set.prescribedSetType = .technique
            case .dailyMaximum: set.prescribedSetType = .dailyMaximum
            case .test: set.prescribedSetType = .test
            case .recovery: set.prescribedSetType = .recovery
            case .working: set.prescribedSetType = .normal
            }
            switch definition.repetitions {
            case .fixed(let repetitions):
                set.prescribedRepetitions = max(1, repetitions + (state?.repetitionOffset ?? 0))
            case .range(let minimum, let maximum):
                let offset = state?.repetitionOffset ?? 0
                set.prescribedRepRangeMinimum = max(1, minimum + offset)
                set.prescribedRepRangeMaximum = max(set.prescribedRepRangeMinimum ?? maximum, maximum + offset)
            case .amrap(let minimum, let maximum):
                let offset = state?.repetitionOffset ?? 0
                set.prescribedRepRangeMinimum = minimum.map { max(0, $0 + offset) }
                set.prescribedRepRangeMaximum = maximum.map { max(set.prescribedRepRangeMinimum ?? 0, $0 + offset) }
            case .duration(let seconds):
                set.duration = seconds.map { max(1, $0 + (state?.durationOffset ?? 0)) }
            case .distance(let meters):
                set.distance = meters.map { Float(max(0.01, $0 + (state?.distanceOffset ?? 0))) }
            case .calories(let calories):
                set.calories = calories.map { max(0, $0 + (state?.caloriesOffset ?? 0)) }
            set.prescribedCalories = set.calories
            case .sequence(let components):
                let repetitions = components.reduce(0) { $0 + $1.repetitions }
                set.prescribedRepetitions = max(1, repetitions + (state?.repetitionOffset ?? 0))
                if set.repetitions <= 0 {
                    set.repetitions = Float(set.prescribedRepetitions ?? repetitions)
                }
                set.ensureComplexComponents(for: components.enumerated().map { index, component in
                    ComplexComponentSnapshot(
                        exerciseID: component.exerciseID,
                        exerciseNameSnapshot: component.exerciseNameSnapshot ?? "Component \(index + 1)",
                        prescribedRepetitions: component.repetitions
                    )
                })
                let notation = components.map { String($0.repetitions) }.joined(separator: "+")
                set.prescriptionNotes = ["Complex: \(notation)", definition.notes]
                    .compactMap { $0 }
                    .joined(separator: " · ")
            case .open:
                break
            }
            set.prescribedRestSeconds = definition.restSeconds.map { max(0, $0 + (state?.restDurationOffset ?? 0)) }
            set.prescribedRPE = definition.targetRPE
            set.prescribedRIR = definition.targetRIR
            set.prescribedTempo = definition.tempo
            set.prescribedProgressionEligible = definition.progressionEligible
            applyVelocityPrescription(definition.velocity, to: set)
            set.isPrescribedOptional = definition.isOptional
            if set.prescriptionNotes == nil {
                set.prescriptionNotes = definition.notes
            }
            if let load = try? ProgramLoadResolver.resolve(definition.load, context: context),
               let value = load.prescribedLoad {
                let sourceType = persistedState?.currentLoadType ?? .kg
                let targetType: WeightType = unitSystem == .metric ? .kg : .lbs
                let converted = Double(UnitConversion.weight(Float(value), from: sourceType, to: targetType))
                let unrounded = load.unroundedLoad.map {
                    Double(UnitConversion.weight(Float($0), from: sourceType, to: targetType))
                } ?? converted
                let equipmentRounding = definition.load.rounding == .none
                    ? EquipmentLoadRounding.round(
                        unrounded,
                        equipment: entry.exercise.equipmentType,
                        resistance: entry.exercise.resistanceType,
                        isPlateLoaded: entry.exercise.isPlateLoaded,
                        unit: targetType
                    )
                    : nil
                set.prescribedSuggestedLoad = equipmentRounding?.prescribedLoad ?? converted
                set.prescribedSuggestedLoadType = targetType
                set.prescribedUnroundedLoad = unrounded
                set.prescribedReferenceValue = load.referenceValue
                set.prescriptionLoadExplanation = equipmentRounding.map {
                    "\(load.explanation) Equipment rounding: nearest \($0.increment.formatted(.number.precision(.fractionLength(0...2)))) \(targetType.rawValue)."
                } ?? load.explanation
            }
            applyFutureOverride(
                from: inheritedOverrides[set.orderIndex],
                to: set,
                trackingType: entry.trackingTypeSnapshot
            )
        }
        if !preservingCompletedSets, let countOffset = state?.setCountOffset, countOffset != 0 {
            let originalCount = entry.orderedSets.count
            let adjustedCount = max(1, originalCount + countOffset)
            if adjustedCount < originalCount {
                entry.sets = Array(entry.orderedSets.prefix(adjustedCount))
            } else if let source = entry.orderedSets.last {
                for _ in originalCount..<adjustedCount {
                    let extra = ExerciseSet(
                        repetitions: 0,
                        weight: source.weight,
                        calories: source.calories,
                        setType: source.setType,
                        orderIndex: entry.orderedSets.count,
                        usedMetric: source.usedMetric
                    )
                    extra.prescribedSetType = source.prescribedSetType
                    extra.prescribedRepetitions = source.prescribedRepetitions
                    extra.prescribedRepRangeMinimum = source.prescribedRepRangeMinimum
                    extra.prescribedRepRangeMaximum = source.prescribedRepRangeMaximum
                    extra.prescribedSuggestedLoad = source.prescribedSuggestedLoad
                    extra.prescribedSuggestedLoadType = source.prescribedSuggestedLoadType
                    extra.prescribedUnroundedLoad = source.prescribedUnroundedLoad
                    extra.prescribedReferenceValue = source.prescribedReferenceValue
                    extra.prescriptionLoadExplanation = source.prescriptionLoadExplanation
                    extra.prescribedRestSeconds = source.prescribedRestSeconds
                    extra.prescribedRPE = source.prescribedRPE
                    extra.prescribedRIR = source.prescribedRIR
                    extra.prescribedTempo = source.prescribedTempo
                    extra.prescribedProgressionEligible = source.prescribedProgressionEligible
                    extra.prescribedCalories = source.prescribedCalories
                    extra.isUserOverridden = source.isUserOverridden
                    extra.userOverrideReason = source.userOverrideReason
                    extra.userOverrideAffectsFuture = source.userOverrideAffectsFuture
                    extra.isPrescribedOptional = source.isPrescribedOptional
                    extra.prescriptionNotes = source.prescriptionNotes
                    extra.prescriptionDefinitionData = source.prescriptionDefinitionData
                    entry.sets.append(extra)
                }
            }
            entry.prescribedSets = adjustedCount
            entry.normalizeSetOrder()
        }
        if state?.isDeloading == true {
            applyAutomaticDeload(to: entry, plannedExercise: plannedExercise)
            // `startDeload` means the next generated occurrence. Clearing the
            // mutable run flag after its prescription snapshot is frozen keeps
            // later occurrences on their normal policy unless another rule
            // explicitly starts a new deload.
            persistedState?.isDeloading = false
        }
        ProgramWarmupSnapshotter.insertWarmups(
            into: entry,
            plannedExercise: plannedExercise,
            decoder: decoder
        )
    }

}

#endif
