import SwiftUI
import SwiftData

struct WorkoutSaveView: View {
    @Environment(\.modelContext) private var modelContext

    let workoutVM: WorkoutViewModel
    @Binding var navigationPath: [ActiveWorkoutRoute]
    @Binding var isPresented: Bool
    let activeLoggingMetrics: ActiveLoggingMetricsRecorder
    let onOpenNutrition: (() -> Void)?
    /// Returns whether the root training cover should dismiss. A linked
    /// post-workout mobility stage returns `false` so execution can continue
    /// in the same cover after the strength evidence has been committed.
    let onWorkoutSaved: (UUID) -> Bool
    let onDiscardRequested: () -> Void

    @AppStorage(DefaultsKey.bodyWeightPromptCadence) private var bodyWeightPromptCadence: BodyWeightPromptCadence = .off
    @Query private var latestBodyWeightEntries: [BodyWeightEntry]
    @Query private var todayBodyWeightEntries: [BodyWeightEntry]
    /// Declining is a decision about this screen, not a permanent one — the
    /// cadence setting owns "never ask again".
    @State private var hasDismissedBodyWeightPrompt = false
    @State private var isAddingBodyWeight = false
    @State private var isShowingDiscardConfirmation = false
    @State private var isEditingDuration = false
    @State private var sessionDuration: TimeInterval = Constants.Session.minimumDuration
    @State private var didCaptureSessionDuration = false
    @State private var saveErrorMessage: String?
    /// Separate counters so success and failure can never fire together, and
    /// so neither can fire from anything except a completed attempt.
    @State private var saveSucceededCount = 0
    @State private var saveFailedCount = 0
    @State private var shouldOpenNutritionAfterSave = false
    @FocusState private var isNotesFocused: Bool

    init(
        workoutVM: WorkoutViewModel,
        navigationPath: Binding<[ActiveWorkoutRoute]>,
        isPresented: Binding<Bool>,
        activeLoggingMetrics: ActiveLoggingMetricsRecorder,
        onOpenNutrition: (() -> Void)? = nil,
        onWorkoutSaved: @escaping (UUID) -> Bool,
        onDiscardRequested: @escaping () -> Void
    ) {
        self.workoutVM = workoutVM
        _navigationPath = navigationPath
        _isPresented = isPresented
        self.activeLoggingMetrics = activeLoggingMetrics
        self.onOpenNutrition = onOpenNutrition
        self.onWorkoutSaved = onWorkoutSaved
        self.onDiscardRequested = onDiscardRequested

        var latestWeight = FetchDescriptor<BodyWeightEntry>(
            sortBy: [SortDescriptor(\BodyWeightEntry.measuredAt, order: .reverse)]
        )
        latestWeight.fetchLimit = 1
        _latestBodyWeightEntries = Query(latestWeight)

        let todayKey = LocalDay.today.rawValue
        _todayBodyWeightEntries = Query(
            filter: #Predicate<BodyWeightEntry> { $0.dayKey == todayKey }
        )
    }

