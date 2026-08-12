import Testing
@testable import GymTracker

struct TodayStartActionTests {
    @Test(
        "The primary Today card owns every available forward workout action",
        arguments: [
            TodayWorkoutSummary.Kind.active,
            .free,
            .planned,
            .repeating
        ]
    )
    func availableSummaryOffersStartAction(kind: TodayWorkoutSummary.Kind) {
        let summary = TodayWorkoutSummary(kind: kind, title: "Fixture", subtitle: "Fixture")

        #expect(summary.offersStartAction)
    }

    @Test(
        "Unavailable Today states leave recovery actions to supporting cards",
        arguments: [
            TodayWorkoutSummary.Kind.guidedConflict,
            .unavailable
        ]
    )
    func unavailableSummaryDoesNotOfferStartAction(kind: TodayWorkoutSummary.Kind) {
        let summary = TodayWorkoutSummary(kind: kind, title: "Fixture", subtitle: "Fixture")

        #expect(!summary.offersStartAction)
    }
}
