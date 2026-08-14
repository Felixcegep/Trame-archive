import Foundation

/// A within-workout execution structure. This is intentionally distinct from
/// `PlanBlock`, which represents a multi-week periodization phase.
nonisolated enum ExerciseBlockKind: String, Codable, CaseIterable {
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

    /// A short, plain-language description of how the format is performed. It is
    /// shown beneath the format picker so a lifter does not need to already know
    /// the jargon before choosing.
    var summary: String {
        switch self {
        case .straight: "One exercise performed on its own."
        case .pairedSet: "Two exercises alternated back to back."
        case .triset: "Three exercises performed back to back."
        case .giantSet: "Four or more exercises performed back to back."
        case .circuit: "Cycle through the exercises for a number of rounds."
        case .olympicComplex: "An ordered lift sequence scored per component."
        case .amrap: "As many rounds as possible before the time cap."
        case .emom: "Start a new round on every interval."
        case .forTime: "Finish all the work as fast as possible."
        case .ladder: "Repetitions climb or drop each round."
        case .chipper: "Work through every exercise once, in order."
        case .interval: "Alternate fixed work and rest intervals."
        case .medley: "Move through mixed stations in sequence."
        }
    }

    /// Whether the format repeats for a configurable number of rounds.
    var supportsRounds: Bool {
        switch self {
        case .pairedSet, .triset, .giantSet, .circuit, .olympicComplex, .ladder, .interval, .medley: true
        case .straight, .amrap, .emom, .forTime, .chipper: false
        }
    }

    /// Formats whose execution is bound to a shared clock. Their timing inputs
    /// are surfaced directly rather than hidden behind the optional clock
    /// override, because the clock is intrinsic to the format.
    var isTimed: Bool {
        switch self {
        case .amrap, .emom, .forTime, .interval: true
        default: false
        }
    }

    /// A time cap is a required — not optional — input for these formats.
    var requiresTimeCap: Bool { self == .amrap || self == .emom }

    /// A repeating-interval length is a required input for these formats.
    var requiresInterval: Bool { self == .emom || self == .interval }

    /// Guidance for how many exercises the format expects, shown above the
    /// exercise picker.
    var exerciseSelectionHint: String {
        switch self {
        case .straight: "Choose exactly one exercise."
        case .pairedSet: "Choose exactly two exercises."
        case .triset: "Choose exactly three exercises."
        case .giantSet: "Choose four or more exercises."
        default: "Choose the exercises that belong to this block."
        }
    }
}

nonisolated enum WorkoutBlockStatus: String, Codable, CaseIterable {
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

nonisolated enum BlockClockMode: String, Codable, CaseIterable {
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
nonisolated enum BlockScoreKind: String, Codable, CaseIterable {
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
nonisolated enum BlockRepetitionScheme: String, Codable, CaseIterable {
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
nonisolated enum SetMethod: String, Codable, CaseIterable {
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

/// The performed outcome of one ordered component in a prescribed Olympic
/// complex. This stays distinct from `LiftQuality`: a component can be
/// partially completed and still carry a technical-quality observation.
nonisolated enum ComplexComponentOutcome: String, Codable, CaseIterable {
    case notStarted
    case completed
    case partial
    case missed
    case skipped

    var title: String {
        switch self {
        case .notStarted: "Not logged"
        case .completed: "Made"
        case .partial: "Partial"
        case .missed: "Missed"
        case .skipped: "Skipped"
        }
    }
}

/// Snapshot input accepted by the persisted workout model. It intentionally
/// does not depend on the Program Engine so the Live Activity extension can
/// compile the workout schema independently.
nonisolated struct ComplexComponentSnapshot: Hashable {
    let exerciseID: UUID
    let exerciseNameSnapshot: String
    let prescribedRepetitions: Int
}

/// Parent-level result of one Olympic attempt. This is derived from the
/// ordered component evidence and therefore cannot disagree with it.
nonisolated enum OlympicAttemptOutcome: String, Codable, CaseIterable, Hashable {
    case notStarted
    case made
    case partial
    case missed
    case skipped

    var title: String {
        switch self {
        case .notStarted: "Not logged"
        case .made: "Made"
        case .partial: "Partial"
        case .missed: "Missed"
        case .skipped: "Skipped"
        }
    }
}

nonisolated enum MeasurementSource: String, Codable, CaseIterable {
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
nonisolated enum SpecializedPerformanceMetricKind: String, Codable, CaseIterable {
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

nonisolated enum ExecutionBlockConfigurationValidator {
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
