import Foundation
import SwiftData

/// Where a mobility plan sits on the beginner/intermediate/advanced ladder,
/// for ranking exactly the way `PlanExperienceLevel` ranks the workout
/// catalogue. Kept as its own type rather than reusing `PlanExperienceLevel`:
/// a mobility plan is never compiled by the workout engine, and borrowing its
/// experience vocabulary would imply a coupling that does not exist.
enum MobilityMatchExperienceLevel: Int, Equatable, Sendable, Comparable {
    case beginner = 0
    case intermediate = 1
    case advanced = 2

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .beginner: String(localized: "Beginner")
        case .intermediate: String(localized: "Intermediate")
        case .advanced: String(localized: "Advanced")
        }
    }
}

/// One mobility plan, reduced to what ranking needs — mirroring
/// `ProgramMatchCandidate`'s role on the workout side.
///
/// `MobilityProgramDefinitionPayload` carries no goal, experience or
/// prerequisite fields: mobility plans are seven curated, hand-authored plans
/// rather than an open, growing catalogue, so adding matching metadata to the
/// shared engine payload — the way the workout engine did — is not worth the
/// risk to `MobilityProgramCompiler`/`MobilityProgramValidationError` for a
/// feature that is intake, matching and presentation only. This type carries
/// a small hand-authored table instead, keyed by the plan's stable
/// `programKey`, and touches nothing under `MobilityProgramEngine`.
struct MobilityMatchCandidate: Identifiable, Equatable, Sendable {
    let id: UUID
    let programKey: String
    let name: String
    let summary: String?
    let durationWeeks: Int
    let supportedDaysPerWeek: [Int]
    let requiredCapabilities: [String]

    /// `MobilityGoalPreference` raw values this plan is a reasonable answer
    /// to. Empty means the table does not (yet) describe this plan — it earns
    /// no goal bonus, never a penalty.
    let goalIDs: Set<String>
    let experienceLevel: MobilityMatchExperienceLevel
    /// Free-text, unverifiable from the intake. Always disclosed, never used
    /// to exclude — the same honesty rule `ProgramMatchService` applies to
    /// the workout catalogue's own `prerequisites` field.
    let prerequisites: [String]
}

extension MobilityMatchCandidate {
    private struct Metadata {
        let goalIDs: Set<String>
        let experienceLevel: MobilityMatchExperienceLevel
        let prerequisites: [String]
    }

    /// One entry per bundled plan, reviewed against `MobilityProgramLibraryData`
    /// each time a plan is added there. A `programKey` this table does not
    /// recognise — a future plan, or a lifter's own imported one — still
    /// ranks; it simply earns no goal or experience bonus and lists no
    /// prerequisite, exactly like a workout program that never declared its
    /// own matching metadata.
    private static let metadataByProgramKey: [String: Metadata] = [
        "general-flexibility-foundation": Metadata(
            goalIDs: [MobilityGoalPreference.generalFlexibility.rawValue, MobilityGoalPreference.recovery.rawValue],
            experienceLevel: .beginner,
            prerequisites: []
        ),
        "contract-relax-lower-body": Metadata(
            goalIDs: [MobilityGoalPreference.generalFlexibility.rawValue, MobilityGoalPreference.recovery.rawValue],
            experienceLevel: .intermediate,
            prerequisites: []
        ),
        "active-range-end-range-control": Metadata(
            goalIDs: [MobilityGoalPreference.generalFlexibility.rawValue, MobilityGoalPreference.targetedPosition.rawValue],
            experienceLevel: .intermediate,
            prerequisites: []
        ),
        // Prerequisite text below is plain, un-localized `String` — deliberately,
        // the same way `ProgramDefinitionPayload.prerequisites` is bundled
        // catalogue content rather than UI chrome, and is never wrapped in
        // `String(localized:)`. This table describes the same seven bundled
        // plans; it is authored in Swift instead of `ProgramLibrary.json`'s
        // JSON only because `MobilityProgramDefinitionPayload` has no field to
        // hold it (see the type's own doc comment above).
        "loaded-flexibility-foundations": Metadata(
            goalIDs: [MobilityGoalPreference.targetedPosition.rawValue],
            experienceLevel: .advanced,
            prerequisites: [
                "Best suited to lifters already comfortable with the unloaded version of each position"
            ]
        ),
        "squat-mobility-integration": Metadata(
            goalIDs: [MobilityGoalPreference.targetedPosition.rawValue],
            experienceLevel: .advanced,
            prerequisites: ["Written to pair with training that already includes squatting"]
        ),
        "overhead-mobility-integration": Metadata(
            goalIDs: [MobilityGoalPreference.targetedPosition.rawValue],
            experienceLevel: .advanced,
            prerequisites: ["Written to pair with training that already includes overhead pressing"]
        ),
        "front-split-assistance-ladder": Metadata(
            goalIDs: [MobilityGoalPreference.targetedPosition.rawValue],
            experienceLevel: .advanced,
            prerequisites: ["Comfortable holding a supported split position"]
        )
    ]

    init(payload: MobilityProgramDefinitionPayload) {
        let metadata = Self.metadataByProgramKey[payload.programKey]
        self.init(
            id: payload.id,
            programKey: payload.programKey,
            name: payload.name,
            summary: payload.summary,
            durationWeeks: payload.durationWeeks,
            supportedDaysPerWeek: payload.supportedDaysPerWeek,
            requiredCapabilities: payload.requiredCapabilities,
            goalIDs: metadata?.goalIDs ?? [],
            experienceLevel: metadata?.experienceLevel ?? .beginner,
            prerequisites: metadata?.prerequisites ?? []
        )
    }

    /// Every mobility plan this build could start today.
    ///
    /// A record whose payload will not decode is skipped rather than
    /// surfaced as a broken card, mirroring `ProgramMatchCandidate.candidates`.
    @MainActor
    static func candidates(using context: ModelContext) -> [MobilityMatchCandidate] {
        let records = (try? context.fetch(FetchDescriptor<MobilityProgramDefinitionRecord>())) ?? []
        return records
            .filter { !$0.isArchived }
            .compactMap { record in
                guard let payload = try? record.payload() else { return nil }
                return MobilityMatchCandidate(payload: payload)
            }
    }
}
