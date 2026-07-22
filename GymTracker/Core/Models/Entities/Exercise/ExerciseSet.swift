//
//  Set.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//


import Combine
import Foundation
import SwiftData

@Model
final class ExerciseSet {
    var id = UUID()
    var orderIndex: Int = 0
    var weightType: WeightType = WeightType.kg
    var distanceType: DistanceType = DistanceType.kilometers
    var repetitions: Float
    var weight: Float
    var duration: TimeInterval?
    var distance: Float?
    var calories: Double?
    var done: Bool = false
    /// Captures an intentional edit to a generated prescription without
    /// changing the reusable program definition.
    var isUserOverridden: Bool = false
    var userOverrideReason: String?
    var userOverrideAffectsFuture: Bool = false
    var rpe: Int?
    var rir: Int?
    var liftQuality: LiftQuality?
    var meanVelocity: Double?
    /// Peak concentric velocity in metres per second. It is optional because
    /// manual and device capture are both opt-in and absent data is never zero.
    var peakVelocity: Double?
    var velocityMeasurementSource: MeasurementSource?
    var specializedMetricKind: SpecializedPerformanceMetricKind = SpecializedPerformanceMetricKind.none
    /// Measured vertically in metres; presentation can convert to the user's
    /// preferred unit without losing a stable analytical unit.
    var jumpHeightMeters: Double?
    /// Ground-contact duration in milliseconds for reactive jump work.
    var contactTimeMilliseconds: Double?
    /// Distance in metres for throws and comparable strongman events.
    var throwDistanceMeters: Double?
    /// Repetitions per minute for kettlebell and cyclical implement work.
    var kettlebellCadenceRPM: Double?
    var specializedMetricMeasurementSource: MeasurementSource?
    /// Independent from `setType`: describes how the work was performed.
    var setMethod: SetMethod = SetMethod.standard
    var setType: SetType = SetType.normal
    /// For a daily-maximum exposure, the lifter can choose which completed
    /// attempt supplies same-session derived back-off work.
    var isSelectedDailyMaximum: Bool = false
    /// Non-nil only for a dynamically generated back-off set. The definition
    /// UUID lets refreshes update the same incomplete row instead of adding a
    /// duplicate after repeated source events or relaunch.
    var generatedBackOffDefinitionID: UUID?
    /// Immutable-at-start prescription evidence. Performed values above remain
    /// authoritative and are never overwritten from these fields.
    var prescribedSetType: SetType?
    var prescribedRepetitions: Int?
    var prescribedRepRangeMinimum: Int?
    var prescribedRepRangeMaximum: Int?
    var prescribedSuggestedLoad: Double?
    var prescribedSuggestedLoadType: WeightType?
    /// The calculation before equipment rounding, retained with the snapshot
    /// so History can explain why the displayed prescribed load was chosen.
    var prescribedUnroundedLoad: Double?
    /// The source TM/e1RM/top-set value used by the prescription calculation, in kilograms.
    var prescribedReferenceValue: Double?
    var prescriptionLoadExplanation: String?
    var prescribedRestSeconds: Int?
    var prescribedRPE: Double?
    var prescribedRIR: Int?
    var prescribedTempo: String?
    var prescribedProgressionEligible: Bool?
    var prescribedCalories: Double?
    var prescribedVelocityMinimum: Double?
    var prescribedVelocityMaximum: Double?
    var prescribedVelocityLossStopPercent: Double?
    var isVelocityProbe: Bool = false
    var isPrescribedOptional: Bool?
    var prescriptionNotes: String?
    var prescriptionDefinitionData: Data?
    var usedMetric : UnitSystem
    var exerciseEntry: ExerciseEntry?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSetSegment.exerciseSet)
    var segments: [ExerciseSetSegment] = []
    @Relationship(deleteRule: .cascade, inverse: \ComplexComponentResult.exerciseSet)
    var complexComponents: [ComplexComponentResult] = []
    init(
        repetitions: Float = 0,
        weight: Float = 0,
        duration: TimeInterval? = nil,
        distance: Float? = nil,
        calories: Double? = nil,
        
        
        done: Bool = false,
        isUserOverridden: Bool = false,
        userOverrideReason: String? = nil,
        userOverrideAffectsFuture: Bool = false,
        rpe: Int? = nil,
        rir: Int? = nil,
        liftQuality: LiftQuality? = nil,
        meanVelocity: Double? = nil,
        peakVelocity: Double? = nil,
        velocityMeasurementSource: MeasurementSource? = nil,
        specializedMetricKind: SpecializedPerformanceMetricKind = .none,
        jumpHeightMeters: Double? = nil,
        contactTimeMilliseconds: Double? = nil,
        throwDistanceMeters: Double? = nil,
        kettlebellCadenceRPM: Double? = nil,
        specializedMetricMeasurementSource: MeasurementSource? = nil,
        setMethod: SetMethod = .standard,
        setType: SetType = .normal,
        orderIndex: Int = 0,
        usedMetric : UnitSystem
    ) {
        self.orderIndex = orderIndex
        self.weightType = usedMetric == .metric ? .kg : .lbs
        self.distanceType = usedMetric == .metric ? .kilometers : .miles
        self.repetitions = repetitions
        self.weight = weight
        self.duration = duration
        self.distance = distance
        self.calories = calories
        self.done = done
        self.isUserOverridden = isUserOverridden
        self.userOverrideReason = userOverrideReason
        self.userOverrideAffectsFuture = userOverrideAffectsFuture
        self.rpe = rpe
        self.rir = rir
        self.liftQuality = liftQuality
        self.meanVelocity = meanVelocity
        self.peakVelocity = peakVelocity
        self.velocityMeasurementSource = velocityMeasurementSource
        self.specializedMetricKind = specializedMetricKind
        self.jumpHeightMeters = jumpHeightMeters
        self.contactTimeMilliseconds = contactTimeMilliseconds
        self.throwDistanceMeters = throwDistanceMeters
        self.kettlebellCadenceRPM = kettlebellCadenceRPM
        self.specializedMetricMeasurementSource = specializedMetricMeasurementSource
        self.setMethod = setMethod
        self.setType = setType
        self.isSelectedDailyMaximum = false
        self.generatedBackOffDefinitionID = nil
        self.prescribedSetType = nil
        self.prescribedRepetitions = nil
        self.prescribedRepRangeMinimum = nil
        self.prescribedRepRangeMaximum = nil
        self.prescribedSuggestedLoad = nil
        self.prescribedSuggestedLoadType = nil
        self.prescribedUnroundedLoad = nil
        self.prescribedReferenceValue = nil
        self.prescriptionLoadExplanation = nil
        self.prescribedRestSeconds = nil
        self.prescribedRPE = nil
        self.prescribedRIR = nil
        self.prescribedTempo = nil
        self.prescribedProgressionEligible = nil
        self.prescribedCalories = nil
        self.prescribedVelocityMinimum = nil
        self.prescribedVelocityMaximum = nil
        self.prescribedVelocityLossStopPercent = nil
        self.isVelocityProbe = false
        self.isPrescribedOptional = nil
        self.prescriptionNotes = nil
        self.prescriptionDefinitionData = nil
        self.usedMetric = usedMetric
        self.segments = []
        self.complexComponents = []
    }

    func copy() -> ExerciseSet {
        let copy = ExerciseSet(
            repetitions: repetitions,
            weight: weight,
            duration: duration,
            distance: distance,
            calories: calories,
            
            
            done: false,
            rpe: rpe,
            rir: rir,
            liftQuality: liftQuality,
            meanVelocity: meanVelocity,
            peakVelocity: peakVelocity,
            velocityMeasurementSource: velocityMeasurementSource,
            specializedMetricKind: specializedMetricKind,
            jumpHeightMeters: jumpHeightMeters,
            contactTimeMilliseconds: contactTimeMilliseconds,
            throwDistanceMeters: throwDistanceMeters,
            kettlebellCadenceRPM: kettlebellCadenceRPM,
            specializedMetricMeasurementSource: specializedMetricMeasurementSource,
            setMethod: setMethod,
            setType: setType,
            orderIndex: 0,
            usedMetric: usedMetric
        )
        copy.weightType = weightType
        copy.distanceType = distanceType
        // A copied active set is a new performed effort, but it remains part
        // of the same active prescription. Retain immutable target evidence
        // so an appended daily-maximum attempt or working set can still feed
        // same-session formulas and later History explanations.
        copy.prescribedSetType = prescribedSetType
        copy.prescribedRepetitions = prescribedRepetitions
        copy.prescribedRepRangeMinimum = prescribedRepRangeMinimum
        copy.prescribedRepRangeMaximum = prescribedRepRangeMaximum
        copy.prescribedSuggestedLoad = prescribedSuggestedLoad
        copy.prescribedSuggestedLoadType = prescribedSuggestedLoadType
        copy.prescribedUnroundedLoad = prescribedUnroundedLoad
        copy.prescribedReferenceValue = prescribedReferenceValue
        copy.prescriptionLoadExplanation = prescriptionLoadExplanation
        copy.prescribedRestSeconds = prescribedRestSeconds
        copy.prescribedRPE = prescribedRPE
        copy.prescribedRIR = prescribedRIR
        copy.prescribedTempo = prescribedTempo
        copy.prescribedProgressionEligible = prescribedProgressionEligible
        copy.prescribedCalories = prescribedCalories
        copy.prescribedVelocityMinimum = prescribedVelocityMinimum
        copy.prescribedVelocityMaximum = prescribedVelocityMaximum
        copy.prescribedVelocityLossStopPercent = prescribedVelocityLossStopPercent
        copy.isVelocityProbe = isVelocityProbe
        copy.isPrescribedOptional = isPrescribedOptional
        copy.prescriptionNotes = prescriptionNotes
        copy.prescriptionDefinitionData = prescriptionDefinitionData
        // A new attempt must be selected deliberately; copying a prior daily
        // maximum cannot create two reference attempts.
        copy.isSelectedDailyMaximum = false
        copy.generatedBackOffDefinitionID = nil
        copy.segments = orderedSegments.map { segment in
            ExerciseSetSegment(
                orderIndex: segment.orderIndex,
                repetitions: segment.repetitions,
                weight: segment.weight,
                weightType: segment.weightType,
                duration: segment.duration,
                restAfterSeconds: segment.restAfterSeconds,
                done: false,
                variationNote: segment.variationNote,
                rpe: segment.rpe,
                rir: segment.rir
            )
        }
        copy.complexComponents = orderedComplexComponents.map { component in
            ComplexComponentResult(
                orderIndex: component.orderIndex,
                exerciseID: component.exerciseID,
                exerciseNameSnapshot: component.exerciseNameSnapshot,
                prescribedRepetitions: component.prescribedRepetitions,
                performedRepetitions: 0,
                outcome: .notStarted
            )
        }
        return copy
    }

    /// Initializes internal evidence only when a segmented method is selected.
    /// Existing segments are never overwritten by a method change, preserving
    /// recorded work instead of silently fabricating or deleting history.
    func ensureSegmentsForMethod() {
        let requiredCount = setMethod.minimumSegmentCount
        guard requiredCount > 0, segments.count < requiredCount else { return }
        for index in segments.count..<requiredCount {
            segments.append(ExerciseSetSegment(
                orderIndex: index,
                repetitions: repetitions,
                weight: weight,
                weightType: weightType,
                restAfterSeconds: index + 1 < requiredCount ? setMethod.defaultInterSegmentRestSeconds : nil
            ))
        }
        normalizeSegmentOrder()
    }

    /// Segments are evidence inside this one set, so they share the parent
    /// completion transition and never become independently completable work.
    func synchronizeSegmentCompletion() {
        for segment in segments {
            segment.done = done
        }
    }

    /// Removes prescription evidence when the user intentionally creates a
    /// new ad-hoc set rather than extending a generated set role.
    func clearPrescription() {
        prescribedSetType = nil
        prescribedRepetitions = nil
        prescribedRepRangeMinimum = nil
        prescribedRepRangeMaximum = nil
        prescribedSuggestedLoad = nil
        prescribedSuggestedLoadType = nil
        prescribedUnroundedLoad = nil
        prescribedReferenceValue = nil
        prescriptionLoadExplanation = nil
        prescribedRestSeconds = nil
        prescribedRPE = nil
        prescribedRIR = nil
        prescribedTempo = nil
        prescribedProgressionEligible = nil
        prescribedCalories = nil
        prescribedVelocityMinimum = nil
        prescribedVelocityMaximum = nil
        prescribedVelocityLossStopPercent = nil
        isVelocityProbe = false
        isPrescribedOptional = nil
        prescriptionNotes = nil
        prescriptionDefinitionData = nil
    }

    func displayText() -> String {
        if let calories, calories > 0 {
            return "\(String(format: "%.0f", calories)) cal"
        }
        if let duration = duration, duration > 0 {
            if let distance = distance, distance > 0 {
                return String(format: "%ds @ %.2f %@", Int(duration), distance, distanceType.rawValue)
            }
            return "\(Int(duration))s"
        }

        if weight > 0 {
            return "\(Int(repetitions)) x \(String(format: "%.1f", weight)) \(weightType.rawValue)"
        }

        return "\(Int(repetitions)) reps"
    }

    var orderedSegments: [ExerciseSetSegment] {
        segments.sorted { lhs, rhs in
            lhs.orderIndex == rhs.orderIndex
                ? lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
                : lhs.orderIndex < rhs.orderIndex
        }
    }

    func normalizeSegmentOrder() {
        for (index, segment) in orderedSegments.enumerated() {
            segment.orderIndex = index
        }
    }

    var orderedComplexComponents: [ComplexComponentResult] {
        complexComponents.sorted { lhs, rhs in
            lhs.orderIndex == rhs.orderIndex
                ? lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
                : lhs.orderIndex < rhs.orderIndex
        }
    }

    /// Creates performed component rows only for a structured complex. Existing
    /// results are never replaced, preserving a partial active or historical
    /// attempt across reconciliation and relaunch.
    func ensureComplexComponents(for components: [ComplexComponentSnapshot]) {
        guard complexComponents.isEmpty else { return }
        repetitions = Float(components.reduce(0) { $0 + $1.prescribedRepetitions })
        complexComponents = components.enumerated().map { index, component in
            ComplexComponentResult(
                orderIndex: index,
                exerciseID: component.exerciseID,
                exerciseNameSnapshot: component.exerciseNameSnapshot,
                prescribedRepetitions: component.prescribedRepetitions
            )
        }
    }

    func synchronizeComplexCompletion() {
        guard !complexComponents.isEmpty else { return }
        if done {
            for component in complexComponents where component.outcome == .notStarted {
                component.outcome = .completed
                component.performedRepetitions = component.prescribedRepetitions
                component.liftQuality = component.liftQuality ?? .acceptable
            }
        } else {
            for component in complexComponents {
                component.outcome = .notStarted
                component.performedRepetitions = 0
                component.liftQuality = nil
            }
        }
        repetitions = Float(complexComponents.reduce(0) { $0 + $1.performedRepetitions })
        liftQuality = complexComponents.contains(where: { $0.outcome == .missed }) ? .missed : nil
    }
}
