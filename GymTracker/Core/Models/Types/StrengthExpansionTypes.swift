import Foundation

/// A within-workout execution structure. This is intentionally distinct from
/// `PlanBlock`, which represents a multi-week periodization phase.
enum ExerciseBlockKind: String, Codable, CaseIterable {
    case straight
    case pairedSet
    case triset
    case giantSet
    case circuit
    case olympicComplex
    case amrap
    case emom
    case forTime
    case ladder
    case chipper
    case interval
    case medley

    var title: String {
        switch self {
        case .straight: "Straight set"
        case .pairedSet: "Paired set"
        case .triset: "Triset"
        case .giantSet: "Giant set"
        case .circuit: "Circuit"
        case .olympicComplex: "Olympic complex"
        case .amrap: "AMRAP"
        case .emom: "EMOM"
        case .forTime: "For time"
        case .ladder: "Ladder"
        case .chipper: "Chipper"
        case .interval: "Intervals"
        case .medley: "Medley"
        }
    }

}

enum WorkoutBlockStatus: String, Codable, CaseIterable {
    case notStarted
    case inProgress
    case completed
    case capped
    case partial
    case stopped
    case skipped

    var title: String {
        switch self {
        case .notStarted: "Not started"
        case .inProgress: "In progress"
        case .completed: "Complete"
        case .capped: "Time capped"
        case .partial: "Partial"
        case .stopped: "Stopped"
        case .skipped: "Skipped"
        }
    }
}

enum BlockClockMode: String, Codable, CaseIterable {
    case none
    case countUp
    case countdown
    case repeatingInterval

    var title: String {
        switch self {
        case .none: "No shared clock"
        case .countUp: "Count up"
        case .countdown: "Countdown"
        case .repeatingInterval: "Repeating interval"
        }
    }
}

/// The score is stored as raw, typed evidence. Presentation and comparison
/// policies decide whether it is eligible for a record or progression rule.
enum BlockScoreKind: String, Codable, CaseIterable {
    case none
    case duration
    case roundsAndRepetitions
    case completedWork
    case distance
    case calories
    case load
    case points

    var title: String {
        switch self {
        case .none: "No score"
        case .duration: "Time"
        case .roundsAndRepetitions: "Rounds + repetitions"
        case .completedWork: "Completed work"
        case .distance: "Distance"
        case .calories: "Calories"
        case .load: "Load"
        case .points: "Points"
        }
    }
}

/// Explicitly describes when a block's repetitions change across rounds.
/// Per-exercise target sets/reps remain the component prescription for fixed
/// circuits and chippers.
enum BlockRepetitionScheme: String, Codable, CaseIterable {
    case fixed
    case ascendingLadder
    case descendingLadder
    case chipper

    var title: String {
        switch self {
        case .fixed: "Fixed repetitions"
        case .ascendingLadder: "Ascending ladder"
        case .descendingLadder: "Descending ladder"
        case .chipper: "Chipper"
        }
    }
}

/// A set role (`SetType`) and its method are independent. A top set may be a
/// cluster; a back-off set may be a dropset.
enum SetMethod: String, Codable, CaseIterable {
    case standard
    case dropSet
    case mechanicalDropSet
    case cluster
    case restPause
    case myoReps

    var title: String {
        switch self {
        case .standard: "Standard"
        case .dropSet: "Dropset"
        case .mechanicalDropSet: "Mechanical dropset"
        case .cluster: "Cluster"
        case .restPause: "Rest-pause"
        case .myoReps: "Myo-reps"
        }
    }

    var detail: String {
        switch self {
        case .standard: "One uninterrupted effort."
        case .dropSet: "Record each load reduction as an internal segment."
        case .mechanicalDropSet: "Record each leverage or variation change as an internal segment."
        case .cluster: "Record the short-rest efforts inside this set."
        case .restPause: "Record each rest-pause burst without inflating set count."
        case .myoReps: "Record the activation effort and mini-sets as segments."
        }
    }

    /// A segmented method needs enough internal efforts to preserve its
    /// meaning. The top-level parent remains the only counted working set.
    var minimumSegmentCount: Int {
        switch self {
        case .standard: 0
        case .dropSet, .mechanicalDropSet, .restPause, .myoReps: 2
        case .cluster: 3
        }
    }

