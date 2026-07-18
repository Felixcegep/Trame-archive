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
    var prescriptionLoadExplanation: String?
    var prescribedRestSeconds: Int?
    var prescribedRPE: Double?
    var prescribedRIR: Int?
    var prescribedTempo: String?
    var prescribedProgressionEligible: Bool?
    var prescribedCalories: Double?
    var isPrescribedOptional: Bool?
    var prescriptionNotes: String?
    var prescriptionDefinitionData: Data?
    var usedMetric : UnitSystem
    var exerciseEntry: ExerciseEntry?
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
        self.prescriptionLoadExplanation = nil
        self.prescribedRestSeconds = nil
        self.prescribedRPE = nil
        self.prescribedRIR = nil
        self.prescribedTempo = nil
        self.prescribedProgressionEligible = nil
        self.prescribedCalories = nil
        self.isPrescribedOptional = nil
        self.prescriptionNotes = nil
        self.prescriptionDefinitionData = nil
        self.usedMetric = usedMetric
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
        copy.prescriptionLoadExplanation = prescriptionLoadExplanation
        copy.prescribedRestSeconds = prescribedRestSeconds
        copy.prescribedRPE = prescribedRPE
        copy.prescribedRIR = prescribedRIR
        copy.prescribedTempo = prescribedTempo
        copy.prescribedProgressionEligible = prescribedProgressionEligible
        copy.prescribedCalories = prescribedCalories
        copy.isPrescribedOptional = isPrescribedOptional
        copy.prescriptionNotes = prescriptionNotes
        copy.prescriptionDefinitionData = prescriptionDefinitionData
        // A new attempt must be selected deliberately; copying a prior daily
        // maximum cannot create two reference attempts.
        copy.isSelectedDailyMaximum = false
        copy.generatedBackOffDefinitionID = nil
        return copy
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
        prescriptionLoadExplanation = nil
        prescribedRestSeconds = nil
        prescribedRPE = nil
        prescribedRIR = nil
        prescribedTempo = nil
        prescribedProgressionEligible = nil
        prescribedCalories = nil
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
}
