import SwiftUI

enum GymCardVariant {
    case standard
    case current
    case completed
    case accent

    var background: Color {
        switch self {
        case .standard: Color.gymCard
        case .current: Color.gymCurrentSetSurface
        case .completed: Color.gymSecondarySurface
        case .accent: Color.gymAccentSurface
        }
    }

    var border: Color {
        switch self {
        case .current: Color.gymPrimary.opacity(0.42)
        case .standard, .completed, .accent: Color.gymBorder
        }
    }
}

struct GymCard<Content: View>: View {
    let variant: GymCardVariant
    let radius: CGFloat
    @ViewBuilder let content: Content

    init(
        variant: GymCardVariant = .standard,
        radius: CGFloat = Radius.card,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .background(variant.background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(variant.border, lineWidth: 1)
        }
    }
}

struct GymSectionHeader: View {
    let title: String
    var detail: String? = nil
    var systemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let systemImage {
                Label(title, systemImage: systemImage)
                    .font(AppFont.headlineSemibold)
            } else {
                Text(title)
                    .font(AppFont.headlineSemibold)
            }

            if let detail {
                Text(detail)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
        .foregroundStyle(Color.gymText)
    }
}

struct GymIconChip: View {
    let systemImage: String
    var tint: Color = .gymPrimary
    var shape: Shape = .roundedRectangle

    enum Shape {
        case circle
        case roundedRectangle
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(AppFont.subheadlineSemibold)
            .foregroundStyle(tint)
            .frame(width: ComponentSize.iconChip, height: ComponentSize.iconChip)
            .background {
                if shape == .circle {
                    Circle().fill(tint.opacity(0.12))
                } else {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .fill(tint.opacity(0.12))
                }
            }
            .accessibilityHidden(true)
    }
}

struct GymStatusBadge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(AppFont.captionBold)
            .foregroundStyle(tint)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(tint.opacity(0.12), in: Capsule())
            .accessibilityElement(children: .combine)
    }
}

struct GymMetricValue: View {
    let value: String
    let unit: String
    var isEstimate = false
    var prominence: Prominence = .standard

    enum Prominence {
        case standard
        case display
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text(isEstimate ? "≈\(value)" : value)
                .font(valueFont)
                .foregroundStyle(prominence == .display ? Color.gymPrimary : Color.gymText)
            if !unit.isEmpty {
                Text(unit)
                    .font(unitFont)
                    .foregroundStyle(Color.gymText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isEstimate ? "Approximately \(value) \(unit)" : "\(value) \(unit)")
    }

    private var valueFont: Font {
        prominence == .display ? AppFont.displayMedium : AppFont.subheadlineSemiboldMonospaced
    }

    private var unitFont: Font {
        prominence == .display ? AppFont.titleSmallSemibold : AppFont.subheadline
    }
}

struct AnalyticsInsightDisclosureView: View {
    let insight: AnalyticsInsight
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: isExpanded ? AppIcon.chevronDown : AppIcon.chevronRight)
                        .font(AppFont.caption2Bold)
                        .foregroundStyle(Color.gymSubduedText)
                    Text(buttonTitle)
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Evidence and methodology details")
            .accessibilityIdentifier("insight-details-toggle")

            if isExpanded {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    detailRow(
                        title: "Session count",
                        value: "\(insight.sessionCount) completed \(insight.sessionCount == 1 ? "session" : "sessions")"
                    )
                    detailRow(
                        title: "Comparison conditions",
                        value: insight.comparisonConditions
                    )
                    detailRow(
                        title: "Excluded evidence",
                        value: insight.excludedEvidence
                    )
                    detailRow(
                        title: "Calculation method",
                        value: insight.calculationMethod
                    )
                }
                .padding(.top, Spacing.xs)
                .padding(.leading, Spacing.s)
                .accessibilityIdentifier("insight-details-content")
            }
        }
        .padding(.top, Spacing.s)
    }

    private var buttonTitle: String {
        if let wordingTier = insight.wordingTier {
            return "\(wordingTier) · Evidence & method"
        } else {
            return "Evidence & method"
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(AppFont.captionBold)
                .foregroundStyle(Color.gymText)
            Text(value)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
    }
}

