import SwiftData
import SwiftUI

/// The Weekly Review screen: what a fixed-plan week planned, what actually
/// happened to it, and what comes next.
///
/// The route carries only a run identifier and an optional week index. The
/// projection is resolved fresh at presentation time through
/// `WeeklyProgramReviewRepository`, the same pattern `ProgramPathView` uses
/// for `ProgramPathRoute` — a navigation stack restored after a pause, a
/// completion, or a backup restore never renders a stale review.
///
/// This screen is entirely read-only. It reports what the projection already
/// decided; it starts nothing, reschedules nothing, and resolves nothing.
struct WeeklyProgramReviewView: View {
    @Environment(\.modelContext) private var modelContext

    let route: WeeklyProgramReviewRoute

    var body: some View {
        content
            .navigationTitle(WeeklyProgramReviewPresentation.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        if let projection {
            reviewList(projection)
        } else {
            WeeklyProgramReviewUnavailableView()
        }
    }

    /// `try?`: a thrown fetch is presentation-equivalent to "unavailable" —
    /// the required visible state already covers both a missing run and a
    /// lookup failure with the same screen.
    private var projection: WeeklyProgramReviewProjection? {
        (try? WeeklyProgramReviewRepository.projection(for: route, in: modelContext)) ?? nil
    }

    private func reviewList(_ projection: WeeklyProgramReviewProjection) -> some View {
        List {
            Section {
                WeeklyProgramReviewHeader(
                    planName: projection.planName,
                    weekPositionTitle: WeeklyProgramReviewPresentation.weekPositionTitle(projection.week),
                    blockName: projection.week.blockName,
                    phaseType: projection.week.phaseType,
                    statusTitle: ProgramPathPresentation.runStatusTitle(projection.runStatus),
                    statusNote: WeeklyProgramReviewPresentation.runStatusNote(projection.runStatus),
                    isMuted: projection.runStatus != .active,
                    dateRangeTitle: projection.week.scheduledDateRange.map {
                        WeeklyProgramReviewPresentation.dateRangeTitle($0)
                    }
                )
            }

            Section("Sessions") {
                WeeklyProgramReviewSessionSummary(summary: projection.sessionSummary)
            }

            if !projection.sessions.isEmpty {
                Section("This week") {
                    ForEach(projection.sessions) { session in
                        WeeklyProgramReviewSessionLink(session: session)
                    }
                }
            }

            Section("Sets") {
                WeeklyProgramReviewSetSummary(summary: projection.setSummary)
            }

            if !projection.progressionDecisions.isEmpty {
                Section("Progression decisions") {
                    ForEach(projection.progressionDecisions) { decision in
                        WeeklyProgramReviewProgressionDecisionRow(decision: decision)
                    }
                }
            }

            if !projection.substitutions.isEmpty {
                Section("Substitutions") {
                    ForEach(projection.substitutions) { substitution in
                        WeeklyProgramReviewSubstitutionRow(substitution: substitution)
                    }
                }
            }

            Section("Next week") {
                if let nextWeek = projection.nextWeek {
                    WeeklyProgramReviewNextWeekView(nextWeek: nextWeek)
                } else {
                    WeeklyProgramReviewFinalWeekView()
                }
            }

            if !projection.warnings.isEmpty {
                Section("Needs attention") {
                    WeeklyProgramReviewWarningView(
                        messages: projection.warnings.map { WeeklyProgramReviewPresentation.warningMessage($0) }
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .overlay(alignment: .topLeading) {
            screenshotStateMarker("weekly-review-screen", label: "Weekly review")
        }
    }
}
