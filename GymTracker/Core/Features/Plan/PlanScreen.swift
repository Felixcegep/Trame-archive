import SwiftUI

/// Which face of a plan is showing.
enum PlanScreenSegment: String, CaseIterable, Identifiable {
    /// The plan itself: what it is, where the run stands, what to do next.
    case overview
    /// The run's derived position and history — the Plan Path.
    case path
    /// The week just finished and the decision it produces. Fixed plans only.
    case review

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: String(localized: "Overview")
        case .path: String(localized: "Path")
        case .review: String(localized: "Review")
        }
    }

    var accessibilityIdentifier: String { "plan-segment-\(rawValue)" }
}

/// One plan, three faces.
///
/// A plan used to be four sibling destinations — `plan`, `repeatingPlan`,
/// `programPath` and `weeklyReview` — reachable as separate pushes from Today
/// and from Train. Four screens for one noun, and the lifter had to know which
/// of them held the answer before they could look for it. Overview, Path and
/// Review are three views of the same run, so they are now three segments of
/// one screen and moving between them costs no navigation.
///
/// Nothing was merged or rewritten. Each segment is the screen that already
/// existed, handed its own content closure — those screens own real lifecycle
/// rules (starting, pausing, restarting, undoing an advancement) that do not
/// belong in a container. What changed is that reaching them is a segment
/// rather than a push.
///
/// `programPath` and `weeklyReview` remain routes: Plan Path is also reachable
/// from Train, where there is no plan screen to host it.
struct PlanScreen<Overview: View, Path: View, Review: View>: View {
    let title: String
    /// Which segments this plan can offer. A rotation has no weekly review, and
    /// a plan with no current run has no path to show — passing a shorter list
    /// is how the caller says so, rather than the shell guessing.
    let availableSegments: [PlanScreenSegment]

    /// Owned by the caller so the segment can be changed from inside a
    /// segment. Overview still draws its "Plan path" and "Weekly review"
    /// links; they now move the picker instead of pushing a screen, which is
    /// the whole point of the change.
    @Binding var segment: PlanScreenSegment

    @ViewBuilder let overview: Overview
    @ViewBuilder let path: Path
    @ViewBuilder let review: Review

    init(
        title: String,
        availableSegments: [PlanScreenSegment],
        segment: Binding<PlanScreenSegment>,
        @ViewBuilder overview: () -> Overview,
        @ViewBuilder path: () -> Path,
        @ViewBuilder review: () -> Review
    ) {
        self.title = title
        self.availableSegments = availableSegments
        self._segment = segment
        self.overview = overview()
        self.path = path()
        self.review = review()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Shown only when there is a choice to make. A plan with no current
            // run offers Overview alone, and a one-segment picker is a label
            // wearing a control's clothes.
            if availableSegments.count > 1 {
                Picker("Plan view", selection: $segment) {
                    ForEach(availableSegments) { candidate in
                        Text(candidate.title)
                            .tag(candidate)
                            .accessibilityIdentifier(candidate.accessibilityIdentifier)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.m)
                .accessibilityIdentifier("plan-segment-picker")
            }

            content
        }
        .background(Color.trameCanvas)
        // A fallback. Each segment's own screen sets a more specific title —
        // the plan's name on Overview, "Plan path", "Weekly review" — and the
        // innermost wins, which is the same title the lifter saw when these
        // were separate pushes.
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        // A run can end while its screen is open — ending a plan run from
        // Overview removes both the path and the review out from under the
        // segments that were showing them. Falling back keeps the screen on
        // something that exists instead of on an empty segment.
        .onChange(of: availableSegments) { _, newValue in
            if !newValue.contains(segment) {
                segment = .overview
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        // State belongs to the navigation stack, so it can outlive the plan
        // that supplied a segment. Never render a stale, unavailable face on
        // the first frame while the binding is normalized asynchronously.
        switch availableSegments.contains(segment) ? segment : .overview {
        case .overview: overview
        case .path: path
        case .review: review
        }
    }
}
