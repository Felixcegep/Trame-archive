import XCTest
@testable import GymTracker

final class TrainingJourneyPracticeTransitionsTests: XCTestCase {
    func testStructureTransitionsAreDescriptiveAndEvidenceBacked() {
        let fixed = chapter(id: "fixed", kind: .fixedPlan, start: date(2024, 1, 1), end: date(2024, 1, 3), discipline: .powerlifting)
        let free = chapter(id: "free", kind: .freeTraining, start: date(2024, 1, 4), end: date(2024, 1, 5), discipline: .powerlifting)
        let rotation = chapter(id: "rotation", kind: .repeatingPlan, start: date(2024, 1, 6), end: date(2024, 1, 8), discipline: .powerlifting)
        let nextPlan = chapter(id: "next-plan", kind: .fixedPlan, start: date(2024, 1, 9), end: date(2024, 1, 10), discipline: .powerlifting)

        let projection = project([nextPlan, free, rotation, fixed], reference: date(2024, 1, 10))
        let structures = projection.observedMarkers.compactMap { marker -> (TrainingJourneyTimelineLane, TrainingJourneyTimelineLane)? in
            guard case let .structureChange(from, to) = marker.kind else { return nil }
            return (from, to)
        }

        XCTAssertEqual(
            structures.map { "\($0.0.rawValue)->\($0.1.rawValue)" },
            ["fixedPlan->freeTraining", "freeTraining->repeatingPlan", "repeatingPlan->fixedPlan"]
        )
        XCTAssertTrue(projection.observedMarkers.allSatisfy { $0.state == .observed })
        XCTAssertTrue(projection.observedMarkers.allSatisfy { $0.from.sourceEvidence.isEmpty == false && $0.to.sourceEvidence.isEmpty == false })
    }

    func testDominantDisciplineChangeAndReturnAreSeparateObservedMarkers() {
        let first = chapter(id: "first", kind: .freeTraining, start: date(2024, 1, 1), end: date(2024, 1, 2), discipline: .bodybuilding)
        let second = chapter(id: "second", kind: .freeTraining, start: date(2024, 1, 3), end: date(2024, 1, 4), discipline: .powerlifting)
        let third = chapter(id: "third", kind: .freeTraining, start: date(2024, 1, 5), end: date(2024, 1, 6), discipline: .bodybuilding)

        let projection = project([third, first, second], reference: date(2024, 1, 6))
        XCTAssertEqual(projection.observedMarkers.count, 2)
        XCTAssertEqual(
            projection.observedMarkers.map { marker in
                switch marker.kind {
                case .dominantDisciplineChange: return "change"
                case .returnToEarlierDiscipline: return "return"
                case .structureChange: return "structure"
                }
            },
            ["change", "return"]
        )
        XCTAssertEqual(projection.observedMarkers[1].to.discipline, .dominant(.bodybuilding))
    }

    func testConcurrentIntervalsRemainExplicitlyUncertain() {
        let plan = chapter(id: "plan", kind: .fixedPlan, start: date(2024, 1, 1), end: date(2024, 1, 10), discipline: .powerlifting)
        let free = chapter(id: "free", kind: .freeTraining, start: date(2024, 1, 5), end: date(2024, 1, 6), discipline: .bodybuilding)

        let projection = project([free, plan], reference: date(2024, 1, 10))
        let marker = try! XCTUnwrap(projection.markers.first)
        guard case .structureChange(from: .fixedPlan, to: .freeTraining) = marker.kind else {
            return XCTFail("Expected a structure candidate")
        }
        XCTAssertEqual(marker.state, .concurrentIntervals)
        XCTAssertTrue(projection.observedMarkers.isEmpty)
        XCTAssertEqual(marker.from.chapterID, "plan")
        XCTAssertEqual(marker.to.chapterID, "free")
    }

    func testMissingCompletedEvidenceDoesNotBecomeAnObservedTransition() {
        let emptyPlan = chapter(id: "empty-plan", kind: .fixedPlan, start: date(2024, 1, 1), end: date(2024, 1, 2), discipline: nil, workouts: 0)
        let free = chapter(id: "free", kind: .freeTraining, start: date(2024, 1, 3), end: date(2024, 1, 4), discipline: .powerlifting)

        let projection = project([emptyPlan, free], reference: date(2024, 1, 4))
        XCTAssertEqual(projection.markers.count, 1)
        XCTAssertEqual(projection.markers[0].state, .insufficientCompletedEvidence)
        XCTAssertTrue(projection.observedMarkers.isEmpty)
        XCTAssertEqual(projection.markers[0].from.discipline, .noCompletedEvidence)
    }

