import SwiftUI

#if !GYMTRACKER_EXTENSION

struct SavedWorkoutTemplatePicker: View {
    @Environment(\.dismiss) private var dismiss

    let templates: [WorkoutTemplate]
    let onStartWorkout: (WorkoutTemplate) -> Void

    var body: some View {
        List {
            if templates.isEmpty {
                ContentUnavailableView(
                    "No saved workouts",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("Create a saved workout in Library, then start it from here.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(templates, id: \.self) { template in
                    Button {
                        dismiss()
                        onStartWorkout(template)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                  Text(template.name)
                                      .font(AppFont.subheadlineBold)
                                      .foregroundStyle(Color.gymText)
                                  Text("\(template.exercises.count) exercises")
                                      .font(AppFont.caption)
                                      .foregroundStyle(Color.gymSubduedText)
                            }

                            Spacer()

                            Image(systemName: "play.circle.fill")
                                .font(AppFont.titleSmall)
                                .foregroundStyle(Color.gymPrimary)
                        }
                    }
                    .disabled(template.exercises.isEmpty)
                    .accessibilityIdentifier("workout-template-\(template.name)")
                    .accessibilityHint(template.exercises.isEmpty ? "Add an exercise before starting this workout." : "Starts a new session from this saved workout.")
                    .listRowBackground(Color.gymCard)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Start a saved workout")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

#endif
