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

struct GymChartCard<Content: View>: View {
    let title: String
    let evidence: String?
    let takeaway: String?
    let titleIdentifier: String?
    @ViewBuilder let content: Content

    init(
        title: String,
        evidence: String? = nil,
        takeaway: String? = nil,
        titleIdentifier: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.evidence = evidence
        self.takeaway = takeaway
        self.titleIdentifier = titleIdentifier
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
            }
        }
    }
}

struct GymChartSelectionAnnotation: View {
    let title: String
    let value: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
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
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .stroke(Color.gymPrimary.opacity(0.42), lineWidth: 1)
        }
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

struct GymPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.bodyMedium)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, Spacing.l)
            .background(Color.gymPrimary, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
            .animation(AppMotion.pressResponse, value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.45)
    }
}

extension ButtonStyle where Self == GymPrimaryButtonStyle {
    static var gymPrimary: GymPrimaryButtonStyle { GymPrimaryButtonStyle() }
}
