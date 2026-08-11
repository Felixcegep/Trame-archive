import Foundation

/// Value-only presentation contract for the eyes-up execution surface.
///
/// The block model remains the source of persisted truth and the mutation
/// service remains the source of legal state changes. This contract only says
/// what an active block should expose for each format and state, which keeps
/// the SwiftUI surface testable without constructing a SwiftData graph.
enum WorkoutExecutionBlockExecutionPhase: Equatable {
    case ready
    case running
    case paused
    case completed
    case capped
    case partial
    case stopped
    case skipped
}

enum WorkoutExecutionBlockPrimaryAction: Equatable {
    case start
    case advance
    case complete
    case none
}

struct WorkoutExecutionBlockPresentation: Equatable {
    struct Input: Equatable {
        let kind: ExerciseBlockKind
        let targetRounds: Int?
        let clockMode: BlockClockMode
        let prescribedDurationSeconds: Int?
        let timeCapSeconds: Int?
        let intervalSeconds: Int?
        let scoreKind: BlockScoreKind
        let repetitionScheme: BlockRepetitionScheme
        let componentNames: [String]
        let status: WorkoutBlockStatus
        let completedRounds: Int
        let additionalRepetitions: Int
        let scoreValue: Double?
        let elapsed: TimeInterval
        let isClockRunning: Bool
    }

    let formatTitle: String
    let phase: WorkoutExecutionBlockExecutionPhase
    let timerText: String?
    let timerAccessibilityText: String?
    /// The durable snapshot stores ordered membership but no component cursor.
    /// Keep the sequence visible without claiming which component is active.
    let movementSequence: [String]
    let progressText: String?
    let intervalText: String?
    let scoreText: String?
    let primaryAction: WorkoutExecutionBlockPrimaryAction
    let primaryActionTitle: String?
    let primaryActionHint: String?
    let canPause: Bool
    let pauseActionTitle: String?
    let capActionTitle: String?

    static func make(input: Input) -> Self {
        let phase = phase(for: input)
        let timerText = timerText(for: input)
        let primaryAction: WorkoutExecutionBlockPrimaryAction
        switch phase {
        case .ready: primaryAction = .start
        case .running, .paused:
            primaryAction = input.kind.supportsRounds
                || input.kind == .amrap
                || input.kind == .emom
                || input.scoreKind == .roundsAndRepetitions
                ? .advance
                : .complete
        case .completed, .capped, .partial, .stopped, .skipped: primaryAction = .none
        }

        return Self(
            formatTitle: formatTitle(for: input.kind),
            phase: phase,
            timerText: timerText,
            timerAccessibilityText: timerText.map {
                String(format: String(localized: "Time %@"), $0)
            },
            movementSequence: phase == .ready || phase == .running || phase == .paused
                ? input.componentNames
                : [],
            progressText: progressText(for: input),
            intervalText: intervalText(for: input),
            scoreText: scoreText(for: input),
            primaryAction: primaryAction,
            primaryActionTitle: primaryActionTitle(for: primaryAction),
            primaryActionHint: primaryAction == .advance
                ? String(localized: "Advances to the next round or records a split.")
                : nil,
            canPause: (phase == .running || phase == .paused) && input.clockMode != .none,
            pauseActionTitle: phase == .paused
                ? String(localized: "Resume clock")
                : (phase == .running ? String(localized: "Pause clock") : nil),
            capActionTitle: phase == .running || phase == .paused
                ? (input.timeCapSeconds == nil
                    ? String(localized: "Stop block")
                    : String(localized: "End at cap"))
                : nil
        )
    }

    static func make(
        block: WorkoutExecutionBlock,
        workout: Workout,
        at date: Date = .now
    ) -> Self {
        return Self.make(input: Input(
            kind: block.kind,
            targetRounds: block.targetRounds,
            clockMode: block.clockMode,
            prescribedDurationSeconds: block.prescribedDurationSeconds,
            timeCapSeconds: block.timeCapSeconds,
            intervalSeconds: block.intervalSeconds,
            scoreKind: block.scoreKind,
            repetitionScheme: block.repetitionScheme,
            componentNames: WorkoutExecutionBlockService.entries(in: block, workout: workout)
                .map(\.occurrenceDisplayName),
            status: block.status,
            completedRounds: block.completedRounds,
            additionalRepetitions: block.additionalRepetitions,
            scoreValue: block.scoreValue,
            elapsed: block.elapsedDuration(at: date),
            isClockRunning: block.elapsedStartedAt != nil
        ))
    }

    private static func phase(for input: Input) -> WorkoutExecutionBlockExecutionPhase {
        switch input.status {
        case .notStarted: .ready
        case .inProgress:
            input.clockMode != .none && !input.isClockRunning ? .paused : .running
        case .completed: .completed
        case .capped: .capped
        case .partial: .partial
        case .stopped: .stopped
        case .skipped: .skipped
        }
    }

    private static func timerText(for input: Input) -> String? {
        guard input.clockMode != .none else { return nil }
        let duration: TimeInterval
        if input.clockMode == .countdown {
            duration = max(0, Double(input.prescribedDurationSeconds ?? 0) - input.elapsed)
        } else {
            duration = max(0, input.elapsed)
        }
        return format(duration)
    }

    private static func progressText(for input: Input) -> String? {
        if let targetRounds = input.targetRounds {
            return String(
                format: String(localized: "Round %lld of %lld"),
                Int64(min(max(0, input.completedRounds), targetRounds)),
                Int64(targetRounds)
            )
        }
        guard input.completedRounds > 0 else { return nil }
        return String(format: String(localized: "%lld rounds"), Int64(input.completedRounds))
    }

    private static func intervalText(for input: Input) -> String? {
        guard input.clockMode == .repeatingInterval,
              let intervalSeconds = input.intervalSeconds,
              intervalSeconds > 0
        else { return nil }
        let interval = Int(max(0, input.elapsed) / Double(intervalSeconds)) + 1
        let remainder = max(0, input.elapsed).truncatingRemainder(dividingBy: Double(intervalSeconds))
        return String(
            format: String(localized: "Interval %lld · %@ remaining"),
            Int64(interval),
            format(max(0, Double(intervalSeconds) - remainder))
        )
    }

    private static func scoreText(for input: Input) -> String? {
        switch input.scoreKind {
        case .none: nil
        case .roundsAndRepetitions: "\(input.completedRounds) + \(input.additionalRepetitions)"
        default: input.scoreValue?.formatted()
        }
    }

    private static func primaryActionTitle(for action: WorkoutExecutionBlockPrimaryAction) -> String? {
        switch action {
        case .start: String(localized: "Start block")
        case .advance: String(localized: "Complete round")
        case .complete: String(localized: "Complete block")
        case .none: nil
        }
    }

    private static func formatTitle(for kind: ExerciseBlockKind) -> String {
        switch kind {
        case .straight: String(localized: "Straight set")
        case .pairedSet: String(localized: "Paired set")
        case .triset: String(localized: "Triset")
        case .giantSet: String(localized: "Giant set")
        case .circuit: String(localized: "Circuit")
        case .olympicComplex: String(localized: "Olympic complex")
        case .amrap: String(localized: "AMRAP")
        case .emom: String(localized: "EMOM")
        case .forTime: String(localized: "For time")
        case .ladder: String(localized: "Ladder")
        case .chipper: String(localized: "Chipper")
        case .interval: String(localized: "Intervals")
        case .medley: String(localized: "Medley")
        }
    }

    private static func format(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
