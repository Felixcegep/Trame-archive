import Foundation
import SwiftData
import WidgetKit

/// Builds and publishes the widget-facing `WidgetSnapshot` from existing
/// projections and services — no new domain logic. Called from the app
/// process only; the widget extension never imports this file's write path.
@MainActor
enum WidgetSnapshotService {
    static func refresh(using context: ModelContext) {
        WidgetSnapshotStore.write(buildSnapshot(using: context))
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func buildSnapshot(using context: ModelContext) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: .now,
            today: todayData(using: context),
            weeklyVolume: weeklyVolumeData(using: context),
            caffeine: caffeineData(using: context),
            creatine: creatineData(using: context)
        )
    }

    private static func todayData(using context: ModelContext) -> TodayWidgetData {
        let plan = WorkoutIntentProjectionService.todayPlan(using: context)
        let state: TodayWidgetData.State = switch plan.state {
        case .activeWorkout: .activeWorkout
        case .scheduledWorkout: .scheduledWorkout
        case .noWorkout: .noWorkout
        }
        return TodayWidgetData(
            state: state,
            title: plan.title,
            completedSetCount: plan.completedSetCount,
            totalSetCount: plan.totalSetCount,
            currentExerciseName: plan.exercises.first(where: \.isCurrent)?.name
        )
    }

    private static func weeklyVolumeData(using context: ModelContext) -> WeeklyVolumeWidgetData {
        let unit: WeightType = UserDefaults.standard.unitSystem == .metric ? .kg : .lbs
        let projection = WorkoutIntentProjectionService.weeklyVolume(using: context, preferredUnit: unit)
        return WeeklyVolumeWidgetData(
            completedWorkoutCount: projection.completedWorkoutCount,
            workingSetCount: projection.workingSetCount,
            loadVolume: projection.loadVolume.map(Double.init),
            unitSymbol: projection.unit?.rawValue
        )
    }

    private static func caffeineData(using context: ModelContext) -> CaffeineWidgetData {
        let meals = (try? context.fetch(FetchDescriptor<LoggedMeal>())) ?? []
        let totals = NutritionDaySummary.resolve(day: .today, meals: meals).totals

        let birthdate = UserDefaults.standard.double(forKey: DefaultsKey.caffeineBirthdateTimestamp).nonZeroDate
        let latestBodyWeightKilograms = (try? context.fetch(FetchDescriptor<BodyWeightEntry>(
            sortBy: [SortDescriptor(\.measuredAt, order: .reverse)]
        )))?.first.map { Double($0.kilograms) }

        let ageBand = CaffeineGuidance.ageBand(birthdate: birthdate)
        let limit = CaffeineGuidance.dailyLimit(ageBand: ageBand, bodyWeightKilograms: latestBodyWeightKilograms)
        let referenceMilligrams: Double? = if case .milligrams(let mg, _) = limit { mg } else { nil }

        return CaffeineWidgetData(loggedMilligrams: totals.caffeineMilligrams, referenceMilligrams: referenceMilligrams)
    }

    private static func creatineData(using context: ModelContext) -> CreatineWidgetData {
        let today = LocalDay.today
        let occurrences = (try? context.fetch(FetchDescriptor<SupplementOccurrence>())) ?? []
        let isConfirmed = occurrences.first { $0.dayKey == today.rawValue && $0.kind == .creatine }?.status == .completed
        return CreatineWidgetData(isConfirmed: isConfirmed)
    }
}

private extension Double {
    /// `UserDefaults.double(forKey:)` returns 0 for a missing key, which is a
    /// real epoch date — indistinguishable from "unset" unless treated as nil.
    var nonZeroDate: Date? {
        self == 0 ? nil : Date(timeIntervalSince1970: self)
    }
}
