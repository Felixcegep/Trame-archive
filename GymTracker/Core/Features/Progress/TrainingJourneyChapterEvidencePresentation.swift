import Foundation

/// Value-only presentation data for one Journey chapter. The chapter and its
/// discipline projection remain the source of truth; this adapter only gives
/// the UI stable labels and evidence rows to render.
struct TrainingJourneyChapterEvidencePresentation: Equatable, Sendable {
    struct DisciplineSlice: Identifiable, Equatable, Sendable {
        let id: String
        let title: String
        let entryCount: Int
        let proportion: Double
        let recordKindTitles: [String]
        let evidence: [AnalyticsSourceReference]

        var evidenceCount: Int { evidence.count }
    }

    let totalEntryCount: Int
    let classifiedEntryCount: Int
    let unknownEntryCount: Int
    let slices: [DisciplineSlice]

    var hasEvidence: Bool { totalEntryCount > 0 }

    static func make(
        distribution: TrainingJourneyDisciplineDistribution
    ) -> Self {
        Self(
            totalEntryCount: distribution.totalEntryCount,
            classifiedEntryCount: distribution.classifiedEntryCount,
            unknownEntryCount: distribution.unknownEntryCount,
            slices: distribution.slices.map { slice in
                DisciplineSlice(
                    id: slice.id,
                    title: slice.discipline?.title ?? String(
                        localized: "training.journey.distribution.unknown",
                        defaultValue: "Unclassified"
                    ),
                    entryCount: slice.entryCount,
                    proportion: slice.proportion,
                    recordKindTitles: slice.recordKinds.map { recordKindTitle($0) },
                    evidence: slice.evidence
                )
            }
        )
    }

    static func summary(
        distribution: TrainingJourneyDisciplineDistribution
    ) -> String? {
        guard distribution.hasEvidence else { return nil }

        let presentation = make(distribution: distribution)
        let labels = presentation.slices
            .prefix(3)
            .map(\.title)
            .joined(separator: ", ")
        let suffix = presentation.slices.count > 3 ? "…" : ""
        let unknownText = distribution.unknownEntryCount > 0
            ? String(
                format: String(
                    localized: "training.journey.distribution.unknown.summary",
                    defaultValue: " · %lld unclassified"
                ),
                locale: .current,
                Int64(distribution.unknownEntryCount)
            )
            : ""
        return String(
            format: String(
                localized: "training.journey.distribution.summary",
                defaultValue: "%lld exercise entries · %@"
            ),
            locale: .current,
            Int64(distribution.totalEntryCount),
            "\(labels)\(suffix)\(unknownText)"
        )
    }

    private static func recordKindTitle(_ kind: SportRecordKind) -> String {
        switch kind {
        case .load: String(localized: "Load")
        case .repetition: String(localized: "Repetitions")
        case .estimatedOneRepMax: String(localized: "Estimated one-rep max")
        case .volume: String(localized: "Volume")
        case .bestSuccessfulLift: String(localized: "Best successful lift")
        case .attemptSuccessRate: String(localized: "Attempt success rate")
        case .complexResult: String(localized: "Complex result")
        case .loadDistance: String(localized: "Load-distance")
        case .loadDuration: String(localized: "Load-duration")
        case .distance: String(localized: "Distance")
        case .time: String(localized: "Time")
        case .pace: String(localized: "Pace")
        case .totalTime: String(localized: "Total time")
        case .runSplit: String(localized: "Run split")
        case .stationSplit: String(localized: "Station split")
        case .transitionSplit: String(localized: "Transition split")
        }
    }
}
