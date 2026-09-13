import SwiftData
import SwiftUI

struct ComplexComponentResultsView: View {
    let components: [ComplexComponentResult]
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("COMPONENTS")
                .font(AppFont.caption2Bold)
                .foregroundStyle(Color.trameSubdued)

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

    private static let outcomes: [ComplexComponentOutcome] = [.completed, .partial, .missed]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.s) {
                Text(component.exerciseNameSnapshot)
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.trameText)
                Text("×\(component.prescribedRepetitions)")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameSubdued)
                Spacer(minLength: Spacing.s)
                Menu {
                    Button("Skipped") { update(.skipped) }
                    Button("Clear", role: .destructive) { update(.notStarted) }
                } label: {
                    Image(systemName: AppIcon.ellipsis)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.trameSubdued)
                        .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
                }
                .accessibilityLabel("More outcomes for \(component.exerciseNameSnapshot)")
                .accessibilityIdentifier("complex-component-more-\(component.orderIndex)")
            }

            HStack(spacing: Spacing.s) {
                ForEach(Self.outcomes, id: \.self) { outcome in
                    outcomeButton(outcome)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(component.exerciseNameSnapshot), \(component.prescribedRepetitions) prescribed repetitions")
        .accessibilityValue(component.outcome.title)
    }

    private func outcomeButton(_ outcome: ComplexComponentOutcome) -> some View {
        let isSelected = component.outcome == outcome
        return Button {
            update(outcome)
        } label: {
            Text(outcome.title)
                .font(AppFont.footnoteMedium)
                .foregroundStyle(isSelected ? Color.trameText : Color.trameSubdued)
                .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                .background(isSelected ? Color.trameCurrent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.trameActionOutline : Color.trameSeparator,
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.gymPress)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Choose the component outcome")
        .accessibilityIdentifier(
            outcome == .completed
                ? "complex-component-\(component.orderIndex)"
                : "complex-component-\(component.orderIndex)-\(outcome.rawValue)"
        )
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
