import XCTest
@testable import GymTracker

@MainActor
final class StageSetGroupingTests: XCTestCase {
    func testGroupsPartitionWarmUpsAndWorkingSets() {
        let sets = makeSets([.warmup, .normal, .warmup, .topSet])

        let groups = StageSetGrouping.groups(for: sets)

        XCTAssertEqual(groups.map(\.kind), [.warmUp, .working])
        XCTAssertEqual(groups[0].sets.map(\.id), [sets[0].id, sets[2].id])
        XCTAssertEqual(groups[1].sets.map(\.id), [sets[1].id, sets[3].id])
    }

    func testAbsoluteIndicesAddressTheFullSetList() {
        let sets = makeSets([.warmup, .normal, .topSet, .warmup])

        let groups = StageSetGrouping.groups(for: sets)

        for group in groups {
            for pair in group.indexedSets {
                XCTAssertTrue(pair.set === sets[pair.index])
            }
        }
        XCTAssertEqual(groups.flatMap(\.absoluteIndices), [0, 3, 1, 2])
    }

    func testNonContiguousWarmUpIsStillGrouped() {
        let sets = makeSets([.normal, .normal, .warmup, .topSet])

        let groups = StageSetGrouping.groups(for: sets)

        XCTAssertEqual(groups.first?.kind, .warmUp)
        XCTAssertEqual(groups.first?.absoluteIndices, [2])
        XCTAssertEqual(groups.last?.absoluteIndices, [0, 1, 3])
    }

    func testEmptyGroupsAreDropped() {
        let sets = makeSets([.normal, .topSet])

        let groups = StageSetGrouping.groups(for: sets)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.kind, .working)
    }

    func testShouldCollapseWarmUpOnlyWhenEveryWarmUpIsDone() {
        let sets = makeSets([.warmup, .warmup, .normal])
        let groups = StageSetGrouping.groups(for: sets)

        XCTAssertFalse(StageSetGrouping.shouldCollapseWarmUp(groups))
        sets[0].done = true
        XCTAssertFalse(StageSetGrouping.shouldCollapseWarmUp(StageSetGrouping.groups(for: sets)))
        sets[1].done = true
        XCTAssertTrue(StageSetGrouping.shouldCollapseWarmUp(StageSetGrouping.groups(for: sets)))
    }

    private func makeSets(_ types: [SetType]) -> [ExerciseSet] {
        types.enumerated().map { index, type in
            ExerciseSet(
                repetitions: 8,
                weight: 40,
                setType: type,
                orderIndex: index,
                usedMetric: .metric
            )
        }
    }
}
