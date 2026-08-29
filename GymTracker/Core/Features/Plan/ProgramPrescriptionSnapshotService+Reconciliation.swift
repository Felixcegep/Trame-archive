import Foundation

#if !GYMTRACKER_EXTENSION

extension ProgramPrescriptionSnapshotService {
    static func latestFutureOverrides(
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

    static func reconcileStructuredSetCount(
        in entry: ExerciseEntry,
        targetCount: Int,
        preservingCompletedSets: Bool
    ) {
        // Count every prescription-backed row, including explicit
        // warmup-role prescriptions; only rows generated from a warm-up
        // scheme sit outside the structured count.
        let workingSets = entry.orderedSets.filter { !ProgramWarmupSnapshotter.isGeneratedWarmup($0) }
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

    static func refreshGeneratedBackOffs(
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
                $0.prescribedSetType != .warmup && !$0.setType.isStrengthAnalyticsExcluded
            }.count
        }
    }

    static func configureGeneratedBackOff(
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
            set.duration = definition.separatesPerformedEvidence ? nil : seconds
        case .distance(let meters):
            set.distance = definition.separatesPerformedEvidence ? nil : meters.map(Float.init)
            set.distanceType = .meters
        case .calories(let calories):
            set.calories = definition.separatesPerformedEvidence ? nil : calories
            set.prescribedCalories = definition.separatesPerformedEvidence ? nil : calories
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

    static func applyVelocityPrescription(
        _ prescription: SetPrescriptionDefinition.VelocityPrescription?,
        to set: ExerciseSet
    ) {
        set.prescribedVelocityMinimum = prescription?.targetMinimum
        set.prescribedVelocityMaximum = prescription?.targetMaximum
        set.prescribedVelocityLossStopPercent = prescription?.lossStopPercent
        set.isVelocityProbe = prescription?.isProbe ?? false
    }

    static func applyAutomaticDeload(to entry: ExerciseEntry, plannedExercise: PlannedExercise) {
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

    static func applyFutureOverride(
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
            target.distance = WorkoutDistancePolicy.meters(of: source)
            target.distanceType = .meters
        }
        if trackingType.usesCalories { target.calories = source.calories }
        target.isUserOverridden = true
        target.userOverrideReason = source.userOverrideReason
        target.userOverrideAffectsFuture = true
    }
}

#endif
