import SwiftUI

/// A dense row inside Today's single grouped card.
///
/// Today used to stack one full-width bordered card per item across four
/// sections. Every item is a one-line status plus a tap target, so they share a
/// compact row instead: the card border and section heading are paid once by
/// `LibraryGroupCard`, not once per item.
struct TodayLogRow: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    let value: String
    var isComplete: Bool = false

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: isComplete ? AppIcon.checkmarkCircle : icon)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(isComplete ? Color.gymSecondary : iconColor)
                .frame(width: 34, height: 34)
                .background(
                    (isComplete ? Color.gymSecondary : iconColor).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: Radius.medium)
                )

            Text(title)
                .font(AppFont.bodyMedium)
                .foregroundStyle(Color.gymText)

            Spacer(minLength: Spacing.s)

            Text(value)
                .font(AppFont.caption)
                .foregroundStyle(isComplete ? Color.gymSecondary : Color.gymSubduedText)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)

            Image(systemName: AppIcon.chevronRight)
                .font(AppFont.captionBold)
                .foregroundStyle(Color.gymSubtleText)
        }
        .padding(.horizontal, Spacing.l - 2)
        .padding(.vertical, Spacing.m)
        .contentShape(Rectangle())
    }
}
