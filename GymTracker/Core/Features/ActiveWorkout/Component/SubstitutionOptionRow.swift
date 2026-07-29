import SwiftUI

/// One evaluated substitution option.
///
/// The row's whole job is to keep the two verdicts visually separate. They sit
/// on their own lines with their own glyph families, because collapsing them
/// into a single badge would recreate exactly the "one equivalence score"
/// this feature refuses to show.
struct SubstitutionOptionRow: View {
    let evaluation: SubstitutionEvaluation
    let isSelected: Bool
    let onSelect: () -> Void
    let onExplain: () -> Void

    private var suitability: SubstitutionSuitability { evaluation.suitability }
    private var comparability: SubstitutionComparability { evaluation.comparability }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                        Text(evaluation.exercise.name)
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(evaluation.isSelectable ? Color.gymText : Color.gymSubduedText)
                        Spacer(minLength: Spacing.s)
                        if isSelected {
                            Image(systemName: AppIcon.checkmarkCircle)
                                .foregroundStyle(Color.gymPrimary)
                                .accessibilityHidden(true)
                        }
                    }

                    Text(evaluation.exercise.subtitle)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)

                    verdictLine(
                        icon: SubstitutionPresentation.suitabilityIcon(suitability),
                        text: SubstitutionPresentation.suitabilityTitle(suitability),
                        color: SubstitutionPresentation.suitabilityColor(suitability)
                    )

                    verdictLine(
                        icon: SubstitutionPresentation.comparabilityIcon(comparability),
                        text: SubstitutionPresentation.comparabilityTitle(comparability),
                        color: SubstitutionPresentation.comparabilityColor(comparability)
                    )

                    if let blocked = evaluation.snapshot.hardFilterFailureCodes.first,
                       let reason = SubstitutionPresentation.hardFilterTitle(blocked) {
                        Text(reason)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymDestructive)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!evaluation.isSelectable)
            // Both verdicts are read as one statement so VoiceOver never
            // announces a fit without its history consequence.
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityIdentifier("swap-option-\(evaluation.exercise.name)")

            // A separate control, not a row tap: reading the reasoning must
            // never be the same gesture as accepting it.
            WhyButton(identifier: "swap-why-\(evaluation.exercise.name)", action: onExplain)
        }
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(isSelected ? Color.gymPrimary : Color.clear, lineWidth: 2)
        )
        .opacity(evaluation.isSelectable ? 1 : 0.6)
    }

    private func verdictLine(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(text)
                .font(AppFont.footnote)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accessibilityLabel: String {
        var parts = [
            evaluation.exercise.name,
            SubstitutionPresentation.suitabilityTitle(suitability),
            SubstitutionPresentation.comparabilityTitle(comparability)
        ]
        if let blocked = evaluation.snapshot.hardFilterFailureCodes.first,
           let reason = SubstitutionPresentation.hardFilterTitle(blocked) {
            parts.append(reason)
        }
        return parts.joined(separator: ", ")
    }
}
