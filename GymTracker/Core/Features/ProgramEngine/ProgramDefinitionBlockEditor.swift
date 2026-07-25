import SwiftUI

#if !GYMTRACKER_EXTENSION

struct ProgramDefinitionBlockEditor: View {
    @Binding var block: ProgramBlockDefinition
    let exercises: [Exercise]
    let availableExposureKeys: [String]
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                TextField("Phase name", text: $block.name)
                    .font(AppFont.subheadlineSemibold)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: AppIcon.trash)
                }
                .accessibilityLabel("Delete phase")
            }

            Picker("Phase", selection: $block.phaseType) {
                ForEach(PlanPhaseType.allCases, id: \.self) { phase in
                    Text(phase.title).tag(phase)
                }
            }

            if block.phaseType == .deload {
                Stepper(
                    "Reduce sets by \(block.deloadVolumeReductionPercent ?? 50)%",
                    value: Binding(
                        get: { block.deloadVolumeReductionPercent ?? 50 },
                        set: { block.deloadVolumeReductionPercent = $0 }
                    ),
                    in: 0...90
                )
                Stepper(
                    "Reduce load by \(block.deloadIntensityReductionPercent ?? 10)%",
                    value: Binding(
                        get: { block.deloadIntensityReductionPercent ?? 10 },
                        set: { block.deloadIntensityReductionPercent = $0 }
                    ),
                    in: 0...90
                )
            } else {
                Text("\(block.weeks.count) weeks")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }

            ForEach($block.weeks) { $week in
                ProgramDefinitionWeekEditor(
                    week: $week,
                    exercises: exercises,
                    availableExposureKeys: availableExposureKeys
                ) {
                    removeWeek(week.id)
                }
            }
            .onMove { source, destination in
                block.weeks.move(fromOffsets: source, toOffset: destination)
                normalizeWeeks()
            }

            Button("Add week", systemImage: AppIcon.plus) {
                addWeek()
            }
            .font(AppFont.captionBold)
        }
        .padding(.vertical, Spacing.xs)
    }

    private func addWeek() {
        let index = block.weeks.count
        block.weeks.append(
            ProgramWeekDefinition(
                weekIndex: index,
                name: nil,
                workouts: [
                    ProgramWorkoutDefinition(
                        orderIndex: 0,
                        name: "Workout \(index + 1)",
                        dayOffset: 0,
                        plannedExercises: []
                    )
                ]
            )
        )
    }

    private func removeWeek(_ id: UUID) {
        block.weeks.removeAll { $0.id == id }
        if block.weeks.isEmpty { addWeek() }
        normalizeWeeks()
    }

    private func normalizeWeeks() {
        for index in block.weeks.indices {
            block.weeks[index].weekIndex = index
        }
    }
}

struct ProgramDefinitionWeekEditor: View {
    @Binding var week: ProgramWeekDefinition
    let exercises: [Exercise]
    let availableExposureKeys: [String]
    let onDelete: () -> Void

    var body: some View {
        DisclosureGroup {
            TextField("Week name", text: optionalNameBinding)
            ForEach($week.workouts) { $workout in
                ProgramDefinitionWorkoutEditor(
                    workout: $workout,
                    exercises: exercises,
                    availableExposureKeys: availableExposureKeys
                ) {
                    removeWorkout(workout.id)
                }
            }
            .onMove { source, destination in
                week.workouts.move(fromOffsets: source, toOffset: destination)
                normalizeWorkouts()
            }
            Button("Add workout", systemImage: AppIcon.plus) {
                addWorkout()
            }
            Button("Delete week", role: .destructive, action: onDelete)
        } label: {
            Text("Week \(week.weekIndex + 1)")
                .font(AppFont.subheadlineSemibold)
        }
    }

    private var optionalNameBinding: Binding<String> {
        Binding(
            get: { week.name ?? "" },
            set: { week.name = $0.isEmpty ? nil : $0 }
        )
    }

    private func addWorkout() {
        let index = week.workouts.count
        week.workouts.append(
            ProgramWorkoutDefinition(
                orderIndex: index,
                name: "Workout \(index + 1)",
                dayOffset: index % 7,
                plannedExercises: []
            )
        )
    }

    private func removeWorkout(_ id: UUID) {
        week.workouts.removeAll { $0.id == id }
        if week.workouts.isEmpty { addWorkout() }
        normalizeWorkouts()
    }

    private func normalizeWorkouts() {
        for index in week.workouts.indices {
            week.workouts[index].orderIndex = index
        }
    }
}

struct ProgramDefinitionWorkoutEditor: View {
    @Binding var workout: ProgramWorkoutDefinition
    let exercises: [Exercise]
    let availableExposureKeys: [String]
    let onDelete: () -> Void

    var body: some View {
        DisclosureGroup {
            TextField("Workout name", text: $workout.name)
            Stepper("Day \(workout.dayOffset + 1)", value: $workout.dayOffset, in: 0...6)
            TextField("Role", text: $workout.role)
            Toggle("Optional session", isOn: $workout.isOptional)

            ForEach($workout.plannedExercises) { $exercise in
                ProgramDefinitionExerciseEditor(
                    exercise: $exercise,
                    exercises: exercises,
                    availableExposureKeys: availableExposureKeys
                ) {
                    removeExercise(exercise.id)
                }
            }
            .onMove { source, destination in
                workout.plannedExercises.move(fromOffsets: source, toOffset: destination)
                normalizeExercises()
            }

            Button("Add exercise", systemImage: AppIcon.plus) {
                addExercise()
            }
            Button("Delete workout", role: .destructive, action: onDelete)
        } label: {
            HStack {
                Text(workout.name.isEmpty ? "Workout" : workout.name)
                    .font(AppFont.subheadlineSemibold)
                Spacer()
                Text("Day \(workout.dayOffset + 1)")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
    }

    private func addExercise() {
        guard let first = exercises.first else { return }
        let index = workout.plannedExercises.count
        workout.plannedExercises.append(
            ProgramExerciseDefinition(
                exerciseID: first.id,
                exposureKey: "\(first.name.lowercased().replacingOccurrences(of: " ", with: "-"))-\(index + 1)",
                orderIndex: index,
                plannedSets: [
                    SetPrescriptionDefinition(
                        orderIndex: 0,
                        repetitions: .fixed(8),
                        load: LoadPrescription(reference: LoadReference(kind: .manual)),
                        restSeconds: 90
                    )
                ]
            )
        )
    }

    private func removeExercise(_ id: UUID) {
        workout.plannedExercises.removeAll { $0.id == id }
        if workout.plannedExercises.isEmpty, let first = exercises.first {
            workout.plannedExercises.append(
                ProgramExerciseDefinition(
                    exerciseID: first.id,
                    exposureKey: "\(first.name.lowercased().replacingOccurrences(of: " ", with: "-"))-1",
                    orderIndex: 0,
                    plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(8))]
                )
            )
        }
        normalizeExercises()
    }

    private func normalizeExercises() {
        for index in workout.plannedExercises.indices {
            workout.plannedExercises[index].orderIndex = index
        }
    }
}

#endif
