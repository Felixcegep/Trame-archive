import XCTest
@testable import GymTracker

final class MobilityAnalyticsPolicyTests: XCTestCase {
    
    // MARK: - Development Volume
    
    func testPreparationPurposeDoesNotContributeToDevelopmentVolume() {
        let entry = MobilityEntry(definitionIDSnapshot: UUID(), definitionNameSnapshot: "test", instructionsSnapshot: nil, trackingType: .duration, targetDurationSeconds: nil, targetRepetitions: nil, side: .left, restSeconds: nil, notesSnapshot: nil, timerStartedAt: nil, orderIndex: 0, id: UUID())
        let result = MobilityResult(side: .left)
        entry.results = [result]
        let evidence = MobilityResultEvidence(resultID: result.id, entryIDSnapshot: entry.id, side: .left, methodSnapshot: .staticPassive, purposeSnapshot: .preparation)
        
        let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: [result.id: evidence])
        
        XCTAssertFalse(policy.contributesToDevelopmentVolume(entry: entry), "Preparation purpose must never contribute to development volume")
    }
    
    func testDevelopmentPurposesDoContributeToDevelopmentVolume() {
        let purposes: [MobilityTrainingPurpose] = [.flexibilityDevelopment, .activeControl, .maintenance]
        
        for purpose in purposes {
            let entry = MobilityEntry(definitionIDSnapshot: UUID(), definitionNameSnapshot: "test", instructionsSnapshot: nil, trackingType: .duration, targetDurationSeconds: nil, targetRepetitions: nil, side: .left, restSeconds: nil, notesSnapshot: nil, timerStartedAt: nil, orderIndex: 0, id: UUID())
            let result = MobilityResult(side: .left)
            entry.results = [result]
            let evidence = MobilityResultEvidence(resultID: result.id, entryIDSnapshot: entry.id, side: .left, methodSnapshot: .staticPassive, purposeSnapshot: purpose)
            
            let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: [result.id: evidence])
            
            XCTAssertTrue(policy.contributesToDevelopmentVolume(entry: entry), "Purpose \(purpose) should contribute to development volume")
        }
    }
    
    func testUnauthoredPlainItemContributesToDevelopmentVolume() {
        let entry = MobilityEntry(definitionIDSnapshot: UUID(), definitionNameSnapshot: "test", instructionsSnapshot: nil, trackingType: .duration, targetDurationSeconds: nil, targetRepetitions: nil, side: .left, restSeconds: nil, notesSnapshot: nil, timerStartedAt: nil, orderIndex: 0, id: UUID())
        let result = MobilityResult(side: .left)
        entry.results = [result]
        let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: [:])
        
        XCTAssertTrue(policy.contributesToDevelopmentVolume(entry: entry), "Plain routine item with no authored purpose should count as development volume")
    }
    
    // MARK: - Comparison Eligibility
    
    func testMissingEvidenceBlocksComparisonEntirely() {
        let prevResult = MobilityResult(side: .left)
        let currResult = MobilityResult(side: .left)
        
        let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: [:])
        
        let eligibility = policy.comparisonEligibility(current: currResult, previous: prevResult)
        
        if case let .notComparable(diffs) = eligibility {
            XCTAssertEqual(diffs.count, 4, "Missing evidence should declare all conditions as differing")
            XCTAssertTrue(diffs.contains(.method))
            XCTAssertTrue(diffs.contains(.purpose))
            XCTAssertTrue(diffs.contains(.assistance))
            XCTAssertTrue(diffs.contains(.effectiveSupport))
        } else {
            XCTFail("Expected notComparable, got \(eligibility)")
        }
    }
    
    func testIdenticalConditionsAllowComparison() {
        let prevResult = MobilityResult(side: .left)
        let currResult = MobilityResult(side: .left)
        
        let prevEv = MobilityResultEvidence(resultID: prevResult.id, entryIDSnapshot: UUID(), side: .left, methodSnapshot: .staticPassive, purposeSnapshot: .flexibilityDevelopment, assistancePrescriptionSnapshot: nil, supportLevelSnapshot: .unsupported)
        prevEv.performedSupportLevelRaw = MobilitySupportLevel.unsupported.rawValue
        prevEv.performedAssistanceLevel = 1
        
        let currEv = MobilityResultEvidence(resultID: currResult.id, entryIDSnapshot: UUID(), side: .left, methodSnapshot: .staticPassive, purposeSnapshot: .flexibilityDevelopment, assistancePrescriptionSnapshot: nil, supportLevelSnapshot: .unsupported)
        currEv.performedSupportLevelRaw = MobilitySupportLevel.unsupported.rawValue
        currEv.performedAssistanceLevel = 1
        
        let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: [
            prevResult.id: prevEv,
            currResult.id: currEv
        ])
        
        XCTAssertEqual(policy.comparisonEligibility(current: currResult, previous: prevResult), .comparable)
    }
    
    func testSingleDifferingConditionBlocksComparison() {
        let prevResult = MobilityResult(side: .left)
        let currResult = MobilityResult(side: .left)
        
        let prevEv = MobilityResultEvidence(resultID: prevResult.id, entryIDSnapshot: UUID(), side: .left, methodSnapshot: .staticPassive, purposeSnapshot: .flexibilityDevelopment, assistancePrescriptionSnapshot: nil, supportLevelSnapshot: .unsupported)
        
        let currEv = MobilityResultEvidence(resultID: currResult.id, entryIDSnapshot: UUID(), side: .left, methodSnapshot: .dynamic, purposeSnapshot: .flexibilityDevelopment, assistancePrescriptionSnapshot: nil, supportLevelSnapshot: .unsupported)
        
        let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: [
            prevResult.id: prevEv,
            currResult.id: currEv
        ])
        
        let eligibility = policy.comparisonEligibility(current: currResult, previous: prevResult)
        if case let .notComparable(diffs) = eligibility {
            XCTAssertEqual(diffs, [MobilityComparisonConditionDifference.method])
        } else {
            XCTFail("Expected notComparable")
        }
    }
}
