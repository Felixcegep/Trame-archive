import SwiftUI

struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var exerciseSet: ExerciseSet

    private var equipment: PlateEquipment {
        PlateEquipment(unitSystem: exerciseSet.usedMetric)
    }

    private var calculation: PlateCalculation {
        PlateCalculation(target: exerciseSet.weight, barWeight: equipment.barWeight, plates: equipment.plates)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    Divider()
                    result
                    plateKeyboard
                }
                .padding(20)
            }
            .background(WorkoutPalette.background)
            .navigationTitle("Plate calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TARGET WEIGHT")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(WorkoutPalette.subduedText)
            Text("\(formatted(exerciseSet.weight)) \(equipment.unitLabel)")
                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
        }
    }

    @ViewBuilder
    private var result: some View {
        if exerciseSet.weight <= 0 {
            calculatorMessage("Use the plate keyboard or enter a target weight.", icon: "number")
        } else if exerciseSet.weight < equipment.barWeight {
            calculatorMessage("This is lighter than the \(formatted(equipment.barWeight)) \(equipment.unitLabel) bar.", icon: "exclamationmark.triangle")
        } else if calculation.remainingWeight > 0.01 {
            calculatorMessage("This cannot be loaded exactly with the standard plates.", icon: "exclamationmark.triangle")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Label("Load each side", systemImage: "dumbbell.fill")
                    .font(.headline)
                Text(calculation.plates.isEmpty ? "No plates" : calculation.plates.map(formatted).joined(separator: " + "))
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(WorkoutPalette.primary)
                Text("Bar: \(formatted(equipment.barWeight)) \(equipment.unitLabel)  ·  Same plates on both sides")
                    .font(.footnote)
                    .foregroundStyle(WorkoutPalette.subduedText)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WorkoutPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var plateKeyboard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PLATE KEYBOARD")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(WorkoutPalette.subduedText)

            HStack(spacing: 10) {
                Button("Bar \(formatted(equipment.barWeight))") {
                    exerciseSet.weight = equipment.barWeight
                }
                Button("Clear", role: .destructive) {
                    exerciseSet.weight = 0
                }
            }
            .buttonStyle(.bordered)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                ForEach(equipment.plates, id: \.self) { plate in
                    HStack(spacing: 4) {
                        Button("−") { removePlatePair(plate) }
                            .accessibilityLabel("Remove a pair of \(formatted(plate)) \(equipment.unitLabel) plates")
                        Text("\(formatted(plate)) ×2")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .frame(maxWidth: .infinity)
                        Button("+") { addPlatePair(plate) }
                            .accessibilityLabel("Add a pair of \(formatted(plate)) \(equipment.unitLabel) plates")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(WorkoutPalette.primary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .background(WorkoutPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("\(formatted(plate)) \(equipment.unitLabel) plate pair")
                }
            }
        }
    }

    private func addPlatePair(_ plate: Float) {
        if exerciseSet.weight < equipment.barWeight {
            exerciseSet.weight = equipment.barWeight
        }
        exerciseSet.weight += plate * 2
    }

    private func removePlatePair(_ plate: Float) {
        exerciseSet.weight = max(0, exerciseSet.weight - plate * 2)
    }

    private func calculatorMessage(_ message: String, icon: String) -> some View {
        Label(message, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(WorkoutPalette.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(WorkoutPalette.accentSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func formatted(_ value: Float) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }
}

private struct PlateEquipment {
    let barWeight: Float
    let plates: [Float]
    let unitLabel: String

    init(unitSystem: UnitSystem) {
        switch unitSystem {
        case .metric:
            barWeight = 20
            plates = [25, 20, 15, 10, 5, 2.5, 1.25]
            unitLabel = "kg"
        case .imperial:
            barWeight = 45
            plates = [45, 35, 25, 10, 5, 2.5]
            unitLabel = "lb"
        }
    }
}

private struct PlateCalculation {
    let plates: [Float]
    let remainingWeight: Float

    init(target: Float, barWeight: Float, plates availablePlates: [Float]) {
        guard target >= barWeight else {
            plates = []
            remainingWeight = 0
            return
        }

        var remainingPerSide = (target - barWeight) / 2
        var selectedPlates: [Float] = []

        for plate in availablePlates.sorted(by: >) {
            while remainingPerSide + 0.001 >= plate {
                selectedPlates.append(plate)
                remainingPerSide -= plate
            }
        }

        plates = selectedPlates
        remainingWeight = remainingPerSide * 2
    }
}
