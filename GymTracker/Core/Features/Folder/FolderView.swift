//
//  FolderView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI
import SwiftData


struct FolderView : View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutPlans: [WorkoutPlan]
    @Query private var workoutTemplates: [WorkoutTemplate]
    @Query private var exerciceTemplates: [ExerciceTemplate]

    @State private var activeSheet: FolderSheet?

    var body: some View {
        List {
            Section("Workout Plans") {
                if workoutPlans.isEmpty {
                    Text("No workout plans")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workoutPlans) { plan in
                        NavigationLink {
                            WorkoutPlanDetailView(plan: plan)
                        } label: {
                            FolderRow(
                                title: plan.name,
                                subtitle: "\(plan.workoutTemplates.count) templates",
                                systemImage: "calendar"
                            )
                        }
                    }
                }
            }

            Section("Workout Templates") {
                if workoutTemplates.isEmpty {
                    Text("No workout templates")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workoutTemplates, id: \.self) { template in
                        NavigationLink {
                            WorkoutTemplateDetailView(template: template)
                        } label: {
                            FolderRow(
                                title: template.name,
                                subtitle: "\(template.exercises.count) exercises",
                                systemImage: "list.bullet.rectangle"
                            )
                        }
                    }
                }
            }

            Section("Exercises") {
                if exerciceTemplates.isEmpty {
                    Text("No exercises")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(exerciceTemplates, id: \.self) { exercice in
                        NavigationLink {
                            ExerciceView(exercice: exercice)
                        } label: {
                            FolderRow(
                                title: exercice.name,
                                subtitle: exercice.trackingType.rawValue,
                                systemImage: "figure.strengthtraining.traditional"
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Folders")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Workout Plan", systemImage: "calendar.badge.plus") {
                        activeSheet = .workoutPlan
                    }

                    Button("Workout Template", systemImage: "list.bullet.rectangle.portrait") {
                        activeSheet = .workoutTemplate
                    }

                    Button("Exercise", systemImage: "figure.strengthtraining.traditional") {
                        activeSheet = .exercise
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .workoutPlan:
                    WorkoutPlanFormView(availableTemplates: workoutTemplates) { name, templates in
                        modelContext.insert(WorkoutPlan(name: name, workoutTemplates: templates))
                        saveModelContext(modelContext)
                    }
                case .workoutTemplate:
                    WorkoutTemplateFormView(availableExercises: exerciceTemplates) { name, exercises in
                        modelContext.insert(WorkoutTemplate(name: name, exercises: exercises))
                        saveModelContext(modelContext)
                    }
                case .exercise:
                    ExerciseFormView { exercise in
                        modelContext.insert(exercise)
                        saveModelContext(modelContext)
                    }
                }
            }
        }
    }
}

private enum FolderSheet: String, Identifiable {
    case workoutPlan
    case workoutTemplate
    case exercise

    var id: String { rawValue }
}

private struct FolderRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
        }
    }
}

private struct WorkoutPlanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var availableTemplates: [WorkoutTemplate]

    let plan: WorkoutPlan

    @State private var isShowingTemplatePicker = false

    var body: some View {
        List {
            Section("Templates") {
                if plan.workoutTemplates.isEmpty {
                    Text("No templates in this plan")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(plan.workoutTemplates, id: \.self) { template in
                        NavigationLink {
                            WorkoutTemplateDetailView(template: template)
                        } label: {
                            FolderRow(
                                title: template.name,
                                subtitle: "\(template.exercises.count) exercises",
                                systemImage: "list.bullet.rectangle"
                            )
                        }
                    }
                    .onDelete(perform: removeTemplates)
                }
            }
        }
        .navigationTitle(plan.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingTemplatePicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(templatesToAdd.isEmpty)
            }
        }
        .sheet(isPresented: $isShowingTemplatePicker) {
            NavigationStack {
                TemplatePickerView(templates: templatesToAdd) { template in
                    addTemplate(template)
                }
            }
        }
    }

    private var templatesToAdd: [WorkoutTemplate] {
        availableTemplates.filter { template in
            !plan.workoutTemplates.contains {
                $0.persistentModelID == template.persistentModelID
            }
        }
    }

    private func addTemplate(_ template: WorkoutTemplate) {
        guard !plan.workoutTemplates.contains(where: {
            $0.persistentModelID == template.persistentModelID
        }) else {
            return
        }

        plan.workoutTemplates.append(template)
        saveModelContext(modelContext)
    }

    private func removeTemplates(at offsets: IndexSet) {
        plan.workoutTemplates.remove(atOffsets: offsets)
        saveModelContext(modelContext)
    }
}

