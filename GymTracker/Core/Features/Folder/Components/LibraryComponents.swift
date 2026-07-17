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

struct LibraryCategoryRow: View {
    let title: String
    let subtitle: String
    let count: Int
    let icon: String
    let color: Color
    let surface: Color

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(surface, in: RoundedRectangle(cornerRadius: Radius.medium))
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(.body.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(Color.gymSubduedText)
            }
            Spacer()
            Text("\(count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.gymSubduedText)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.gymSubtleText)
        }
        .padding(Spacing.l - 2)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.large))
        .overlay { RoundedRectangle(cornerRadius: Radius.large).stroke(Color.gymBorder, lineWidth: 1) }
    }
}

struct LibraryItemRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let surface: Color
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
                Text(subtitle).font(.caption).foregroundStyle(Color.gymSubduedText).lineLimit(1)
            }
            Spacer()
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
