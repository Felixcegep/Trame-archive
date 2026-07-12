import SwiftData
import SwiftUI

struct PlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let plan: WorkoutPlan
    @Query(filter: #Predicate<ExerciceTemplate> { !$0.isArchived }) private var exercises: [ExerciceTemplate]
    @State private var draft: PlanEditorDraft
    @State private var selectedWeekIndex: Int?
    @State private var selectedWorkoutIndex: Int?
    @State private var isShowingWorkoutEditor = false
    @State private var isShowingReview = false

    init(plan: WorkoutPlan) {
        self.plan = plan
        _draft = State(initialValue: PlanEditorDraft(plan: plan))
    }

    var body: some View {
        Form {
            Section("Plan overview") {
                TextField("Name", text: $draft.name)
                Picker("Goal", selection: $draft.goal) {
                    ForEach(PlanGoal.allCases, id: \.self) { goal in
                        Text(goal.title).tag(goal)
                    }
                }
                Picker("Experience", selection: $draft.experienceLevel) {
                    ForEach(PlanExperienceLevel.allCases, id: \.self) { level in
                        Text(level.title).tag(level)
                    }
                }
            }

            ForEach($draft.weeks) { $week in
                Section("Week \(week.weekIndex + 1)") {
                    ForEach($week.workouts) { $workout in
                        Button {
                            selectedWeekIndex = week.weekIndex
                            selectedWorkoutIndex = week.workouts.firstIndex { $0.id == workout.id }
                            isShowingWorkoutEditor = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(workout.name)
                                        .font(AppFont.subheadlineSemibold)
                                        .foregroundStyle(Color.gymText)
                                    Text("Day \(workout.dayOffset + 1) · \(workout.exercises.count) exercises")
                                        .font(AppFont.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: AppIcon.chevronRight)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Edit Plan")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    isShowingReview = true
                }
                .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("save-plan-edits")
            }
        }
        .sheet(isPresented: $isShowingWorkoutEditor) {
            if let weekIndex = selectedWeekIndex,
               let workoutIndex = selectedWorkoutIndex,
               let weekIndexInDraft = draft.weeks.firstIndex(where: { $0.weekIndex == weekIndex }) {
                NavigationStack {
                    PlanWorkoutEditorView(
                        workout: $draft.weeks[weekIndexInDraft].workouts[workoutIndex],
                        exercises: exercises
                    )
                }
            }
        }
        .sheet(isPresented: $isShowingReview) {
            NavigationStack {
                PlanReviewView(draft: draft) {
                    draft.apply(to: plan, using: modelContext)
                    saveModelContext(modelContext)
                    isShowingReview = false
                    dismiss()
                }
            }
        }
    }
}

private struct PlanReviewView: View {
    @Environment(\.dismiss) private var dismiss

    let draft: PlanEditorDraft
    let onConfirm: () -> Void

    var body: some View {
        List {
            Section {
                Label {
                    Text("These changes update future prescriptions only. Completed workouts and their recorded history are not changed.")
                        .font(AppFont.subheadline)
                } icon: {
                    Image(systemName: AppIcon.info)
                        .foregroundStyle(Color.gymPrimary)
                }
                .accessibilityIdentifier("plan-review-future-only")
            }

            Section("Schedule summary") {
                LabeledContent("Plan", value: draft.name)
                LabeledContent("Weeks", value: "\(draft.weeks.count)")
                LabeledContent("Training days", value: trainingDaysText)
            }

            if !warnings.isEmpty {
                Section("Needs attention") {
                    ForEach(warnings, id: \.self) { warning in
                        Label(warning, systemImage: AppIcon.warning)
                            .foregroundStyle(Color.gymDestructive)
                    }
                }
            }

            Section("Upcoming workouts") {
                ForEach(draft.weeks) { week in
                    DisclosureGroup("Week \(week.weekIndex + 1)") {
                        ForEach(week.workouts) { workout in
                            PlanReviewWorkoutRow(
                                workout: workout,
                                dayName: dayName(for: workout.dayOffset)
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Review Plan")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Confirm Changes") {
                    onConfirm()
                }
                .disabled(!warnings.isEmpty)
                .accessibilityIdentifier("confirm-plan-changes")
            }
        }
    }

    private var warnings: [String] {
        var results: [String] = []
        for week in draft.weeks {
            for workout in week.workouts {
                if workout.exercises.isEmpty {
                    results.append("Week \(week.weekIndex + 1), \(workout.name) needs at least one exercise.")
                }
                for exercise in workout.exercises where exercise.repRangeMinimum > exercise.repRangeMaximum {
                    results.append("\(exercise.exercise.name) has an invalid rep range.")
                }
            }
        }
        return results
    }

    private var trainingDaysText: String {
        let days = Set(draft.weeks.flatMap { $0.workouts.map(\.dayOffset) }).sorted()
        return days.map(dayName(for:)).joined(separator: ", ")
    }

    private func dayName(for offset: Int) -> String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][max(0, min(offset, 6))]
    }
}

private struct PlanReviewWorkoutRow: View {
    let workout: PlanWorkoutDraft
    let dayName: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(workout.name)
                    .font(AppFont.subheadlineSemibold)
                Spacer()
                Text(dayName)
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }

            if workout.exercises.isEmpty {
                Text("No exercises prescribed")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymDestructive)
            } else {
                ForEach(workout.exercises) { exercise in
                    PlanReviewExerciseRow(exercise: exercise)
                }
            }
        }
        .padding(.vertical, Spacing.xxs)
    }
}