private struct WorkoutTemplateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var availableExercises: [ExerciceTemplate]

    let template: WorkoutTemplate

    @State private var isShowingExercisePicker = false

    var body: some View {
        List {
            Section("Exercises") {
                if template.exercises.isEmpty {
                    Text("No exercises in this template")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(template.exercises, id: \.self) { exercice in
                        NavigationLink {
                            ExerciceView(exercice: exercice)
                        } label: {
                            FolderRow(
                                title: exercice.name,
                                subtitle: exercice.trackingType.rawValue,
                                systemImage: "figure.strengthtraining.traditional"
                            )
                        }
                    }
                    .onDelete(perform: removeExercises)
                }
            }
        }
        .navigationTitle(template.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingExercisePicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(exercisesToAdd.isEmpty)
            }
        }
        .sheet(isPresented: $isShowingExercisePicker) {
            NavigationStack {
                ExercisePickerView(exercises: exercisesToAdd) { exercise in
                    addExercise(exercise)
                }
            }
        }
    }

    private var exercisesToAdd: [ExerciceTemplate] {
        availableExercises.filter { exercise in
            !template.exercises.contains {
                $0.persistentModelID == exercise.persistentModelID
            }
        }
    }

    private func addExercise(_ exercise: ExerciceTemplate) {
        guard !template.exercises.contains(where: {
            $0.persistentModelID == exercise.persistentModelID
        }) else {
            return
        }

        template.exercises.append(exercise)
        saveModelContext(modelContext)
    }

    private func removeExercises(at offsets: IndexSet) {
        template.exercises.remove(atOffsets: offsets)
        saveModelContext(modelContext)
    }
}

private struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let templates: [WorkoutTemplate]
    let onSelect: (WorkoutTemplate) -> Void

    @State private var addedTemplateIDs: Set<ObjectIdentifier> = []

    var body: some View {
        List {
            if templates.isEmpty {
                Text("No templates to add")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(templates, id: \.self) { template in
                    let isAdded = addedTemplateIDs.contains(ObjectIdentifier(template))

                    Button {
                        addedTemplateIDs.insert(ObjectIdentifier(template))
                        onSelect(template)
                    } label: {
                        HStack {
                            FolderRow(
                                title: template.name,
                                subtitle: "\(template.exercises.count) exercises",
                                systemImage: "list.bullet.rectangle"
                            )

                            Spacer()

                            if isAdded {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            } else {
                                Text("Add")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isAdded)
                }
            }
        }
        .navigationTitle("Add Template")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let exercises: [ExerciceTemplate]
    let onSelect: (ExerciceTemplate) -> Void

    @State private var addedExerciseIDs: Set<ObjectIdentifier> = []

    var body: some View {
        List {
            if exercises.isEmpty {
                Text("No exercises to add")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(exercises, id: \.self) { exercise in
                    let isAdded = addedExerciseIDs.contains(ObjectIdentifier(exercise))

                    Button {
                        addedExerciseIDs.insert(ObjectIdentifier(exercise))
                        onSelect(exercise)
                    } label: {
                        HStack {
                            FolderRow(
                                title: exercise.name,
                                subtitle: exercise.trackingType.rawValue,
                                systemImage: "figure.strengthtraining.traditional"
                            )

                            Spacer()

                            if isAdded {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            } else {
                                Text("Add")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isAdded)
                }
            }
        }
        .navigationTitle("Add Exercise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct WorkoutPlanFormView: View {
    @Environment(\.dismiss) private var dismiss

    let availableTemplates: [WorkoutTemplate]
    let onSave: (String, [WorkoutTemplate]) -> Void

    @State private var name = ""
    @State private var selectedTemplateNames: Set<String> = []

    var body: some View {
        Form {
            Section("Plan") {
                TextField("Name", text: $name)
            }

            Section("Templates") {
                if availableTemplates.isEmpty {
                    Text("Create a workout template first")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableTemplates, id: \.self) { template in
                        SelectionRow(
                            title: template.name,
                            isSelected: selectedTemplateNames.contains(template.name)
                        ) {
                            toggle(template.name, in: &selectedTemplateNames)
                        }
                    }
                }
            }
        }
        .navigationTitle("New Plan")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    onSave(trimmedName, selectedTemplates)
                    dismiss()
                }
                .disabled(trimmedName.isEmpty)
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedTemplates: [WorkoutTemplate] {
        availableTemplates.filter { selectedTemplateNames.contains($0.name) }
    }
}

private struct WorkoutTemplateFormView: View {
    @Environment(\.dismiss) private var dismiss

    let availableExercises: [ExerciceTemplate]
    let onSave: (String, [ExerciceTemplate]) -> Void

    @State private var name = ""
    @State private var selectedExerciseNames: Set<String> = []

    var body: some View {
        Form {
            Section("Template") {
                TextField("Name", text: $name)
            }

            Section("Exercises") {
                if availableExercises.isEmpty {
                    Text("Create an exercise first")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableExercises, id: \.self) { exercise in
                        ExerciseSelectionRow(
                            exercise: exercise,
                            isSelected: selectedExerciseNames.contains(exercise.name)
                        ) {
                            toggle(exercise.name, in: &selectedExerciseNames)
                        }
                    }
                }
            }
        }
        .navigationTitle("New Template")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    onSave(trimmedName, selectedExercises)
                    dismiss()
                }
                .disabled(trimmedName.isEmpty)
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedExercises: [ExerciceTemplate] {
        availableExercises.filter { selectedExerciseNames.contains($0.name) }
    }
}

private struct ExerciseSelectionRow: View {
    let exercise: ExerciceTemplate
    let isSelected: Bool
    let onSelect: () -> Void
    private let exerciseDetail: ExerciceDetailSnapshot

    init(exercise: ExerciceTemplate, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.exercise = exercise
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.exerciseDetail = ExerciceDetailSnapshot(exercice: exercise)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onSelect()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .foregroundStyle(.primary)
                        Text(exercise.trackingType.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            NavigationLink {
                ExerciceView(exercice: exerciseDetail)
            } label: {
                Image(systemName: "info.circle")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ExerciseFormView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (ExerciceTemplate) -> Void

    @State private var name = ""
    @State private var category: ExerciseCategory = .strength
    @State private var trackingType: TrackingType = .weightAndReps
    @State private var primaryMuscles: Set<Muscle> = [.middleChest]
    @State private var secondaryMuscles: Set<Muscle> = []
    @State private var difficulty: Difficulty = .beginner

    var body: some View {
        Form {
            Section("Exercise") {
                TextField("Name", text: $name)

                Picker("Category", selection: $category) {
                    ForEach(ExerciseCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }

                Picker("Tracking", selection: $trackingType) {
                    ForEach(TrackingType.allCases, id: \.self) { trackingType in
                        Text(trackingType.rawValue).tag(trackingType)
                    }
                }

                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { difficulty in
                        Text(difficulty.rawValue).tag(difficulty)
                    }
                }
            }

            MuscleSelectionSection(
                title: "Primary Muscles",
                selectedMuscles: primaryMuscles,
                onSelect: togglePrimaryMuscle
            )

            MuscleSelectionSection(
                title: "Secondary Muscles",
                selectedMuscles: secondaryMuscles,
                onSelect: toggleSecondaryMuscle
            )
        }
        .navigationTitle("New Exercise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    onSave(newExercise)
                    dismiss()
                }
                .disabled(trimmedName.isEmpty || primaryMuscles.isEmpty)
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var newExercise: ExerciceTemplate {
        ExerciceTemplate(
            name: trimmedName,
            PrimaryMuscle: sortedMuscles(primaryMuscles),
            SecondaryMuscle: secondaryMuscles.isEmpty ? nil : sortedMuscles(secondaryMuscles),
            category: category,
            trackingType: trackingType,
            difficulty: difficulty
        )
    }

    private func togglePrimaryMuscle(_ muscle: Muscle) {
        if primaryMuscles.contains(muscle) {
            primaryMuscles.remove(muscle)
        } else {
            primaryMuscles.insert(muscle)
            secondaryMuscles.remove(muscle)
        }
    }

    private func toggleSecondaryMuscle(_ muscle: Muscle) {
        if secondaryMuscles.contains(muscle) {
            secondaryMuscles.remove(muscle)
        } else {
            secondaryMuscles.insert(muscle)
            primaryMuscles.remove(muscle)
        }
    }

    private func sortedMuscles(_ muscles: Set<Muscle>) -> [Muscle] {
        Muscle.allCases.filter { muscles.contains($0) }
    }
}

private struct MuscleSelectionSection: View {
    let title: String
    let selectedMuscles: Set<Muscle>
    let onSelect: (Muscle) -> Void

    var body: some View {
        Section(title) {
            ForEach(Muscle.allCases, id: \.self) { muscle in
                SelectionRow(
                    title: muscle.displayName,
                    isSelected: selectedMuscles.contains(muscle)
                ) {
                    onSelect(muscle)
                }
            }
        }
    }
}

private struct SelectionRow: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
}

private func toggle(_ value: String, in selection: inout Set<String>) {
    if selection.contains(value) {
        selection.remove(value)
    } else {
        selection.insert(value)
    }
}

private func saveModelContext(_ modelContext: ModelContext) {
    do {
        try modelContext.save()
    } catch {
        print("Failed to save folder changes: \(error)")
    }
}
