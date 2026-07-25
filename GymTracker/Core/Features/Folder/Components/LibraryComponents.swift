import SwiftData
import SwiftUI

struct LibraryBrowserList<Content: View>: View {
    let title: String
    @Binding var searchText: String
    @ViewBuilder let content: Content

    init(title: String, searchText: Binding<String>, @ViewBuilder content: () -> Content) {
        self.title = title
        _searchText = searchText
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.s) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.gymSubduedText)
                    TextField(String(localized: "Search \(NSLocalizedString(title.lowercased(), comment: ""))"), text: $searchText)
                }
                .padding(.horizontal, Spacing.m)
                .frame(height: 46)
                .background(Color.gymCard, in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: Spacing.md) {
                    content
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
            .padding(.bottom, 92)
        }
        .folderScreenStyle()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LibraryItemRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color
    let surface: Color
    var count: Int?
    var showsCard = true
    var showsChevron = true

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(surface, in: RoundedRectangle(cornerRadius: Radius.medium))
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.gymText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(Color.gymSubduedText).lineLimit(1)
                }
            }
            Spacer()
            if let count {
                Text("\(count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.gymSubduedText)
            }
            if showsChevron {
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Color.gymSubtleText)
            }
        }
        .padding(.horizontal, Spacing.l - 2)
        .padding(.vertical, showsCard ? Spacing.l - 2 : Spacing.md)
        .background {
            if showsCard {
                RoundedRectangle(cornerRadius: Radius.large)
                    .fill(Color.gymCard)
                    .stroke(Color.gymBorder, lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
    }
}

/// A workout row whose primary tap immediately starts a session, with the
/// workout editor demoted to a small trailing button. This mirrors the
/// one-tap-to-start behavior already used by `SavedWorkoutTemplatePicker`,
/// removing the extra "open detail → find Start" step from browse flows.
struct StartableWorkoutRow<RowContent: View, Editor: View>: View {
    let accessibilityName: String
    var isStartDisabled = false
    let onStart: () -> Void
    @ViewBuilder let rowContent: () -> RowContent
    @ViewBuilder let editor: () -> Editor

    var body: some View {
        HStack(spacing: Spacing.s) {
            Button(action: onStart) {
                rowContent()
            }
            .buttonStyle(.plain)
            .disabled(isStartDisabled)
            .accessibilityIdentifier("start-workout-\(accessibilityName)")
            .accessibilityHint(isStartDisabled
                ? "Add an exercise before starting this workout."
                : "Starts a new session from this workout.")

            NavigationLink {
                editor()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.gymSubduedText)
                    .frame(width: 38, height: 38)
                    .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.medium)
                            .stroke(Color.gymBorder, lineWidth: 1)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(accessibilityName)")
            .accessibilityIdentifier("edit-workout-\(accessibilityName)")
        }
    }
}

struct LibraryGroupCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .background {
            RoundedRectangle(cornerRadius: Radius.large)
                .fill(Color.gymCard)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.large))
    }
}

struct LibraryGroupDivider: View {
    var body: some View {
        Divider()
            .overlay(Color.gymBorder)
            .padding(.leading, 60)
    }
}

struct LibraryCreateRow: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    let icon: String

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.gymPrimary)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.gymPrimary)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(Color.gymSubduedText)
                }
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.l - 2)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }
}

struct LibraryListSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)
            Spacer()
            Text("\(count)")
                .font(AppFont.caption)
                .monospacedDigit()
                .foregroundStyle(Color.gymSubtleText)
        }
        .padding(.horizontal, Spacing.xxs)
        .padding(.top, Spacing.m)
    }
}

struct RecentLibraryRow: View {
    let title: String
    let type: LocalizedStringKey
    let icon: String
    let color: Color
    let surface: Color

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(surface, in: RoundedRectangle(cornerRadius: Radius.medium))

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.gymText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text(type)
                    .font(AppFont.caption2Bold)
                    .tracking(0.5)
                    .foregroundStyle(color)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppFont.captionBold)
                .foregroundStyle(Color.gymSubtleText)
        }
        .padding(.horizontal, Spacing.l - 2)
        .padding(.vertical, Spacing.m)
        .background {
            RoundedRectangle(cornerRadius: Radius.large)
                .fill(Color.gymCard)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
        .contentShape(Rectangle())
    }
}

struct LibrarySectionTitle: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(AppFont.captionBold)
            .tracking(0.8)
            .foregroundStyle(Color.gymSubduedText)
    }
}
