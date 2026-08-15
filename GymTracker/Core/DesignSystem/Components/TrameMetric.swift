import SwiftUI

/// One answer-sized value with direct context and a complete spoken equivalent.
struct TrameMetric: View {
    let value: String
    let label: LocalizedStringKey
    var unit: LocalizedStringKey? = nil
    let accessibilityLabel: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Text(value)
                .font(AppFont.metricHero)
                .foregroundStyle(Color.trameText)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(label)
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)

                if let unit {
                    Text(unit)
                        .font(AppFont.micro)
                        .foregroundStyle(Color.trameSubdued)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}
