import WidgetKit

struct WidgetSnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Shared by all four widgets: the extension process never opens SwiftData —
/// it only decodes the snapshot the app process last wrote to the App Group
/// container (mirrors the existing Live Activity's app-pushes/extension-
/// renders pattern). A missing snapshot (first install, before any app
/// launch) falls back to representative placeholder content.
struct WidgetSnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetSnapshotEntry {
        WidgetSnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetSnapshotEntry) -> Void) {
        completion(WidgetSnapshotEntry(date: .now, snapshot: WidgetSnapshotStore.read() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetSnapshotEntry>) -> Void) {
        let entry = WidgetSnapshotEntry(date: .now, snapshot: WidgetSnapshotStore.read() ?? .placeholder)
        // Real updates arrive via WidgetCenter.reloadAllTimelines() from the
        // app (on backgrounding); this is only a safety-net refresh in case
        // that signal was missed while the app was killed.
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
    }
}

extension WidgetSnapshot {
    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: .now,
            today: TodayWidgetData(state: .noWorkout, title: "No workout today", completedSetCount: 0, totalSetCount: 0, currentExerciseName: nil),
            weeklyVolume: WeeklyVolumeWidgetData(completedWorkoutCount: 0, workingSetCount: 0, loadVolume: nil, unitSymbol: nil),
            caffeine: CaffeineWidgetData(loggedMilligrams: 0, referenceMilligrams: 400),
            creatine: CreatineWidgetData(isConfirmed: false)
        )
    }
}
