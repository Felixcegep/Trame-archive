import SwiftData
import SwiftUI
import UIKit

/// The user-confirmable UI around an on-device workout draft. This view owns
/// transient request and review state only; it never persists a template or
/// starts a workout until its presentation owner explicitly accepts the
/// validated draft.
struct PersonalizedWorkoutBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [TrainingProfile]
    @Query private var completedWorkouts: [Workout]
    @Query(filter: #Predicate<WorkoutTemplate> { !$0.isArchived }) private var templates: [WorkoutTemplate]

    let availableExercises: [Exercise]
    let generator: any WorkoutDraftGenerator
    var onApply: ((ValidatedWorkoutDraft) -> Void)?
    var onStart: ((ValidatedWorkoutDraft) -> Bool)?

    @State private var requestText: String
    @State private var durationMinutes: Int?
    @State private var selectedEquipment: Set<EquipmentType>
    @State private var excludedExerciseIDs: Set<UUID>
    @State private var stimulus: TrainingStimulus?
    @State private var phase: Phase = .request
    @State private var generatedDraft: ValidatedWorkoutDraft?
    @State private var generationTask: Task<Void, Never>?
    @State private var errorMessage: String?

    init(
        availableExercises: [Exercise],
        launchRequest: WorkoutGenerationLaunchRequest? = nil,
        generator: any WorkoutDraftGenerator = FoundationWorkoutDraftGenerator(),
        onApply: ((ValidatedWorkoutDraft) -> Void)? = nil,
        onStart: ((ValidatedWorkoutDraft) -> Bool)? = nil
    ) {
        self.availableExercises = availableExercises
        self.generator = generator
        self.onApply = onApply
        self.onStart = onStart
        let recentHistoryStart = Calendar.current.date(
            byAdding: .day,
            value: -WorkoutGenerationContextBuilder.recentHistoryDays,
            to: .now
        ) ?? .now
        _completedWorkouts = Query(
            filter: #Predicate<Workout> {
                $0.endTime != nil && $0.startTime >= recentHistoryStart
            },
            sort: [SortDescriptor(\Workout.startTime, order: .reverse)]
        )
        var profileDescriptor = FetchDescriptor<TrainingProfile>()
        profileDescriptor.fetchLimit = 1
        _profiles = Query(profileDescriptor)
        _requestText = State(initialValue: launchRequest?.request ?? launchRequest?.focus ?? "")
        _durationMinutes = State(initialValue: launchRequest?.durationMinutes)
        _selectedEquipment = State(initialValue: [])
        _excludedExerciseIDs = State(initialValue: [])
        _stimulus = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .request:
                    requestForm
                case .generating:
                    generatingView
                case .review:
                    reviewView
                case .manualFallback:
                    manualFallbackView
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gymBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear {
                applyProfileDefaultsIfNeeded()
                presentManualFallbackIfUnavailable()
            }
            .onDisappear { generationTask?.cancel() }
        }
    }
}

private extension PersonalizedWorkoutBuilderView {
    enum Phase: Equatable {
        case request
        case generating
        case review
        case manualFallback
    }

    var title: String {
        switch phase {
        case .request: "Build a workout"
        case .generating: "Building workout"
        case .review: "Review workout"
        case .manualFallback: "Build a workout"
        }
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(phase == .generating ? "Cancel" : "Close") {
                if phase == .generating {
                    generationTask?.cancel()
                    phase = .request
                } else {
                    dismiss()
                }
            }
        }

        if phase == .review {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit request") {
                    phase = .request
                }
            }
        }
    }
}

// MARK: - Request

