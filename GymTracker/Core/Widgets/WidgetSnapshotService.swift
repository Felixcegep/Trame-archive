import Foundation
import SwiftData
import WidgetKit

/// Builds and publishes the widget-facing `WidgetSnapshot` from existing
/// projections and services — no new domain logic. Called from the app
/// process only; the widget extension never imports this file's write path.
@MainActor
enum WidgetSnapshotService {
    static func refresh(using context: ModelContext) {
        do {
            try WidgetSnapshotStore.write(buildSnapshot(using: context))
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Preserve the last complete snapshot. Reloading after a failed
            // projection or write would only advertise stale or partial data.
            print("WidgetSnapshotService: failed to publish snapshot: \(error)")
        }
    }

    private static func buildSnapshot(using context: ModelContext) throws -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: .now,
            today: try todayData(using: context),
            weeklyVolume: try weeklyVolumeData(using: context),
            caffeine: try caffeineData(using: context),
            creatine: try creatineData(using: context),
            mobility: try mobilityData(using: context)
        )
    }

    private static func todayData(using context: ModelContext) throws -> TodayWidgetData {
        let plan = try WorkoutIntentProjectionService.todayPlanRequiringStore(using: context)
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

    private static func weeklyVolumeData(using context: ModelContext) throws -> WeeklyVolumeWidgetData {
        let unit: WeightType = UserDefaults.standard.unitSystem == .metric ? .kg : .lbs
        let projection = try WorkoutIntentProjectionService.weeklyVolumeRequiringStore(
            using: context,
            preferredUnit: unit
        )
        return WeeklyVolumeWidgetData(
            completedWorkoutCount: projection.completedWorkoutCount,
            workingSetCount: projection.workingSetCount,
            loadVolume: projection.loadVolume.map(Double.init),
            unitSymbol: projection.unit?.rawValue
        )
    }

    private static func caffeineData(using context: ModelContext) throws -> CaffeineWidgetData {
        let today = LocalDay.today
        let dayKey = today.rawValue
        let meals = try context.fetch(FetchDescriptor<LoggedMeal>(
            predicate: #Predicate { $0.dayKey == dayKey }
        ))
        let totals = NutritionDaySummary.resolve(day: today, meals: meals).totals

        let birthdate = UserDefaults.standard.double(forKey: DefaultsKey.caffeineBirthdateTimestamp).nonZeroDate
        var bodyWeightDescriptor = FetchDescriptor<BodyWeightEntry>(
            sortBy: [SortDescriptor(\.measuredAt, order: .reverse)]
        )
        bodyWeightDescriptor.fetchLimit = 1
        let latestBodyWeightKilograms = try context.fetch(bodyWeightDescriptor).first.map { Double($0.kilograms) }

        let ageBand = CaffeineGuidance.ageBand(birthdate: birthdate)
        let limit = CaffeineGuidance.dailyLimit(ageBand: ageBand, bodyWeightKilograms: latestBodyWeightKilograms)
        let referenceMilligrams: Double? = if case .milligrams(let mg, _) = limit { mg } else { nil }

        return CaffeineWidgetData(loggedMilligrams: totals.caffeineMilligrams, referenceMilligrams: referenceMilligrams)
    }

    private static func creatineData(using context: ModelContext) throws -> CreatineWidgetData {
        let today = LocalDay.today
        let occurrenceKey = "\(today.rawValue)|\(SupplementKind.creatine.rawValue)"
        var descriptor = FetchDescriptor<SupplementOccurrence>(
            predicate: #Predicate { $0.occurrenceKey == occurrenceKey }
        )
        descriptor.fetchLimit = 1
        let isConfirmed = try context.fetch(descriptor).first?.status == .completed
        return CreatineWidgetData(isConfirmed: isConfirmed)
    }

    private static func mobilityData(using context: ModelContext) throws -> MobilityWidgetData {
        let now = Date.now
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let activeStatus = MobilitySessionStatus.active.rawValue
        let completedStatus = MobilitySessionStatus.completed.rawValue
        // The widget needs active sessions, this week's completion count, and
        // the latest completed session. Avoid materializing the entire mobility
        // history and all of its entry/result relationships on every refresh.
        let recent = try context.fetch(FetchDescriptor<MobilitySession>(
            predicate: #Predicate {
                $0.statusRaw == activeStatus
                    || ($0.statusRaw == completedStatus && $0.startTime >= weekStart)
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        ))
        var latestEndedDescriptor = FetchDescriptor<MobilitySession>(
            predicate: #Predicate { $0.statusRaw == completedStatus },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        latestEndedDescriptor.fetchLimit = 1
        let latestCompleted = try context.fetch(latestEndedDescriptor).first
        var sessions = recent
        if let latestCompleted, sessions.contains(where: { $0.id == latestCompleted.id }) == false {
            sessions.append(latestCompleted)
        }
        let snapshots = sessions.map { session in
            let entries = session.orderedEntries
            let completedEntries = entries.filter { entry in
                entry.results.contains { result in
                    result.status == .completed || result.status == .partial
                }
            }.count
            let state: MobilityWidgetSessionSnapshot.State = switch session.status {
            case .active: .active
            case .completed: .completed
            case .stopped: .stopped
            }
            return MobilityWidgetSessionSnapshot(
                state: state,
                sessionID: session.id,
                title: session.nameSnapshot,
                currentEntryID: session.currentEntry?.id,
                currentMovementName: session.currentEntry?.definitionNameSnapshot,
                currentEntryNeedsRepetitions: session.currentEntry.map {
                    $0.trackingType == .repetitions && !$0.isPhaseDriven
                },
                completedEntryCount: completedEntries,
                totalEntryCount: entries.count,
                startTime: session.startTime
            )
        }
        return MobilityWidgetProjection.resolve(sessions: snapshots, now: now, calendar: .current)
    }
}

private extension Double {
    /// `UserDefaults.double(forKey:)` returns 0 for a missing key, which is a
    /// real epoch date — indistinguishable from "unset" unless treated as nil.
    var nonZeroDate: Date? {
        self == 0 ? nil : Date(timeIntervalSince1970: self)
    }
}
