import Foundation

/// The vocabulary of what a lifter says they want, kept deliberately separate
/// from `PlanGoal` (what a program is *designed to provide*) and from a
/// `WorkoutPlan` (the executable prescription).
///
/// Overloading `PlanGoal` with onboarding answers was the obvious shortcut and
/// the wrong one: it has four cases because four is what the compiler and the
/// substitution engine need, while a person describing their training needs
/// more room than that and needs to be allowed to say "I'm not sure yet".
/// Matching between the two layers lives in `ProgramMatchService`, where it can
/// be read, argued with, and shown to the user as a reason.
///
/// Every case here carries a stable raw identifier. Preferences are persisted
/// and backed up as those raw strings and decoded leniently, so a profile
/// written by a newer build restores into an older one as "unspecified" rather
/// than failing the restore.

// MARK: - Structure

/// How the lifter wants their next workout decided. The one question the app
/// genuinely cannot infer, and the only one asked before any training happens.
nonisolated enum TrainingStructureChoice: String, Codable, CaseIterable, Hashable, Sendable {
    case plan
    case rotation
    case freeWorkout

    /// Whether choosing this path leads into the profile questions at all.
    /// Free Workout must reach training immediately; personalization is offered
    /// afterwards, once the app has given something back.
    var asksProfileQuestions: Bool {
        switch self {
        case .plan, .rotation: true
        case .freeWorkout: false
        }
    }
}

// MARK: - Discipline

nonisolated enum TrainingDisciplinePreference: String, Codable, CaseIterable, Hashable, Sendable {
    case generalStrength
    case bodybuilding
    case powerlifting
    case olympicWeightlifting
    case strongman
    case hybridFitnessRacing
    case cardioEndurance
    case mobilityFlexibility
    case generalFitness
    case mixed
    case unspecified

    init?(rawValue: String) {
        switch rawValue {
        case "generalStrength": self = .generalStrength
        case "bodybuilding": self = .bodybuilding
        case "powerlifting": self = .powerlifting
        case "olympicWeightlifting": self = .olympicWeightlifting
        case "strongman": self = .strongman
        case "hybridFitnessRacing", "fitnessRacing": self = .hybridFitnessRacing
        case "cardioEndurance": self = .cardioEndurance
        case "mobilityFlexibility": self = .mobilityFlexibility
        case "generalFitness": self = .generalFitness
        case "mixed": self = .mixed
        case "unspecified": self = .unspecified
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .generalStrength: String(localized: "General strength")
        case .bodybuilding: String(localized: "Bodybuilding and hypertrophy")
        case .powerlifting: String(localized: "Powerlifting")
        case .olympicWeightlifting: String(localized: "Olympic weightlifting")
        case .strongman: String(localized: "Strongman")
        case .hybridFitnessRacing: String(localized: "HYROX and Hybrid Racing")
        case .cardioEndurance: String(localized: "Cardio and endurance")
        case .mobilityFlexibility: String(localized: "Mobility and flexibility")
        case .generalFitness: String(localized: "General fitness")
        case .mixed: String(localized: "Multiple training styles")
        case .unspecified: String(localized: "I’m not sure yet")
        }
    }

    var icon: String {
        switch self {
        case .generalStrength: AppIcon.muscles
        case .bodybuilding: AppIcon.workout
        case .powerlifting: "figure.strengthtraining.functional"
        case .olympicWeightlifting: "figure.australian.football"
        case .strongman: "figure.martial.arts"
        case .hybridFitnessRacing: "figure.mixed.cardio"
        case .cardioEndurance: "figure.run"
        case .mobilityFlexibility: AppIcon.mobility
        case .generalFitness: "figure.walk"
        case .mixed: "square.grid.2x2"
        case .unspecified: AppIcon.info
        }
    }

    /// The specialized-implement question this discipline opens, if any. A
    /// yoke belongs to the six people who train strongman, not to the universal
    /// equipment grid.
    var specializedEquipmentGroup: SpecializedEquipmentGroup? {
        switch self {
        case .olympicWeightlifting: .olympicWeightlifting
        case .strongman: .strongman
        case .hybridFitnessRacing: .hybrid
        case .mobilityFlexibility: .mobility
        default: nil
        }
    }
}

