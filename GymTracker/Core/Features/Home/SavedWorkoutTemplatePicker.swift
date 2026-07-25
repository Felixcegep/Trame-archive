import SwiftUI
import SwiftData

#if !GYMTRACKER_EXTENSION

struct SavedWorkoutTemplatePicker: View {
    @Environment(\.dismiss) private var dismiss

    let templates: [WorkoutTemplate]
    let onStartWorkout: (WorkoutTemplate) -> Void
    let onStartEmpty: () -> Void

    var body: some View {
        List {
            Section {
                if templates.isEmpty {
                    ContentUnavailableView(
                        "No saved workouts",
                        systemImage: "rectangle.stack.badge.plus",
                        description: Text("Create a saved workout in Library, or start an empty one below.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(templates, id: \.persistentModelID) { template in
                        Button {
                            dismiss()
                            onStartWorkout(template)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                      HStack(spacing: Spacing.xs) {
                                          Text(template.name)
                                              .font(AppFont.subheadlineBold)
                                              .foregroundStyle(Color.gymText)
                                          if template.isBuiltIn {
                                              BuiltInBadge()
                                          }
                                      }
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

            Section {
                Button {
                    dismiss()
                    onStartEmpty()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Start empty workout")
                                .font(AppFont.subheadlineBold)
                                .foregroundStyle(Color.gymText)
                            Text("Add exercises as you go")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                        }

                        Spacer()

                        Image(systemName: "plus.circle.fill")
                            .font(AppFont.titleSmall)
                            .foregroundStyle(Color.gymSecondary)
                    }
                }
                .accessibilityIdentifier("start-empty-workout")
                .accessibilityHint("Starts a new session with no exercises.")
                .listRowBackground(Color.gymCard)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Start a workout")
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
