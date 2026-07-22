import Foundation

extension ExerciseSet {
    /// Records one performed effort scale and clears the inverse scale. This
    /// preserves the meaning of a newly logged set regardless of which UI
    /// entry point recorded it.
    func recordRPE(_ value: Double?) {
        rpe = value
        if value != nil {
            rir = nil
        }
    }

    /// Records one performed effort scale and clears the inverse scale. This
    /// is deliberately separate from prescribed RPE/RIR, which may both be
    /// part of a program definition without changing performed truth.
    func recordRIR(_ value: Int?) {
        rir = value
        if value != nil {
            rpe = nil
        }
    }
}
