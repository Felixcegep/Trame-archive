import SwiftUI

/// One reusable explanation surface for any decision the app presents.
///
/// This is the shared "Why?" component from FeaturesList.md 2c, introduced
/// here by decision-aware substitution and intended for adoption by the
/// progression receipt and prescription rows next. Its contract is the six
/// sections below: what is being explained, why it was suggested, what
/// differs, what it does to history, what it does to the plan, and how
/// confident the app is — including what evidence is *missing*.
///
/// It renders caller-supplied localized strings only. There is no text
/// generation here and no per-surface bespoke copy: a surface that needs a
/// different shape of explanation should extend this model rather than build
/// its own sheet.
struct WhyExplanationModel: Equatable {
    /// One section. Its heading, order, and emphasis all come from its `kind`
    /// — there is deliberately no way for a caller to supply them, which is
    /// what keeps the vocabulary shared rather than per-surface. Construct
    /// these through `WhyExplanationBuilder`.
    struct Section: Equatable, Identifiable {
        let kind: WhyExplanationSectionKind
        /// Rendered as a bulleted list when populated.
        let items: [String]
        /// Rendered as a paragraph when populated.
        let body: String?

        var id: String { kind.rawValue }
        var title: String { kind.title }
        var emphasis: WhyExplanationEmphasis { kind.emphasis }

        init(
            kind: WhyExplanationSectionKind,
            items: [String] = [],
            body: String? = nil
        ) {
            self.kind = kind
            self.items = items
            self.body = body
        }

        var isEmpty: Bool { items.isEmpty && (body?.isEmpty ?? true) }
    }

    let title: String
    let subtitle: String?
    let sections: [Section]

    /// Empty sections are dropped rather than rendered as blank headings, so a
    /// sparse explanation stays honest instead of looking broken.
    var visibleSections: [Section] { sections.filter { !$0.isEmpty } }
}

struct WhyExplanationView: View {
    @Environment(\.dismiss) private var dismiss

    let model: WhyExplanationModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    if let subtitle = model.subtitle {
                        Text(subtitle)
                            .font(AppFont.subheadline)
                            .foregroundStyle(Color.gymSubduedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(model.visibleSections) { section in
                        sectionView(section)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.l)
            }
            .background(Color.gymBackground.ignoresSafeArea())
            .navigationTitle(model.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                    }
                    .accessibilityIdentifier("why-explanation-done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func sectionView(_ section: WhyExplanationModel.Section) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(section.title)
                .font(AppFont.headlineSemibold)
                .foregroundStyle(color(for: section.emphasis))

            if let body = section.body, !body.isEmpty {
                Text(body)
                    .font(AppFont.body)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(section.items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                    Image(systemName: AppIcon.circleFill)
                        .font(AppFont.caption2)
                        .foregroundStyle(Color.gymSubtleText)
                        .accessibilityHidden(true)
                    Text(item)
                        .font(AppFont.body)
                        .foregroundStyle(Color.gymText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.card))
        // The whole section reads as one unit; without this each bullet
        // becomes a separate VoiceOver stop with no heading context.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("why-section-\(section.id)")
    }

    private func color(for emphasis: WhyExplanationEmphasis) -> Color {
        switch emphasis {
        case .neutral: return .gymText
        case .positive: return .gymSecondary
        case .caution: return .gymAccent
        case .subdued: return .gymSubduedText
        }
    }
}
