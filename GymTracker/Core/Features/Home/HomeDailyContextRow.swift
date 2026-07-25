import SwiftUI

struct HomeDailyContextRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let detail: String
    let completion: Bool
    var showsDisclosure: Bool = true

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: completion ? "checkmark.circle.fill" : icon)
                .font(AppFont.headline)
                .frame(width: 38, height: 38)
                .foregroundStyle(completion ? Color.gymSecondary : iconColor)
                .background((completion ? Color.gymSecondary : iconColor).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppFont.subheadlineSemibold)
                Text(detail)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }

            Spacer()

            if completion || showsDisclosure {
                Image(systemName: completion ? "checkmark" : "chevron.right")
                    .font(AppFont.captionBold)
                    .foregroundStyle(completion ? Color.gymSecondary : Color.gymSubduedText)
            }
        }
        .padding(Spacing.m)
        .background(Color.gymCard)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }
}