/// How Progress should prioritize the athlete's training identity.
///
/// This is an explicit presentation preference, not a classification of the
/// user's history. A mixed or undecided athlete can still see sport lenses
/// when completed-workout evidence exists; this value only controls priority.
nonisolated enum ProgressOrganizationMode: String, Codable, CaseIterable, Hashable, Sendable {
    case sportPriority
    case mixed
    case undecided

    var title: String {
        switch self {
        case .sportPriority: String(localized: "Prioritize my sports")
        case .mixed: String(localized: "Keep Progress mixed")
        case .undecided: String(localized: "I’m not sure yet")
        }
    }

    var detail: String {
        switch self {
        case .sportPriority: String(localized: "Use my primary and secondary sports to organize Progress.")
        case .mixed: String(localized: "Keep one combined Progress view without a primary sport.")
        case .undecided: String(localized: "Leave the organization unchanged until I choose.")
        }
    }
}

// MARK: - Goal

nonisolated enum TrainingGoalPreference: String, Codable, CaseIterable, Hashable, Sendable {
    case buildMuscle
    case getStronger
    case techniqueAndPower
    case conditioning
    case prepareForCompetition
    case mobility
    case bodyComposition
    case returnToTraining
    case maintain
    case explore

    var title: String {
        switch self {
        case .buildMuscle: String(localized: "Build muscle")
        case .getStronger: String(localized: "Get stronger")
        case .techniqueAndPower: String(localized: "Improve technique and power")
        case .conditioning: String(localized: "Improve conditioning")
        case .prepareForCompetition: String(localized: "Prepare for a competition")
        case .mobility: String(localized: "Improve mobility and flexibility")
        case .bodyComposition: String(localized: "Improve body composition")
        case .returnToTraining: String(localized: "Return to consistent training")
        case .maintain: String(localized: "Maintain my current fitness")
        case .explore: String(localized: "Explore without a specific goal")
        }
    }

    /// Whether the emphasis question is worth asking. Only physique-led goals
    /// earn it; asking a powerlifter which muscle to emphasize is noise.
    var asksMuscleEmphasis: Bool {
        switch self {
        case .buildMuscle, .bodyComposition: true
        default: false
        }
    }
}

// MARK: - Experience

/// Four answers rather than three, because "I don't know" is a real answer and
/// forcing a guess produces a worse ranking input than an honest nil.
nonisolated enum ProfileExperienceLevel: String, Codable, CaseIterable, Hashable, Sendable {
    case new
    case experienced
    case advanced
    case unsure

    var title: String {
        switch self {
        case .new: String(localized: "New")
        case .experienced: String(localized: "Experienced")
        case .advanced: String(localized: "Advanced")
        case .unsure: String(localized: "Not sure")
        }
    }

    var detail: String {
        switch self {
        case .new:
            String(localized: "I’m learning the basics or haven’t trained consistently yet.")
        case .experienced:
            String(localized: "I train consistently and understand the main exercises.")
        case .advanced:
            String(localized: "I use advanced programming, specialise or compete.")
        case .unsure:
            String(localized: "Help me choose.")
        }
    }

    /// The program-facing level, or `nil` when the lifter declined to claim
    /// one. Experience ranks programs; it does not lock them away.
    var planExperienceLevel: PlanExperienceLevel? {
        switch self {
        case .new: .beginner
        case .experienced: .intermediate
        case .advanced: .advanced
        case .unsure: nil
        }
    }
}

// MARK: - Schedule

/// How firm the week is. A lifter whose days move is not a lifter who trains
/// less, and a plan that pins sessions to weekdays is the wrong recommendation
/// for them even when the frequency matches.
nonisolated enum ScheduleFlexibility: String, Codable, CaseIterable, Hashable, Sendable {
    case fixedWeekdays
    case variable

    var title: String {
        switch self {
        case .fixedWeekdays: String(localized: "The same days each week")
        case .variable: String(localized: "My days change week to week")
        }
    }
}

/// Rotation users answer cadence, not weekdays. Asking someone who trains
/// "whenever I show up" to commit to Tuesdays is asking them to lie.
nonisolated enum RotationCadencePreference: String, Codable, CaseIterable, Hashable, Sendable {
    case daily
    case everyOtherDay
    case twoToThree
    case threeToFour
    case fourToFive
    case varies

    var title: String {
        switch self {
        case .daily: String(localized: "Every day")
        case .everyOtherDay: String(localized: "Every other day")
        case .twoToThree: String(localized: "2–3 times per week")
        case .threeToFour: String(localized: "3–4 times per week")
        case .fourToFive: String(localized: "4–5 times per week")
        case .varies: String(localized: "It changes")
        }
    }

    /// The weekly frequency this cadence implies, for ranking against a
    /// program's `supportedDaysPerWeek`. `nil` where no honest number exists.
    var impliedDaysPerWeek: ClosedRange<Int>? {
        switch self {
        case .daily: 6...7
        case .everyOtherDay: 3...4
        case .twoToThree: 2...3
        case .threeToFour: 3...4
        case .fourToFive: 4...5
        case .varies: nil
        }
    }
}

