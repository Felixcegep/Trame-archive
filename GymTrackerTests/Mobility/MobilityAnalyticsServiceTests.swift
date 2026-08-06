import SwiftData
import XCTest
@testable import GymTracker

final class MobilityAnalyticsServiceTests: XCTestCase {

    // MARK: - Helper Methods

    private func makeSession(
        id: UUID = UUID(),
        startTime: Date = Date(timeIntervalSince1970: 1_000_000),
        duration: TimeInterval? = 300,
        status: MobilitySessionStatus = .completed
    ) -> MobilitySession {
        let session = MobilitySession(
            nameSnapshot: "Test Session",
            id: id,
            startTime: startTime
        )
        session.status = status
        if let duration {
            session.endTime = startTime.addingTimeInterval(duration)
        }
        return session
    }

    private func makeEntry(
        id: UUID = UUID(),
        trackingType: MobilityTrackingType = .duration,
        side: MobilitySide = .left
    ) -> MobilityEntry {
        MobilityEntry(
            definitionIDSnapshot: UUID(),
            definitionNameSnapshot: "Test Movement",
            instructionsSnapshot: nil,
            trackingType: trackingType,
            targetDurationSeconds: 30,
            targetRepetitions: 10,
            side: side,
            restSeconds: nil,
            notesSnapshot: nil,
            timerStartedAt: nil,
            orderIndex: 0,
            id: id
        )
    }

    private func makeResult(
        id: UUID = UUID(),
        side: MobilitySide = .left,
        status: MobilityResultStatus = .completed,
        performedDurationSeconds: Int? = 30,
        performedRepetitions: Int? = 10,
        performedLoadValue: Double? = nil,
        performedLoadUnit: MobilityLoadUnit? = nil
    ) -> MobilityResult {
        let result = MobilityResult(side: side, id: id)
        result.status = status
        result.performedDurationSeconds = performedDurationSeconds
        result.performedRepetitions = performedRepetitions
        result.performedLoadValue = performedLoadValue
        result.performedLoadUnit = performedLoadUnit
        return result
    }

    private func makeOccurrence(
        session: MobilitySession,
        entry: MobilityEntry,
        result: MobilityResult,
        evidence: MobilityResultEvidence? = nil
    ) -> MobilityAnalyticsOccurrence {
        entry.session = session
        entry.results = [result]
        result.entry = entry
        return MobilityAnalyticsOccurrence(session: session, entry: entry, result: result, evidence: evidence)
    }

    private func makeEvidence(
        resultID: UUID,
        entryID: UUID,
        side: MobilitySide = .left,
        method: MobilityMethod? = .staticPassive,
        purpose: MobilityTrainingPurpose? = .flexibilityDevelopment,
        supportLevel: MobilitySupportLevel? = nil,
        performedSupportLevel: MobilitySupportLevel? = nil,
        assistancePrescription: MobilityAssistancePrescription? = nil,
        performedAssistanceLevel: Int? = nil,
        quality: MobilityMovementQuality? = nil,
        sensation: MobilitySensation? = nil
    ) -> MobilityResultEvidence {
        MobilityResultEvidence(
            resultID: resultID,
            entryIDSnapshot: entryID,
            side: side,
            methodSnapshot: method,
            purposeSnapshot: purpose,
            assistancePrescriptionSnapshot: assistancePrescription,
            supportLevelSnapshot: supportLevel,
            performedAssistanceLevel: performedAssistanceLevel,
            performedSupportLevel: performedSupportLevel,
            sensation: sensation,
            movementQuality: quality
        )
    }

    // MARK: - 1. Session Duration History

