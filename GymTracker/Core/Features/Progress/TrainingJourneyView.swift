import SwiftData
import SwiftUI

/// The lifter's training history across plans, newest first.
///
/// Program Path answers "where am I inside this run". This answers the
/// different question of what the whole history has looked like — which plans
/// were followed, for how long, and what came out of them.
///
/// Vertical and chronological by design, not as a fallback: it is the
/// representation that survives Dynamic Type and reads correctly under
/// VoiceOver, so it is the one that ships first and stays.
struct TrainingJourneyView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var years: [TrainingJourneyYear] = []
    @State private var loadState: LoadState = .loading

    private enum LoadState: Equatable {
        case loading
        case failed
        case ready
    }

    var body: some View {
        List {
            switch loadState {
            case .loading:
                loadingRow
            case .failed:
                failedRow
            case .ready:
                if years.isEmpty {
                    emptyRow
                } else {
                    ForEach(years) { year in
                        Section(verbatim(year.year)) {
                            ForEach(year.chapters) { chapter in
                                chapterRow(chapter)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Journey")
        .accessibilityIdentifier("training-journey-screen")
        .task {
            do {
                years = try TrainingJourneyBuilder(modelContext: modelContext).journey()
                loadState = .ready
            } catch {
                print("TrainingJourneyView: journey read failed: \(error)")
                loadState = .failed
            }
        }
    }

    // MARK: - Rows

    private func chapterRow(_ chapter: TrainingJourneyChapter) -> some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            GymIconChip(systemImage: icon(for: chapter.kind), tint: tint(for: chapter.kind))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(chapter.title)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)

                Text(dateRangeText(chapter))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)

                if let statusText = chapter.statusText {
                    // Status is a word, never a colour alone — a paused run and
                    // a completed one must be distinguishable without relying
                    // on the chip tint.
                    Text(statusText)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }

                Text(summaryText(chapter))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(chapter))
        .accessibilityIdentifier("training-journey-chapter")
    }

    private var loadingRow: some View {
        HStack(spacing: Spacing.m) {
            ProgressView()
            Text("Reading your history…")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
        .accessibilityIdentifier("training-journey-loading")
    }

    /// Distinct from empty: a failed read must not look like "you never trained".
    private var failedRow: some View {
        GymSectionHeader(
            title: "Journey unavailable",
            detail: "Your history could not be read just now. Training history and records still open from Progress.",
            systemImage: AppIcon.warning
        )
        .accessibilityIdentifier("training-journey-failed")
    }

    private var emptyRow: some View {
        GymSectionHeader(
            title: "No training history yet",
            detail: "Complete a workout, or start a plan, and it appears here as a chapter of your training.",
            systemImage: AppIcon.history
        )
        .accessibilityIdentifier("training-journey-empty")
    }

    // MARK: - Presentation

    private func verbatim(_ year: Int) -> String {
        // Year is an identifier, not a formatted number: `1 234` or `1,234`
        // would be wrong in every locale.
        String(year)
    }

    private func icon(for kind: TrainingJourneyChapter.Kind) -> String {
        switch kind {
        case .fixedPlan: AppIcon.plan
        case .repeatingPlan: AppIcon.repeatingPlan
        case .freeTraining: AppIcon.workout
        }
    }

    private func tint(for kind: TrainingJourneyChapter.Kind) -> Color {
        switch kind {
        case .fixedPlan: .gymPrimary
        case .repeatingPlan: .gymSecondary
        case .freeTraining: .gymAccent
        }
    }

    private func dateRangeText(_ chapter: TrainingJourneyChapter) -> String {
        let start = chapter.start.formatted(date: .abbreviated, time: .omitted)
        guard let end = chapter.end else { return "\(start) — now" }
        let endText = end.formatted(date: .abbreviated, time: .omitted)
        // A chapter that began and ended on one day reads as a date, not as a
        // range from a day to itself.
        return start == endText ? start : "\(start) — \(endText)"
    }

    /// Counts are listed, never fused into a score. A "journey score" would
    /// invent a comparison the records do not support.
    private func summaryText(_ chapter: TrainingJourneyChapter) -> String {
        var parts: [String] = [
            chapter.completedWorkouts == 1 ? "1 workout" : "\(chapter.completedWorkouts) workouts"
        ]
        if chapter.personalRecords > 0 {
            parts.append(chapter.personalRecords == 1 ? "1 record" : "\(chapter.personalRecords) records")
        }
        if chapter.mobilitySessions > 0 {
            parts.append(
                chapter.mobilitySessions == 1
                    ? "1 mobility session"
                    : "\(chapter.mobilitySessions) mobility sessions"
            )
        }
        if chapter.assessments > 0 {
            parts.append(chapter.assessments == 1 ? "1 assessment" : "\(chapter.assessments) assessments")
        }
        return parts.joined(separator: " · ")
    }

    private func accessibilityLabel(_ chapter: TrainingJourneyChapter) -> String {
        [chapter.title, dateRangeText(chapter), chapter.statusText, summaryText(chapter)]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
