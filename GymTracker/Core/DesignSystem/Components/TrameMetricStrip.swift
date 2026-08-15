import SwiftUI

struct TrameMetricStripItem: Identifiable {
    let id: String
    let value: String
    let label: LocalizedStringKey
    let accessibilityLabel: String

    init(
        id: String? = nil,
        value: String,
        label: LocalizedStringKey,
        accessibilityLabel: String
    ) {
        self.id = id ?? "\(value)-\(label)"
        self.value = value
        self.label = label
        self.accessibilityLabel = accessibilityLabel
    }
}

struct TrameMetricStrip: View {
    let items: [TrameMetricStripItem]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Spacing.xxl) {
                content
            }

            VStack(alignment: .leading, spacing: Spacing.m) {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        ForEach(items) { item in
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(item.value)
                    .font(AppFont.metricCompact)
                    .foregroundStyle(Color.trameText)

                Text(item.label)
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.accessibilityLabel)
        }
    }
}