struct GymChartCard<Content: View>: View {
    let title: String
    let evidence: String?
    let takeaway: String?
    let titleIdentifier: String?
    let insight: AnalyticsInsight?
    @ViewBuilder let content: Content

    init(
        title: String,
        evidence: String? = nil,
        takeaway: String? = nil,
        titleIdentifier: String? = nil,
        insight: AnalyticsInsight? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.evidence = evidence
        self.takeaway = takeaway
        self.titleIdentifier = titleIdentifier
        self.insight = insight
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymSectionHeader(title: title, detail: evidence)
                .accessibilityIdentifier(titleIdentifier ?? title)
            GymCard {
                content
                if let takeaway {
                    Label(takeaway, systemImage: AppIcon.info)
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymText)
                }
                if let insight {
                    AnalyticsInsightDisclosureView(insight: insight)
                }
            }
        }
    }
}

struct GymChartSelectionAnnotation: View {
    let title: String
    let value: String
    var detail: String? = nil

    /// A line, not a box.
    ///
    /// This is only ever rendered inside `GymChartCard`'s `GymCard`, where it
    /// used to draw a second `gymCard` fill and a tinted stroke on top of the
    /// first — a card inside a card, in the same colour, to hold two short
    /// strings. Every analytics screen paid for that nesting: chart card,
    /// annotation card, evidence text, takeaway row. The selected reading is
    /// now a labelled value on the card it already belongs to, and the tinted
    /// rule mark on the chart is what says which point it refers to.
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Text(title)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)

            Text(value)
                .font(AppFont.captionSemiboldMonospaced)
                .foregroundStyle(Color.gymText)

            if let detail {
                Text(detail)
                    .font(AppFont.caption2)
                    .foregroundStyle(Color.gymSubduedText)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Uppercase tracked label that introduces a group inside a card. Smaller and
/// quieter than `GymSectionHeader`, so several groups can share one card
/// without competing with the screen title.
struct GymEyebrow: View {
    let title: LocalizedStringKey
    var tint: Color = .gymSubduedText

    init(_ title: LocalizedStringKey, tint: Color = .gymSubduedText) {
        self.title = title
        self.tint = tint
    }

    var body: some View {
        Text(title)
            .font(AppFont.caption2Bold)
            .textCase(.uppercase)
            .tracking(0.55)
            .foregroundStyle(tint)
    }
}

/// Read-only tag for a single attribute value. Tinted style carries meaning
/// (category, difficulty); outlined style is a quiet supporting value.
struct GymTagChip: View {
    enum Style {
        case tinted
        case outlined
    }

    let title: String
    var systemImage: String? = nil
    var tint: Color = .gymPrimary
    var style: Style = .tinted

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(AppFont.caption2Bold)
                    .accessibilityHidden(true)
            }
            Text(LocalizedStringKey(title))
                .font(AppFont.captionBold)
        }
        .foregroundStyle(style == .tinted ? tint : Color.gymSubduedText)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.s)
        .background {
            if style == .tinted {
                Capsule().fill(tint.opacity(0.12))
            } else {
                Capsule().stroke(Color.gymBorder, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Wrapping row layout for chips and tags. A row breaks when the next subview
/// would overflow the proposed width.
struct ChipFlowLayout: Layout {
    var spacing: CGFloat = Spacing.s

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: proposal.width ?? x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Emoji-led tile for a small set of mutually exclusive choices. Selection is
/// carried by a tinted surface plus a heavier border and a checkmark, never by
/// color alone.
struct GymChoiceTile: View {
    let emoji: String
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Text(emoji)
                    .font(AppFont.titleSmall)
                Text(title)
                    .font(AppFont.footnoteMedium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(Color.gymText)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, Spacing.m)
            .background(
                isSelected ? Color.gymPrimarySurface : Color.gymCard,
                in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .stroke(isSelected ? Color.gymPrimary : Color.gymBorder, lineWidth: isSelected ? 1.5 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: AppIcon.checkmarkCircle)
                        .font(AppFont.caption2Bold)
                        .foregroundStyle(Color.gymPrimary)
                        .padding(Spacing.xs)
                }
            }
        }
        .buttonStyle(.gymPress)
        .accessibilityLabel(title)
        .accessibilityIdentifier(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension View {
    /// Text-field chrome for the warm palette. `.roundedBorder` renders a gray
    /// system border that reads as foreign against the cream background.
    func gymFieldStyle() -> some View {
        frame(minHeight: ComponentSize.minimumTouchTarget)
            .padding(.horizontal, Spacing.m)
            .background(
                Color.gymRowSurface,
                in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
            )
    }
}

/// The app's one filled action.
///
/// Four screens previously hand-rolled this — `.buttonStyle(.plain)` plus a
/// manual fill, corner radius, and `padding(.vertical, 17)` — which is why the
/// bottom-bar buttons and the styled ones had drifted apart in height, font,
/// and disabled behaviour. `prominence` covers the one real difference between
/// them: a bottom-bar call to action is taller and bolder than an inline one.
struct GymPrimaryButtonStyle: ButtonStyle {
    enum Prominence {
        /// Inline. 44pt.
        case standard
        /// A screen's committing action, in a bottom bar or an empty state.
        case prominent
    }

    var prominence: Prominence = .standard

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(prominence == .prominent ? AppFont.headline : AppFont.bodyMedium)
            // Disabled is an outline, not a faded fill. White on a 45%-opacity
            // blue computed to about 1.9:1 — the label was the least legible
            // text on screen at the moment it most needed to explain itself.
            .foregroundStyle(isEnabled ? Color.white : Color.gymSubduedText)
            .frame(
                maxWidth: .infinity,
                minHeight: prominence == .prominent ? 54 : ComponentSize.minimumTouchTarget
            )
            .padding(.horizontal, Spacing.l)
            .background {
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    // `gymPrimaryDeep`, not `gymPrimary`: white on the latter is
                    // 4.46:1, which misses AA for the 17pt label this carries.
                    .fill(isEnabled ? Color.gymPrimaryDeep : Color.clear)
            }
            .overlay {
                if !isEnabled {
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .stroke(Color.gymBorder, lineWidth: 1)
                }
            }
            // The same Weighted Pulse the plain press style uses. It was a
            // near-copy of that logic before, which is how the two drifted:
            // this one never dimmed, so the app's most prominent button gave
            // the *weakest* press response.
            .weightedPulse(isPressed: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GymPrimaryButtonStyle {
    static var gymPrimary: GymPrimaryButtonStyle { GymPrimaryButtonStyle() }
    static var gymPrimaryProminent: GymPrimaryButtonStyle {
        GymPrimaryButtonStyle(prominence: .prominent)
    }
}

/// The app's one *alternative* action: same shape and weight as the filled
/// button, outlined instead of filled.
///
/// It exists because the app had no way to say "this is also a real choice, but
/// it is not the recommended one". A screen offering two full-width actions had
/// to draw both with `gymPrimary`, and two identical blue capsules stacked on
/// top of each other is not a hierarchy — it is a coin toss. Reaching for
/// `.bordered` instead would have solved the weight and broken the shape,
/// leaving the pair looking like controls from two different apps.
///
/// Match `prominence` to the primary it sits beneath so the two capsules are
/// the same height.
///
/// Named for the treatment rather than for rank: `Color.gymSecondary` is the
/// palette's *green*, and a `gymSecondary` button style sitting next to it
/// while rendering blue would be a trap for the next person to read either one.
struct GymOutlineButtonStyle: ButtonStyle {
    var prominence: GymPrimaryButtonStyle.Prominence = .standard

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(prominence == .prominent ? AppFont.headline : AppFont.bodyMedium)
            .foregroundStyle(isEnabled ? Color.gymPrimary : Color.gymSubduedText)
            .frame(
                maxWidth: .infinity,
                minHeight: prominence == .prominent ? 54 : ComponentSize.minimumTouchTarget
            )
            .padding(.horizontal, Spacing.l)
            .background {
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .fill(Color.gymCard)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .stroke(isEnabled ? Color.gymPrimary.opacity(0.35) : Color.gymBorder, lineWidth: 1)
            }
            .weightedPulse(isPressed: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GymOutlineButtonStyle {
    static var gymOutline: GymOutlineButtonStyle { GymOutlineButtonStyle() }
    static var gymOutlineProminent: GymOutlineButtonStyle {
        GymOutlineButtonStyle(prominence: .prominent)
    }
}
