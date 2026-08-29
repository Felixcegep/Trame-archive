import SwiftUI

struct PerformanceComparisonView: View {
    let comparison: WorkoutPerformanceComparison

    var body: some View {
        if comparison.hasTargets {
            TrameColorField(fill: .trameSurface, ink: .trameText, border: .trameCompleted, radius: Radius.field) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                HStack {
                    Text("Planned vs performed")
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.trameText)
                    Spacer()
                    statusLabel(comparison.overall)
                }

                comparisonRow("Planned", value: comparison.plannedSummary)
                comparisonRow("Performed", value: comparison.performedSummary)
                if let recommendation = comparison.recommendationSummary {
                    comparisonRow("Suggested", value: recommendation)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.s) {
                        dimensionLabels
                    }
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        dimensionLabels
                    }
                }
                }
                .padding(Spacing.m)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityIdentifier("performance-comparison")
        }
    }

    @ViewBuilder
    private var dimensionLabels: some View {
        ForEach(comparison.dimensions) { dimension in
            Label("\(dimension.name): \(dimension.status.title)", systemImage: icon(for: dimension.status))
                .font(AppFont.caption)
                .foregroundStyle(color(for: dimension.status))
        }
    }

    private func comparisonRow(_ label: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(AppFont.captionSemiboldMonospaced)
                .foregroundStyle(Color.trameText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statusLabel(_ status: PerformanceComparisonStatus) -> some View {
        GymStatusBadge(
            title: status.title,
            systemImage: icon(for: status),
            tint: color(for: status)
        )
    }

    private func icon(for status: PerformanceComparisonStatus) -> String {
        switch status {
        case .below: return AppIcon.warningCircle
        case .met: return AppIcon.checkmarkCircle
        case .above: return AppIcon.progression
        case .noTarget: return AppIcon.info
        }
    }

    private func color(for status: PerformanceComparisonStatus) -> Color {
        switch status {
        case .below: return Color.trameAttention
        case .met: return Color.trameCompleted
        case .above: return Color.trameStrength
        case .noTarget: return Color.trameSubdued
        }
    }

    private var accessibilitySummary: String {
        let dimensions = comparison.dimensions
            .map { "\($0.name): \($0.status.title)" }
            .joined(separator: ", ")
        return "Planned versus performed: \(comparison.overall.title). Planned: \(comparison.plannedSummary). Performed: \(comparison.performedSummary). \(dimensions)"
    }
}
