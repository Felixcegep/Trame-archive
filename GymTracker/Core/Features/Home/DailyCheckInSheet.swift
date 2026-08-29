import SwiftData
import SwiftUI

private struct MoodOption: Identifiable {
    let score: Int
    let emoji: String
    let title: String

    var id: Int { score }
}

private let moodOptions: [MoodOption] = [
    MoodOption(score: 1, emoji: "😔", title: "Rough"),
    MoodOption(score: 2, emoji: "🙁", title: "Low"),
    MoodOption(score: 3, emoji: "😐", title: "Okay"),
    MoodOption(score: 4, emoji: "🙂", title: "Good"),
    MoodOption(score: 5, emoji: "😁", title: "Great")
]

struct DailyCheckInSheet: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(DefaultsKey.bodyWeightPromptCadence) private var weightCadence: BodyWeightPromptCadence = .off

    let day: LocalDay
    let onSaved: () -> Void

    @Query private var entries: [DailyLogEntry]
    @Query private var latestWeightEntries: [BodyWeightEntry]
    @Query private var dayWeightEntries: [BodyWeightEntry]
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    @State private var sleepQuality = 0
    @State private var energy = 0
    @State private var workoutDifficulty = 0
    @State private var note = ""
    @State private var weightValue = ""
    @State private var weightUnit: WeightType = UserDefaults.standard.unitSystem == .metric ? .kg : .lbs
    @State private var hidesWeightPrompt = false
    @State private var hasLoaded = false
    @State private var saveError: ValidationIssue?
    @State private var detent: PresentationDetent = .medium

    init(day: LocalDay, onSaved: @escaping () -> Void) {
        self.day = day
        self.onSaved = onSaved

        let dayKey = day.rawValue
        _entries = Query(filter: #Predicate<DailyLogEntry> { $0.dayKey == dayKey })
        _dayWeightEntries = Query(filter: #Predicate<BodyWeightEntry> { $0.dayKey == dayKey })

        var latestWeight = FetchDescriptor<BodyWeightEntry>(
            sortBy: [SortDescriptor(\BodyWeightEntry.measuredAt, order: .reverse)]
        )
        latestWeight.fetchLimit = 1
        _latestWeightEntries = Query(latestWeight)

        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        let calendar = Calendar.current
        let dayStart: Date
        if parts.count == 3,
           let resolved = calendar.date(
               from: DateComponents(year: parts[0], month: parts[1], day: parts[2])
           ) {
            dayStart = resolved
        } else {
            dayStart = calendar.startOfDay(for: .now)
        }
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        _workouts = Query(
            filter: #Predicate<Workout> {
                $0.endTime != nil && $0.startTime >= dayStart && $0.startTime < dayEnd
            },
            sort: [SortDescriptor(\Workout.startTime, order: .reverse)]
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    ratingsCard
                    if shouldShowWeightPrompt { weightCard }
                    noteCard
                    footer
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.trameCanvas)
            .navigationTitle("Daily check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("daily-check-in-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(status: .completed) }
                        .font(AppFont.bodyMedium)
                        .accessibilityIdentifier("daily-check-in-save")
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .task {
            loadExistingEntry()
            // A due measurement puts a text field on the screen; medium would
            // leave it below the fold.
            if shouldShowWeightPrompt { detent = .large }
        }
        .alert("Couldn’t save check-in", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError?.message ?? "Please try again.")
        }
    }

    // MARK: - Ratings

    /// Mood, sleep, and workout difficulty are one question — "how did today
    /// go?" — so they share a card and are separated by dividers rather than by
    /// three competing headlines.
    private var ratingsCard: some View {
        trameSurface {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("How did today go?")
                    .font(AppFont.headlineSemibold)
                    .foregroundStyle(Color.trameText)
                Text(dayLabel)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameSubdued)
            }

            moodSection

            Divider().overlay(Color.trameSeparator)

            ratingSection(
                "Sleep",
                options: [("Poor", 1), ("Okay", 3), ("Great", 5)],
                selection: $sleepQuality,
                accessibilityName: "Sleep quality"
            )

            if hasWorkoutForDay {
                Divider().overlay(Color.trameSeparator)

                ratingSection(
                    "Workout",
                    options: [("Easy", 1), ("Moderate", 3), ("Hard", 5)],
                    selection: $workoutDifficulty,
                    accessibilityName: "Workout difficulty"
                )
            }
        }
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymEyebrow("Mood")
            HStack(alignment: .top, spacing: Spacing.xs) {
                ForEach(moodOptions) { option in
                    moodChip(option)
                }
            }
        }
    }

    private func moodChip(_ option: MoodOption) -> some View {
        let isSelected = energy == option.score
        return Button {
            withAnimation(reduceMotion ? nil : AppMotion.compact) {
                energy = isSelected ? 0 : option.score
            }
        } label: {
            VStack(spacing: Spacing.xs) {
                Text(option.emoji)
                    .font(AppFont.titleMedium)
                    .frame(width: 46, height: 46)
                    .background(
                        isSelected ? Color.trameCurrent : Color.trameRow,
                        in: Circle()
                    )
                    .overlay {
                        Circle().stroke(
                            isSelected ? Color.trameAction : Color.trameSeparator,
                            lineWidth: isSelected ? 2 : 1
                        )
                    }
                Text(option.title)
                    .font(AppFont.captionBold)
                    .foregroundStyle(isSelected ? Color.trameText : Color.trameSubdued)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.gymPress)
        .accessibilityLabel("\(option.title), \(option.score) of 5")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Activate again to record no mood" : "")
    }

    /// Three-way rating as pills instead of a segmented control: the old
    /// control spent a quarter of its width on a "Not recorded" placeholder,
    /// while recording nothing is the default here. Tapping the selection again
    /// clears it, so no answer is ever forced.
    private func ratingSection(
        _ title: LocalizedStringKey,
        options: [(String, Int)],
        selection: Binding<Int>,
        accessibilityName: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymEyebrow(title)
            HStack(spacing: Spacing.s) {
                ForEach(options, id: \.1) { option in
                    let isSelected = selection.wrappedValue == option.1
                    Button {
                        withAnimation(reduceMotion ? nil : AppMotion.compact) {
                            selection.wrappedValue = isSelected ? 0 : option.1
                        }
                    } label: {
                        Text(option.0)
                            .font(AppFont.footnoteMedium)
                            .foregroundStyle(isSelected ? Color.trameText : Color.trameSubdued)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                            .background(
                                isSelected ? Color.trameCurrent : Color.trameRow,
                                in: Capsule()
                            )
                            .overlay {
                                Capsule().stroke(
                                    isSelected ? Color.trameAction : Color.clear,
                                    lineWidth: 1.5
                                )
                            }
                    }
                    .buttonStyle(.gymPress)
                    .accessibilityLabel("\(accessibilityName), \(option.0)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityHint(isSelected ? "Activate again to record nothing" : "")
                }
            }
        }
    }

    // MARK: - Weight

    private var weightCard: some View {
        trameSurface {
            HStack(alignment: .firstTextBaseline) {
                GymEyebrow("Body weight")
                Spacer(minLength: Spacing.s)
                Button("Not now") { withAnimation(reduceMotion ? nil : AppMotion.compact) { hidesWeightPrompt = true } }
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.trameAction)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .accessibilityHint("Hides the weight field for this check-in")
            }
            Text("Your optional \(weightCadence == .weekly ? "weekly" : "monthly") measurement is due.")
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
            HStack(spacing: Spacing.m) {
                TextField("0", text: $weightValue)
                    .keyboardType(.decimalPad)
                    .font(AppFont.headlineMonospaced)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .padding(.horizontal, Spacing.m)
                    .background(
                        Color.trameRow,
                        in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                            .stroke(Color.trameSeparator)
                    }
                    .accessibilityLabel("Current weight")
                    .accessibilityIdentifier("daily-check-in-weight")
                Picker("Unit", selection: $weightUnit) {
                    Text("kg").tag(WeightType.kg)
                    Text("lb").tag(WeightType.lbs)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 116)
            }
        }
    }

    // MARK: - Note

    private var noteCard: some View {
        trameSurface {
            GymEyebrow("Note")
            TextEditor(text: $note)
                .font(AppFont.subheadline)
                .frame(minHeight: 76)
                .scrollContentBackground(.hidden)
                .padding(Spacing.xs)
                .background(Color.trameRow, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if note.isEmpty {
                        Text("Anything worth remembering?")
                            .font(AppFont.subheadline)
                            .foregroundStyle(Color.trameSubdued)
                            .padding(.leading, Spacing.md)
                            .padding(.top, Spacing.m)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityIdentifier("daily-check-in-note")
        }
    }

    // MARK: - Footer

    /// Skip records that the day was seen and answered with nothing, which is
    /// different from Cancel. It stays a quiet footer action so it can't be
    /// mistaken for the way out of the sheet.
    private var footer: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Everything is optional. Your answers and weight never change a workout or nutrition target automatically.")
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
            Button {
                save(status: .skipped)
            } label: {
                Label("Skip today", systemImage: AppIcon.skip)
                    .font(AppFont.footnoteMedium)
                    .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.trameSubdued)
            .contentShape(Rectangle())
            .accessibilityIdentifier("daily-check-in-skip")
            .accessibilityHint("Records the day as skipped without answers")
        }
    }

    private func trameSurface<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        TrameColorField(fill: .trameSurface, ink: .trameText, border: .trameSeparator, radius: Radius.card) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.l)
        }
    }

    // MARK: - Derived state

    private var entryForDay: DailyLogEntry? { entries.first }
    private var latestWeight: BodyWeightEntry? { latestWeightEntries.first }
    private var shouldShowWeightPrompt: Bool { !hidesWeightPrompt && weightCadence.isDue(latest: latestWeight) }
    private var hasWorkoutForDay: Bool {
        workouts.contains { $0.status == .completed && LocalDay(date: $0.startTime).rawValue == day.rawValue }
    }
    private var parsedWeight: Float? {
        guard let value = Float(weightValue.replacingOccurrences(of: ",", with: ".")), value > 0, value <= 1_500 else { return nil }
        return value
    }

    private var dayLabel: String {
        if day == .today { return "Today" }
        let parts = day.rawValue.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return day.rawValue }
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private func loadExistingEntry() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let entry = entryForDay else { return }
        sleepQuality = entry.sleepQuality ?? 0
        energy = entry.energy ?? 0
        workoutDifficulty = entry.workoutDifficulty ?? 0
        note = entry.note ?? ""
    }

    private func save(status: DailyCheckInStatus) {
        let entry = entryForDay ?? DailyLogEntry(day: day)
        entry.update(
            status: status,
            sleepQuality: sleepQuality == 0 ? nil : sleepQuality,
            energy: energy == 0 ? nil : energy,
            workoutDifficulty: hasWorkoutForDay && workoutDifficulty > 0 ? workoutDifficulty : nil,
            note: note
        )
        if entryForDay == nil { modelContext.insert(entry) }

        if status == .completed, shouldShowWeightPrompt, let parsedWeight {
            let measuredAt = Date.now
            let existing = dayWeightEntries.first
            let weight = existing ?? BodyWeightEntry(day: day, value: parsedWeight, unit: weightUnit, source: .checkIn, measuredAt: measuredAt)
            weight.update(value: parsedWeight, unit: weightUnit, source: .checkIn, measuredAt: measuredAt)
            if existing == nil { modelContext.insert(weight) }
        }

        if modelContext.saveOrRollback() {
            onSaved()
            dismiss()
        } else {
            saveError = ValidationIssue(severity: .error, message: "Your answers are still here. Please try saving again.")
        }
    }
}
