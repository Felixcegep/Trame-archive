import Foundation

enum RepeatingPlanPresentation {
    static func cycleSummary(
        currentSlotIndex: Int,
        slotCount: Int,
        completedCycleCount: Int
    ) -> String {
        guard slotCount > 0, (0..<slotCount).contains(currentSlotIndex) else {
            return String(localized: "Rotation needs attention")
        }
        return String(localized: "Cycle \(completedCycleCount + 1) · Workout \(currentSlotIndex + 1) of \(slotCount)")
    }

    static func rotationSummary(slotCount: Int) -> String {
        if slotCount == 1 {
            return String(localized: "1 workout in rotation")
        }
        return String(localized: "\(slotCount) workouts in rotation")
    }

    static func goalTitle(_ goal: PlanGoal) -> String {
        switch goal {
        case .generalStrength: String(localized: "General strength")
        case .hypertrophy: String(localized: "Hypertrophy")
        case .powerlifting: String(localized: "Powerlifting")
        case .generalFitness: String(localized: "General fitness")
        }
    }

    static func experienceTitle(_ level: PlanExperienceLevel) -> String {
        switch level {
        case .beginner: String(localized: "Beginner")
        case .intermediate: String(localized: "Intermediate")
        case .advanced: String(localized: "Advanced")
        }
    }

    static func alternateContinuationTitle(_ mode: RepeatingPlanContinuationMode) -> String {
        switch mode {
        case .keepExpected: String(localized: "Keep expected workout next")
        case .continueAfterSelected: String(localized: "Continue after selected workout")
        }
    }

    static func alternateContinuationDescription(_ mode: RepeatingPlanContinuationMode) -> String {
        switch mode {
        case .keepExpected: String(localized: "Your current next workout stays in place after this session.")
        case .continueAfterSelected: String(localized: "The rotation continues with the workout after this session.")
        }
    }

    static func runStatusTitle(_ status: RepeatingPlanRunStatus) -> String {
        switch status {
        case .active: String(localized: "Active")
        case .paused: String(localized: "Paused")
        case .ended: String(localized: "Ended")
        case .archived: String(localized: "Archived")
        }
    }

    static func alternateContinuationPrompt(workoutName: String) -> String {
        String(localized: "Start \(workoutName). Choose whether the expected rotation position stays next or follows this workout.")
    }
}
