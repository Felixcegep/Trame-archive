import Foundation

#if !GYMTRACKER_EXTENSION

nonisolated struct LoadResolutionContext {
    var trainingMaxByExposure: [String: Double] = [:]
    var estimatedOneRepMaxByExposure: [String: Double] = [:]
    var actualOneRepMaxByExposure: [String: Double] = [:]
    var exerciseOneRepMaxByID: [UUID: Double] = [:]
    var referenceValuesByExerciseID: [UUID: Double] = [:]
    var previousWorkoutByExposure: [String: Double] = [:]
    var previousSuccessfulSetByExposure: [String: Double] = [:]
    var previousOccurrenceByExposure: [String: Double] = [:]
    var completedTopSetByExposure: [String: Double] = [:]
    var dailyMaximumByExposure: [String: Double] = [:]
    var anotherPlannedExerciseByExposure: [String: Double] = [:]
    var equipmentAvailableLoads: [Double] = []

    init() {}
}

nonisolated struct LoadResolutionResult: Equatable {
    let referenceValue: Double?
    let unroundedLoad: Double?
    let prescribedLoad: Double?
    let explanation: String
}

nonisolated enum LoadResolutionError: Error, Equatable {
    case missingReference(LoadReferenceKind)
    case invalidValue(String)
}

