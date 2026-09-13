import SwiftUI

enum MobilityFocus: String, CaseIterable, Identifiable {
    case hips = "Hips"
    case shoulders = "Shoulders"
    case spine = "Spine"
    case ankles = "Ankles"
    case hamstrings = "Hamstrings"
    case chest = "Chest"
    case wrists = "Wrists"
    case neck = "Neck"

    var id: Self { self }

    /// Seeded `MobilityFamily` names that belong to this region chip.
    var familyNames: [String] {
        switch self {
        case .hips: ["Hip mobility"]
        case .shoulders: ["Shoulder mobility"]
        case .spine: ["Thoracic & Spine mobility"]
        case .ankles: ["Ankle & Calf mobility"]
        case .hamstrings: ["Hamstrings & Posterior Chain"]
        case .chest: ["Chest & Lat mobility"]
        case .wrists: ["Wrist & Forearm mobility"]
        case .neck: ["Neck & Upper Traps"]
        }
    }

    func matches(_ definition: MobilityDefinition) -> Bool {
        guard let familyName = definition.family?.name,
              familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else {
            return false
        }
        return familyNames.contains {
            $0.compare(familyName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }
}

struct MobilityFilterState: Equatable {
    var focus: MobilityFocus?
    var tracking: MobilityTrackingType?
    var favoritesOnly = false

    var activeFilterCount: Int {
        [focus != nil, tracking != nil, favoritesOnly].filter(\.self).count
    }

    mutating func clear() {
        self = MobilityFilterState()
    }

    func matches(_ definition: MobilityDefinition, searchText: String) -> Bool {
        if let tracking, definition.trackingType != tracking { return false }
        if favoritesOnly && definition.isFavorite == false { return false }
        if let focus, focus.matches(definition) == false { return false }

        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedSearch.isEmpty == false else { return true }

        return SearchNormalization.matches(
            query: normalizedSearch,
            primaryName: definition.name,
            aliases: searchAliases(for: definition)
        )
    }

    private func searchAliases(for definition: MobilityDefinition) -> [String] {
        [
            definition.family?.name,
            definition.instructions,
            definition.trackingType.displayName,
            MobilityFocus.allCases.first { $0.matches(definition) }?.rawValue
        ]
        .compactMap { $0 }
    }
}

struct MobilityFilterControls: View {
    @Environment(\.dismissSearch) private var dismissSearch

    @Binding var filter: MobilityFilterState
    let resultCount: Int

    @State private var isShowingFilters = false

    var body: some View {
        HStack(spacing: Spacing.s) {
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.s) {
                    focusButton(title: "All", focus: nil)

                    ForEach(MobilityFocus.allCases) { focus in
                        focusButton(title: focus.rawValue, focus: focus)
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
            .scrollIndicators(.hidden)

            Button {
                dismissSearch()
                isShowingFilters = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text("REFINE")
                        .font(AppFont.eyebrow)
                        .tracking(0.6)

                    if filter.activeFilterCount > 0 {
                        Text(filter.activeFilterCount.formatted())
                            .font(AppFont.micro)
                            .monospacedDigit()
                    }
                }
                .foregroundStyle(Color.trameText)
                .padding(.horizontal, Spacing.s)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(filter.activeFilterCount > 0 ? Color.trameMobility : Color.trameSeparator)
                        .frame(height: filter.activeFilterCount > 0 ? 2 : 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mobility-filters-button")
            .accessibilityLabel("Filters, \(filter.activeFilterCount) active")
        }
        .sheet(isPresented: $isShowingFilters) {
            NavigationStack {
                MobilityFiltersSheet(filter: $filter, resultCount: resultCount)
            }
            .presentationDetents([.large])
        }
    }

    private func focusButton(title: String, focus: MobilityFocus?) -> some View {
        let isSelected = filter.focus == focus

        return Button {
            filter.focus = focus
        } label: {
            Text(LocalizedStringKey(title))
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(isSelected ? Color.trameText : Color.trameSubdued)
                .padding(.horizontal, Spacing.s)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isSelected ? Color.trameMobility : Color.clear)
                        .frame(height: 2)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mobility-focus-\(focus?.rawValue ?? "All")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MobilityFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: MobilityFilterState
    let resultCount: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                singleChipSection(
                    title: "Focus",
                    values: MobilityFocus.allCases,
                    label: \.rawValue,
                    selection: $filter.focus
                )

                singleChipSection(
                    title: "Tracking",
                    values: MobilityTrackingType.allCases,
                    label: \.displayName,
                    selection: $filter.tracking
                )

                Toggle("Favorites only", isOn: $filter.favoritesOnly)
                    .font(AppFont.bodyMedium)
                    .tint(Color.trameMobility)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.trameSeparator)
                            .frame(height: 1)
                    }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .background(Color.trameCanvas)
        .navigationTitle("Filters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Clear filters") {
                    filter.clear()
                }
                .disabled(filter.activeFilterCount == 0)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                dismiss()
            } label: {
                Text("Show \(resultCount) stretches")
                    .font(AppFont.subheadlineSemibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.tramePrimaryAction)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .background(Color.trameCanvas)
        }
    }

    private func singleChipSection<Value: Hashable>(
        title: String,
        values: [Value],
        label: KeyPath<Value, String>,
        selection: Binding<Value?>
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title.uppercased())
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.trameSubdued)
            ChipFlowLayout(spacing: Spacing.s) {
                ForEach(values, id: \.self) { value in
                    FilterChip(
                        title: value[keyPath: label],
                        isSelected: selection.wrappedValue == value,
                        accent: Color.trameMobility
                    ) {
                        selection.wrappedValue = selection.wrappedValue == value ? nil : value
                    }
                }
            }
        }
    }
}