// MARK: - Session duration

nonisolated enum SessionDurationPreference: String, Codable, CaseIterable, Hashable, Sendable {
    case underThirty
    case thirtyToFortyFive
    case fortyFiveToSixty
    case sixtyToSeventyFive
    case overSeventyFive
    case doesNotMatter
    case varies

    var title: String {
        switch self {
        case .underThirty: String(localized: "Under 30 minutes")
        case .thirtyToFortyFive: String(localized: "Around 30–45 minutes")
        case .fortyFiveToSixty: String(localized: "Around 45–60 minutes")
        case .sixtyToSeventyFive: String(localized: "Around 60–75 minutes")
        case .overSeventyFive: String(localized: "More than 75 minutes")
        case .doesNotMatter: String(localized: "It doesn’t matter")
        case .varies: String(localized: "It changes")
        }
    }

    /// The preferred window in minutes, or `nil` when the lifter expressed no
    /// preference. A `nil` here must never be read as "any length is fine" for
    /// ranking purposes — it means the factor does not apply.
    var minutesRange: ClosedRange<Int>? {
        switch self {
        case .underThirty: 0...30
        case .thirtyToFortyFive: 30...45
        case .fortyFiveToSixty: 45...60
        case .sixtyToSeventyFive: 60...75
        case .overSeventyFive: 75...240
        case .doesNotMatter, .varies: nil
        }
    }

    /// Short form for the profile summary, where the full sentence is too long.
    var summaryTitle: String {
        switch self {
        case .underThirty: String(localized: "< 30 min")
        case .thirtyToFortyFive: String(localized: "30–45 min")
        case .fortyFiveToSixty: String(localized: "45–60 min")
        case .sixtyToSeventyFive: String(localized: "60–75 min")
        case .overSeventyFive: String(localized: "75+ min")
        case .doesNotMatter: String(localized: "Any length")
        case .varies: String(localized: "Varies")
        }
    }
}

// MARK: - Location and equipment

/// A location is a shortcut for an equipment list, not a fact about the user.
/// It preselects; it never asserts. The equipment screen that follows always
/// shows what was assumed and invites correction.
nonisolated enum TrainingLocationPreference: String, Codable, CaseIterable, Hashable, Sendable {
    case commercialGym
    case smallGym
    case homeGym
    case minimalEquipment
    case bodyweightOnly
    case multipleLocations
    case other

    var title: String {
        switch self {
        case .commercialGym: String(localized: "Full commercial gym")
        case .smallGym: String(localized: "Small gym")
        case .homeGym: String(localized: "Home gym")
        case .minimalEquipment: String(localized: "Minimal equipment")
        case .bodyweightOnly: String(localized: "Bodyweight only")
        case .multipleLocations: String(localized: "Multiple locations")
        case .other: String(localized: "Other")
        }
    }

    var detail: String? {
        switch self {
        case .commercialGym: String(localized: "Racks, machines, cables and full dumbbell range.")
        case .smallGym: String(localized: "Barbells and dumbbells, fewer machines.")
        case .homeGym: String(localized: "A rack or bench with the plates you own.")
        case .minimalEquipment: String(localized: "A few dumbbells, kettlebells or bands.")
        case .bodyweightOnly: String(localized: "Floor space and whatever the room offers.")
        case .multipleLocations: String(localized: "You train in more than one place.")
        case .other: nil
        }
    }

    var icon: String {
        switch self {
        case .commercialGym: "building.2"
        case .smallGym: "building"
        case .homeGym: "house"
        case .minimalEquipment: "shippingbox"
        case .bodyweightOnly: "figure.cooldown"
        case .multipleLocations: "arrow.triangle.swap"
        case .other: AppIcon.ellipsis
        }
    }

    /// Common equipment for this location. The onboarding screen presents this
    /// as a starting point the user is expected to edit — never as a claim
    /// about their gym.
    ///
    /// `.multipleLocations` and `.other` deliberately suggest nothing: guessing
    /// on behalf of someone who just told you their situation is irregular is
    /// how a preset becomes a wrong answer the user has to hunt down.
    var suggestedEquipment: Set<EquipmentType> {
        switch self {
        case .commercialGym:
            [.barbell, .dumbbell, .kettlebell, .cable, .machine, .cardioMachine, .bodyweight]
        case .smallGym:
            [.barbell, .dumbbell, .kettlebell, .cable, .bodyweight]
        case .homeGym:
            [.barbell, .dumbbell, .bodyweight]
        case .minimalEquipment:
            [.dumbbell, .kettlebell, .bodyweight]
        case .bodyweightOnly:
            [.bodyweight]
        case .multipleLocations, .other:
            []
        }
    }
}