    var defaultInterSegmentRestSeconds: Int? {
        switch self {
        case .standard, .dropSet, .mechanicalDropSet: nil
        case .cluster: 15
        case .restPause: 20
        case .myoReps: 5
        }
    }
}

enum MeasurementSource: String, Codable, CaseIterable {
    case manual
    case imported
    case device
    case estimated

    var title: String {
        switch self {
        case .manual: "Manual"
        case .imported: "Imported"
        case .device: "Device"
        case .estimated: "Estimated"
        }
    }
}

/// A deliberately small, typed set of sport-specific outcomes. The value for
/// each kind lives in its own unit-bearing property on `ExerciseSet`, avoiding
/// ambiguous custom key/value metrics in workout history.
enum SpecializedPerformanceMetricKind: String, Codable, CaseIterable {
    case none
    case jumpHeight
    case contactTime
    case throwDistance
    case kettlebellCadence

    var title: String {
        switch self {
        case .none: "None"
        case .jumpHeight: "Jump height"
        case .contactTime: "Contact time"
        case .throwDistance: "Throw distance"
        case .kettlebellCadence: "Kettlebell cadence"
        }
    }
}

enum ExecutionBlockConfigurationValidator {
    static func message(
        kind: ExerciseBlockKind,
        clockMode: BlockClockMode,
        prescribedDurationSeconds: Int?,
        timeCapSeconds: Int?,
        intervalSeconds: Int?,
        repetitionScheme: BlockRepetitionScheme,
        repetitionStart: Int?,
        repetitionEnd: Int?,
        repetitionStep: Int?
    ) -> String? {
        if let prescribedDurationSeconds, prescribedDurationSeconds <= 0 {
            return "A prescribed duration must be positive."
        }
        if let timeCapSeconds, timeCapSeconds <= 0 {
            return "A time cap must be positive."
        }
        if clockMode == .countdown && (prescribedDurationSeconds ?? 0) <= 0 {
            return "A countdown block needs a duration."
        }
        if clockMode == .repeatingInterval && (intervalSeconds ?? 0) <= 0 {
            return "A repeating interval needs an interval length."
        }
        if kind == .amrap && (timeCapSeconds ?? 0) <= 0 {
            return "An AMRAP needs a time cap."
        }
        if kind == .amrap && clockMode != .countUp {
            return "An AMRAP uses a count-up clock."
        }
        if kind == .emom && (timeCapSeconds ?? 0) <= 0 {
            return "An EMOM needs a time cap."
        }
        if kind == .emom && clockMode != .repeatingInterval {
            return "An EMOM needs a repeating interval clock."
        }
        if kind == .forTime && clockMode != .countUp {
            return "A For Time block uses a count-up clock."
        }
        if kind == .interval && clockMode != .repeatingInterval {
            return "An interval block needs a repeating interval clock."
        }
        if kind == .ladder,
           repetitionScheme != .ascendingLadder,
           repetitionScheme != .descendingLadder {
            return "A ladder needs an ascending or descending repetition pattern."
        }
        if kind == .chipper, repetitionScheme != .chipper {
            return "A chipper needs a chipper repetition pattern."
        }
        if kind != .ladder,
           kind != .chipper,
           repetitionScheme != .fixed {
            return "Only ladder and chipper blocks can change repetitions across the block."
        }
        if repetitionScheme == .ascendingLadder || repetitionScheme == .descendingLadder {
            guard let start = repetitionStart,
                  let end = repetitionEnd,
                  let step = repetitionStep,
                  start > 0, end > 0, step > 0, start != end
            else {
                return "A ladder needs distinct positive start and end repetitions plus a positive step."
            }
        }
        if repetitionScheme == .ascendingLadder,
           let start = repetitionStart,
           let end = repetitionEnd,
           start >= end {
            return "An ascending ladder must end above its starting repetitions."
        }
        if repetitionScheme == .descendingLadder,
           let start = repetitionStart,
           let end = repetitionEnd,
           start <= end {
            return "A descending ladder must end below its starting repetitions."
        }
        return nil
    }
}