nonisolated enum ProgramLoadResolver {
    static func resolve(
        _ prescription: LoadPrescription,
        context: LoadResolutionContext
    ) throws -> LoadResolutionResult {
        let reference = try referenceValue(for: prescription.reference, context: context)
        let base: Double?
        if let fixedValue = prescription.fixedValue {
            base = fixedValue
        } else if prescription.reference.kind == .manual {
            base = nil
        } else {
            base = reference
        }

        guard let base else {
            return LoadResolutionResult(
                referenceValue: reference,
                unroundedLoad: nil,
                prescribedLoad: nil,
                explanation: "No load was prescribed; enter the load manually."
            )
        }
        guard base.isFinite else { throw LoadResolutionError.invalidValue("Reference load is not finite.") }

        var calculated = base
        if let percentage = prescription.percentage {
            calculated *= percentage
        }
        if let percentageOffset = prescription.percentageOffset {
            calculated += base * percentageOffset
        }
        calculated += prescription.absoluteOffset
        if let minimum = prescription.minimum { calculated = max(calculated, minimum) }
        if let maximum = prescription.maximum { calculated = min(calculated, maximum) }
        guard calculated.isFinite else { throw LoadResolutionError.invalidValue("Calculated load is not finite.") }

        let rounded = round(calculated, rule: prescription.rounding, available: context.equipmentAvailableLoads)
        let prescribed = rounded ?? calculated
        let referenceDescription = reference.map { format($0) } ?? "manual"
        let percentageDescription = prescription.percentage.map { " × \(format($0 * 100))%" } ?? ""
        let offsetDescription = prescription.absoluteOffset == 0 ? "" : " + \(format(prescription.absoluteOffset))"
        let roundingDescription = rounded.map { " → rounded to \(format($0))" } ?? ""
        return LoadResolutionResult(
            referenceValue: reference,
            unroundedLoad: calculated,
            prescribedLoad: prescribed,
            explanation: "Reference \(referenceDescription)\(percentageDescription)\(offsetDescription) = \(format(calculated))\(roundingDescription)."
        )
    }

    private static func referenceValue(
        for reference: LoadReference,
        context: LoadResolutionContext
    ) throws -> Double? {
        let value: Double?
        switch reference.kind {
        case .manual, .fixedLoad:
            value = reference.exposureKey.flatMap { context.anotherPlannedExerciseByExposure[$0] }
        case .exerciseOneRepMax:
            value = reference.exerciseID.flatMap { context.exerciseOneRepMaxByID[$0] }
                ?? reference.exposureKey.flatMap { context.actualOneRepMaxByExposure[$0] }
        case .estimatedOneRepMax:
            value = reference.exposureKey.flatMap { context.estimatedOneRepMaxByExposure[$0] }
        case .trainingMax:
            value = reference.exposureKey.flatMap { context.trainingMaxByExposure[$0] }
        case .referenceExercise:
            value = reference.exerciseID.flatMap { context.referenceValuesByExerciseID[$0] }
        case .previousWorkout:
            value = reference.exposureKey.flatMap { context.previousWorkoutByExposure[$0] }
        case .previousSuccessfulSet:
            value = reference.exposureKey.flatMap { context.previousSuccessfulSetByExposure[$0] }
        case .previousOccurrence:
            value = reference.exposureKey.flatMap { context.previousOccurrenceByExposure[$0] }
        case .topSet:
            value = reference.exposureKey.flatMap { context.completedTopSetByExposure[$0] }
        case .dailyMaximum:
            value = reference.exposureKey.flatMap { context.dailyMaximumByExposure[$0] }
        case .anotherPlannedExercise:
            value = reference.exposureKey.flatMap { context.anotherPlannedExerciseByExposure[$0] }
        }
        if value == nil && reference.kind != .manual && reference.kind != .fixedLoad {
            throw LoadResolutionError.missingReference(reference.kind)
        }
        return value
    }

    private static func round(_ value: Double, rule: LoadRoundingRule, available: [Double]) -> Double? {
        switch rule {
        case .none:
            return nil
        case .nearestIncrement(let increment):
            guard increment > 0 else { return nil }
            return (value / increment).rounded() * increment
        case .floorToIncrement(let increment):
            guard increment > 0 else { return nil }
            return floor(value / increment) * increment
        case .ceilingToIncrement(let increment):
            guard increment > 0 else { return nil }
            return ceil(value / increment) * increment
        case .nearestAvailable(let values):
            let choices = (values.isEmpty ? available : values).filter(\.isFinite)
            return choices.min { lhs, rhs in
                abs(lhs - value) < abs(rhs - value)
            }
        }
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

nonisolated struct FormulaResolutionContext {
    var valuesByExposure: [String: Double] = [:]
    var trainingMaxByExposure: [String: Double] = [:]
    var estimatedOneRepMaxByExposure: [String: Double] = [:]
    var actualOneRepMaxByExposure: [String: Double] = [:]
    var previousOccurrenceByExposure: [String: Double] = [:]
    var previousSuccessfulSetByExposure: [String: Double] = [:]
    var completedTopSetByExposure: [String: Double] = [:]
    var dailyMaximumByExposure: [String: Double] = [:]
    var completedMetricsByExposure: [String: [ProgressionMetric: Double]] = [:]
    var velocityBaselineByExposure: [String: Double] = [:]
}

nonisolated enum FormulaResolutionError: Error, Equatable {
    case missingSource(String)
    case divisionByZero
    case invalidResult
}

nonisolated enum ProgramFormulaResolver {
    static func resolve(_ formula: ProgressionFormula, context: FormulaResolutionContext) throws -> Double {
        let value: Double
        switch formula {
        case .source(let source):
            value = try sourceValue(source, context: context)
        case .add(let lhs, let rhs): value = try resolve(lhs, context: context) + resolve(rhs, context: context)
        case .subtract(let lhs, let rhs): value = try resolve(lhs, context: context) - resolve(rhs, context: context)
        case .multiply(let lhs, let rhs): value = try resolve(lhs, context: context) * resolve(rhs, context: context)
        case .divide(let lhs, let rhs):
            let divisor = try resolve(rhs, context: context)
            guard divisor != 0 else { throw FormulaResolutionError.divisionByZero }
            value = try resolve(lhs, context: context) / divisor
        case .minimum(let lhs, let rhs): value = min(try resolve(lhs, context: context), try resolve(rhs, context: context))
        case .maximum(let lhs, let rhs): value = max(try resolve(lhs, context: context), try resolve(rhs, context: context))
        case .clamp(let formula, let minimum, let maximum): value = min(max(try resolve(formula, context: context), minimum), maximum)
        case .round(let formula, let rule):
            let raw = try resolve(formula, context: context)
            value = round(raw, rule: rule)
        }
        guard value.isFinite else { throw FormulaResolutionError.invalidResult }
        return value
    }

    private static func sourceValue(_ source: FormulaSource, context: FormulaResolutionContext) throws -> Double {
        let value: Double?
        switch source {
        case .constant(let constant): return constant
        case .trainingMax(let key): value = context.trainingMaxByExposure[key]
        case .estimatedOneRepMax(let key): value = context.estimatedOneRepMaxByExposure[key]
        case .actualOneRepMax(let key): value = context.actualOneRepMaxByExposure[key]
        case .previousOccurrence(let key): value = context.previousOccurrenceByExposure[key]
        case .previousSuccessfulSet(let key): value = context.previousSuccessfulSetByExposure[key]
        case .completedTopSet(let key): value = context.completedTopSetByExposure[key]
        case .dailyMaximum(let key): value = context.dailyMaximumByExposure[key]
        case .anotherExposure(let key): value = context.valuesByExposure[key]
        case .completedMetric(let key, let metric): value = context.completedMetricsByExposure[key]?[metric]
        case .velocityBaseline(let key): value = context.velocityBaselineByExposure[key]
        }
        guard let value else {
            throw FormulaResolutionError.missingSource(String(describing: source))
        }
        return value
    }

    private static func round(_ value: Double, rule: LoadRoundingRule) -> Double {
        switch rule {
        case .none: return value
        case .nearestIncrement(let increment) where increment > 0: return (value / increment).rounded() * increment
        case .floorToIncrement(let increment) where increment > 0: return floor(value / increment) * increment
        case .ceilingToIncrement(let increment) where increment > 0: return ceil(value / increment) * increment
        case .nearestAvailable(let values): return values.min { abs($0 - value) < abs($1 - value) } ?? value
        default: return value
        }
    }
}
#endif
