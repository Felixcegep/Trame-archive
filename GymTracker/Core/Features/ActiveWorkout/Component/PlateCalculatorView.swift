import SwiftUI

struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var exerciseSet: ExerciseSet
    @State private var selectedBarID = BarKind.mensOlympic.id

    private var equipment: PlateEquipment {
        PlateEquipment(unitSystem: exerciseSet.usedMetric, selectedBarID: selectedBarID)
    }

    private var calculation: PlateCalculation {
        PlateCalculation(target: exerciseSet.weight, barWeight: equipment.barWeight, plates: equipment.plates)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header
                    Divider()
                    result
                    barSelector
                    plateKeyboard
                }
                .padding(Spacing.xl)
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

    private var barSelector: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("BAR TYPE")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(WorkoutPalette.subduedText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    ForEach(BarKind.allCases) { bar in
                        Button {
                            selectedBarID = bar.id
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(LocalizedStringKey(bar.title))
                                    .font(AppFont.captionSemiboldMonospaced)
                                Text("\(formatted(bar.weight(for: exerciseSet.usedMetric))) \(equipment.unitLabel)")
                                    .font(AppFont.captionSemiboldMonospaced)
                                    .foregroundStyle(selectedBarID == bar.id ? WorkoutPalette.primary : WorkoutPalette.subduedText)
                            }
                            .frame(minWidth: 104, alignment: .leading)
                            .padding(.horizontal, Spacing.m)
                            .padding(.vertical, Spacing.s)
                            .background(selectedBarID == bar.id ? WorkoutPalette.primarySurface : WorkoutPalette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                                    .stroke(selectedBarID == bar.id ? WorkoutPalette.primary : .clear, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedBarID == bar.id ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("TARGET WEIGHT")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(WorkoutPalette.subduedText)
            Text("\(formatted(exerciseSet.weight)) \(equipment.unitLabel)")
                .font(AppFont.displayLarge)
        }
    }

    @ViewBuilder
    private var result: some View {
        if exerciseSet.weight <= 0 {
            calculatorMessage("Use the plate keyboard or enter a target weight.", icon: AppIcon.number)
        } else if exerciseSet.weight < equipment.barWeight {
            calculatorMessage("This is lighter than the \(formatted(equipment.barWeight)) \(equipment.unitLabel) bar.", icon: AppIcon.warning)
        } else if calculation.remainingWeight > 0.01 {
            calculatorMessage("This cannot be loaded exactly with the standard plates.", icon: AppIcon.warning)
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Load each side", systemImage: AppIcon.workout)
                    .font(AppFont.headline)
                Text(calculation.plates.isEmpty ? "No plates" : calculation.plates.map(formatted).joined(separator: " + "))
                    .font(AppFont.titleSmallSemiboldMonospaced)
                    .foregroundStyle(WorkoutPalette.primary)
                Text("Bar: \(formatted(equipment.barWeight)) \(equipment.unitLabel)  ·  Same plates on both sides")
                    .font(AppFont.footnote)
                    .foregroundStyle(WorkoutPalette.subduedText)
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WorkoutPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        }
    }

    private var plateKeyboard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("PLATE KEYBOARD")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(WorkoutPalette.subduedText)

            HStack(spacing: Spacing.md) {
                Button("Bar \(formatted(equipment.barWeight))") {
                    exerciseSet.weight = equipment.barWeight
                }
                Button("Clear", role: .destructive) {
                    exerciseSet.weight = 0
                }
            }
            .buttonStyle(.bordered)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: Spacing.md)], spacing: Spacing.md) {
                ForEach(equipment.plates, id: \.self) { plate in
                    HStack(spacing: Spacing.xs) {
                        Button("−") { removePlatePair(plate) }
                            .accessibilityLabel("Remove a pair of \(formatted(plate)) \(equipment.unitLabel) plates")
                        Text("\(formatted(plate)) ×2")
                            .font(AppFont.captionSemiboldMonospaced)
                            .frame(maxWidth: .infinity)
                        Button("+") { addPlatePair(plate) }
                            .accessibilityLabel("Add a pair of \(formatted(plate)) \(equipment.unitLabel) plates")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(WorkoutPalette.primary)
                    .padding(.vertical, Spacing.s)
                    .padding(.horizontal, 6)
                    .background(WorkoutPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
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

    private func calculatorMessage(_ message: LocalizedStringKey, icon: String) -> some View {
        Label(message, systemImage: icon)
            .font(AppFont.subheadline)
            .foregroundStyle(WorkoutPalette.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.l)
            .background(WorkoutPalette.accentSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    private func formatted(_ value: Float) -> String {
        Formatters.formatFloat(value)
    }
}

private struct PlateEquipment {
    let barWeight: Float
    let plates: [Float]
    let unitLabel: String

    init(unitSystem: UnitSystem, selectedBarID: String) {
        let selectedBar = BarKind.allCases.first { $0.id == selectedBarID } ?? .mensOlympic

        switch unitSystem {
        case .metric:
            barWeight = selectedBar.metricWeight
            plates = Constants.Barbell.metricPlates
            unitLabel = "kg"
        case .imperial:
            barWeight = selectedBar.imperialWeight
            plates = Constants.Barbell.imperialPlates
            unitLabel = "lb"
        }
    }
}

private enum BarKind: String, CaseIterable, Identifiable {
    case mensOlympic
    case womensOlympic
    case juniorTechnique
    case ezCurl
    case shortStudio
    case safetySquat
    case trapHex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mensOlympic: "Men's Olympic"
        case .womensOlympic: "Women's Olympic"
        case .juniorTechnique: "Junior / Technique"
        case .ezCurl: "EZ Curl"
        case .shortStudio: "Short / Studio"
        case .safetySquat: "Safety Squat"
        case .trapHex: "Trap / Hex"
        }
    }

    var metricWeight: Float {
        switch self {
        case .mensOlympic: 20
        case .womensOlympic: 15
        case .juniorTechnique, .ezCurl: 10
        case .shortStudio: 7
        case .safetySquat, .trapHex: 25
        }
    }

    var imperialWeight: Float {
        switch self {
        case .mensOlympic: 45
        case .womensOlympic: 33
        case .juniorTechnique, .ezCurl: 22
        case .shortStudio: 15
        case .safetySquat, .trapHex: 55
        }
    }

    func weight(for unitSystem: UnitSystem) -> Float {
        unitSystem == .metric ? metricWeight : imperialWeight
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
