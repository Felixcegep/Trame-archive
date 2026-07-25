import SwiftData
import SwiftUI

struct ComplexComponentResultsView: View {
    let components: [ComplexComponentResult]
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("COMPLEX")
                .font(AppFont.caption2Bold)
                .foregroundStyle(Color.gymSubduedText)

            ForEach(components, id: \.persistentModelID) { component in
                ComplexComponentResultRow(component: component, onChange: onChange)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Complex component results")
    }
}

private struct ComplexComponentResultRow: View {
    @Bindable var component: ComplexComponentResult
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(component.exerciseNameSnapshot)
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.gymText)
                Text("×\(component.prescribedRepetitions)")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }

            Spacer(minLength: Spacing.s)

            Menu {
                Button("Made") { update(.completed) }
                Button("Partial") { update(.partial) }
                Button("Missed") { update(.missed) }
                Button("Skipped") { update(.skipped) }
                Button("Clear", role: .destructive) { update(.notStarted) }
            } label: {
                Label(component.outcome.title, systemImage: icon)
                    .font(AppFont.captionBold)
                    .foregroundStyle(color)
                    .frame(minHeight: 44)
            }
            .accessibilityLabel("\(component.exerciseNameSnapshot), \(component.prescribedRepetitions) prescribed repetitions")
            .accessibilityValue(component.outcome.title)
            .accessibilityHint("Choose the component outcome")
            .accessibilityIdentifier("complex-component-\(component.orderIndex)")
        }
    }

    private var icon: String {
        switch component.outcome {
        case .notStarted: AppIcon.circle
        case .completed: AppIcon.checkmarkCircle
        case .partial: AppIcon.timer
        case .missed: AppIcon.failureCircle
        case .skipped: AppIcon.skip
        }
    }

    private var color: Color {
        switch component.outcome {
        case .completed: Color.gymSecondary
        case .missed: Color.gymDestructive
        case .notStarted, .partial, .skipped: Color.gymPrimary
        }
    }

    private func update(_ outcome: ComplexComponentOutcome) {
        component.outcome = outcome
        switch outcome {
        case .notStarted:
            component.performedRepetitions = 0
            component.liftQuality = nil
        case .completed:
            component.performedRepetitions = component.prescribedRepetitions
            component.liftQuality = .acceptable
        case .partial:
            component.performedRepetitions = max(0, component.prescribedRepetitions - 1)
            component.liftQuality = .technicallyPoor
        case .missed:
            component.performedRepetitions = 0
            component.liftQuality = .missed
        case .skipped:
            component.performedRepetitions = 0
            component.liftQuality = nil
        }
        onChange()
    }
}
