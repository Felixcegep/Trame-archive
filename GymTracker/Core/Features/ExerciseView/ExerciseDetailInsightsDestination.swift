import SwiftData
import SwiftUI

struct ExerciseDetailInsightsDestination: View {
    @Environment(\.modelContext) private var modelContext

    let exercise: Exercise

    @State private var model: ExerciseDetailInsightsModel?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let model {
                ExerciseDetailInsightsView(model: model)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Insights unavailable",
                    systemImage: AppIcon.warning,
                    description: Text(errorMessage)
                )
                .accessibilityIdentifier("exercise-insights-error")
            } else {
                ProgressView("Loading insights…")
                    .tint(Color.gymPrimary)
                    .accessibilityIdentifier("exercise-insights-loading")
            }
        }
        .task {
            guard model == nil, errorMessage == nil else { return }
            do {
                model = try ExerciseDetailInsightsBuilder.make(for: exercise, using: modelContext)
            } catch {
                errorMessage = "Completed workout history could not be loaded."
            }
        }
    }
}