extension EquipmentType {
    /// The lifter-facing name for the equipment grid. `rawValue` is the
    /// persisted identity and is singular ("Dumbbell"); a checklist reads
    /// better in the plural, and the two must not be conflated.
    var onboardingTitle: String {
        switch self {
        case .barbell: String(localized: "Barbell")
        case .dumbbell: String(localized: "Dumbbells")
        case .kettlebell: String(localized: "Kettlebells")
        case .medicineBall: String(localized: "Medicine balls")
        case .cable: String(localized: "Cable station")
        case .machine: String(localized: "Resistance machines")
        case .bodyweight: String(localized: "Bodyweight space")
        case .cardioMachine: String(localized: "Cardio machines")
        case .battleRopes: String(localized: "Battle ropes")
        case .sandbag: String(localized: "Sandbags")
        case .sled: String(localized: "Sled / Prowler")
        case .rings: String(localized: "Gymnastics rings")
        case .other: String(localized: "Other")
        }
    }

    var onboardingIcon: String {
        switch self {
        case .barbell: "figure.strengthtraining.traditional"
        case .dumbbell: AppIcon.workout
        case .kettlebell: "figure.cross.training"
        case .medicineBall: AppIcon.circleFill
        case .cable: "arrow.up.and.down"
        case .machine: "gearshape.2"
        case .bodyweight: "figure.arms.open"
        case .cardioMachine: "figure.run"
        case .battleRopes: "waveform.path"
        case .sandbag: "shippingbox.fill"
        case .sled: "arrow.forward.square.fill"
        case .rings: "circle.circle"
        case .other: AppIcon.ellipsis
        }
    }

    /// A kebab-case token safe to build an accessibility identifier from.
    ///
    /// `rawValue` is a *display* string — "Medicine Ball", "Cardio Machine" —
    /// so interpolating it directly produces identifiers containing capitals
    /// and a literal space, which a UI test then has to match verbatim.
    ///
    /// `PlanEquipmentPickerView` derives the same token from a private
    /// extension of its own; worth collapsing into this one when that screen is
    /// next touched.
    var identifierSlug: String {
        rawValue
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }

    /// The order the grid presents. `allCases` order is the model's, which puts
    /// `.other` in the middle of the checklist.
    static var onboardingOrder: [EquipmentType] {
        [.barbell, .dumbbell, .kettlebell, .cable, .machine, .cardioMachine, .medicineBall, .bodyweight, .battleRopes, .sandbag, .sled, .rings, .other]
    }
}

