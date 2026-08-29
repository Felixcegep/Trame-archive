import Foundation

#if !GYMTRACKER_EXTENSION
/// Equipment defaults used only when a program did not explicitly choose a
/// rounding rule. Values are rounded in the active workout's display unit so
/// a pound-based session never receives a metric-only plate increment.
enum EquipmentLoadRounding {
    struct Result: Equatable {
        var prescribedLoad: Double
        var increment: Double
    }

    static func round(
        _ value: Double,
        equipment: EquipmentType?,
        resistance: ResistanceType?,
        isPlateLoaded: Bool,
        unit: WeightType
    ) -> Result? {
        guard value.isFinite, let increment = increment(
            equipment: equipment,
            resistance: resistance,
            isPlateLoaded: isPlateLoaded,
            unit: unit
        ) else { return nil }
        return Result(
            prescribedLoad: (value / increment).rounded() * increment,
            increment: increment
        )
    }

    /// The smallest load change this equipment can actually make. Also drives
    /// the set-entry panel's coarse +/- stepper, so a barbell moves in plate
    /// jumps while a dumbbell moves in rack jumps.
    static func increment(
        equipment: EquipmentType?,
        resistance: ResistanceType?,
        isPlateLoaded: Bool,
        unit: WeightType
    ) -> Double? {
        if resistance == .bodyweight || equipment == .bodyweight {
            return resistance == .weightedBodyweight || resistance == .assistedBodyweight
                ? unit == .kg ? 2.5 : 5
                : nil
        }
        if isPlateLoaded || equipment == .barbell {
            return unit == .kg ? 2.5 : 5
        }
        switch equipment {
        case .barbell:
            // This case is handled by the plate-loaded fast path above, but
            // remains explicit so the optional equipment switch is exhaustive.
            return unit == .kg ? 2.5 : 5
        case .dumbbell:
            return unit == .kg ? 2 : 5
        case .kettlebell:
            return unit == .kg ? 4 : 5
        case .cable, .machine:
            return unit == .kg ? 5 : 5
        case .medicineBall:
            return unit == .kg ? 1 : 2
        case .sandbag, .sled:
            return unit == .kg ? 5 : 10
        case .battleRopes, .rings, .bodyweight, .cardioMachine, .other, .none:
            return nil
        }
    }
}
#endif