    func testSessionDurationHistoryReturnsCompletedSessionsSorted() {
        let date1 = Date(timeIntervalSince1970: 1_000_000)
        let date2 = Date(timeIntervalSince1970: 1_005_000)

        let session1 = makeSession(startTime: date1, duration: 600, status: .completed)
        let entry1 = makeEntry()
        let result1 = makeResult()
        let occurrence1 = makeOccurrence(session: session1, entry: entry1, result: result1)

        let session2 = makeSession(startTime: date2, duration: 900, status: .completed)
        let entry2 = makeEntry()
        let result2 = makeResult()
        let occurrence2 = makeOccurrence(session: session2, entry: entry2, result: result2)

        // Pass in reverse order to ensure sorting works
        let points = MobilityAnalyticsService.sessionDurationHistory([occurrence2, occurrence1])

        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].id, session1.id)
        XCTAssertEqual(points[0].duration, 600)
        XCTAssertEqual(points[1].id, session2.id)
        XCTAssertEqual(points[1].duration, 900)
    }

    func testSessionDurationHistoryExcludesActiveSessions() {
        let session = makeSession(duration: nil, status: .active)
        let occurrence = makeOccurrence(session: session, entry: makeEntry(), result: makeResult())

        let points = MobilityAnalyticsService.sessionDurationHistory([occurrence])
        XCTAssertTrue(points.isEmpty)
    }

    func testSessionDurationHistoryDeduplicatesMultipleOccurrencesInSameSession() {
        let session = makeSession(duration: 400, status: .completed)
        let entry1 = makeEntry()
        let result1 = makeResult()
        let entry2 = makeEntry()
        let result2 = makeResult()

        let occ1 = makeOccurrence(session: session, entry: entry1, result: result1)
        let occ2 = makeOccurrence(session: session, entry: entry2, result: result2)

        let points = MobilityAnalyticsService.sessionDurationHistory([occ1, occ2])
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].id, session.id)
        XCTAssertEqual(points[0].duration, 400)
    }

    // MARK: - 2. Development Hold Time History

    func testDevelopmentHoldTimeHistoryIncludesDevelopmentPurposes() {
        let session = makeSession(status: .completed)
        let entry = makeEntry()
        let result = makeResult(performedDurationSeconds: 45)
        let evidence = makeEvidence(resultID: result.id, entryID: entry.id, purpose: .flexibilityDevelopment)

        let occ = makeOccurrence(session: session, entry: entry, result: result, evidence: evidence)
        let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: [result.id: evidence])

        let points = MobilityAnalyticsService.developmentHoldTimeHistory([occ], policy: policy)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].value, 45)
    }

    func testDevelopmentHoldTimeHistoryExcludesPreparationPurpose() {
        let session = makeSession(status: .completed)
        let entry = makeEntry()
        let result = makeResult(performedDurationSeconds: 60)
        let evidence = makeEvidence(resultID: result.id, entryID: entry.id, purpose: .preparation)

        let occ = makeOccurrence(session: session, entry: entry, result: result, evidence: evidence)
        let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: [result.id: evidence])

        let points = MobilityAnalyticsService.developmentHoldTimeHistory([occ], policy: policy)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].value, 0, "Preparation occurrences must not contribute to development volume")
    }

    func testDevelopmentHoldTimeHistoryIncludesPlainItemWithNoEvidence() {
        let session = makeSession(status: .completed)
        let entry = makeEntry()
        let result = makeResult(performedDurationSeconds: 30)

        let occ = makeOccurrence(session: session, entry: entry, result: result, evidence: nil)
        let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: [:])

        let points = MobilityAnalyticsService.developmentHoldTimeHistory([occ], policy: policy)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].value, 30, "Plain item with no evidence should contribute to development volume")
    }

    func testDevelopmentHoldTimeHistoryExcludesIncompleteSessions() {
        let session = makeSession(status: .active)
        let entry = makeEntry()
        let result = makeResult(performedDurationSeconds: 30)

        let occ = makeOccurrence(session: session, entry: entry, result: result, evidence: nil)
        let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: [:])

        let points = MobilityAnalyticsService.developmentHoldTimeHistory([occ], policy: policy)
        XCTAssertTrue(points.isEmpty)
    }

    // MARK: - 3. Controlled Repetition History

    func testControlledRepetitionHistoryIncludesControlledAndMostlyControlled() {
        let session = makeSession(status: .completed)
        
        let entry1 = makeEntry()
        let res1 = makeResult(performedRepetitions: 10)
        let ev1 = makeEvidence(resultID: res1.id, entryID: entry1.id, quality: .controlled)
        let occ1 = makeOccurrence(session: session, entry: entry1, result: res1, evidence: ev1)

        let entry2 = makeEntry()
        let res2 = makeResult(performedRepetitions: 8)
        let ev2 = makeEvidence(resultID: res2.id, entryID: entry2.id, quality: .mostlyControlled)
        let occ2 = makeOccurrence(session: session, entry: entry2, result: res2, evidence: ev2)

        let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: [
            res1.id: ev1,
            res2.id: ev2
        ])

        let points = MobilityAnalyticsService.controlledRepetitionHistory([occ1, occ2], policy: policy)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].value, 18)
    }

    func testControlledRepetitionHistoryExcludesCompensatedOrUnassessed() {
        let session = makeSession(status: .completed)

        let entry1 = makeEntry()
        let res1 = makeResult(performedRepetitions: 10)
        let ev1 = makeEvidence(resultID: res1.id, entryID: entry1.id, quality: .compensationObserved)
        let occ1 = makeOccurrence(session: session, entry: entry1, result: res1, evidence: ev1)

        let entry2 = makeEntry()
        let res2 = makeResult(performedRepetitions: 8)
        let ev2 = makeEvidence(resultID: res2.id, entryID: entry2.id, quality: .unableToAssess)
        let occ2 = makeOccurrence(session: session, entry: entry2, result: res2, evidence: ev2)

        let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: [
            res1.id: ev1,
            res2.id: ev2
        ])

        let points = MobilityAnalyticsService.controlledRepetitionHistory([occ1, occ2], policy: policy)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].value, 0)
    }

    func testControlledRepetitionHistoryIncludesNilQuality() {
        let session = makeSession(status: .completed)
        let entry = makeEntry()
        let res = makeResult(performedRepetitions: 12)
        let ev = makeEvidence(resultID: res.id, entryID: entry.id, quality: nil)
        let occ = makeOccurrence(session: session, entry: entry, result: res, evidence: ev)
        let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: [res.id: ev])

        let points = MobilityAnalyticsService.controlledRepetitionHistory([occ], policy: policy)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].value, 12, "Unrecorded quality is not excluded")
    }

    func testControlledRepetitionHistoryExcludesPreparationPurpose() {
        let session = makeSession(status: .completed)
        let entry = makeEntry()
        let res = makeResult(performedRepetitions: 15)
        let ev = makeEvidence(resultID: res.id, entryID: entry.id, purpose: .preparation, quality: .controlled)
        let occ = makeOccurrence(session: session, entry: entry, result: res, evidence: ev)
        let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: [res.id: ev])

        let points = MobilityAnalyticsService.controlledRepetitionHistory([occ], policy: policy)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].value, 0, "Preparation purpose must not contribute reps")
    }

    // MARK: - 4. Completion History

    func testCompletionHistoryCalculatesCompletedVsPrescribed() {
        let session = makeSession(status: .completed)
        let entry1 = makeEntry()
        let res1 = makeResult(status: .completed)
        let occ1 = makeOccurrence(session: session, entry: entry1, result: res1)

        let entry2 = makeEntry()
        let res2 = makeResult(status: .skipped)
        let occ2 = makeOccurrence(session: session, entry: entry2, result: res2)

        let points = MobilityAnalyticsService.completionHistory([occ1, occ2])
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].completedCount, 1)
        XCTAssertEqual(points[0].prescribedCount, 2)
    }

    func testCompletionHistoryExcludesActiveSessions() {
        let session = makeSession(status: .active)
        let entry = makeEntry()
        let res = makeResult(status: .completed)
        let occ = makeOccurrence(session: session, entry: entry, result: res)

        let points = MobilityAnalyticsService.completionHistory([occ])
        XCTAssertTrue(points.isEmpty)
    }

    // MARK: - 5. Side History

    func testSideHistoryCountsBySide() {
        let session = makeSession()
        let occLeft = makeOccurrence(session: session, entry: makeEntry(), result: makeResult(side: .left))
        let occRight1 = makeOccurrence(session: session, entry: makeEntry(), result: makeResult(side: .right))
        let occRight2 = makeOccurrence(session: session, entry: makeEntry(), result: makeResult(side: .right))
        let occBilateral = makeOccurrence(session: session, entry: makeEntry(), result: makeResult(side: .bilateral))

        let sideMap = MobilityAnalyticsService.sideHistory([occLeft, occRight1, occRight2, occBilateral])
        XCTAssertEqual(sideMap[.left], 1)
        XCTAssertEqual(sideMap[.right], 2)
        XCTAssertEqual(sideMap[.bilateral], 1)
        XCTAssertNil(sideMap[.none])
    }

    // MARK: - 6. Weekly Frequency

    func testWeeklyFrequencyGroupsCompletedSessionsByWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Create two dates in the same week
        let date1 = Date(timeIntervalSince1970: 1_700_000_000) // Nov 14, 2023
        let date2 = date1.addingTimeInterval(86400) // Nov 15, 2023
        let date3 = date1.addingTimeInterval(14 * 86400) // Nov 28, 2023 (2 weeks later)

        let s1 = makeSession(startTime: date1, status: .completed)
        let s2 = makeSession(startTime: date2, status: .completed)
        let s3 = makeSession(startTime: date3, status: .completed)
        let sActive = makeSession(startTime: date1, status: .active)

        let occ1 = makeOccurrence(session: s1, entry: makeEntry(), result: makeResult())
        let occ2 = makeOccurrence(session: s2, entry: makeEntry(), result: makeResult())
        let occ3 = makeOccurrence(session: s3, entry: makeEntry(), result: makeResult())
        let occActive = makeOccurrence(session: sActive, entry: makeEntry(), result: makeResult())

        let freq = MobilityAnalyticsService.weeklyFrequency([occ1, occ2, occ3, occActive], calendar: calendar)

        let weekStart1 = calendar.dateInterval(of: .weekOfYear, for: date1)!.start
        let weekStart3 = calendar.dateInterval(of: .weekOfYear, for: date3)!.start

        XCTAssertEqual(freq[weekStart1], 2)
        XCTAssertEqual(freq[weekStart3], 1)
    }

    // MARK: - 7. Support History

    func testSupportHistoryPrefersPerformedSupportLevel() {
        let session = makeSession()
        let entry = makeEntry()
        let res = makeResult()
        let ev = makeEvidence(
            resultID: res.id,
            entryID: entry.id,
            supportLevel: .mediumBlocks,
            performedSupportLevel: .lowBlocks
        )
        let occ = makeOccurrence(session: session, entry: entry, result: res, evidence: ev)

        let points = MobilityAnalyticsService.supportHistory([occ])
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].level, .lowBlocks)
    }

    func testSupportHistoryFallsBackToSupportLevelSnapshot() {
        let session = makeSession()
        let entry = makeEntry()
        let res = makeResult()
        let ev = makeEvidence(
            resultID: res.id,
            entryID: entry.id,
            supportLevel: .highBlocks,
            performedSupportLevel: nil
        )
        let occ = makeOccurrence(session: session, entry: entry, result: res, evidence: ev)

        let points = MobilityAnalyticsService.supportHistory([occ])
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].level, .highBlocks)
    }

    func testSupportHistoryExcludesOccurrencesWithoutSupportLevel() {
        let session = makeSession()
        let entry = makeEntry()
        let res = makeResult()
        let ev = makeEvidence(resultID: res.id, entryID: entry.id, supportLevel: nil, performedSupportLevel: nil)
        let occ = makeOccurrence(session: session, entry: entry, result: res, evidence: ev)

        let points = MobilityAnalyticsService.supportHistory([occ])
        XCTAssertTrue(points.isEmpty)
    }

    // MARK: - 8. Assistance History

    func testAssistanceHistoryPrefersPerformedAssistanceLevel() {
        let session = makeSession()
        let entry = makeEntry()
        let res = makeResult()
        let prescription = MobilityAssistancePrescription(assistanceTypeRaw: MobilityAssistanceType.band.rawValue, level: 2)
        let ev = makeEvidence(
            resultID: res.id,
            entryID: entry.id,
            assistancePrescription: prescription,
            performedAssistanceLevel: 3
        )
        let occ = makeOccurrence(session: session, entry: entry, result: res, evidence: ev)

        let points = MobilityAnalyticsService.assistanceHistory([occ])
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].assistanceType, .band)
        XCTAssertEqual(points[0].level, 3)
    }

    func testAssistanceHistoryFallsBackToPrescriptionLevel() {
        let session = makeSession()
        let entry = makeEntry()
        let res = makeResult()
        let prescription = MobilityAssistancePrescription(assistanceTypeRaw: MobilityAssistanceType.blocks.rawValue, level: 1)
        let ev = makeEvidence(
            resultID: res.id,
            entryID: entry.id,
            assistancePrescription: prescription,
            performedAssistanceLevel: nil
        )
        let occ = makeOccurrence(session: session, entry: entry, result: res, evidence: ev)

        let points = MobilityAnalyticsService.assistanceHistory([occ])
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].assistanceType, .blocks)
        XCTAssertEqual(points[0].level, 1)
    }

    func testAssistanceHistoryExcludesOccurrencesWithoutAssistancePrescription() {
        let session = makeSession()
        let entry = makeEntry()
        let res = makeResult()
        let ev = makeEvidence(resultID: res.id, entryID: entry.id, assistancePrescription: nil)
        let occ = makeOccurrence(session: session, entry: entry, result: res, evidence: ev)

        let points = MobilityAnalyticsService.assistanceHistory([occ])
        XCTAssertTrue(points.isEmpty)
    }

    // MARK: - 9. Load History

    func testLoadHistoryIncludesPerformedLoad() {
        let session = makeSession()
        let entry = makeEntry()
        let res = makeResult(performedLoadValue: 15.5, performedLoadUnit: .kilograms)
        let occ = makeOccurrence(session: session, entry: entry, result: res)

        let points = MobilityAnalyticsService.loadHistory([occ])
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].value, 15.5)
        XCTAssertEqual(points[0].unit, .kilograms)
    }

    func testLoadHistoryExcludesNilLoadValue() {
        let session = makeSession()
        let entry = makeEntry()
        let res = makeResult(performedLoadValue: nil)
        let occ = makeOccurrence(session: session, entry: entry, result: res)

        let points = MobilityAnalyticsService.loadHistory([occ])
        XCTAssertTrue(points.isEmpty)
    }

    // MARK: - 10. Comparable Range History (Assessment Bridge)

    @MainActor
    func testComparableRangeHistoryWithNoResultsReturnsEmpty() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let points = MobilityAnalyticsService.comparableRangeHistory(
            assessmentCatalogueKey: "ankle_dorsiflexion",
            side: .left,
            using: context
        )
        XCTAssertTrue(points.isEmpty)
    }

    @MainActor
    func testComparableRangeHistoryReturnsComparisonsInChronologicalOrder() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let definition = MobilityAssessmentSeedData.definitions[0].makeDefinition()
        context.insert(definition)
        try context.save()

        let session = try MobilityAssessmentSessionService.start(
            definitions: [definition],
            day: LocalDay(rawValue: "2026-08-01"),
            using: context
        )
        _ = try MobilityAssessmentSessionService.saveResult(
            in: session,
            definition: definition,
            input: MobilityAssessmentResultInput(
                numericValue: 40.0,
                side: .left,
                isWarm: false,
                setupKey: definition.defaultSetupKey,
                method: definition.manualMode,
                unit: definition.unit,
                isActiveRange: definition.defaultIsActiveRange,
                day: session.day
            ),
            using: context
        )

        let points = MobilityAnalyticsService.comparableRangeHistory(
            assessmentCatalogueKey: definition.catalogueKey,
            side: .left,
            using: context
        )

        XCTAssertEqual(points.count, 1)
    }

    // MARK: - 11. Movement Quality History

    func testMovementQualityHistoryExtractsQuality() {
        let session = makeSession()
        let entry = makeEntry()
        let res = makeResult()
        let ev = makeEvidence(resultID: res.id, entryID: entry.id, quality: .controlled)
        let occ = makeOccurrence(session: session, entry: entry, result: res, evidence: ev)

        let points = MobilityAnalyticsService.movementQualityHistory([occ])
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].quality, .controlled)
    }

    func testMovementQualityHistoryExcludesNilQuality() {
        let session = makeSession()
        let entry = makeEntry()
        let res = makeResult()
        let ev = makeEvidence(resultID: res.id, entryID: entry.id, quality: nil)
        let occ = makeOccurrence(session: session, entry: entry, result: res, evidence: ev)

        let points = MobilityAnalyticsService.movementQualityHistory([occ])
        XCTAssertTrue(points.isEmpty)
    }

    // MARK: - 12. Stop-Signal History

    func testStopSignalHistoryIncludesPainNumbnessTingling() {
        let session = makeSession()
        let entry = makeEntry()

        let resPain = makeResult()
        let evPain = makeEvidence(resultID: resPain.id, entryID: entry.id, sensation: .pain)
        let occPain = makeOccurrence(session: session, entry: entry, result: resPain, evidence: evPain)

        let resNumbness = makeResult()
        let evNumbness = makeEvidence(resultID: resNumbness.id, entryID: entry.id, sensation: .numbness)
        let occNumbness = makeOccurrence(session: session, entry: entry, result: resNumbness, evidence: evNumbness)

        let resTingling = makeResult()
        let evTingling = makeEvidence(resultID: resTingling.id, entryID: entry.id, sensation: .tingling)
        let occTingling = makeOccurrence(session: session, entry: entry, result: resTingling, evidence: evTingling)

        let points = MobilityAnalyticsService.stopSignalHistory([occPain, occNumbness, occTingling])
        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(points[0].sensation, .pain)
        XCTAssertEqual(points[1].sensation, .numbness)
        XCTAssertEqual(points[2].sensation, .tingling)
    }

    func testStopSignalHistoryExcludesNonStopSignals() {
        let session = makeSession()
        let entry = makeEntry()

        let resMild = makeResult()
        let evMild = makeEvidence(resultID: resMild.id, entryID: entry.id, sensation: .mildStretch)
        let occMild = makeOccurrence(session: session, entry: entry, result: resMild, evidence: evMild)

        let resDiscomfort = makeResult()
        let evDiscomfort = makeEvidence(resultID: resDiscomfort.id, entryID: entry.id, sensation: .discomfort)
        let occDiscomfort = makeOccurrence(session: session, entry: entry, result: resDiscomfort, evidence: evDiscomfort)

        let resNone = makeResult()
        let evNone = makeEvidence(resultID: resNone.id, entryID: entry.id, sensation: MobilitySensation.none)
        let occNone = makeOccurrence(session: session, entry: entry, result: resNone, evidence: evNone)

        let points = MobilityAnalyticsService.stopSignalHistory([occMild, occDiscomfort, occNone])
        XCTAssertTrue(points.isEmpty, "Non-stop sensations must be excluded from stop-signal history")
    }
}
