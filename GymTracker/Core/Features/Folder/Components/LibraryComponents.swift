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
            LazyVStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.s) {
                    Image(systemName: AppIcon.search)
                        .foregroundStyle(Color.gymSubduedText)
                    TextField(String(localized: "Search \(NSLocalizedString(title.lowercased(), comment: ""))"), text: $searchText)
                }
                .padding(.horizontal, Spacing.m)
                .frame(height: 46)
                .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium))

                LazyVStack(alignment: .leading, spacing: Spacing.md) {
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

/// Marks bundled/seeded content (e.g. the starter workout program) so it
/// isn't mistaken for something the user created themselves.
struct BuiltInBadge: View {
    var text: String = "Starter"

    var body: some View {
        Text(text)
            .font(AppFont.captionBold)
            .tracking(0.3)
            .foregroundStyle(Color.gymSecondary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(Color.gymSecondarySurface, in: Capsule())
    }
}

struct LibraryItemRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color
    let surface: Color
    var count: Int?
    var badge: String? = nil
    var showsCard = true
    var showsChevron = true

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(surface, in: RoundedRectangle(cornerRadius: Radius.medium))
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text(title)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.gymText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    if let badge {
                        BuiltInBadge(text: badge)
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            if let count {
                Text("\(count)")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
            if showsChevron {
                Image(systemName: AppIcon.chevronRight).font(AppFont.captionBold).foregroundStyle(Color.gymSubduedText)
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
                Image(systemName: AppIcon.advanced)
                    .font(AppFont.subheadlineSemibold)
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
                .font(AppFont.bodyMedium)
                .foregroundStyle(Color.gymPrimary)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.gymPrimary)
                if let subtitle {
                    Text(subtitle).font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
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
                .foregroundStyle(Color.gymSubduedText)
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
                    .font(AppFont.captionBold)
                    .tracking(0.5)
                    .foregroundStyle(color)
            }

            Spacer()

            Image(systemName: AppIcon.chevronRight)
                .font(AppFont.captionBold)
                .foregroundStyle(Color.gymSubduedText)
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
