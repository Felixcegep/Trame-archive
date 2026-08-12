import SwiftUI

/// Mobility routines, journal check-ins and logged meals under one title.
///
/// These were three rows in Progress opening three screens that differ only in
/// which record they list — same `List`, same empty state, same
/// reverse-chronological order. Three rows for one idea is three decisions to
/// make before reading anything, so the idea is now the destination and the
/// record is a scope inside it.
///
/// The bodies are still the original views. They hold real per-domain
/// presentation — mobility's evidence summarisation is 90 lines of policy — and
/// merging that into a single generic list would have traded three honest
/// screens for one that renders none of them well. What is shared is the frame;
/// what differs stays differentiated.
///
/// Deliberately excludes mobility *assessments*: performed work and measured
/// evidence are different kinds of record, and that screen is feature-gated
/// where these are not.
struct SupportingHistoryView: View {
    let initialScope: SupportingHistoryScope

    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current
    @State private var scope: SupportingHistoryScope

    init(initialScope: SupportingHistoryScope) {
        self.initialScope = initialScope
        // Seeded from the route so a deep link — a calendar day, a
        // notification — lands on the record it meant rather than on the
        // first scope.
        let nutritionAvailable = FeatureFlags.current.isEnabled(.nutrition)
        _scope = State(initialValue: initialScope == .nutrition && !nutritionAvailable ? .mobility : initialScope)
    }

    /// Nutrition disappears entirely when the flag is off rather than showing
    /// an empty scope, matching how the hub row behaved before this merge.
    private var availableScopes: [SupportingHistoryScope] {
        SupportingHistoryScope.allCases.filter { candidate in
            candidate != .nutrition || featureFlags.isEnabled(.nutrition)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // A segmented control rather than a menu: three short, mutually
            // exclusive scopes, all worth showing at once. It sits above the
            // list rather than in the toolbar because toolbar controls on
            // pushed screens do not reliably fire in this iOS generation —
            // the same reason the Progress range picker is a row.
            if availableScopes.count > 1 {
                Picker("Record", selection: $scope) {
                    ForEach(availableScopes) { candidate in
                        Text(candidate.title)
                            .tag(candidate)
                            .accessibilityIdentifier(candidate.accessibilityIdentifier)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.m)
                .accessibilityIdentifier("supporting-history-scope")
            }

            scopedContent
        }
        .background(Color.gymBackground)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("supporting-history-screen")
        // Correcting the scope after the fact rather than rebuilding: the
        // route can change under a screen already on screen when a
        // notification routes into a scope other than the one being read.
        .onChange(of: initialScope) { _, newValue in
            scope = availableScopes.contains(newValue) ? newValue : (availableScopes.first ?? .mobility)
        }
    }

    @ViewBuilder
    private var scopedContent: some View {
        switch scope {
        case .mobility:
            MobilityHistoryView()
        case .journal:
            JournalHistoryView()
        case .nutrition:
            NutritionHistoryView()
        }
    }
}
