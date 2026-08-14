import Foundation
import SwiftData

/// The application-layer query boundary for Weekly Program Review.
///
/// UI receives one projection and never coordinates separate run, workout, and
/// receipt queries or decides which records belong to the reviewed week.
enum WeeklyProgramReviewRepository {
    static func projection(
        for route: WeeklyProgramReviewRoute,
        in context: ModelContext,
        today: Date = .now,
        calendar: Calendar = .current
    ) throws -> WeeklyProgramReviewProjection? {
        let runID = route.runID
        var runDescriptor = FetchDescriptor<PlanRun>(predicate: #Predicate { $0.id == runID })
        runDescriptor.fetchLimit = 1
        guard let run = try context.fetch(runDescriptor).first
        else {
            return nil
        }
        let records = try context.fetch(FetchDescriptor<PlanProgressionRecommendationRecord>(
            predicate: #Predicate { $0.planRunID == runID }
        ))

        return WeeklyProgramReviewBuilder.build(
            for: run,
            progressionRecords: records,
            reviewedWeekIndex: route.weekIndex,
            today: today,
            calendar: calendar
        )
    }
}
