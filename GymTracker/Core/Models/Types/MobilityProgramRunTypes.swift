import Foundation

/// Lifecycle status of a `MobilityProgramRun`, mirroring `PlanRunStatus`'s
/// vocabulary. There is deliberately no `testDayAvailable` case: mobility
/// programs have no test-day completion policy equivalent in this slice.
nonisolated enum MobilityProgramRunStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case active
    case paused
    case completed
    case archived
}

/// Terminal/pending status of one planned occurrence inside a
/// `MobilityProgramRun`. Deliberately only the four states the spec names —
/// "next startable" and "in progress" are derived, never persisted, by
/// comparing a `.pending` row's `mobilitySessionID` against the live
/// `MobilitySession` it points at (see `MobilityProgramRunCoordinator`).
nonisolated enum MobilityProgramSessionStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case pending
    case completed
    case skipped
    case missed
}
