import Foundation

struct ExerciseDetailInsightsModel: Equatable {
    let exerciseName: String
    let subtitle: String
    let latestSession: ExerciseDetailSession?
    let previousSession: ExerciseDetailSession?
    let bestResults: [ExerciseDetailBestResult]
    let estimatedOneRepMax: ExerciseDetailMetric?
    let volumePoints: [ExerciseDetailVolumePoint]
    let changeSummary: String?
    let volumeTakeaway: String?
    let notes: [ExerciseDetailNote]
    let progression: ExerciseDetailProgression?
    let historyCount: Int

    var hasHistory: Bool {
        latestSession != nil || historyCount > 0
    }

    var hasInsufficientHistory: Bool {
        hasHistory && historyCount < 2
    }
}

struct ExerciseDetailSession: Equatable, Identifiable {
    let id: String
    let workoutID: UUID?
    let date: String
    let summary: String
    let sets: [ExerciseDetailSet]

    init(
        id: String,
        workoutID: UUID? = nil,
        date: String,
        summary: String,
        sets: [ExerciseDetailSet]
    ) {
        self.id = id
        self.workoutID = workoutID
        self.date = date
        self.summary = summary
        self.sets = sets
    }
}

struct ExerciseDetailSet: Equatable, Identifiable {
    let id: String
    let label: String
    let value: String
    let detail: String?
}

struct ExerciseDetailBestResult: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String?
}

struct ExerciseDetailMetric: Equatable {
    let value: String
    let unit: String
    let context: String?
}

struct ExerciseDetailVolumePoint: Equatable, Identifiable {
    let id: String
    let date: Date
    let label: String
    let value: Double
    let unit: String
    let workingSetCount: Int
    let sessionCount: Int
    let accessibilityValue: String
}

struct ExerciseDetailNote: Equatable, Identifiable {
    let id: String
    let date: String
    let text: String
}

struct ExerciseDetailProgression: Equatable {
    let title: String
    let explanation: String
    let actionLabel: String?
}