/// Specialized implements, stored as versioned capability identifiers rather
/// than as a central Swift enum that grows by one case every time a discipline
/// is added. An identifier a build does not recognise is carried through
/// backups untouched instead of being dropped.
nonisolated enum SpecializedEquipmentGroup: String, Codable, CaseIterable, Hashable, Sendable {
    case olympicWeightlifting
    case strongman
    case hybrid
    case mobility

    var question: String {
        switch self {
        case .olympicWeightlifting: String(localized: "Which lifting equipment do you have?")
        case .strongman: String(localized: "Which strongman implements can you use?")
        case .hybrid: String(localized: "Which conditioning equipment can you use?")
        case .mobility: String(localized: "What do you have for mobility work?")
        }
    }

    var capabilities: [SpecializedEquipmentCapability] {
        switch self {
        case .olympicWeightlifting:
            [
                .init(id: "bumperPlates", title: String(localized: "Bumper plates")),
                .init(id: "platform", title: String(localized: "Platform")),
                .init(id: "blocks", title: String(localized: "Blocks")),
                .init(id: "jerkBlocks", title: String(localized: "Jerk blocks")),
                .init(id: "squatRack", title: String(localized: "Squat rack"))
            ]
        case .strongman:
            [
                .init(id: "log", title: String(localized: "Log")),
                .init(id: "yoke", title: String(localized: "Yoke")),
                .init(id: "farmersHandles", title: String(localized: "Farmer’s handles")),
                .init(id: "sandbag", title: String(localized: "Sandbags")),
                .init(id: "sled", title: String(localized: "Sled")),
                .init(id: "atlasStones", title: String(localized: "Stones")),
                .init(id: "throwingEquipment", title: String(localized: "Throwing equipment"))
            ]
        case .hybrid:
            [
                .init(id: "skiErg", title: String(localized: "SkiErg")),
                .init(id: "rowErg", title: String(localized: "RowErg")),
                .init(id: "airBike", title: String(localized: "Air bike")),
                .init(id: "sled", title: String(localized: "Sled")),
                .init(id: "wallBallTarget", title: String(localized: "Wall-ball target")),
                .init(id: "sandbag", title: String(localized: "Sandbags")),
                .init(id: "farmersHandles", title: String(localized: "Farmer’s handles"))
            ]
        case .mobility:
            [
                .init(id: "bands", title: String(localized: "Bands")),
                .init(id: "straps", title: String(localized: "Straps")),
                .init(id: "yogaBlocks", title: String(localized: "Blocks")),
                .init(id: "foamRoller", title: String(localized: "Foam roller")),
                .init(id: "wallSpace", title: String(localized: "Wall space")),
                .init(id: "floorSpace", title: String(localized: "Open floor space"))
            ]
        }
    }
}

nonisolated struct SpecializedEquipmentCapability: Identifiable, Hashable, Sendable {
    let id: String
    let title: String

    static func title(for id: String) -> String {
        SpecializedEquipmentGroup.allCases
            .flatMap(\.capabilities)
            .first { $0.id == id }?.title ?? id
    }
}

// MARK: - Emphasis

nonisolated enum FocusArea: String, Codable, CaseIterable, Hashable, Sendable {
    case balanced
    case chest
    case back
    case shoulders
    case arms
    case quadriceps
    case hamstringsAndGlutes
    case calves
    case core

    var title: String {
        switch self {
        case .balanced: String(localized: "Balanced development")
        case .chest: String(localized: "Chest")
        case .back: String(localized: "Back")
        case .shoulders: String(localized: "Shoulders")
        case .arms: String(localized: "Arms")
        case .quadriceps: String(localized: "Quadriceps")
        case .hamstringsAndGlutes: String(localized: "Hamstrings and glutes")
        case .calves: String(localized: "Calves")
        case .core: String(localized: "Core")
        }
    }

    /// At most two emphases are accepted, and `.balanced` is exclusive with the
    /// rest: "balanced, but mostly arms" is not a preference, it is a
    /// contradiction the ranking cannot honour.
    static let maximumSelections = 2
}

// MARK: - Competition

nonisolated enum CompetitionDiscipline: String, Codable, CaseIterable, Hashable, Sendable {
    case powerlifting
    case olympicWeightlifting
    case strongman
    case bodybuilding
    case hybridFitnessRacing
    case endurance
    case other
    case undecided

    init?(rawValue: String) {
        switch rawValue {
        case "powerlifting": self = .powerlifting
        case "olympicWeightlifting": self = .olympicWeightlifting
        case "strongman": self = .strongman
        case "bodybuilding": self = .bodybuilding
        case "hybridFitnessRacing", "fitnessRacing": self = .hybridFitnessRacing
        case "endurance": self = .endurance
        case "other": self = .other
        case "undecided": self = .undecided
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .powerlifting: String(localized: "Powerlifting")
        case .olympicWeightlifting: String(localized: "Olympic weightlifting")
        case .strongman: String(localized: "Strongman")
        case .bodybuilding: String(localized: "Bodybuilding")
        case .hybridFitnessRacing: String(localized: "HYROX Race Preparation")
        case .endurance: String(localized: "Running or endurance event")
        case .other: String(localized: "Other")
        case .undecided: String(localized: "I haven’t decided")
        }
    }
}

/// Which rulebook the app should measure against.
///
/// Deliberately not a gender question, and deliberately not the first thing the
/// app asks anyone. Federations publish different loads, divisions, and weight
/// classes; that is a property of the competition, not of the person entering
/// it, and the app only needs it when it changes what is shown.
nonisolated enum CompetitionStandards: String, Codable, CaseIterable, Hashable, Sendable {
    case womens
    case mens
    case open
    case perEvent
    case unsure
    case preferNotToSay

    var title: String {
        switch self {
        case .womens: String(localized: "Women’s standards")
        case .mens: String(localized: "Men’s standards")
        case .open: String(localized: "Open or general standards")
        case .perEvent: String(localized: "Let me choose for each event")
        case .unsure: String(localized: "Not sure yet")
        case .preferNotToSay: String(localized: "Prefer not to say")
        }
    }
}

