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

        // A normal workout start resolves prescriptions before generated
        // warm-ups are inserted. An active-event refresh happens afterwards,
        // so it must address only working sets or the first prescription would
        // be shifted onto a warm-up row.
        let targetSets = preservingCompletedSets
            ? entry.orderedSets.filter { $0.prescribedSetType != .warmup && $0.setType != .warmup }
            : entry.orderedSets
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
        insertWarmups(into: entry, plannedExercise: plannedExercise, decoder: decoder)
    }

    private static func latestFutureOverrides(
        for progressionKey: String,
        in run: PlanRun
    ) -> [Int: ExerciseSet] {
        let entries = run.orderedWorkoutProgress
            .filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .compactMap { progress in
                progress.completedWorkout?.orderedExercises.first {
                    $0.progressionKey == progressionKey
                }
            }
        guard let latest = entries.first else { return [:] }
        return Dictionary(
            uniqueKeysWithValues: latest.orderedSets
                .filter { $0.userOverrideAffectsFuture }
                .map { ($0.orderIndex, $0) }
        )
    }

    private static func reconcileStructuredSetCount(
        in entry: ExerciseEntry,
        targetCount: Int,
        preservingCompletedSets: Bool
    ) {
        let workingSets = entry.orderedSets.filter {
            $0.prescribedSetType != .warmup && $0.setType != .warmup
        }
        if workingSets.count > targetCount {
            let required = Set(workingSets.prefix(targetCount).map(\.id))
            entry.sets.removeAll { set in
                guard workingSets.contains(where: { $0.id == set.id }) else { return false }
                return !required.contains(set.id) && !(preservingCompletedSets && set.done)
            }
        } else if workingSets.count < targetCount, let source = workingSets.last ?? entry.orderedSets.last {
            for _ in workingSets.count..<targetCount {
                entry.sets.append(
                    ExerciseSet(
                        repetitions: 0,
                        weight: source.weight,
                        calories: source.calories,
                        setType: source.setType,
                        orderIndex: entry.sets.count,
                        usedMetric: source.usedMetric
                    )
                )
            }
        }
        entry.normalizeSetOrder()
    }

    private static func refreshGeneratedBackOffs(
        in entry: ExerciseEntry,
        context: LoadResolutionContext,
        decoder: JSONDecoder
    ) {
        guard let data = entry.deferredBackOffDefinitionsData,
              let definitions = try? decoder.decode([SetPrescriptionDefinition].self, from: data) else {
            return
        }

        var changed = false
        for definition in definitions where definition.role == .backOff {
            let matching = entry.orderedSets.filter { $0.generatedBackOffDefinitionID == definition.id }
            let completed = matching.filter(\.done)
            let incomplete = matching.filter { !$0.done }

            // A deferred definition represents one future prescription, not
            // an open-ended source of duplicate sets. A completed generated
            // row is immutable evidence, so it wins over any stray unfinished
            // rows that might have been left by an interrupted refresh or an
            // older restore. Never delete completed rows here.
            if !completed.isEmpty {
                if !incomplete.isEmpty {
                    entry.sets.removeAll { candidate in
                        candidate.generatedBackOffDefinitionID == definition.id && !candidate.done
                    }
                    changed = true
                }
                continue
            }

            guard let resolution = try? ProgramLoadResolver.resolve(definition.load, context: context),
                  let prescribedLoad = resolution.prescribedLoad else {
                if !incomplete.isEmpty {
                    entry.sets.removeAll { candidate in
                        candidate.generatedBackOffDefinitionID == definition.id && !candidate.done
                    }
                    changed = true
                }
                continue
            }

            if incomplete.isEmpty {
                let created = ExerciseSet(
                    repetitions: 0,
                    weight: 0,
                    setType: .backoff,
                    orderIndex: (entry.orderedSets.last?.orderIndex ?? -1) + 1,
                    usedMetric: entry.usedMetric
                )
                created.generatedBackOffDefinitionID = definition.id
                configureGeneratedBackOff(
                    created,
                    definition: definition,
                    resolution: resolution,
                    prescribedLoad: prescribedLoad,
                    entry: entry
                )
                entry.sets.append(created)
                changed = true
            } else {
                let canonical = incomplete.first!
                if incomplete.count > 1 {
                    entry.sets.removeAll { candidate in
                        candidate.generatedBackOffDefinitionID == definition.id
                            && !candidate.done
                            && candidate.id != canonical.id
                    }
                    changed = true
                }
                configureGeneratedBackOff(
                    canonical,
                    definition: definition,
                    resolution: resolution,
                    prescribedLoad: prescribedLoad,
                    entry: entry
                )
                changed = true
            }
        }
        if changed {
            entry.normalizeSetOrder()
            entry.prescribedSets = entry.orderedSets.filter {
                $0.prescribedSetType != .warmup && $0.setType != .warmup
            }.count
        }
    }

    private static func configureGeneratedBackOff(
        _ set: ExerciseSet,
        definition: SetPrescriptionDefinition,
        resolution: LoadResolutionResult,
        prescribedLoad: Double,
        entry: ExerciseEntry
    ) {
        set.setType = .backoff
        set.prescribedSetType = .backoff
        set.prescriptionDefinitionData = try? JSONEncoder().encode(definition)
        switch definition.repetitions {
        case .fixed(let repetitions):
            set.prescribedRepetitions = repetitions
        case .range(let minimum, let maximum):
            set.prescribedRepRangeMinimum = minimum
            set.prescribedRepRangeMaximum = maximum
        case .amrap(let minimum, let maximum):
            set.prescribedRepRangeMinimum = minimum
            set.prescribedRepRangeMaximum = maximum
        case .sequence(let components):
            set.prescribedRepetitions = components.reduce(0) { $0 + $1.repetitions }
            set.prescriptionNotes = "Complex: \(components.map { String($0.repetitions) }.joined(separator: "+"))"
        case .duration(let seconds):
            set.duration = seconds
        case .distance(let meters):
            set.distance = meters.map { Float($0) }
        case .calories(let calories):
            set.calories = calories
            set.prescribedCalories = calories
        case .open:
            break
        }
        set.prescribedRestSeconds = definition.restSeconds
        set.prescribedRPE = definition.targetRPE
        set.prescribedRIR = definition.targetRIR
        set.prescribedTempo = definition.tempo
        set.prescribedProgressionEligible = definition.progressionEligible
        applyVelocityPrescription(definition.velocity, to: set)
        set.isPrescribedOptional = definition.isOptional
        if set.prescriptionNotes == nil { set.prescriptionNotes = definition.notes }

        let targetType: WeightType = entry.usedMetric == .metric ? .kg : .lbs
        let converted = Double(UnitConversion.weight(Float(prescribedLoad), from: .kg, to: targetType))
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
    }

    private static func applyVelocityPrescription(
        _ prescription: SetPrescriptionDefinition.VelocityPrescription?,
        to set: ExerciseSet
    ) {
        set.prescribedVelocityMinimum = prescription?.targetMinimum
        set.prescribedVelocityMaximum = prescription?.targetMaximum
        set.prescribedVelocityLossStopPercent = prescription?.lossStopPercent
        set.isVelocityProbe = prescription?.isProbe ?? false
    }

    private static func applyAutomaticDeload(to entry: ExerciseEntry, plannedExercise: PlannedExercise) {
        let volumeMultiplier = 1 - Double(plannedExercise.automaticDeloadVolumeReductionPercent ?? 50) / 100
        let intensityMultiplier = 1 - Double(plannedExercise.automaticDeloadIntensityReductionPercent ?? 10) / 100
        let originalSets = entry.orderedSets
        guard !originalSets.isEmpty else { return }
        let adjustedCount = max(1, Int((Double(originalSets.count) * volumeMultiplier).rounded(.up)))
        entry.sets = Array(originalSets.prefix(adjustedCount))
        entry.prescribedSets = adjustedCount
        for set in entry.sets {
            if let prescribed = set.prescribedSuggestedLoad {
                set.prescribedSuggestedLoad = prescribed * intensityMultiplier
            }
            if let unrounded = set.prescribedUnroundedLoad {
                set.prescribedUnroundedLoad = unrounded * intensityMultiplier
            }
            if let explanation = set.prescriptionLoadExplanation {
                set.prescriptionLoadExplanation = "\(explanation) Automatic deload applied."
            }
            if entry.trackingTypeSnapshot.usesWeight {
                set.weight *= Float(intensityMultiplier)
            }
        }
        if let prescribed = entry.prescribedSuggestedLoad {
            entry.prescribedSuggestedLoad = prescribed * intensityMultiplier
        }
        entry.normalizeSetOrder()
    }

    private static func insertWarmups(
        into entry: ExerciseEntry,
        plannedExercise: PlannedExercise,
        decoder: JSONDecoder
    ) {
        guard let data = plannedExercise.warmupSchemeData,
              let scheme = try? decoder.decode(WarmupSchemeDefinition.self, from: data),
              !scheme.steps.isEmpty,
              !entry.orderedSets.contains(where: { $0.prescriptionNotes == "Generated warm-up" }),
              let workingLoad = entry.orderedSets.first?.prescribedSuggestedLoad ?? entry.prescribedSuggestedLoad
        else { return }
        let warmups = scheme.steps.enumerated().map { index, step in
            let set = ExerciseSet(
                repetitions: Float(step.repetitions),
                weight: Float(workingLoad * step.percentage),
                setType: .warmup,
                orderIndex: index,
                usedMetric: entry.usedMetric
            )
            set.prescribedSetType = .warmup
            set.prescribedRepetitions = step.repetitions
            set.prescribedSuggestedLoad = workingLoad * step.percentage
            set.prescribedSuggestedLoadType = entry.prescribedSuggestedLoadType
            set.prescribedUnroundedLoad = workingLoad * step.percentage
            set.prescribedReferenceValue = Double(
                UnitConversion.weight(
                    Float(workingLoad),
                    from: entry.orderedSets.first?.prescribedSuggestedLoadType
                        ?? entry.prescribedSuggestedLoadType
                        ?? .kg,
                    to: .kg
                )
            )
            set.prescriptionLoadExplanation = "Generated warm-up at \(Int((step.percentage * 100).rounded()))% of the first working load."
            set.prescribedRestSeconds = step.restSeconds
            set.prescriptionNotes = "Generated warm-up"
            return set
        }
        entry.sets = warmups + entry.orderedSets
        entry.normalizeSetOrder()
        entry.prescribedSets = entry.orderedSets.count
    }

    private static func applyFutureOverride(
        from source: ExerciseSet?,
        to target: ExerciseSet,
        trackingType: TrackingType
    ) {
        guard let source, source.userOverrideAffectsFuture else { return }
        if trackingType.usesReps { target.repetitions = source.repetitions }
        if trackingType.usesWeight {
            target.weight = UnitConversion.weight(source.weight, from: source.weightType, to: target.weightType)
        }
        if trackingType.usesDuration { target.duration = source.duration }
        if trackingType.usesDistance {
            if let distance = source.distance {
                target.distance = UnitConversion.distance(distance, from: source.distanceType, to: target.distanceType)
            } else {
                target.distance = nil
            }
        }
        if trackingType.usesCalories { target.calories = source.calories }
        target.isUserOverridden = true
        target.userOverrideReason = source.userOverrideReason
        target.userOverrideAffectsFuture = true
    }
}
#endif