private extension PersonalizedWorkoutBuilderView {
    var requestForm: some View {
        Form {
            Section {
                TextField("What would you like to train?", text: $requestText, axis: .vertical)
                    .lineLimit(2...5)
                    .accessibilityIdentifier("personalized-workout-request")
                Text("For example: a 45-minute upper-body workout with dumbbells.")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            } header: {
                Text("Today’s workout")
            }

            Section("Time") {
                Picker("Duration", selection: $durationMinutes) {
                    Text("Use my preference").tag(Int?.none)
                    ForEach([20, 30, 45, 60, 75, 90], id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(Optional(minutes))
                    }
                }
                .accessibilityIdentifier("personalized-workout-duration")
            }

            Section {
                ForEach(EquipmentType.allCases, id: \.self) { equipment in
                    Toggle(equipment.rawValue, isOn: equipmentBinding(equipment))
                }
            } header: {
                Text("Equipment available today")
            } footer: {
                Text("Leave this empty to use the equipment saved in your training profile.")
            }

            Section("Focus") {
                Picker("Training focus", selection: $stimulus) {
                    Text("Use my preference").tag(TrainingStimulus?.none)
                    ForEach(TrainingStimulus.allCases, id: \.self) { option in
                        Text(option.title).tag(Optional(option))
                    }
                }
                .accessibilityIdentifier("personalized-workout-stimulus")
            }

            Section {
                NavigationLink {
                    PersonalizedWorkoutExclusionsView(
                        exercises: availableExercises,
                        excludedExerciseIDs: $excludedExerciseIDs
                    )
                } label: {
                    HStack {
                        Text("Exercises to avoid")
                        Spacer()
                        if excludedExerciseIDs.isEmpty == false {
                            Text("\(excludedExerciseIDs.count)")
                                .font(AppFont.subheadlineMonospaced)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                    }
                }
                .accessibilityIdentifier("personalized-workout-exclusions")
            } footer: {
                Text("Avoided exercises are a preference, not medical advice. Choose exercises manually if you have pain or need individualized guidance.")
            }

            Section {
                Button(action: generate) {
                    Label("Build personalized workout", systemImage: AppIcon.recipeGenerate)
                        .font(AppFont.subheadlineBold)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gymPrimaryDeep)
                .disabled(availableExercises.isEmpty)
                .accessibilityIdentifier("build-personalized-workout")

                Button("Continue building manually") {
                    phase = .manualFallback
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("personalized-workout-manual-fallback")
            } footer: {
                Text("Your request is processed on this device. Review and edit the draft before it is saved or started.")
            }
        }
    }

    var generatingView: some View {
        VStack(spacing: Spacing.xl) {
            ProgressView()
                .controlSize(.large)
                .accessibilityHidden(true)
            Text("Building your workout…")
                .font(AppFont.titleSmall)
                .foregroundStyle(Color.gymText)
            Text("Using your request, training profile, and local exercise library. Nothing has been saved.")
                .font(AppFont.body)
                .foregroundStyle(Color.gymSubduedText)
                .multilineTextAlignment(.center)
            Button("Cancel") {
                generationTask?.cancel()
                phase = .request
            }
            .buttonStyle(.bordered)
            .tint(Color.gymPrimary)
        }
        .padding(Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Building your workout. Nothing has been saved.")
    }

    var manualFallbackView: some View {
        ContentUnavailableView {
            Label("Build it manually", systemImage: AppIcon.workout)
        } description: {
            Text(errorMessage ?? "Personalized drafting is unavailable right now. You can still choose and order every exercise yourself.")
        } actions: {
            Button("Back to request") {
                errorMessage = nil
                phase = .request
            }
            .buttonStyle(.bordered)
            .tint(Color.gymPrimary)
            Button("Continue building manually") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.gymPrimaryDeep)
        }
        .accessibilityIdentifier("personalized-workout-unavailable")
    }
}

// MARK: - Review

private extension PersonalizedWorkoutBuilderView {
    @ViewBuilder
    var reviewView: some View {
        if let generatedDraft {
            List {
                Section {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(generatedDraft.name)
                            .font(AppFont.titleSmall)
                            .foregroundStyle(Color.gymText)
                        Text("About \(generatedDraft.estimatedDurationMinutes) minutes")
                            .font(AppFont.subheadline)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                    Text(generatedDraft.rationale)
                        .font(AppFont.body)
                        .foregroundStyle(Color.gymText)
                }
                .listRowBackground(Color.gymCard)

                Section("Exercises") {
                    ForEach(Array(generatedDraft.exercises.enumerated()), id: \.element.exercise.id) { index, item in
                        GeneratedWorkoutExerciseRow(index: index + 1, item: item)
                            .listRowBackground(Color.gymCard)
                    }
                }

                if generatedDraft.assumptions.isEmpty == false {
                    Section("Assumptions") {
                        ForEach(generatedDraft.assumptions, id: \.self) { assumption in
                            Label(assumption, systemImage: AppIcon.info)
                                .font(AppFont.footnote)
                                .foregroundStyle(Color.gymSubduedText)
                                .listRowBackground(Color.gymPrimarySurface)
                        }
                    }
                }

                let warnings = generatedDraft.warnings + generatedDraft.validationWarnings.map(validationWarningText)
                if warnings.isEmpty == false {
                    Section("Review needed") {
                        ForEach(warnings, id: \.self) { warning in
                            Label(warning, systemImage: AppIcon.warning)
                                .font(AppFont.footnote)
                                .foregroundStyle(Color.gymText)
                                .listRowBackground(Color.gymAccentSurface)
                        }
                    }
                }

                Section {
                    if let onApply {
                        Button("Use in workout builder") {
                            onApply(generatedDraft)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.gymPrimaryDeep)
                        .accessibilityIdentifier("personalized-workout-apply-draft")
                    }

                    if let onStart {
                        Button("Start workout") {
                            if onStart(generatedDraft) {
                                dismiss()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.gymPrimary)
                        .accessibilityIdentifier("personalized-workout-start")
                    }

                    Button("Generate again") {
                        generate()
                    }
                    .accessibilityIdentifier("personalized-workout-regenerate")
                } footer: {
                    Text("Review every exercise and prescription before saving or starting. This draft has not changed your workout history.")
                }
            }
        } else {
            manualFallbackView
        }
    }

    func validationWarningText(_ warning: WorkoutDraftValidationWarning) -> String {
        switch warning {
        case .ignoredUnknownOrArchivedExercise:
            "An unavailable exercise was removed."
        case .ignoredDuplicateExercise:
            "A duplicate exercise was removed."
        case .adjustedPrescription:
            "A prescription was adjusted to match this exercise."
        case .removedInvalidSuperset:
            "An invalid superset was changed to individual exercises."
        }
    }
}

// MARK: - Generation

private extension PersonalizedWorkoutBuilderView {
    func applyProfileDefaultsIfNeeded() {
        guard requestText.isEmpty, durationMinutes == nil, selectedEquipment.isEmpty, stimulus == nil else { return }
        let preferences = WorkoutGenerationPreferencesStore.load()
        durationMinutes = preferences.defaultDurationMinutes
        stimulus = preferences.preferredStimulus
    }

    func presentManualFallbackIfUnavailable() {
        guard WorkoutGenerationAvailability.status().allowsGeneration == false else { return }
        errorMessage = availabilityMessage
        phase = .manualFallback
    }

    var availabilityMessage: String {
        switch WorkoutGenerationAvailability.status() {
        case .available:
            ""
        case .modelDownloading:
            "Personalized drafting will be available when Apple Intelligence finishes setting up. You can still build this workout manually."
        case .unsupportedDevice:
            "Personalized drafting isn’t available on this device. You can still build this workout manually."
        case .unsupportedLocale:
            "Personalized drafting isn’t available in this language yet. You can still build this workout manually."
        }
    }

    func equipmentBinding(_ equipment: EquipmentType) -> Binding<Bool> {
        Binding(
            get: { selectedEquipment.contains(equipment) },
            set: { isSelected in
                if isSelected {
                    selectedEquipment.insert(equipment)
                } else {
                    selectedEquipment.remove(equipment)
                }
            }
        )
    }

    func generate() {
        guard phase != .generating else { return }
        let request = WorkoutGenerationRequest(
            requestText: requestText,
            desiredDurationMinutes: durationMinutes,
            selectedEquipment: selectedEquipment,
            excludedExerciseIDs: excludedExerciseIDs,
            preferredStimulus: stimulus
        )
        let preferences = WorkoutGenerationPreferencesStore.load()
        let input = WorkoutGenerationContextBuilder.build(
            request: request,
            profile: profiles.first,
            preferences: preferences,
            exercises: availableExercises,
            completedWorkouts: completedWorkouts,
            templates: templates
        )

        guard input.availableExercises.isEmpty == false else {
            errorMessage = "No available exercises match these preferences. Adjust your equipment or excluded exercises, or build the workout manually."
            phase = .manualFallback
            return
        }

        phase = .generating
        errorMessage = nil
        generationTask = Task {
            do {
                let rawDraft = try await generator.generateDraft(from: input)
                try Task.checkCancellation()
                let validatedDraft = try WorkoutDraftValidator.validate(rawDraft, against: availableExercises)
                try Task.checkCancellation()
                generatedDraft = validatedDraft
                phase = .review
                UIAccessibility.post(notification: .announcement, argument: "Workout draft ready for review.")
            } catch is CancellationError {
                // Cancellation preserves the request and never creates data.
            } catch {
                errorMessage = "The personalized workout couldn’t be built. Try again or continue building manually."
                phase = .manualFallback
            }
        }
    }
}

private struct GeneratedWorkoutExerciseRow: View {
    let index: Int
    let item: ValidatedWorkoutExercise

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Text("\(index)")
                .font(AppFont.subheadlineSemiboldMonospaced)
                .foregroundStyle(Color.gymPrimary)
                .frame(width: 24, alignment: .leading)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(item.exercise.name)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.gymText)
                Text("\(item.targetSets) sets · \(item.repRangeMinimum)–\(item.repRangeMaximum) reps · \(item.restSeconds) sec rest")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                if let targetRIR = item.targetRIR {
                    Text("Target \(targetRIR) RIR")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                } else if let targetRPE = item.targetRPE {
                    Text("Target RPE \(targetRPE.formatted())")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
                if let notes = item.notes, notes.isEmpty == false {
                    Text(notes)
                        .font(AppFont.footnote)
                        .foregroundStyle(Color.gymSubduedText)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(index). \(item.exercise.name), \(item.targetSets) sets of \(item.repRangeMinimum) to \(item.repRangeMaximum) repetitions, \(item.restSeconds) seconds rest.")
    }
}

private struct PersonalizedWorkoutExclusionsView: View {
    let exercises: [Exercise]
    @Binding var excludedExerciseIDs: Set<UUID>

    var body: some View {
        List {
            ForEach(exercises.filter { !$0.isArchived }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }, id: \.id) { exercise in
                Toggle(exercise.name, isOn: Binding(
                    get: { excludedExerciseIDs.contains(exercise.id) },
                    set: { isExcluded in
                        if isExcluded {
                            excludedExerciseIDs.insert(exercise.id)
                        } else {
                            excludedExerciseIDs.remove(exercise.id)
                        }
                    }
                ))
                .accessibilityIdentifier("personalized-workout-exclude-\(exercise.id)")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Exercises to avoid")
        .navigationBarTitleDisplayMode(.inline)
    }
}