    func testAmbiguousAndUnknownDisciplineStayVisibleAsUncertain() {
        let ambiguous = chapter(
            id: "ambiguous",
            kind: .freeTraining,
            start: date(2024, 1, 1),
            end: date(2024, 1, 2),
            discipline: nil,
            distributions: [(.bodybuilding, 1), (.powerlifting, 1)]
        )
        let known = chapter(id: "known", kind: .freeTraining, start: date(2024, 1, 3), end: date(2024, 1, 4), discipline: .powerlifting)
        let unknown = chapter(id: "unknown", kind: .freeTraining, start: date(2024, 1, 5), end: date(2024, 1, 6), discipline: nil, unknownEntries: 2)

        let projection = project([unknown, known, ambiguous], reference: date(2024, 1, 6))
        let states: [TrainingJourneyPracticeTransitionEvidenceState] = projection.uncertainMarkers.map { $0.state }
        XCTAssertEqual(states, [.ambiguousDiscipline, .unknownDiscipline])
        XCTAssertTrue(projection.observedMarkers.isEmpty)
        XCTAssertEqual(
            projection.uncertainMarkers[0].from.discipline,
            TrainingJourneyDisciplineObservation.ambiguous([.bodybuilding, .powerlifting])
        )
        XCTAssertEqual(
            projection.uncertainMarkers[1].to.discipline,
            TrainingJourneyDisciplineObservation.unknown
        )
    }

    func testMarkersHaveStableIDsAndOrderRegardlessOfInputOrder() {
        let first = chapter(id: "a", kind: .fixedPlan, start: date(2024, 1, 1), end: date(2024, 1, 2), discipline: .powerlifting)
        let second = chapter(id: "b", kind: .freeTraining, start: date(2024, 1, 3), end: date(2024, 1, 4), discipline: .powerlifting)
        let forward = project([first, second], reference: date(2024, 1, 4))
        let reversed = project([second, first], reference: date(2024, 1, 4))

        XCTAssertEqual(forward, reversed)
        XCTAssertEqual(forward.markers.map(\.id), reversed.markers.map(\.id))
        XCTAssertEqual(try! XCTUnwrap(forward.markers.first?.position), 0.5, accuracy: 0.000_001)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func project(
        _ chapters: [TrainingJourneyChapter],
        reference: Date
    ) -> TrainingJourneyPracticeTransitionProjection {
        TrainingJourneyPracticeTransitionProjectionService.project(
            chapters: chapters,
            calendar: utcCalendar,
            referenceDate: reference
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func chapter(
        id: String,
        kind: TrainingJourneyChapter.Kind,
        start: Date,
        end: Date?,
        discipline: SportDiscipline?,
        workouts: Int = 1,
        unknownEntries: Int = 0,
        distributions: [(SportDiscipline, Int)] = []
    ) -> TrainingJourneyChapter {
        let slices: [TrainingJourneyDisciplineDistribution.Slice]
        if distributions.isEmpty == false {
            slices = distributions.enumerated().map { index, item in
                TrainingJourneyDisciplineDistribution.Slice(
                    id: "slice-\(index)",
                    discipline: item.0,
                    recordKinds: [],
                    entryCount: item.1,
                    proportion: 0.5,
                    evidence: [AnalyticsSourceReference(workoutID: UUID(), entryID: UUID())]
                )
            }
        } else if let discipline {
            slices = [
                TrainingJourneyDisciplineDistribution.Slice(
                    id: "slice-\(discipline.rawValue)",
                    discipline: discipline,
                    recordKinds: [],
                    entryCount: max(1, workouts),
                    proportion: 1,
                    evidence: [AnalyticsSourceReference(workoutID: UUID(), entryID: UUID())]
                )
            ]
        } else if unknownEntries > 0 {
            slices = [
                TrainingJourneyDisciplineDistribution.Slice(
                    id: "slice-unknown",
                    discipline: nil,
                    recordKinds: [],
                    entryCount: unknownEntries,
                    proportion: 1,
                    evidence: [AnalyticsSourceReference(workoutID: UUID(), entryID: UUID())]
                )
            ]
        } else {
            slices = []
        }
        let entryCount = slices.reduce(0) { $0 + $1.entryCount }
        let distribution = TrainingJourneyDisciplineDistribution(
            totalEntryCount: entryCount,
            classifiedEntryCount: slices.filter { $0.discipline != nil }.reduce(0) { $0 + $1.entryCount },
            unknownEntryCount: slices.filter(\.isUnknown).reduce(0) { $0 + $1.entryCount },
            slices: slices
        )
        return TrainingJourneyChapter(
            id: id,
            kind: kind,
            title: id,
            start: start,
            end: end,
            statusText: nil,
            completedWorkouts: workouts,
            personalRecords: 0,
            mobilitySessions: 0,
            assessments: 0,
            disciplineDistribution: distribution
        )
    }
}
