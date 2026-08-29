import SwiftUI

/// The final step of a swap: state plainly what accepting will do, then let
/// the lifter accept it.
///
/// Three rules this screen enforces:
///
/// 1. **Today-only is preselected.** Changing the plan is a deliberate second
///    choice, never the path of least resistance.
/// 2. **Shared progression is only offered when comparability is `direct`,**
///    and even then it is opt-in. It is never preselected, because continuing
///    a load progression across two different exercises is a claim the lifter
///    should make, not the app.
/// 3. **Nothing is converted.** No load is translated, no plan is rewritten
///    silently, and the original exercise's own progression is untouched.
struct SubstitutionConfirmationView: View {
    let originalName: String
    let evaluation: SubstitutionEvaluation
    let reason: SubstitutionReason
    @Binding var scope: SubstitutionScope
    @Binding var progressionPolicy: ProgressionTransferPolicy
    let onExplain: () -> Void
    let onConfirm: () -> Void

    private var canOfferSharedProgression: Bool {
        evaluation.comparability.allowsSharedProgression
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(headline)
                        .font(AppFont.headlineSemibold)
                        .foregroundStyle(Color.trameText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(SubstitutionPresentation.suitabilityTitle(evaluation.suitability))
                        .font(AppFont.footnote)
                        .foregroundStyle(SubstitutionPresentation.suitabilityColor(evaluation.suitability))
                    Text(SubstitutionPresentation.comparabilityTitle(evaluation.comparability))
                        .font(AppFont.footnote)
                        .foregroundStyle(SubstitutionPresentation.comparabilityColor(evaluation.comparability))
                }
                .accessibilityElement(children: .combine)

                WhyButton(identifier: "swap-confirm-why", action: onExplain)
            }

            Section {
                Text(SubstitutionPresentation.comparabilityDetail(evaluation.comparability))
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.trameSubdued)
                Text(prescriptionEffect)
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.trameSubdued)
            } header: {
                Text("What changes")
            }

            Section {
                scopeRow(
                    .todayOnly,
                    title: String(localized: "substitution.scope.todayOnly", defaultValue: "Just today"),
                    identifier: "swap-scope-today"
                )
                scopeRow(
                    .futurePlan,
                    title: String(localized: "substitution.scope.futurePlan", defaultValue: "Replace in my plan"),
                    identifier: "swap-scope-future"
                )
            } header: {
                Text("How far this applies")
            } footer: {
                Text(SubstitutionPresentation.scopeEffect(scope))
            }

            Section {
                if canOfferSharedProgression {
                    Toggle(isOn: sharedProgressionBinding) {
                        Text("Continue progression from \(originalName)")
                            .font(AppFont.body)
                    }
                    .accessibilityIdentifier("swap-share-progression")
                } else {
                    Text(SubstitutionPresentation.progressionEffect(progressionPolicy))
                        .font(AppFont.footnote)
                        .foregroundStyle(Color.trameSubdued)
                }
            } header: {
                Text("Progression")
            } footer: {
                if canOfferSharedProgression {
                    Text(SubstitutionPresentation.progressionEffect(progressionPolicy))
                }
            }

            Section {
                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .font(AppFont.bodyMedium)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("swap-confirm")
            }
        }
        .navigationTitle("Confirm swap")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("substitution-confirmation")
    }

    private var headline: String {
        let format = String(
            localized: "substitution.confirm.headline",
            defaultValue: "Replace %@ with %@"
        )
        return String(format: format, originalName, evaluation.exercise.name)
    }

    private var confirmTitle: String {
        switch scope {
        case .todayOnly:
            return String(localized: "substitution.confirm.todayOnly", defaultValue: "Swap for today")
        case .futurePlan:
            return String(localized: "substitution.confirm.futurePlan", defaultValue: "Preview plan change")
        }
    }

    /// The prescription is retained in both cases — the sets, reps, and rest
    /// the lifter was given do not change just because the implement did.
    private var prescriptionEffect: String {
        String(
            localized: "substitution.confirm.prescription",
            defaultValue: "Your sets, reps, and rest stay as prescribed. Any sets you haven't completed are reset for the new exercise."
        )
    }

    private var sharedProgressionBinding: Binding<Bool> {
        Binding(
            get: { progressionPolicy == .continueShared },
            set: { progressionPolicy = $0 ? .continueShared : .separate }
        )
    }

    private func scopeRow(_ value: SubstitutionScope, title: String, identifier: String) -> some View {
        Button {
            scope = value
            // Changing the plan is a plan edit, not a history claim: it must
            // never carry a progression-transfer choice along with it.
            if value == .futurePlan, progressionPolicy == .continueShared {
                progressionPolicy = .separate
            }
        } label: {
            HStack {
                Text(title)
                    .font(AppFont.body)
                    .foregroundStyle(Color.trameText)
                Spacer(minLength: Spacing.s)
                if scope == value {
                    Image(systemName: AppIcon.checkmark)
                        .foregroundStyle(Color.trameStrength)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(scope == value ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(identifier)
    }
}
