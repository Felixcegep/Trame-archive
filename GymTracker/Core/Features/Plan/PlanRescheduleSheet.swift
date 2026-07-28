import SwiftUI

/// The shared date picker behind every "move this session" affordance.
///
/// Save is the only path that dismisses: a rejected edit keeps the sheet open
/// with the user's chosen date intact, so a failed write never silently drops
/// what they picked.
struct PlanRescheduleSheet: View {
    @Environment(\.dismiss) private var dismiss

    let workoutName: String
    let confirmIdentifier: String
    /// Returns `false` when the edit was refused or could not be saved.
    let onSave: (Date) -> Bool

    @State private var date: Date
    @State private var errorMessage: String?

    init(
        workoutName: String,
        initialDate: Date?,
        confirmIdentifier: String,
        onSave: @escaping (Date) -> Bool
    ) {
        self.workoutName = workoutName
        self.confirmIdentifier = confirmIdentifier
        self.onSave = onSave
        _date = State(initialValue: initialDate ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Scheduled date", selection: $date, displayedComponents: .date)
                        .accessibilityIdentifier("plan-reschedule-date")
                } header: {
                    Text(workoutName)
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(Color.gymDestructive)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gymBackground)
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .accessibilityIdentifier(confirmIdentifier)
                }
            }
        }
    }

    private func save() {
        guard onSave(date) else {
            errorMessage = String(localized: "The workout could not be rescheduled. Try again.")
            return
        }
        dismiss()
    }
}
