import SwiftData
import SwiftUI

struct DailyCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(DefaultsKey.bodyWeightPromptCadence) private var weightCadence: BodyWeightPromptCadence = .off

    let day: LocalDay
    let onSaved: () -> Void

    @Query private var entries: [DailyLogEntry]
    @Query(sort: \BodyWeightEntry.measuredAt, order: .reverse) private var weightEntries: [BodyWeightEntry]
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    feelingSection
                    selectionSection("Sleep quality", values: [("Poor", 1), ("Okay", 3), ("Great", 5)], selection: $sleepQuality)
                    if hasWorkoutForDay {
                        selectionSection("Workout difficulty", values: [("Easy", 1), ("Moderate", 3), ("Hard", 5)], selection: $workoutDifficulty)
                    }
                    if shouldShowWeightPrompt { weightSection }
                    noteSection
                    Text("Everything is optional. Your answers and weight never change a workout or nutrition target automatically.")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.l)
            }
            .background(Color.gymBackground)
            .navigationTitle("Daily check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { save(status: .skipped) }
                        .foregroundStyle(Color.gymSubduedText)
                        .accessibilityIdentifier("daily-check-in-skip")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(status: .completed) }
                        .font(AppFont.bodyMedium)
                        .accessibilityIdentifier("daily-check-in-save")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { loadExistingEntry() }
        .alert("Couldn’t save check-in", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError?.message ?? "Please try again.")
        }
    }

    private var feelingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("How are you feeling?").font(AppFont.headline).foregroundStyle(Color.gymText)
            HStack(spacing: Spacing.s) {
                ForEach(Array(["😔", "🙁", "😐", "🙂", "😁"].enumerated()), id: \.offset) { index, symbol in
                    let score = index + 1
                    Button {
                        energy = score
                    } label: {
                        Text(symbol)
                            .font(AppFont.titleMedium)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(energy == score ? Color.gymPrimary : Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium))
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.medium)
                                    .stroke(energy == score ? Color.gymPrimary : Color.gymBorder, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.gymPress)
                    .accessibilityLabel("Feeling \(score) of 5")
                    .accessibilityAddTraits(energy == score ? .isSelected : [])
                }
            }
        }
    }

    private func selectionSection(_ title: LocalizedStringKey, values: [(String, Int)], selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title).font(AppFont.headline).foregroundStyle(Color.gymText)
            Picker(title, selection: selection) {
                Text("Not recorded").tag(0)
                ForEach(values, id: \.1) { value in Text(value.0).tag(value.1) }
            }
            .pickerStyle(.segmented)
            .accessibilityValue(selection.wrappedValue == 0 ? "Not recorded" : "\(selection.wrappedValue) of 5")
        }
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Current weight").font(AppFont.headline).foregroundStyle(Color.gymText)
                    Text("Your optional \(weightCadence == .weekly ? "weekly" : "monthly") measurement is due.")
                        .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                }
                Spacer()
                Button("Not now") { hidesWeightPrompt = true }
                    .font(AppFont.caption)
            }
            HStack(spacing: Spacing.m) {
                TextField("Weight", text: $weightValue)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("daily-check-in-weight")
                Picker("Unit", selection: $weightUnit) {
                    Text("kg").tag(WeightType.kg)
                    Text("lb").tag(WeightType.lbs)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 132)
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Note (optional)").font(AppFont.headline).foregroundStyle(Color.gymText)
            TextEditor(text: $note)
                .frame(minHeight: 104)
                .padding(Spacing.xs)
                .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium))
                .overlay { RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.gymBorder, lineWidth: 1) }
                .accessibilityIdentifier("daily-check-in-note")
        }
    }

    private var entryForDay: DailyLogEntry? { entries.first { $0.dayKey == day.rawValue } }
    private var latestWeight: BodyWeightEntry? { weightEntries.first }
    private var shouldShowWeightPrompt: Bool { !hidesWeightPrompt && weightCadence.isDue(latest: latestWeight) }
    private var hasWorkoutForDay: Bool {
        workouts.contains { $0.status == .completed && LocalDay(date: $0.startTime).rawValue == day.rawValue }
    }
    private var parsedWeight: Float? {
        guard let value = Float(weightValue.replacingOccurrences(of: ",", with: ".")), value > 0, value <= 1_500 else { return nil }
        return value
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
            let existing = weightEntries.first { $0.dayKey == day.rawValue }
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