nonisolated struct CompetitionProfileDraft: Codable, Equatable, Hashable, Sendable {
    var discipline: CompetitionDiscipline? = nil
    var eventDate: Date? = nil
    var standards: CompetitionStandards? = nil
    /// Explicit historical exercise identities used by the Powerlifting lens.
    /// They are never inferred from names or movement patterns.
    var squatExerciseID: UUID? = nil
    var benchExerciseID: UUID? = nil
    var deadliftExerciseID: UUID? = nil

    var isEmpty: Bool {
        discipline == nil && eventDate == nil && standards == nil
            && squatExerciseID == nil && benchExerciseID == nil && deadliftExerciseID == nil
    }
}

// MARK: - Mobility intake
//
// Kept independent of the strength-training questions above: a lifter can
// want a mobility plan alongside a strength plan, instead of one, or neither.
// Answering here never implies anything about `primaryDiscipline`/`primaryGoal`
// even when someone picks `.mobilityFlexibility`/`.mobility` there — the two
// tracks are ranked separately by `ProgramMatchService` and `MobilityMatchService`.

/// What the lifter wants a mobility plan to do for them, in plain language —
/// never "PNF", "end-range control" or any other engine vocabulary.
nonisolated enum MobilityGoalPreference: String, Codable, CaseIterable, Hashable, Sendable {
    case generalFlexibility
    case recovery
    case targetedPosition

    var title: String {
        switch self {
        case .generalFlexibility: String(localized: "Move and stretch more freely overall")
        case .recovery: String(localized: "Recover and reduce stiffness between workouts")
        case .targetedPosition: String(localized: "Improve a specific position — like squat depth or overhead reach")
        }
    }
}

/// Separate from `ProfileExperienceLevel`: a lifter can be advanced in the
/// weight room and brand new to structured mobility work, or the reverse.
nonisolated enum MobilityExperiencePreference: String, Codable, CaseIterable, Hashable, Sendable {
    case new
    case someExperience
    case experienced
    case unsure

    var title: String {
        switch self {
        case .new: String(localized: "New to mobility work")
        case .someExperience: String(localized: "Some experience")
        case .experienced: String(localized: "Very experienced")
        case .unsure: String(localized: "Not sure")
        }
    }

    var detail: String {
        switch self {
        case .new:
            String(localized: "I’m just starting to stretch and mobilize on purpose.")
        case .someExperience:
            String(localized: "I stretch regularly and know the basics.")
        case .experienced:
            String(localized: "I’m comfortable with loaded or advanced mobility work.")
        case .unsure:
            String(localized: "Help me choose.")
        }
    }

    /// The plan-facing level, or `nil` when the lifter declined to claim one.
    /// Mirrors `ProfileExperienceLevel.planExperienceLevel`: experience ranks
    /// mobility plans, it never hides one.
    var mobilityMatchLevel: MobilityMatchExperienceLevel? {
        switch self {
        case .new: .beginner
        case .someExperience: .intermediate
        case .experienced: .advanced
        case .unsure: nil
        }
    }
}

/// How often the lifter wants to do mobility work, asked the same plain way
/// as the strength-training frequency question.
nonisolated enum MobilityFrequencyPreference: String, Codable, CaseIterable, Hashable, Sendable {
    case onceOrTwice
    case twoToThree
    case threeOrMore
    case varies

    var title: String {
        switch self {
        case .onceOrTwice: String(localized: "Once or twice a week")
        case .twoToThree: String(localized: "2–3 times a week")
        case .threeOrMore: String(localized: "3 or more times a week")
        case .varies: String(localized: "It changes")
        }
    }

    /// The weekly frequency this bucket implies, for ranking against a
    /// mobility plan's `supportedDaysPerWeek`. `nil` where no honest number
    /// exists — "it changes" contributes nothing rather than a guess.
    var impliedDaysPerWeek: ClosedRange<Int>? {
        switch self {
        case .onceOrTwice: 1...2
        case .twoToThree: 2...3
        case .threeOrMore: 3...5
        case .varies: nil
        }
    }
}