private struct PlanReviewExerciseRow: View {
    let exercise: PlanExerciseDraft

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(exercise.displayName)
                .font(AppFont.captionBold)
            Text(exercise.summary)
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PlanWorkoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var workout: PlanWorkoutDraft
    let exercises: [ExerciceTemplate]
    @State private var selectedExerciseIndex: Int?
    @State private var isShowingExerciseEditor = false
    @State private var isShowingExercisePicker = false

    var body: some View {
        Form {
            Section("Workout") {
                TextField("Name", text: $workout.name)
                Stepper("Day \(workout.dayOffset + 1)", value: $workout.dayOffset, in: 0...6)
            }

            Section("Exercises") {
                if workout.exercises.isEmpty {
                    ContentUnavailableView("No exercises", systemImage: AppIcon.workout, description: Text("Add an exercise to prescribe this workout."))
                } else {
                    ForEach($workout.exercises) { $exercise in
                        Button {
                            selectedExerciseIndex = workout.exercises.firstIndex { $0.id == exercise.id }
                            isShowingExerciseEditor = true
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(exercise.displayName)
                                    .font(AppFont.subheadlineSemibold)
                                    .foregroundStyle(Color.gymText)
                                Text(exercise.summary)
                                    .font(AppFont.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { workout.exercises.remove(atOffsets: $0) }
                    .onMove { workout.exercises.move(fromOffsets: $0, toOffset: $1) }
                }

                Button("Add Exercise", systemImage: AppIcon.plus) {
                    isShowingExercisePicker = true
                }
            }
        }
        .navigationTitle(workout.name.isEmpty ? "Workout" : workout.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $isShowingExerciseEditor) {
            if let index = selectedExerciseIndex {
                NavigationStack {
                    PlanExerciseEditorView(exercise: $workout.exercises[index])
                }
            }
        }
        .sheet(isPresented: $isShowingExercisePicker) {
            NavigationStack {
                PlanExercisePickerView(exercises: exercises) { exercise in
                    workout.exercises.append(PlanExerciseDraft(exercise: exercise, orderIndex: workout.exercises.count))
                    isShowingExercisePicker = false
                }
            }
        }
    }
}

private struct PlanExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let exercises: [ExerciceTemplate]
    let onSelect: (ExerciceTemplate) -> Void
    @State private var searchText = ""

    var body: some View {
        List(filteredExercises) { exercise in
            Button {
                onSelect(exercise)
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(exercise.name)
                        .foregroundStyle(Color.gymText)
                    Text(exercise.subtitle)
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Add Exercise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private var filteredExercises: [ExerciceTemplate] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return exercises.sorted { $0.name < $1.name } }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}

private struct PlanExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var exercise: PlanExerciseDraft

    var body: some View {
        Form {
            exerciseSection
            prescriptionSection
            coachingSection
        }
        .navigationTitle("Prescription")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var exerciseSection: some View {
        Section("Exercise") {
            Text(exercise.exercise.name)
                .font(AppFont.headline)
            Picker("Role", selection: $exercise.role) {
                ForEach(ExerciseRole.allCases, id: \.self) { role in
                    Text(role.title).tag(role)
                }
            }
            Toggle("Optional exercise", isOn: $exercise.isOptional)
        }
    }

    private var prescriptionSection: some View {
        Section("Prescription") {
            Stepper("Sets: \(exercise.targetSets)", value: $exercise.targetSets, in: 1...20)
            Stepper("Minimum reps: \(exercise.repRangeMinimum)", value: $exercise.repRangeMinimum, in: 1...100)
            Stepper("Maximum reps: \(exercise.repRangeMaximum)", value: $exercise.repRangeMaximum, in: exercise.repRangeMinimum...100)
            Stepper("Rest: \(exercise.restSeconds) sec", value: $exercise.restSeconds, in: 0...600, step: 15)
            TextField("Suggested load", text: $exercise.suggestedLoadText)
                .keyboardType(.decimalPad)
            Picker("Load unit", selection: $exercise.suggestedLoadType) {
                Text("Metric (kg)").tag(WeightType.kg)
                Text("Imperial (lb)").tag(WeightType.lbs)
            }
        }
    }

    private var coachingSection: some View {
        Section("Coaching") {
            TextField("Notes", text: $exercise.notes, axis: .vertical)
                .lineLimit(2...5)
            TextField("Target RPE (optional)", text: $exercise.targetRPEText)
                .keyboardType(.decimalPad)
            Stepper("Target RIR: \(exercise.targetRIR)", value: $exercise.targetRIR, in: 0...10)
        }
    }
}

private struct PlanEditorDraft {
    var name: String
    var goal: PlanGoal
    var experienceLevel: PlanExperienceLevel
    var weeks: [PlanWeekDraft]

    init(plan: WorkoutPlan) {
        name = plan.name
        goal = plan.goal
        experienceLevel = plan.experienceLevel
        weeks = plan.orderedWeeks.map(PlanWeekDraft.init)
    }

    func apply(to plan: WorkoutPlan, using context: ModelContext) {
        plan.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.goal = goal
        plan.experienceLevel = experienceLevel
        plan.updatedAt = .now

        for weekDraft in weeks {
            guard let week = plan.orderedWeeks.first(where: { $0.id == weekDraft.id }) else { continue }
            for workoutDraft in weekDraft.workouts {
                guard let workout = week.orderedPlannedWorkouts.first(where: { $0.id == workoutDraft.id }) else { continue }
                workout.name = workoutDraft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                workout.dayOffset = workoutDraft.dayOffset

                let retainedIDs = Set(workoutDraft.exercises.compactMap(\.existingID))
                for existing in workout.plannedExercises where !retainedIDs.contains(existing.id) {
                    context.delete(existing)
                }

                workout.plannedExercises = workoutDraft.exercises.enumerated().map { index, draft in
                    if let existingID = draft.existingID,
                       let existing = workout.plannedExercises.first(where: { $0.id == existingID }) {
                        draft.apply(to: existing, orderIndex: index)
                        return existing
                    }
                    return draft.makeModel(orderIndex: index)
                }
            }
        }
    }
}

private struct PlanWeekDraft: Identifiable {
    let id: UUID
    let weekIndex: Int
    var workouts: [PlanWorkoutDraft]

    init(week: PlanWeek) {
        id = week.id
        weekIndex = week.weekIndex
        workouts = week.orderedPlannedWorkouts.map(PlanWorkoutDraft.init)
    }
}

private struct PlanWorkoutDraft: Identifiable {
    let id: UUID
    var name: String
    var dayOffset: Int
    var exercises: [PlanExerciseDraft]

    init(workout: PlannedWorkout) {
        id = workout.id
        name = workout.name
        dayOffset = workout.dayOffset
        exercises = workout.orderedPlannedExercises.map(PlanExerciseDraft.init)
    }
}

private struct PlanExerciseDraft: Identifiable {
    let id: UUID
    let existingID: UUID?
    var exercise: ExerciceTemplate
    var role: ExerciseRole
    var isOptional: Bool
    var targetSets: Int
    var repRangeMinimum: Int
    var repRangeMaximum: Int
    var suggestedLoadText: String
    var suggestedLoadType: WeightType
    var restSeconds: Int
    var targetRPEText: String
    var targetRIR: Int
    var notes: String

    init(exercise: ExerciceTemplate, orderIndex: Int) {
        id = UUID()
        existingID = nil
        self.exercise = exercise
        role = .main
        isOptional = false
        targetSets = 3
        repRangeMinimum = 8
        repRangeMaximum = 12
        suggestedLoadText = ""
        suggestedLoadType = .kg
        restSeconds = 90
        targetRPEText = ""
        targetRIR = 0
        notes = ""
    }

    init(plannedExercise: PlannedExercise) {
        id = plannedExercise.id
        existingID = plannedExercise.id
        exercise = plannedExercise.exercise
        role = plannedExercise.role
        isOptional = plannedExercise.isOptional
        targetSets = plannedExercise.targetSets
        repRangeMinimum = plannedExercise.repRangeMinimum
        repRangeMaximum = plannedExercise.repRangeMaximum
        suggestedLoadText = plannedExercise.suggestedLoad.map { String($0) } ?? ""
        suggestedLoadType = plannedExercise.suggestedLoadType ?? .kg
        restSeconds = plannedExercise.restSeconds
        targetRPEText = plannedExercise.targetRPE.map { String($0) } ?? ""
        targetRIR = plannedExercise.targetRIR ?? 0
        notes = plannedExercise.notes ?? ""
    }

    var summary: String {
        let load = suggestedLoadText.isEmpty ? "No suggested load" : "\(suggestedLoadText) \(suggestedLoadType == .kg ? "kg" : "lb")"
        return "\(targetSets) × \(repRangeMinimum)-\(repRangeMaximum) · \(load) · \(restSeconds)s rest"
    }

    var displayName: String {
        exercise.name
    }

    func makeModel(orderIndex: Int) -> PlannedExercise {
        PlannedExercise(
            exercise: exercise,
            orderIndex: orderIndex,
            role: role,
            isOptional: isOptional,
            targetSets: targetSets,
            repRangeMinimum: repRangeMinimum,
            repRangeMaximum: max(repRangeMinimum, repRangeMaximum),
            suggestedLoad: Double(suggestedLoadText),
            suggestedLoadType: suggestedLoadType,
            restSeconds: restSeconds,
            targetRPE: Double(targetRPEText),
            targetRIR: targetRIR == 0 ? nil : targetRIR,
            notes: notes.isEmpty ? nil : notes
        )
    }

    func apply(to model: PlannedExercise, orderIndex: Int) {
        model.orderIndex = orderIndex
        model.exercise = exercise
        model.role = role
        model.isOptional = isOptional
        model.targetSets = targetSets
        model.repRangeMinimum = repRangeMinimum
        model.repRangeMaximum = max(repRangeMinimum, repRangeMaximum)
        model.suggestedLoad = Double(suggestedLoadText)
        model.suggestedLoadType = suggestedLoadType
        model.restSeconds = restSeconds
        model.targetRPE = Double(targetRPEText)
        model.targetRIR = targetRIR == 0 ? nil : targetRIR
        model.notes = notes.isEmpty ? nil : notes
    }
}

private extension PlanExerciseDraft {
    var title: String { exercise.name }
}

extension PlanGoal {
    var title: String {
        switch self {
        case .generalStrength: return "General strength"
        case .hypertrophy: return "Hypertrophy"
        case .powerlifting: return "Powerlifting"
        case .generalFitness: return "General fitness"
        }
    }
}

extension PlanExperienceLevel {
    var title: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
}

private extension ExerciseRole {
    var title: String {
        switch self {
        case .preparation: return "Preparation"
        case .main: return "Main"
        case .secondary: return "Secondary"
        case .accessory: return "Accessory"
        }
    }
}
