import SwiftData
import SwiftUI

struct DailyCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let day: LocalDay
    let onSaved: () -> Void

    @Query private var entries: [DailyLogEntry]
    @State private var sleepQuality = 0
    @State private var energy = 0
    @State private var workoutDifficulty = 0
    @State private var note = ""
    @State private var hasLoaded = false
    @State private var saveError: ValidationIssue?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    scorePicker("Sleep quality", selection: $sleepQuality)
                    scorePicker("Energy", selection: $energy)
                    scorePicker("Workout difficulty", selection: $workoutDifficulty)
                } footer: {
                    Text("All questions are optional. This check-in never changes your workout automatically.")
                }

                Section("Note") {
                    TextEditor(text: $note)
                        .frame(minHeight: 112)
                        .accessibilityIdentifier("daily-check-in-note")
                }

                Section {
                    Button("Skip today") { save(status: .skipped) }
                        .foregroundStyle(Color.gymSubduedText)
                        .accessibilityIdentifier("daily-check-in-skip")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gymBackground)
            .navigationTitle("Daily check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(status: .completed) }
                        .accessibilityIdentifier("daily-check-in-save")
                }
            }
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            guard let entry = entryForDay else { return }
            sleepQuality = entry.sleepQuality ?? 0
            energy = entry.energy ?? 0
            workoutDifficulty = entry.workoutDifficulty ?? 0
            note = entry.note ?? ""
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

    private var entryForDay: DailyLogEntry? {
        entries.first { $0.dayKey == day.rawValue }
    }

    private func scorePicker(_ title: String, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            Text("Not recorded").tag(0)
            ForEach(1...5, id: \.self) { score in
                Text("\(score) of 5").tag(score)
            }
        }
        .accessibilityValue(selection.wrappedValue == 0 ? "Not recorded" : "\(selection.wrappedValue) of 5")
    }

    private func save(status: DailyCheckInStatus) {
        let entry = entryForDay ?? DailyLogEntry(day: day)
        entry.update(
            status: status,
            sleepQuality: sleepQuality == 0 ? nil : sleepQuality,
            energy: energy == 0 ? nil : energy,
            workoutDifficulty: workoutDifficulty == 0 ? nil : workoutDifficulty,
            note: note
        )
        if entryForDay == nil { modelContext.insert(entry) }
        do {
            try modelContext.save()
            onSaved()
            dismiss()
        } catch {
            saveError = ValidationIssue(
                severity: .error,
                message: "Your answers are still here. Please try saving again."
            )
        }
    }
}
