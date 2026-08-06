import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class MobilityProgramIntegrationSeparationTests: XCTestCase {
    func testAssessmentResultsNeverAppearInTrainingHistoryOrVolumeQueries() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        
        // 1. Create a mobility assessment definition and completed assessment session
        let assessmentDef = MobilityAssessmentSeedData.definitions[0].makeDefinition()
        context.insert(assessmentDef)
        try context.save()
        
        let assessmentSession = try MobilityAssessmentSessionService.start(
            definitions: [assessmentDef],
            day: LocalDay(rawValue: "2026-08-01"),
            using: context
        )
        let trialInput = MobilityAssessmentResultInput(
            numericValue: 45,
            side: .left,
            isWarm: false,
            setupKey: assessmentDef.defaultSetupKey,
            method: assessmentDef.manualMode,
            unit: assessmentDef.unit,
            isActiveRange: assessmentDef.defaultIsActiveRange,
            day: assessmentSession.day
        )
        _ = try MobilityAssessmentSessionService.saveResult(
            in: assessmentSession,
            definition: assessmentDef,
            input: trialInput,
            using: context
        )
        try MobilityAssessmentSessionService.complete(assessmentSession, using: context)
        
        // 2. Create a training mobility routine and session for a similar movement
        let trainingSession = MobilitySession(
            nameSnapshot: "Daily Ankle Mobility",
            context: .standalone
        )
        trainingSession.status = .completed
        trainingSession.startTime = .now
        trainingSession.endTime = .now
        context.insert(trainingSession)

        let entry = MobilityEntry(
            definitionIDSnapshot: UUID(),
            definitionNameSnapshot: "Ankle Mobility",
            instructionsSnapshot: nil,
            trackingType: .duration,
            targetDurationSeconds: 30,
            targetRepetitions: nil,
            side: .left,
            restSeconds: nil,
            notesSnapshot: nil,
            timerStartedAt: nil,
            orderIndex: 0,
            id: UUID()
        )
        entry.session = trainingSession
        context.insert(entry)

        let result = MobilityResult(side: .left)
        result.performedDurationSeconds = 30
        result.status = .completed
        result.entry = entry
        context.insert(result)

        let evidence = MobilityResultEvidence(
            resultID: result.id,
            entryIDSnapshot: entry.id,
            side: .left,
            methodSnapshot: .staticPassive,
            purposeSnapshot: .flexibilityDevelopment
        )
        context.insert(evidence)
        try context.save()

        // 3. Query MobilitySession and MobilityResultEvidence (underlying queries for MobilityHistoryView)
        let queriedSessions = try context.fetch(FetchDescriptor<MobilitySession>())
        let queriedEvidence = try context.fetch(FetchDescriptor<MobilityResultEvidence>())
        let queriedAssessments = try context.fetch(FetchDescriptor<MobilityAssessmentSession>())
        
        // Assert training history queries contain only training sessions and evidence
        XCTAssertEqual(queriedSessions.count, 1)
        XCTAssertEqual(queriedSessions.first?.id, trainingSession.id)
        
        XCTAssertEqual(queriedEvidence.count, 1)
        XCTAssertEqual(queriedEvidence.first?.resultID, evidence.resultID)
        
        // Assert assessment session is isolated in its own model container/table
        XCTAssertEqual(queriedAssessments.count, 1)
        XCTAssertEqual(queriedAssessments.first?.id, assessmentSession.id)
        
        // 4. Assert MobilityAnalyticsService occurs only from MobilityAnalyticsOccurrence snapshots
        let occurrence = MobilityAnalyticsOccurrence(
            session: trainingSession,
            entry: entry,
            result: result,
            evidence: evidence
        )
        let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: [result.id: evidence])
        let holdTimePoints = MobilityAnalyticsService.developmentHoldTimeHistory(
            [occurrence],
            policy: policy
        )
        XCTAssertEqual(holdTimePoints.count, 1)
        XCTAssertEqual(holdTimePoints.first?.value, 30)
    }

    func testRenamingOrReauthoringACatalogMovementNeverChangesAlreadyComputedHistory() throws {
        let entry = MobilityEntry(
            definitionIDSnapshot: UUID(),
            definitionNameSnapshot: "Ankle Mobilization",
            instructionsSnapshot: nil,
            trackingType: .duration,
            targetDurationSeconds: 45,
            targetRepetitions: nil,
            side: .left,
            restSeconds: nil,
            notesSnapshot: nil,
            timerStartedAt: nil,
            orderIndex: 0,
            id: UUID()
        )
        let session = MobilitySession(
            nameSnapshot: "Pre-Run Mobility",
            context: .standalone
        )
        session.status = .completed
        session.startTime = Date(timeIntervalSince1970: 1_700_000_000)
        session.endTime = Date(timeIntervalSince1970: 1_700_000_045)
        
        let result = MobilityResult(side: .left)
        result.performedDurationSeconds = 45
        result.status = .completed
        
        let evidence = MobilityResultEvidence(
            resultID: result.id,
            entryIDSnapshot: entry.id,
            side: .left,
            methodSnapshot: .staticPassive,
            purposeSnapshot: .flexibilityDevelopment
        )
        
        let occurrence = MobilityAnalyticsOccurrence(
            session: session,
            entry: entry,
            result: result,
            evidence: evidence
        )
        
        let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: [result.id: evidence])
        
        // Compute initial metrics
        let initialHoldTimes = MobilityAnalyticsService.developmentHoldTimeHistory([occurrence], policy: policy)
        let initialDurations = MobilityAnalyticsService.sessionDurationHistory([occurrence])
        
        XCTAssertEqual(initialHoldTimes.count, 1)
        XCTAssertEqual(initialHoldTimes.first?.value, 45)
        XCTAssertEqual(initialDurations.first?.duration, 45)
        
        // 2. Simulate renaming live definition or changing routine entry
        entry.definitionNameSnapshot = "Renamed Ankle Mobility Movement"
        
        // 3. Recompute metrics from unchanged snapshot occurrence
        let recomputedHoldTimes = MobilityAnalyticsService.developmentHoldTimeHistory([occurrence], policy: policy)
        let recomputedDurations = MobilityAnalyticsService.sessionDurationHistory([occurrence])
        
        // Historical digest metrics are identical
        XCTAssertEqual(initialHoldTimes, recomputedHoldTimes)
        XCTAssertEqual(initialDurations, recomputedDurations)
    }
}
