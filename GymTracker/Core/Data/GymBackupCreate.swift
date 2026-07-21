import Foundation
import SwiftData

extension BackupDTO {

    static func create(from context: ModelContext, restTimer: Int, darkMode: Bool, unitSystem: UnitSystem) throws -> BackupDTO {
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let exerciseDTOs = exercises.map { exercise in
            ExerciseTemplateDTO(
                id: exercise.id.uuidString,
                name: exercise.name,
                primaryMuscles: exercise.primaryMuscles.map(\.rawValue),
                secondaryMuscles: exercise.secondaryMuscles?.map(\.rawValue),
                category: exercise.category?.rawValue,
                trackingType: exercise.trackingType.rawValue,
                equipmentType: exercise.equipmentType?.rawValue,
                resistanceType: exercise.resistanceType?.rawValue,
                movementPattern: exercise.movementPattern?.rawValue,
                difficulty: exercise.difficulty?.rawValue,
                tags: exercise.tags,
                isFavorite: exercise.isFavorite,
                isPlateLoaded: exercise.isPlateLoaded,
                isCustom: exercise.isCustom,
                isArchived: exercise.isArchived,
                forceType: exercise.forceType?.rawValue,
                mechanics: exercise.mechanics?.rawValue,
                laterality: exercise.laterality.rawValue,
                repCountingStyle: exercise.repCountingStyle.rawValue,
                weightEntryStyle: exercise.weightEntryStyle.rawValue,
                loadUnitCount: exercise.loadUnitCount,
                gripStyle: exercise.gripStyle?.rawValue,
                stance: exercise.stance?.rawValue,
                rangeOfMotion: exercise.rangeOfMotion?.rawValue,
                setupAngleDegrees: exercise.setupAngleDegrees,
                variationFamilyID: exercise.variationFamilyID
            )
        }

        let relationshipDTOs: [ExerciseRelationshipDTO] = try context.fetch(FetchDescriptor<ExerciseRelationship>()).compactMap { relationship in
            guard let source = relationship.sourceExercise, let target = relationship.targetExercise else {
                return nil
            }
            return ExerciseRelationshipDTO(
                sourceExerciseName: source.name,
                targetExerciseName: target.name,
                type: relationship.type.rawValue
            )
        }

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let templateDTOs = templates.map { template in
            WorkoutTemplateDTO(
                name: template.name,
                templateExercises: template.templateExercises.map { te in
                    TemplateExerciseDTO(
                        exerciseName: te.exercise.name,
                        orderIndex: te.orderIndex,
                        targetSets: te.targetSets,
                        repRangeMinimum: te.repRangeMinimum,
                        repRangeMaximum: te.repRangeMaximum,
                        restSeconds: te.restSeconds,
                        targetRPE: te.targetRPE,
                        targetRIR: te.targetRIR,
                        notes: te.notes,
                        progressionRule: te.progressionRule.rawValue,
                        supersetGroupID: te.supersetGroupID?.uuidString,
                        progressionKey: te.progressionKey,
                        executionBlockID: te.executionBlockID?.uuidString,
                        executionBlockComponentOrder: te.executionBlockComponentOrder
                    )
                },
                executionBlocks: template.orderedExecutionBlocks.map { block in
                    TemplateExerciseBlockDTO(
                        id: block.id.uuidString,
                        orderIndex: block.orderIndex,
                        kind: block.kind.rawValue,
                        name: block.name,
                        targetRounds: block.targetRounds,
                        isSharedLoad: block.isSharedLoad,
                        restSeconds: block.restSeconds,
                        clockMode: block.clockMode.rawValue,
                        prescribedDurationSeconds: block.prescribedDurationSeconds,
                        timeCapSeconds: block.timeCapSeconds,
                        intervalSeconds: block.intervalSeconds,
                        scoreKind: block.scoreKind.rawValue,
                        repetitionScheme: block.repetitionScheme.rawValue,
                        repetitionStart: block.repetitionStart,
                        repetitionEnd: block.repetitionEnd,
                        repetitionStep: block.repetitionStep
                    )
                }
            )
        }

        let collections = try context.fetch(FetchDescriptor<WorkoutCollection>())
        let collectionDTOs = collections.map { collection in
            WorkoutCollectionDTO(
                name: collection.name,
                templateNames: collection.workoutTemplates.map(\.name)
            )
        }

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let workoutDTOs = workouts.map { workout in
            WorkoutDTO(
                id: workout.id.uuidString,
                status: workout.status.rawValue,
                name: workout.name,
                notes: workout.notes,
                startTime: workout.startTime,
                endTime: workout.endTime,
                restEndDate: workout.restEndDate,
                pausedRemainingTime: workout.pausedRemainingTime,
                sourceTemplateName: workout.sourceTemplate?.name,
                sourcePlanID: workout.sourcePlanID?.uuidString,
                sourcePlanRunID: workout.sourcePlanRunID?.uuidString,
                sourcePlanBlockID: workout.sourcePlanBlockID?.uuidString,
                sourcePlanWeekID: workout.sourcePlanWeekID?.uuidString,
                sourcePlannedWorkoutID: workout.sourcePlannedWorkoutID?.uuidString,
                sourcePlanName: workout.sourcePlanName,
                sourceProgramDefinitionID: workout.sourceProgramDefinitionID?.uuidString,
                sourceProgramDefinitionVersion: workout.sourceProgramDefinitionVersion,
                exercises: workout.exercises.map { exercise in
                    let setsDTO = exercise.sets.map { set in
                        ExerciseSetDTO(
                            orderIndex: set.orderIndex,
                            weightType: set.weightType.rawValue,
                            distanceType: set.distanceType.rawValue,
                            repetition: set.repetitions,
                            weight: set.weight,
                            duration: set.duration,
                            distance: set.distance,
                            calories: set.calories,
                            done: set.done,
                            isUserOverridden: set.isUserOverridden,
                            userOverrideReason: set.userOverrideReason,
                            userOverrideAffectsFuture: set.userOverrideAffectsFuture,
                            rpe: set.rpe,
                            rir: set.rir,
                            liftQuality: set.liftQuality?.rawValue,
                            meanVelocity: set.meanVelocity,
                            peakVelocity: set.peakVelocity,
                            velocityMeasurementSource: set.velocityMeasurementSource?.rawValue,
                            specializedMetricKind: set.specializedMetricKind.rawValue,
                            jumpHeightMeters: set.jumpHeightMeters,
                            contactTimeMilliseconds: set.contactTimeMilliseconds,
                            throwDistanceMeters: set.throwDistanceMeters,
                            kettlebellCadenceRPM: set.kettlebellCadenceRPM,
                            specializedMetricMeasurementSource: set.specializedMetricMeasurementSource?.rawValue,
                            setMethod: set.setMethod.rawValue,
                            segments: set.orderedSegments.map { segment in
                                ExerciseSetSegmentDTO(
                                    id: segment.id.uuidString,
                                    orderIndex: segment.orderIndex,
                                    repetitions: segment.repetitions,
                                    weight: segment.weight,
                                    weightType: segment.weightType.rawValue,
                                    duration: segment.duration,
                                    restAfterSeconds: segment.restAfterSeconds,
                                    done: segment.done,
                                    variationNote: segment.variationNote,
                                    rpe: segment.rpe,
                                    rir: segment.rir
                                )
                            },
                            setType: set.setType.rawValue,
                            isSelectedDailyMaximum: set.isSelectedDailyMaximum,
                            generatedBackOffDefinitionID: set.generatedBackOffDefinitionID?.uuidString,
                            usedMetric: set.usedMetric.rawValue,
                            prescribedSetType: set.prescribedSetType?.rawValue,
                            prescribedRepetitions: set.prescribedRepetitions,
                            prescribedRepRangeMinimum: set.prescribedRepRangeMinimum,
                            prescribedRepRangeMaximum: set.prescribedRepRangeMaximum,
                            prescribedSuggestedLoad: set.prescribedSuggestedLoad,
                            prescribedSuggestedLoadType: set.prescribedSuggestedLoadType?.rawValue,
                            prescribedUnroundedLoad: set.prescribedUnroundedLoad,
                            prescribedReferenceValue: set.prescribedReferenceValue,
                            prescriptionLoadExplanation: set.prescriptionLoadExplanation,
                            prescribedRestSeconds: set.prescribedRestSeconds,
                            prescribedRPE: set.prescribedRPE,
                            prescribedRIR: set.prescribedRIR,
                            prescribedTempo: set.prescribedTempo,
                            prescribedProgressionEligible: set.prescribedProgressionEligible,
                            prescribedCalories: set.prescribedCalories,
                            prescribedVelocityMinimum: set.prescribedVelocityMinimum,
                            prescribedVelocityMaximum: set.prescribedVelocityMaximum,
                            prescribedVelocityLossStopPercent: set.prescribedVelocityLossStopPercent,
                            isVelocityProbe: set.isVelocityProbe,
                            isPrescribedOptional: set.isPrescribedOptional,
                            prescriptionNotes: set.prescriptionNotes,
                            prescriptionDefinitionData: set.prescriptionDefinitionData,
                            id: set.id.uuidString
                        )
                    }
                    return ExerciseEntryDTO(
                        orderIndex: exercise.orderIndex,
                        comment: exercise.comment,
                        exerciseName: exercise.exercise.name,
                        usedMetric: exercise.usedMetric.rawValue,
                        sets: setsDTO,
                        prescribedSets: exercise.prescribedSets,
                        prescribedRepRangeMinimum: exercise.prescribedRepRangeMinimum,
                        prescribedRepRangeMaximum: exercise.prescribedRepRangeMaximum,
                        prescribedRestSeconds: exercise.prescribedRestSeconds,
                        prescribedRPE: exercise.prescribedRPE,
                        prescribedRIR: exercise.prescribedRIR,
                        prescriptionNotes: exercise.prescriptionNotes,
                        sourcePlannedExerciseID: exercise.sourcePlannedExerciseID?.uuidString,
                        progressionKey: exercise.progressionKey,
                        prescribedRole: exercise.prescribedRole?.rawValue,
                        isPrescribedOptional: exercise.isPrescribedOptional,
                        prescribedSuggestedLoad: exercise.prescribedSuggestedLoad,
                        prescribedSuggestedLoadType: exercise.prescribedSuggestedLoadType?.rawValue,
                        prescribedProgressionRule: exercise.prescribedProgressionRule?.rawValue,
                        recommendedDecision: exercise.recommendedDecision?.rawValue,
                        recommendedLoad: exercise.recommendedLoad,
                        recommendedUnit: exercise.recommendedUnit?.rawValue,
                        recommendationPriorLoad: exercise.recommendationPriorLoad,
                        recommendationRequiredSets: exercise.recommendationRequiredSets,
                        recommendationRepCeiling: exercise.recommendationRepCeiling,
                        recommendationCompletedSets: exercise.recommendationCompletedSets,
                        recommendationPriorWorkoutDate: exercise.recommendationPriorWorkoutDate,
                        accumulatedActiveDuration: exercise.accumulatedActiveDuration,
                        activeDurationStartedAt: exercise.activeDurationStartedAt,
                        supersetGroupID: exercise.supersetGroupID?.uuidString,
                        executionBlockID: exercise.executionBlockID?.uuidString,
                        executionBlockComponentOrder: exercise.executionBlockComponentOrder,
                        originalExerciseIDSnapshot: exercise.originalExerciseIDSnapshot?.uuidString,
                        originalExerciseNameSnapshot: exercise.originalExerciseNameSnapshot,
                        selectedSubstituteExerciseIDSnapshot: exercise.selectedSubstituteExerciseIDSnapshot?.uuidString,
                        substitutionReason: exercise.substitutionReason,
                        substitutionSharesProgressionState: exercise.substitutionSharesProgressionState,
                        variationSourceExerciseIDSnapshot: exercise.variationSourceExerciseIDSnapshot?.uuidString,
                        variationSelectedExerciseIDSnapshot: exercise.variationSelectedExerciseIDSnapshot?.uuidString,
                        prescriptionDefinitionData: exercise.prescriptionDefinitionData,
                        prescriptionRulesData: exercise.prescriptionRulesData,
                        deferredBackOffDefinitionsData: exercise.deferredBackOffDefinitionsData
                    )
                },
                executionBlocks: workout.orderedExecutionBlocks.map { block in
                    WorkoutExecutionBlockDTO(
                        id: block.id.uuidString,
                        orderIndex: block.orderIndex,
                        kind: block.kind.rawValue,
                        name: block.name,
                        targetRounds: block.targetRounds,
                        isSharedLoad: block.isSharedLoad,
                        restSeconds: block.restSeconds,
                        clockMode: block.clockMode.rawValue,
                        prescribedDurationSeconds: block.prescribedDurationSeconds,
                        timeCapSeconds: block.timeCapSeconds,
                        intervalSeconds: block.intervalSeconds,
                        scoreKind: block.scoreKind.rawValue,
                        repetitionScheme: block.repetitionScheme.rawValue,
                        repetitionStart: block.repetitionStart,
                        repetitionEnd: block.repetitionEnd,
                        repetitionStep: block.repetitionStep,
                        status: block.status.rawValue,
                        completedRounds: block.completedRounds,
                        additionalRepetitions: block.additionalRepetitions,
                        scoreValue: block.scoreValue,
                        scoreTiebreakValue: block.scoreTiebreakValue,
                        accumulatedElapsedDuration: block.accumulatedElapsedDuration,
                        elapsedStartedAt: block.elapsedStartedAt,
                        sourceTemplateBlockID: block.sourceTemplateBlockID?.uuidString,
                        sourcePlannedBlockID: block.sourcePlannedBlockID?.uuidString,
                        sourceDefinitionBlockKey: block.sourceDefinitionBlockKey
                    )
                }
            )
        }

        let plans = try context.fetch(FetchDescriptor<WorkoutPlan>())
        let planDTOs = plans.map { plan in
            WorkoutPlanDTO(
                id: plan.id.uuidString,
                name: plan.name,
                goal: plan.goal.rawValue,
                experienceLevel: plan.experienceLevel.rawValue,
                requiredEquipment: plan.requiredEquipment.map(\.rawValue),
                daysPerWeek: plan.daysPerWeek,
                durationWeeks: plan.durationWeeks,
                scheduleMode: plan.scheduleMode.rawValue,
                scheduleIntervalDays: plan.scheduleIntervalDays,
                notes: plan.notes,
                createdAt: plan.createdAt,
                updatedAt: plan.updatedAt,
                isArchived: plan.isArchived,
                sourceProgramDefinitionID: plan.sourceProgramDefinitionID?.uuidString,
                sourceProgramDefinitionVersion: plan.sourceProgramDefinitionVersion,
                completionPolicyData: plan.completionPolicyData,
                blocks: plan.orderedBlocks.map { block in
                    PlanBlockDTO(
                        id: block.id.uuidString,
                        name: block.name,
                        phaseType: block.phaseType.rawValue,
                        goal: block.goal,
                        notes: block.notes,
                        deloadVolumeReductionPercent: block.deloadVolumeReductionPercent,
                        deloadIntensityReductionPercent: block.deloadIntensityReductionPercent,
                        orderIndex: block.orderIndex,
                        weeks: block.orderedWeeks.map { week in
                            PlanWeekDTO(
                                id: week.id.uuidString,
                                weekIndex: week.weekIndex,
                                name: week.name,
                                notes: week.notes,
                                plannedWorkouts: week.orderedPlannedWorkouts.map { plannedWorkout in
                                    PlannedWorkoutDTO(
                                        id: plannedWorkout.id.uuidString,
                                        name: plannedWorkout.name,
                                        orderIndex: plannedWorkout.orderIndex,
                                        dayOffset: plannedWorkout.dayOffset,
                                        isOptional: plannedWorkout.isOptional,
                                        isTestDay: plannedWorkout.isTestDay,
                                        estimatedDurationSeconds: plannedWorkout.estimatedDurationSeconds,
                                        notes: plannedWorkout.notes,
                                        sourceTemplateName: plannedWorkout.sourceTemplate?.name,
                                        plannedExercises: plannedWorkout.orderedPlannedExercises.map { plannedExercise in
                                            PlannedExerciseDTO(
                                                id: plannedExercise.id.uuidString,
                                                exerciseName: plannedExercise.exercise.name,
                                                orderIndex: plannedExercise.orderIndex,
                                                role: plannedExercise.role.rawValue,
                                                isOptional: plannedExercise.isOptional,
                                                targetSets: plannedExercise.targetSets,
                                                repRangeMinimum: plannedExercise.repRangeMinimum,
                                                repRangeMaximum: plannedExercise.repRangeMaximum,
                                                suggestedLoad: plannedExercise.suggestedLoad,
                                                suggestedLoadType: plannedExercise.suggestedLoadType?.rawValue,
                                                restSeconds: plannedExercise.restSeconds,
                                                targetRPE: plannedExercise.targetRPE,
                                                targetRIR: plannedExercise.targetRIR,
                                                notes: plannedExercise.notes,
                                                progressionRule: plannedExercise.progressionRule.rawValue,
                                                stimulus: plannedExercise.resolvedStimulus.rawValue,
                                                alternativeExerciseNames: plannedExercise.alternatives
                                                    .sorted { $0.orderIndex < $1.orderIndex }
                                                    .map { $0.exercise.name },
                                                supersetGroupID: plannedExercise.supersetGroupID?.uuidString,
                                                executionBlockID: plannedExercise.executionBlockID?.uuidString,
                                                executionBlockComponentOrder: plannedExercise.executionBlockComponentOrder,
                                                plannedSets: plannedExercise.orderedPlannedSets.map { plannedSet in
                                                    PlannedSetDTO(
                                                        orderIndex: plannedSet.orderIndex,
                                                        setType: plannedSet.setType.rawValue,
                                                        repetitions: plannedSet.repetitions,
                                                        repRangeMinimum: plannedSet.repRangeMinimum,
                                                        repRangeMaximum: plannedSet.repRangeMaximum,
                                                        suggestedLoad: plannedSet.suggestedLoad,
                                                        suggestedLoadType: plannedSet.suggestedLoadType?.rawValue,
                                                        restSeconds: plannedSet.restSeconds,
                                                        targetRPE: plannedSet.targetRPE,
                                                        targetRIR: plannedSet.targetRIR,
                                                        tempo: plannedSet.tempo,
                                                        progressionEligible: plannedSet.progressionEligible,
                                                        isOptional: plannedSet.isOptional,
                                                        notes: plannedSet.notes,
                                                        definitionData: plannedSet.definitionData
                                                    )
                                                },
                                                progressionKey: plannedExercise.progressionKey,
                                                progressionRulesData: plannedExercise.progressionRulesData,
                                                progressionWavesData: plannedExercise.progressionWavesData,
                                                progressionStagesData: plannedExercise.progressionStagesData,
                                                variationLadderData: plannedExercise.variationLadderData,
                                                initialVariationExerciseID: plannedExercise.initialVariationExerciseID?.uuidString,
                                                initialVelocityBaseline: plannedExercise.initialVelocityBaseline,
                                                initialTrainingMax: plannedExercise.initialTrainingMax,
                                                initialEstimatedOneRepMax: plannedExercise.initialEstimatedOneRepMax,
                                                initialActualOneRepMax: plannedExercise.initialActualOneRepMax,
                                                automaticDeloadVolumeReductionPercent: plannedExercise.automaticDeloadVolumeReductionPercent,
                                                automaticDeloadIntensityReductionPercent: plannedExercise.automaticDeloadIntensityReductionPercent,
                                                warmupSchemeData: plannedExercise.warmupSchemeData
                                            )
                                        },
                                        executionBlocks: plannedWorkout.orderedExecutionBlocks.map { block in
                                            PlannedExerciseBlockDTO(
                                                id: block.id.uuidString,
                                                orderIndex: block.orderIndex,
                                                kind: block.kind.rawValue,
                                                name: block.name,
                                                targetRounds: block.targetRounds,
                                                isSharedLoad: block.isSharedLoad,
                                                restSeconds: block.restSeconds,
                                                clockMode: block.clockMode.rawValue,
                                                prescribedDurationSeconds: block.prescribedDurationSeconds,
                                                timeCapSeconds: block.timeCapSeconds,
                                                intervalSeconds: block.intervalSeconds,
                                                scoreKind: block.scoreKind.rawValue,
                                                repetitionScheme: block.repetitionScheme.rawValue,
                                                repetitionStart: block.repetitionStart,
                                                repetitionEnd: block.repetitionEnd,
                                                repetitionStep: block.repetitionStep,
                                                sourceTemplateBlockID: block.sourceTemplateBlockID?.uuidString,
                                                definitionBlockKey: block.definitionBlockKey
                                            )
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            )
        }

        let planRuns = try context.fetch(FetchDescriptor<PlanRun>())
        let planRunDTOs = planRuns.map { run in
            PlanRunDTO(
                id: run.id.uuidString,
                sourcePlanID: run.sourcePlanID.uuidString,
                sourcePlanName: run.sourcePlanName,
                planID: run.plan?.id.uuidString,
                startDate: run.startDate,
                endDate: run.endDate,
                status: run.status.rawValue,
                currentWeekIndex: run.currentWeekIndex,
                currentWorkoutIndex: run.currentWorkoutIndex,
                endedProgressionKeysData: run.endedProgressionKeysData,
                createdAt: run.createdAt,
                updatedAt: run.updatedAt,
                workoutProgress: run.orderedWorkoutProgress.map { progress in
                    PlanWorkoutProgressDTO(
                        id: progress.id.uuidString,
                        plannedWorkoutID: progress.plannedWorkoutID.uuidString,
                        plannedWorkoutName: progress.plannedWorkoutName,
                        weekIndex: progress.weekIndex,
                        sourceWeekIndex: progress.sourceWeekIndex,
                        workoutIndex: progress.workoutIndex,
                        scheduledDate: progress.scheduledDate,
                        status: progress.status.rawValue,
                        startedAt: progress.startedAt,
                        completedAt: progress.completedAt,
                        skipReason: progress.skipReason,
                        completedWorkoutID: progress.completedWorkout?.id.uuidString
                    )
                },
                progressionStates: run.orderedProgressionStates.map { state in
                    ProgressionStateDTO(
                        id: state.id.uuidString,
                        progressionKey: state.progressionKey,
                        scope: state.scopeRaw,
                        scopeOwnerKey: state.scopeOwnerKey,
                        currentLoad: state.currentLoad,
                        currentLoadType: state.currentLoadType?.rawValue,
                        repetitionOffset: state.repetitionOffset,
                        setCountOffset: state.setCountOffset,
                        durationOffset: state.durationOffset,
                        distanceOffset: state.distanceOffset,
                        restDurationOffset: state.restDurationOffset,
                        caloriesOffset: state.caloriesOffset,
                        actualOneRepMax: state.actualOneRepMax,
                        currentStageID: state.currentStageID,
                        currentVariationExerciseID: state.currentVariationExerciseID?.uuidString,
                        trainingMax: state.trainingMax,
                        estimatedOneRepMax: state.estimatedOneRepMax,
                        failureCount: state.failureCount,
                        successCount: state.successCount,
                        currentWaveIndex: state.currentWaveIndex,
                        currentBlockIndex: state.currentBlockIndex,
                        previousAMRAPRepetitions: state.previousAMRAPRepetitions,
                        previousActualRPE: state.previousActualRPE,
                        previousActualRIR: state.previousActualRIR,
                        velocityBaseline: state.velocityBaseline,
                        lastCompletedOccurrence: state.lastCompletedOccurrence,
                        lastSuccessfulLoad: state.lastSuccessfulLoad,
                        isDeloading: state.isDeloading,
                        lastAppliedOutcomeID: state.lastAppliedOutcomeID?.uuidString,
                        lastAppliedSetID: state.lastAppliedSetID?.uuidString,
                        appliedProgressionEventsData: state.appliedProgressionEventsData,
                        pendingProgressionData: state.pendingProgressionData
                    )
                }
            )
        }

        let programDefinitionDTOs = try context.fetch(FetchDescriptor<ProgramDefinitionRecord>()).map { record in
            ProgramDefinitionDTO(
                id: record.id.uuidString,
                schemaVersion: record.schemaVersion,
                templateVersion: record.templateVersion,
                name: record.name,
                summary: record.summary,
                goal: record.goal.rawValue,
                experienceLevel: record.experienceLevel.rawValue,
                durationWeeks: record.durationWeeks,
                supportedDaysPerWeek: record.supportedDaysPerWeek,
                isBuiltIn: record.isBuiltIn,
                isArchived: record.isArchived,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                definitionData: record.definitionData
            )
        }
        let progressionRecommendationDTOs = try context.fetch(FetchDescriptor<PlanProgressionRecommendationRecord>()).map { record in
            ProgressionRecommendationDTO(
                id: record.id.uuidString,
                planRunID: record.planRunID.uuidString,
                workoutID: record.workoutID.uuidString,
                progressionKey: record.progressionKey,
                ruleID: record.ruleID.uuidString,
                actionData: record.actionData,
                cadence: record.cadence.rawValue,
                scope: record.scope.rawValue,
                scopeOwnerKey: record.scopeOwnerKey,
                reason: record.reason,
                applicationMode: record.applicationMode.rawValue,
                performanceData: record.performanceData,
                proposedLoad: record.proposedLoad,
                proposedTrainingMax: record.proposedTrainingMax,
                proposedEstimatedOneRepMax: record.proposedEstimatedOneRepMax,
                proposedActualOneRepMax: record.proposedActualOneRepMax,
                proposedStageID: record.proposedStageID,
                proposedVariationExerciseID: record.proposedVariationExerciseID?.uuidString,
                proposedRepetitionOffset: record.proposedRepetitionOffset,
                proposedSetCountOffset: record.proposedSetCountOffset,
                proposedDurationOffset: record.proposedDurationOffset,
                proposedDistanceOffset: record.proposedDistanceOffset,
                proposedRestDurationOffset: record.proposedRestDurationOffset,
                proposedCaloriesOffset: record.proposedCaloriesOffset,
                proposedWaveIndex: record.proposedWaveIndex,
                proposedBlockIndex: record.proposedBlockIndex,
                proposedIsDeloading: record.proposedIsDeloading,
                createdAt: record.createdAt,
                isResolved: record.isResolved,
                resolvedAt: record.resolvedAt
            )
        }

        let dailyLogEntryDTOs = try context.fetch(FetchDescriptor<DailyLogEntry>()).map { entry in
            DailyLogEntryDTO(
                id: entry.id.uuidString,
                dayKey: entry.dayKey,
                status: entry.status.rawValue,
                sleepQuality: entry.sleepQuality,
                energy: entry.energy,
                workoutDifficulty: entry.workoutDifficulty,
                note: entry.note,
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt
            )
        }
        let bodyWeightEntryDTOs = try context.fetch(FetchDescriptor<BodyWeightEntry>()).map { entry in
            BodyWeightEntryDTO(
                id: entry.id.uuidString,
                dayKey: entry.dayKey,
                value: entry.value,
                unit: entry.unit.rawValue,
                source: entry.source.rawValue,
                measuredAt: entry.measuredAt,
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt
            )
        }
        let supplementOccurrenceDTOs = try context.fetch(FetchDescriptor<SupplementOccurrence>()).map { occurrence in
            SupplementOccurrenceDTO(
                id: occurrence.id.uuidString,
                occurrenceKey: occurrence.occurrenceKey,
                dayKey: occurrence.dayKey,
                kind: occurrence.kind.rawValue,
                status: occurrence.status.rawValue,
                completedAt: occurrence.completedAt,
                createdAt: occurrence.createdAt,
                updatedAt: occurrence.updatedAt
            )
        }
        let mobilityFamilyDTOs = try context.fetch(FetchDescriptor<MobilityFamily>()).map {
            MobilityFamilyDTO(id: $0.id.uuidString, name: $0.name, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        let mobilityDefinitionDTOs = try context.fetch(FetchDescriptor<MobilityDefinition>()).map { definition in
            MobilityDefinitionDTO(
                id: definition.id.uuidString,
                name: definition.name,
                instructions: definition.instructions,
                trackingType: definition.trackingType.rawValue,
                defaultDurationSeconds: definition.defaultDurationSeconds,
                defaultRepetitions: definition.defaultRepetitions,
                isFavorite: definition.isFavorite,
                isCustom: definition.isCustom,
                isArchived: definition.isArchived,
                familyID: definition.family?.id.uuidString,
                createdAt: definition.createdAt,
                updatedAt: definition.updatedAt
            )
        }
        let mobilityRoutineDTOs = try context.fetch(FetchDescriptor<MobilityRoutine>()).map { routine in
            MobilityRoutineDTO(
                id: routine.id.uuidString,
                name: routine.name,
                notes: routine.notes,
                isArchived: routine.isArchived,
                createdAt: routine.createdAt,
                updatedAt: routine.updatedAt,
                items: routine.orderedItems.map { item in
                    MobilityRoutineItemDTO(
                        id: item.id.uuidString,
                        definitionID: item.definition.id.uuidString,
                        orderIndex: item.orderIndex,
                        targetDurationSeconds: item.targetDurationSeconds,
                        targetRepetitions: item.targetRepetitions,
                        side: item.side.rawValue,
                        restSeconds: item.restSeconds,
                        notes: item.notes
                    )
                }
            )
        }
        let mobilitySessionDTOs = try context.fetch(FetchDescriptor<MobilitySession>()).map { session in
            MobilitySessionDTO(
                id: session.id.uuidString,
                status: session.status.rawValue,
                nameSnapshot: session.nameSnapshot,
                sourceRoutineID: session.sourceRoutineID?.uuidString,
                sourceRoutineName: session.sourceRoutineName,
                workoutID: session.workoutID?.uuidString,
                context: session.context.rawValue,
                startTime: session.startTime,
                endTime: session.endTime,
                currentEntryIndex: session.currentEntryIndex,
                createdAt: session.createdAt,
                updatedAt: session.updatedAt,
                entries: session.orderedEntries.map { entry in
                    MobilityEntryDTO(
                        id: entry.id.uuidString,
                        orderIndex: entry.orderIndex,
                        definitionIDSnapshot: entry.definitionIDSnapshot.uuidString,
                        definitionNameSnapshot: entry.definitionNameSnapshot,
                        instructionsSnapshot: entry.instructionsSnapshot,
                        trackingType: entry.trackingType.rawValue,
                        targetDurationSeconds: entry.targetDurationSeconds,
                        targetRepetitions: entry.targetRepetitions,
                        side: entry.side.rawValue,
                        restSeconds: entry.restSeconds,
                        notesSnapshot: entry.notesSnapshot,
                        timerStartedAt: entry.timerStartedAt,
                        results: entry.orderedResults.map { result in
                            MobilityResultDTO(
                                id: result.id.uuidString,
                                side: result.side.rawValue,
                                status: result.status.rawValue,
                                prescribedDurationSeconds: result.prescribedDurationSeconds,
                                prescribedRepetitions: result.prescribedRepetitions,
                                performedDurationSeconds: result.performedDurationSeconds,
                                performedRepetitions: result.performedRepetitions,
                                perceivedIntensity: result.perceivedIntensity,
                                discomfortNote: result.discomfortNote,
                                startedAt: result.startedAt,
                                completedAt: result.completedAt
                            )
                        }
                    )
                }
            )
        }
        let foodDTOs = try context.fetch(FetchDescriptor<FoodItem>()).map { food in
            FoodItemDTO(
                id: food.id.uuidString,
                name: food.name,
                referenceAmount: food.referenceAmount,
                referenceUnit: food.referenceUnit.rawValue,
                calories: food.calories,
                proteinGrams: food.proteinGrams,
                carbohydrateGrams: food.carbohydrateGrams,
                fatGrams: food.fatGrams,
                caffeineMilligrams: food.caffeineMilligrams,
                npn: food.npn,
                sourceKind: food.sourceKind.rawValue,
                confidence: food.confidence.rawValue,
                preparationState: food.preparationState.rawValue,
                isFavorite: food.isFavorite,
                isArchived: food.isArchived,
                createdAt: food.createdAt,
                updatedAt: food.updatedAt,
                servings: food.orderedServings.map {
                    FoodServingDTO(id: $0.id.uuidString, name: $0.name, amount: $0.amount, unit: $0.unit.rawValue, equivalentReferenceAmount: $0.equivalentReferenceAmount)
                }
            )
        }
        let mealTemplateDTOs = try context.fetch(FetchDescriptor<MealTemplate>()).map { template in
            MealTemplateDTO(
                id: template.id.uuidString,
                lineageID: template.lineageID.uuidString,
                version: template.version,
                name: template.name,
                preparationState: template.preparationState.rawValue,
                finalCookedWeightGrams: template.finalCookedWeightGrams,
                isCurrent: template.isCurrent,
                isArchived: template.isArchived,
                createdAt: template.createdAt,
                updatedAt: template.updatedAt,
                items: template.orderedItems.map {
                    MealTemplateItemDTO(id: $0.id.uuidString, foodID: $0.food.id.uuidString, orderIndex: $0.orderIndex, servingID: $0.servingID?.uuidString, quantity: $0.quantity)
                }
            )
        }
        let loggedMealDTOs = try context.fetch(FetchDescriptor<LoggedMeal>()).map { meal in
            LoggedMealDTO(
                id: meal.id.uuidString,
                dayKey: meal.dayKey,
                slot: meal.slot.rawValue,
                loggedAt: meal.loggedAt,
                nameSnapshot: meal.nameSnapshot,
                sourceMealTemplateID: meal.sourceMealTemplateID?.uuidString,
                sourceMealTemplateName: meal.sourceMealTemplateName,
                createdAt: meal.createdAt,
                updatedAt: meal.updatedAt,
                items: meal.orderedItems.map {
                    LoggedMealItemDTO(
                        id: $0.id.uuidString,
                        orderIndex: $0.orderIndex,
                        sourceFoodID: $0.sourceFoodID?.uuidString,
                        foodNameSnapshot: $0.foodNameSnapshot,
                        servingNameSnapshot: $0.servingNameSnapshot,
                        quantity: $0.quantity,
                        portionAmountSnapshot: $0.portionAmountSnapshot,
                        portionUnit: $0.portionUnit.rawValue,
                        caloriesSnapshot: $0.caloriesSnapshot,
                        proteinGramsSnapshot: $0.proteinGramsSnapshot,
                        carbohydrateGramsSnapshot: $0.carbohydrateGramsSnapshot,
                        fatGramsSnapshot: $0.fatGramsSnapshot,
                        caffeineMilligramsSnapshot: $0.caffeineMilligramsSnapshot,
                        sourceKind: $0.sourceKindRaw,
                        confidence: $0.confidenceRaw,
                        preparationState: $0.preparationStateRaw
                    )
                }
            )
        }
        let nutritionTargetDTOs = try context.fetch(FetchDescriptor<NutritionTarget>()).map { target in
            NutritionTargetDTO(
                id: target.id.uuidString,
                phase: target.phase.rawValue,
                effectiveStartDayKey: target.effectiveStartDayKey,
                effectiveEndDayKey: target.effectiveEndDayKey,
                trainingCalories: target.trainingCalories,
                trainingProteinGrams: target.trainingProteinGrams,
                trainingCarbohydrateGrams: target.trainingCarbohydrateGrams,
                trainingFatGrams: target.trainingFatGrams,
                restCalories: target.restCalories,
                restProteinGrams: target.restProteinGrams,
                restCarbohydrateGrams: target.restCarbohydrateGrams,
                restFatGrams: target.restFatGrams,
                isArchived: target.isArchived,
                createdAt: target.createdAt,
                updatedAt: target.updatedAt
            )
        }

        return BackupDTO(
            version: currentVersion,
            preferences: PreferencesDTO(
                darkMode: darkMode,
                restTimer: restTimer,
                unitSystem: unitSystem.rawValue,
                bodyWeightPromptCadence: UserDefaults.standard.string(forKey: DefaultsKey.bodyWeightPromptCadence),
                birthdateTimestamp: UserDefaults.standard.object(forKey: DefaultsKey.caffeineBirthdateTimestamp) as? Double
            ),
            exercises: exerciseDTOs,
            templates: templateDTOs,
            collections: collectionDTOs,
            workouts: workoutDTOs,
            plans: planDTOs,
            planRuns: planRunDTOs,
            exerciseRelationships: relationshipDTOs,
            programDefinitions: programDefinitionDTOs,
            progressionRecommendations: progressionRecommendationDTOs,
            dailyLogEntries: dailyLogEntryDTOs,
            bodyWeightEntries: bodyWeightEntryDTOs,
            supplementOccurrences: supplementOccurrenceDTOs,
            mobilityFamilies: mobilityFamilyDTOs,
            mobilityDefinitions: mobilityDefinitionDTOs,
            mobilityRoutines: mobilityRoutineDTOs,
            mobilitySessions: mobilitySessionDTOs,
            foods: foodDTOs,
            mealTemplates: mealTemplateDTOs,
            loggedMeals: loggedMealDTOs,
            nutritionTargets: nutritionTargetDTOs
        )
    }
}
