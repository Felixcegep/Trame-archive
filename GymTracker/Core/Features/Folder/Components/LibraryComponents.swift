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
                .background(Color.trameSurface, in: RoundedRectangle(cornerRadius: Radius.field))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.field)
                        .stroke(Color.trameSeparator)
                }

                LazyVStack(alignment: .leading, spacing: Spacing.md) {
                    content
                }
            }
            .padding(.horizontal, Spacing.screenInset)
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
            .font(AppFont.micro)
            .tracking(0.3)
            .foregroundStyle(Color.trameText)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(Color.trameRow, in: Capsule())
    }
}

struct LibraryItemRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color
    var count: Int?
    var badge: String? = nil
    var showsChevron = true

    var body: some View {
        HStack(spacing: Spacing.m) {
            TrameCategoryTile(systemImage: icon, fill: color)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text(title)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.trameText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    if let badge {
                        BuiltInBadge(text: badge)
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.trameSubdued)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            if let count {
                Text("\(count)")
                    .font(AppFont.metadata)
                    .monospacedDigit()
                    .foregroundStyle(Color.trameSubdued)
            }
            if showsChevron {
                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)
            }
        }
        .padding(.vertical, Spacing.md)
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.trameSeparator)
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
                    .foregroundStyle(Color.trameSubdued)
                    .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(accessibilityName)")
            .accessibilityIdentifier("edit-workout-\(accessibilityName)")
        }
    }
}

/// Rows grouped by alignment and structural rules, without a container card.
struct LibraryOpenGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .foregroundStyle(Color.trameStrength)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.trameText)
                if let subtitle {
                    Text(subtitle).font(AppFont.metadata).foregroundStyle(Color.trameSubdued)
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
                .font(AppFont.eyebrow)
                .tracking(0.8)
                .foregroundStyle(Color.trameSubdued)
            Spacer()
            Text("\(count)")
                .font(AppFont.metadata)
                .monospacedDigit()
                .foregroundStyle(Color.trameSubdued)
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

    var body: some View {
        HStack(spacing: Spacing.m) {
            TrameCategoryTile(systemImage: icon, fill: color)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.trameText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text(type)
                    .font(AppFont.micro)
                    .tracking(0.5)
                    .foregroundStyle(Color.trameSubdued)
            }

            Spacer()

            Image(systemName: AppIcon.chevronRight)
                .font(AppFont.micro)
                .foregroundStyle(Color.trameSubdued)
        }
        .padding(.vertical, Spacing.md)
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.trameSeparator)
        }
        .contentShape(Rectangle())
    }
}

struct LibrarySectionTitle: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(AppFont.eyebrow)
            .tracking(0.8)
            .foregroundStyle(Color.trameSubdued)
    }
}