    var body: some View {
        Group {
            if let workout = workoutVM.activeWorkout {
                saveReview(for: workout)
            } else {
                ContentUnavailableView(
                    "No workout to save",
                    systemImage: "checkmark.circle",
                    description: Text("Return home to start a new session.")
                )
            }
        }
        .foregroundStyle(Color.trameText)
        .background(Color.trameCanvas.ignoresSafeArea())
        .tint(Color.trameAction)
        .navigationTitle("Review and save")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.trameCanvas, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isNotesFocused = false
                }
                .accessibilityIdentifier("dismiss-review-notes-keyboard")
            }
        }
        .alert(
            "Couldn’t save workout",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .sheet(isPresented: $isAddingBodyWeight) {
            BodyWeightEditorSheet(entry: nil, source: .checkIn)
        }
        .sheet(isPresented: $isEditingDuration) {
            SessionDurationEditor(
                duration: sessionDuration,
                onSave: { duration in
                    sessionDuration = duration
                    if let workout = workoutVM.activeWorkout {
                        _ = workout.updateElapsedDuration(duration)
                    }
                    isEditingDuration = false
                },
                onCancel: { isEditingDuration = false }
            )
        }
        .onAppear {
            captureSessionDurationIfNeeded()
        }
        // Saving is the most significant thing that happens in this app and it
        // used to end in a silent dismissal — visually identical to discarding
        // or to a crash. Both signals fire strictly after the attempt resolves,
        // and they are mutually exclusive.
        .gymFeedback(.sessionSaved, trigger: saveSucceededCount)
        .gymFeedback(.saveFailed, trigger: saveFailedCount)
    }

    @ViewBuilder
    private func saveReview(for workout: Workout) -> some View {
        if workout.completedSetCount == 0 {
            emptySaveReview(for: workout)
        } else {
            standardSaveReview(for: workout)
        }
    }

    private func emptySaveReview(for workout: Workout) -> some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            
            Image(systemName: AppIcon.warningFill)
                .font(AppFont.displayLarge)
                .foregroundStyle(Color.trameAttention)
                
            VStack(spacing: Spacing.s) {
                Text("Empty Session")
                    .font(AppFont.displayMedium)
                    .multilineTextAlignment(.center)
                Text("No sets have been completed. Add exercises and complete sets to log your training.")
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.trameSubdued)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.l)
                repeatingPlanSaveContext(for: workout)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack(spacing: Spacing.m) {
                Button {
                    navigationPath.removeLast()
                } label: {
                    Text("Return to Workout")
                }
                .buttonStyle(.tramePrimaryAction)
                
                Button("Discard Workout", role: .destructive) {
                    isShowingDiscardConfirmation = true
                }
                .font(AppFont.subheadlineSemibold)
                .padding(.vertical, Spacing.s)
            }
            .padding(.horizontal, Spacing.xl)
        }
        .padding(.bottom, Spacing.xl)
        .confirmationDialog(
            "Discard this workout?",
            isPresented: $isShowingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard workout", role: .destructive, action: discardWorkout)
        } message: {
            Text(discardConfirmationMessage(for: workout))
        }
    }

    private func standardSaveReview(for workout: Workout) -> some View {
        @Bindable var workout = workout
        let hasIncomplete = workout.incompleteSetCount > 0
        let review = makeSaveReviewProjection(for: workout)

        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl - 2) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Image(systemName: hasIncomplete ? "square.and.pencil" : AppIcon.checkmarkCircle)
                        .font(AppFont.title)
                        .foregroundStyle(hasIncomplete ? Color.trameStrength : Color.trameCompleted)
                    Text(hasIncomplete ? "Ready to save?" : "Nice work.")
                        .font(AppFont.displayMedium)
                    Text(hasIncomplete 
                         ? "Only completed sets will be saved to History. Incomplete sets will be excluded."
                         : "Give this session a name, then save it to your history.")
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.trameSubdued)
                    repeatingPlanSaveContext(for: workout)
                }

                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("WORKOUT NAME")
                        .font(AppFont.captionBold)
                        .tracking(0.8)
                        .foregroundStyle(Color.trameSubdued)
                    TextField(
                        workout.displayTitle,
                        text: Binding(
                            get: { workout.name ?? "" },
                            set: { workout.name = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .font(AppFont.titleSmallSemibold)
                    .padding(Spacing.l)
                    .background(Color.trameSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                }

                bodyWeightPrompt(for: workout)

                sportSection(for: workout)

                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("NOTES")
                        .font(AppFont.captionBold)
                        .tracking(0.8)
                        .foregroundStyle(Color.trameSubdued)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: Binding(
                            get: { workout.notes ?? "" },
                            set: { workout.notes = $0.isEmpty ? nil : $0 }
                        ))
                        .focused($isNotesFocused)
                        .frame(minHeight: notesEditorHeight(for: workout))
                        .padding(Spacing.md)

                        if !hasNotes(for: workout) {
                            Text("Add a note…")
                                .font(AppFont.body)
                                .foregroundStyle(Color.trameSubdued)
                                .padding(.horizontal, Spacing.l + Spacing.md)
                                .padding(.vertical, Spacing.l)
                                .allowsHitTesting(false)
                        }
                    }
                    .background(Color.trameSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                            .stroke(Color.trameSeparator, lineWidth: 1)
                    }
                }

                summaryCard(for: workout, review: review)
                exerciseReview(review)
            }
            .padding(Spacing.xl)
            .padding(.bottom, 98)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Color.trameCanvas)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.md) {
                // The exclusion only. The button beneath now names what *is*
                // being saved, so repeating it here would say the same thing
                // twice in eight points of vertical space.
                if workout.incompleteSetCount > 0 {
                    Label(
                        "\(CountPhrase.incompleteSets(workout.incompleteSetCount)) won't be included",
                        systemImage: AppIcon.warningCircle
                    )
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.trameAttention)
                    .accessibilityLabel("\(CountPhrase.incompleteSets(workout.incompleteSetCount)) will be excluded from History.")
                }

                // The label is the confirmation.
                //
                // This used to read "Save workout" and raise a dialog headed
                // "Save only completed sets?" whose message repeated, word for
                // word, the caption already printed directly above this button.
                // Confirming a fact the screen is currently stating is not a
                // safeguard; it is a second tap. Naming the count in the button
                // makes the promise at the point of action, which is where the
                // lifter is looking. Discard still confirms — that one destroys
                // work and cannot be undone.
                Button(action: saveWorkout) {
                    Label(
                        saveActionTitle(
                            for: workout,
                            completedSetCount: review.completedSetCount
                        ),
                        systemImage: AppIcon.save
                    )
                }
                .buttonStyle(.tramePrimaryAction)
                .accessibilityIdentifier("save-workout")

                if FeatureFlags.current.isEnabled(.nutrition), onOpenNutrition != nil {
                    Button("Save and log food") {
                        shouldOpenNutritionAfterSave = true
                        saveWorkout()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                    .accessibilityIdentifier("save-workout-and-log-food")
                }

                Button("Discard workout", role: .destructive) {
                    isShowingDiscardConfirmation = true
                }
                .font(AppFont.subheadlineSemibold)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.m)
            .background(Color.trameSurface)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.trameSeparator)
                    .frame(height: 1)
            }
        }
        .confirmationDialog(
            "Discard this workout?",
            isPresented: $isShowingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard workout", role: .destructive, action: discardWorkout)
        } message: {
            Text(discardConfirmationMessage(for: workout))
        }
    }

    @ViewBuilder
    private func repeatingPlanSaveContext(for workout: Workout) -> some View {
        if let repeatingPlanName = repeatingPlanName(for: workout) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Label("Rotation: \(repeatingPlanName)", systemImage: AppIcon.routine)
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.trameCompleted)
                Text("When this workout saves successfully, the rotation advances to the next workout.")
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.trameSubdued)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Rotation \(repeatingPlanName). It advances only after this workout is saved successfully."
            )
        }
    }

    private func repeatingPlanName(for workout: Workout) -> String? {
        guard let name = workout.sourceRepeatingPlanName?
            .trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
        else {
            return nil
        }
        return name
    }

    /// What the button will do, stated on the button.
    ///
    /// Named with its count only when some sets are being left behind. A
    /// workout with nothing incomplete has nothing to disambiguate, and
    /// "Save 18 completed sets" there would imply a distinction that does not
    /// exist.
    private func saveActionTitle(
        for workout: Workout,
        completedSetCount: Int
    ) -> String {
        guard workout.incompleteSetCount > 0 else {
            return String(localized: "Save workout")
        }
        return String(localized: "Save \(CountPhrase.completedSets(completedSetCount))")
    }

    private func discardConfirmationMessage(for workout: Workout) -> String {
        let base = String(localized: "Your logged sets and notes will not be saved.")
        guard let repeatingPlanName = repeatingPlanName(for: workout) else {
            return base
        }
        return String(
            localized: "Your logged sets and notes will not be saved. \(repeatingPlanName) will not advance."
        )
    }

    private func workoutDuration() -> String {
        Formatters.sessionDuration(sessionDuration)
    }

    private func captureSessionDurationIfNeeded() {
        guard !didCaptureSessionDuration, let workout = workoutVM.activeWorkout else { return }
        sessionDuration = max(Constants.Session.minimumDuration, workout.elapsedDuration())
        didCaptureSessionDuration = true
    }

    private func summaryCard(
        for workout: Workout,
        review: SaveReviewProjection
    ) -> some View {
        HStack(spacing: 0) {
            Button {
                isEditingDuration = true
            } label: {
                VStack(spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xxs) {
                        Text(workoutDuration())
                            .font(AppFont.metricLarge)
                        Image(systemName: AppIcon.edit)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.trameSubdued)
                    }
                    Text("Duration")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.trameSubdued)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                Text("Time at the gym, \(workoutDuration())")
            )
            .accessibilityHint(Text("Changes how long this session lasted."))
            .accessibilityIdentifier("review-duration")
            Divider().frame(height: 38)
            summaryMetric(value: "\(review.exercises.count)", label: "Exercises")
            Divider().frame(height: 38)
            summaryMetric(value: "\(review.completedSetCount)", label: "Sets saved")
        }
        .padding(.vertical, Spacing.l)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.trameSeparator).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.trameSeparator).frame(height: 1)
        }
    }

    private func summaryMetric(value: String, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(AppFont.metricLarge)
            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
        }
        .frame(maxWidth: .infinity)
    }

    private func exerciseReview(_ review: SaveReviewProjection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("SESSION SUMMARY")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.trameSubdued)

            ForEach(review.exercises) { item in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: Spacing.m) {
                        Image(systemName: AppIcon.checkmarkCircle)
                            .foregroundStyle(Color.trameCompleted)

                        Text(item.exercise.exercise.name)
                            .font(AppFont.subheadlineSemibold)

                        Spacer()

                        Text("\(item.savedSets.count) saved")
                            .font(AppFont.subheadlineMonospaced)
                            .foregroundStyle(Color.trameSubdued)
                    }
                    .padding(Spacing.m)

                    Divider()
                        .padding(.horizontal, Spacing.m)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        let comparison = WorkoutPerformanceComparison(exercise: item.exercise)
                        if comparison.hasTargets {
                            PerformanceComparisonView(comparison: comparison)
                                .padding(.horizontal, Spacing.m)
                                .padding(.top, Spacing.s)
                        }

                        ForEach(Array(item.savedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                            HStack(spacing: Spacing.s) {
                                Text("Set \(index + 1)")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.trameSubdued)

                                Spacer()

                                Text(set.displayText())
                                    .font(AppFont.captionSemiboldMonospaced)

                                Image(systemName: AppIcon.checkmark)
                                    .font(AppFont.caption2Bold)
                                    .foregroundStyle(Color.trameCompleted)
                            }
                            .padding(.horizontal, Spacing.m + 2)
                            .padding(.vertical, Spacing.xxs)
                        }
                    }
                    .padding(.vertical, Spacing.s)

                    if item.incompleteSetCount > 0 {
                        Label("\(item.incompleteSetCount) incomplete • excluded from History", systemImage: AppIcon.warningCircle)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.trameAttention)
                            .padding(.horizontal, Spacing.m + 2)
                            .padding(.bottom, Spacing.m)
                    }
                }
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.trameSeparator).frame(height: 1)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.trameSeparator).frame(height: 1)
                }
            }
        }
    }

    private func hasNotes(for workout: Workout) -> Bool {
        !(workout.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private func notesEditorHeight(for workout: Workout) -> CGFloat {
        hasNotes(for: workout) || isNotesFocused ? 104 : 44
    }

    private struct SaveReviewProjection {
        struct ExerciseReview: Identifiable {
            let exercise: ExerciseEntry
            let savedSets: [ExerciseSet]
            let incompleteSetCount: Int

            var id: PersistentIdentifier { exercise.persistentModelID }
        }

        let exercises: [ExerciseReview]
        let completedSetCount: Int
    }

    /// Resolves the saved/excluded set partition once for every consumer in
    /// this render: summary metrics, detailed rows, and the save action label.
    private func makeSaveReviewProjection(for workout: Workout) -> SaveReviewProjection {
        var exercises: [SaveReviewProjection.ExerciseReview] = []
        exercises.reserveCapacity(workout.exercises.count)
        var completedSetCount = 0

        for exercise in workout.orderedExercises {
            var savedSets: [ExerciseSet] = []
            var incompleteSetCount = 0
            let orderedSets = exercise.orderedSets
            savedSets.reserveCapacity(orderedSets.count)

            for exerciseSet in orderedSets {
                if exerciseSet.done {
                    savedSets.append(exerciseSet)
                } else {
                    incompleteSetCount += 1
                }
            }

            guard savedSets.isEmpty == false else { continue }
            completedSetCount += savedSets.count
            exercises.append(SaveReviewProjection.ExerciseReview(
                exercise: exercise,
                savedSets: savedSets,
                incompleteSetCount: incompleteSetCount
            ))
        }

        return SaveReviewProjection(
            exercises: exercises,
            completedSetCount: completedSetCount
        )
    }

    private func saveWorkout() {
        // The failed-write branch below needs a write that actually fails, which
        // a UI test cannot arrange. This reproduces its exact outcome — counted,
        // workout left open, every logged set intact — so the alert has a
        // screenshot. Capture-only; no shipped launch carries the argument.
        if AppLaunchArguments.current.contains("-ui-testing-fail-workout-save") {
            saveFailedCount += 1
            saveErrorMessage = String(localized: "Your workout could not be saved and is still open, with every logged set intact. Try saving again.")
            return
        }
        guard let workout = workoutVM.activeWorkout else {
            // Distinct from a failed write: there is nothing here to save, so
            // "try again" would be false advice.
            saveFailedCount += 1
            saveErrorMessage = String(localized: "This workout is no longer open, so there was nothing to save. Return home to start a new session.")
            return
        }
        _ = workout.updateElapsedDuration(sessionDuration)
        let workoutID = workout.id
        let wasPartial = workout.incompleteSetCount > 0
        guard workoutVM.saveWorkout(using: modelContext) else {
            saveFailedCount += 1
            // The error goes to the log, not into the alert. SwiftData surfaces
            // text like "The operation couldn't be completed. (SwiftData.
            // SwiftDataError error 1.)", which tells the user nothing and
            // displaces the one sentence that does matter here: their sets are
            // still safe and retrying is worthwhile.
            if let error = workoutVM.lastSaveFailure {
                print("Workout save failed for \(workoutID): \(error)")
            }
            saveErrorMessage = String(localized: "Your workout could not be saved and is still open, with every logged set intact. Try saving again.")
            return
        }

        saveSucceededCount += 1
        GymAnnouncement.post(savedAnnouncement)
        activeLoggingMetrics.workoutSaved(isPartial: wasPartial)
        let shouldDismissTraining = onWorkoutSaved(workoutID)
        navigationPath.removeAll()
        if CloudFileSyncService.shared.isLinked,
           AppLaunchArguments.current.contains("-ui-testing") == false {
            let restTimer = UserDefaults.standard.integer(forKey: DefaultsKey.restTimer)
            let unitSystem = UserDefaults.standard.unitSystem
            let stored = AppAppearance(
                rawValue: UserDefaults.standard.string(forKey: DefaultsKey.appearance) ?? ""
            ) ?? .dark
            let isDark = AppAppearance.resolved(
                stored: stored,
                legacyDarkMode: UserDefaults.standard.bool(forKey: DefaultsKey.darkMode)
            ) == .dark
            Task {
                _ = await CloudFileSyncService.shared.sync(
                    from: modelContext,
                    hasActiveWorkout: false,
                    restTimer: restTimer,
                    darkMode: isDark,
                    unitSystem: unitSystem,
                    request: .automatic
                )
            }
        }
        if shouldOpenNutritionAfterSave {
            onOpenNutrition?()
        }
        if shouldDismissTraining {
            isPresented = false
        }
    }

    /// Reports what was actually written, using the counts recorded by the save
    /// itself. They cannot be recomputed here: the graph has been pruned and
    /// `activeWorkout` cleared by the time this runs.
    // MARK: - Body weight

    /// Asks for body weight after the session, and only when this session
    /// actually needed it.
    ///
    /// Placement is the whole design here. A pull-up logged at 8 reps means
    /// nothing without knowing what was being pulled, so the app wants this
    /// number — but it must never stand between a lifter and logging a set.
    /// Mid-workout the ask would land on the rest timer starting; here the
    /// session is already over and a keyboard interrupts nothing.
    ///
    /// Skipped entirely when the lifter has turned the prompt off in Settings:
    /// `BodyWeightPromptCadence.isDue(latest:)` already encodes both the
    /// off switch and the staleness window.
    @ViewBuilder
    private func bodyWeightPrompt(for workout: Workout) -> some View {
        if !hasDismissedBodyWeightPrompt,
           workout.usesBodyweightLoading,
           bodyWeightPromptCadence.isDue(latest: latestBodyWeightEntries.first) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Label {
                    Text("Add your body weight")
                        .font(AppFont.subheadlineBold)
                } icon: {
                    Image(systemName: AppIcon.bodyWeight)
                }
                .foregroundStyle(Color.trameAttentionInk)

                Text(bodyWeightPromptDetail)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameAttentionInk)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Spacing.s) {
                    if let latest = latestBodyWeightEntries.first {
                        // The common case by far: weight has not meaningfully
                        // moved, so confirming last week's number is one tap
                        // and no keyboard.
                        Button {
                            recordBodyWeight(value: latest.value, unit: latest.unit)
                        } label: {
                            Text("Still \(Formatters.formatFloat(latest.value)) \(latest.unit.rawValue)")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.tramePrimaryAction)
                        .accessibilityIdentifier("confirm-body-weight")
                    } else {
                        // With no previous reading there is nothing to
                        // confirm, and the prompt used to offer only a way out
                        // — an ask with no way to answer it.
                        Button {
                            isAddingBodyWeight = true
                        } label: {
                            Text("Add weight")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.tramePrimaryAction)
                        .accessibilityIdentifier("prompt-add-body-weight")
                    }

                    Button {
                        hasDismissedBodyWeightPrompt = true
                    } label: {
                        Text("Not now")
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(Color.trameAttentionInk)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                                    .stroke(Color.trameAttentionInk.opacity(0.4), lineWidth: 1)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.gymPress)
                    .accessibilityIdentifier("dismiss-body-weight-prompt")
                }
            }
            .padding(Spacing.l)
            .background(Color.trameAttention, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .foregroundStyle(Color.trameAttentionInk)
            .accessibilityIdentifier("body-weight-prompt")
        }
    }

    private var bodyWeightPromptDetail: String {
        guard let latest = latestBodyWeightEntries.first else {
            return String(localized: "This session included bodyweight work. Recording your weight lets the app show total load.")
        }
        let days = Calendar.current.dateComponents([.day], from: latest.measuredAt, to: .now).day ?? 0
        return String(localized: "This session included bodyweight work. Last recorded \(days) days ago — confirming keeps total load accurate.")
    }

    /// Writes today's entry. `dayKey` is the model's own uniquing key, so
    /// re-confirming on a day that already has a reading updates it instead of
    /// stacking a duplicate.
    private func recordBodyWeight(value: Float, unit: WeightType) {
        let today = LocalDay.today

        if let existing = todayBodyWeightEntries.first {
            existing.update(value: value, unit: unit, source: .checkIn, measuredAt: .now)
        } else {
            modelContext.insert(
                BodyWeightEntry(
                    day: today,
                    value: value,
                    unit: unit,
                    source: .checkIn,
                    measuredAt: .now
                )
            )
        }
        hasDismissedBodyWeightPrompt = true
    }

    // MARK: - Sport

    /// Asks what kind of session this was, once, with the answer already filled
    /// in when the exercises make it obvious.
    ///
    /// It is a row of chips rather than a picker because the whole point is that
    /// correcting the guess costs one tap. A picker would make the common case
    /// (the guess is right) free and the uncommon case (it is wrong) three taps
    /// deep, which is backwards: a lifter only looks at this row *because*
    /// something about it caught their eye.
    @ViewBuilder
    private func sportSection(for workout: Workout) -> some View {
        let suggestion = sportSuggestion(for: workout)
        let offered = offeredSports(for: workout, suggestion: suggestion)

        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("SPORT")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.trameSubdued)

            ChipFlowLayout(spacing: Spacing.xs) {
                ForEach(offered) { sport in
                    sportChip(sport, workout: workout)
                }
            }

            Text(sportCaption(for: workout, suggestion: suggestion))
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
        }
        .accessibilityIdentifier("workout-sport-section")
        .onAppear {
            // Pre-fill only a confident guess, only once, and never over an
            // answer the lifter has already given.
            guard workout.sport == nil, let selected = suggestion.selected else { return }
            workout.sport = selected
            workout.sportWasAutoDetected = true
        }
    }

    private func sportChip(_ sport: SessionSport, workout: Workout) -> some View {
        let isSelected = workout.sport == sport
        return Button {
            if isSelected {
                workout.sport = nil
            } else {
                workout.sport = sport
                // A tap is a correction, so the value is no longer the
                // detector's. This is the only signal available for tuning the
                // rules later.
                workout.sportWasAutoDetected = false
            }
        } label: {
            Label {
                Text(sport.title)
            } icon: {
                if isSelected {
                    Image(systemName: AppIcon.checkmark)
                }
            }
            .font(AppFont.footnoteMedium)
            .foregroundStyle(isSelected ? Color.trameActionInk : Color.trameText)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .background(isSelected ? Color.trameAction : Color.trameRow, in: Capsule())
            .overlay {
                Capsule().stroke(isSelected ? Color.trameActionOutline : Color.trameSeparator, lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.gymPress)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("workout-sport-\(sport.rawValue)")
    }

    private func sportSuggestion(for workout: Workout) -> SessionSportSuggestion {
        SessionSportDetector.suggest(for: workout.sportDetectionInputs)
    }

    /// The chips to show: whatever is currently chosen, then the detector's
    /// candidates, then `Mixed` and `Other` as explicit escapes. `Mixed` is
    /// deliberately never inferred — some sessions really are two sports, and
    /// that should be the lifter saying so rather than the app giving up.
    private func offeredSports(
        for workout: Workout,
        suggestion: SessionSportSuggestion
    ) -> [SessionSport] {
        var sports: [SessionSport] = []
        if let selected = workout.sport { sports.append(selected) }
        if let detected = suggestion.selected { sports.append(detected) }
        sports.append(contentsOf: suggestion.alternatives)
        sports.append(contentsOf: [.mixed, .other])

        var seen: Set<SessionSport> = []
        return sports.filter { seen.insert($0).inserted }
    }

    private func sportCaption(
        for workout: Workout,
        suggestion: SessionSportSuggestion
    ) -> String {
        if workout.sport == nil {
            return suggestion.isConfident
                ? String(localized: "Optional — pick one, or save without it.")
                : String(localized: "This session mixes a few things. Pick one, or save without it.")
        }
        if workout.sportWasAutoDetected {
            return String(
                localized: "Detected from \(suggestion.matchedExercises) of \(suggestion.totalExercises) exercises. Tap to change."
            )
        }
        return String(localized: "Tap again to clear.")
    }

    private var savedAnnouncement: String {
        guard let summary = workoutVM.lastSavedSummary else {
            return String(localized: "Workout saved.")
        }
        return String(
            localized: "Workout saved. \(CountPhrase.sets(summary.savedSetCount)) added to History."
        )
    }

    private func discardWorkout() {
        navigationPath.removeAll()
        onDiscardRequested()
    }
}