extension ExerciseDetailInsightsModel {
    static let previewFull = ExerciseDetailInsightsModel(
        exerciseName: "Bench Press",
        subtitle: "Chest · Barbell · Weight and reps",
        latestSession: ExerciseDetailSession(
            id: "latest",
            date: "Today",
            summary: "3 sets · 100 lb",
            sets: [
                ExerciseDetailSet(id: "latest-1", label: "Set 1", value: "100 lb × 8", detail: nil),
                ExerciseDetailSet(id: "latest-2", label: "Set 2", value: "100 lb × 8", detail: nil),
                ExerciseDetailSet(id: "latest-3", label: "Set 3", value: "100 lb × 7", detail: "1 rep below last time")
            ]
        ),
        previousSession: ExerciseDetailSession(
            id: "previous",
            date: "Jul 7, 2026",
            summary: "3 sets · 100 lb",
            sets: [
                ExerciseDetailSet(id: "previous-1", label: "Set 1", value: "100 lb × 8", detail: nil),
                ExerciseDetailSet(id: "previous-2", label: "Set 2", value: "100 lb × 8", detail: nil),
                ExerciseDetailSet(id: "previous-3", label: "Set 3", value: "100 lb × 8", detail: nil)
            ]
        ),
        bestResults: [
            ExerciseDetailBestResult(id: "load", title: "Best load", value: "110 lb × 5", detail: "Jul 1, 2026"),
            ExerciseDetailBestResult(id: "reps", title: "Best reps", value: "100 lb × 10", detail: "Jun 24, 2026"),
            ExerciseDetailBestResult(id: "range", title: "Best 8–12 rep set", value: "100 lb × 10", detail: nil)
        ],
        estimatedOneRepMax: ExerciseDetailMetric(value: "128", unit: "lb", context: "Estimate from your best recent set"),
        volumePoints: [
            ExerciseDetailVolumePoint(id: "w1", date: .now.addingTimeInterval(-42 * 86_400), label: "Jun 3", value: 4_800, unit: "lb", workingSetCount: 3, sessionCount: 1, accessibilityValue: "4,800 pounds, 3 working sets, 1 session"),
            ExerciseDetailVolumePoint(id: "w2", date: .now.addingTimeInterval(-35 * 86_400), label: "Jun 10", value: 5_100, unit: "lb", workingSetCount: 3, sessionCount: 1, accessibilityValue: "5,100 pounds, 3 working sets, 1 session"),
            ExerciseDetailVolumePoint(id: "w3", date: .now.addingTimeInterval(-28 * 86_400), label: "Jun 17", value: 5_400, unit: "lb", workingSetCount: 3, sessionCount: 1, accessibilityValue: "5,400 pounds, 3 working sets, 1 session"),
            ExerciseDetailVolumePoint(id: "w4", date: .now.addingTimeInterval(-21 * 86_400), label: "Jun 24", value: 5_700, unit: "lb", workingSetCount: 3, sessionCount: 1, accessibilityValue: "5,700 pounds, 3 working sets, 1 session"),
            ExerciseDetailVolumePoint(id: "w5", date: .now.addingTimeInterval(-14 * 86_400), label: "Jul 1", value: 5_200, unit: "lb", workingSetCount: 3, sessionCount: 1, accessibilityValue: "5,200 pounds, 3 working sets, 1 session"),
            ExerciseDetailVolumePoint(id: "w6", date: .now.addingTimeInterval(-7 * 86_400), label: "Jul 7", value: 5_600, unit: "lb", workingSetCount: 3, sessionCount: 1, accessibilityValue: "5,600 pounds, 3 working sets, 1 session"),
            ExerciseDetailVolumePoint(id: "w7", date: .now, label: "Today", value: 5_700, unit: "lb", workingSetCount: 3, sessionCount: 1, accessibilityValue: "5,700 pounds, 3 working sets, 1 session")
        ],
        changeSummary: "You completed 100 lb for 8, 8, and 7 reps. The previous session was 100 lb for 8, 8, and 8 reps.",
        volumeTakeaway: "Weekly volume is about the same across the last four weeks.",
        notes: [
            ExerciseDetailNote(id: "note-1", date: "Jul 7, 2026", text: "Paused the last rep and kept the bar path steady."),
            ExerciseDetailNote(id: "note-2", date: "Jun 24, 2026", text: "Add a small amount next time if all sets reach 10 reps.")
        ],
        progression: ExerciseDetailProgression(
            title: "Keep the same load",
            explanation: "Not every required set reached 8 reps last time.",
            actionLabel: "View recommendation"
        ),
        historyCount: 7
    )

    static let previewInsufficient = ExerciseDetailInsightsModel(
        exerciseName: "Cable Chest Press",
        subtitle: "Chest · Cable · Weight and reps",
        latestSession: ExerciseDetailSession(
            id: "only-session",
            date: "Today",
            summary: "3 sets · 50 lb",
            sets: [
                ExerciseDetailSet(id: "only-1", label: "Set 1", value: "50 lb × 10", detail: nil),
                ExerciseDetailSet(id: "only-2", label: "Set 2", value: "50 lb × 9", detail: nil),
                ExerciseDetailSet(id: "only-3", label: "Set 3", value: "50 lb × 8", detail: nil)
            ]
        ),
        previousSession: nil,
        bestResults: [],
        estimatedOneRepMax: nil,
        volumePoints: [],
        changeSummary: nil,
        volumeTakeaway: "Early pattern — complete more sessions before treating this as a trend.",
        notes: [],
        progression: nil,
        historyCount: 1
    )

    static let previewEmpty = ExerciseDetailInsightsModel(
        exerciseName: "Deadlift",
        subtitle: "Back · Barbell · Weight and reps",
        latestSession: nil,
        previousSession: nil,
        bestResults: [],
        estimatedOneRepMax: nil,
        volumePoints: [],
        changeSummary: nil,
        volumeTakeaway: nil,
        notes: [],
        progression: nil,
        historyCount: 0
    )
}
