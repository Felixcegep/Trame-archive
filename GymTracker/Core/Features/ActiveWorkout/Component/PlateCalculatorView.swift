import SwiftUI

struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(DefaultsKey.useMetric) private var preferredUnitSystem: UnitSystem = .metric
    @Bindable var exerciseSet: ExerciseSet
    let usesBarbell: Bool
    @State private var selectedBarID = BarKind.mensOlympic.id

    private var selectedBar: BarKind {
        BarKind.allCases.first { $0.id == selectedBarID } ?? .mensOlympic
    }

    private var equipment: PlateEquipment {
        PlateEquipment(
            unitSystem: preferredUnitSystem,
            selectedBarID: selectedBarID,
            usesBarbell: usesBarbell
        )
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
                    if usesBarbell {
                        plateDiagram
                    } else {
                        plateLoadedEquipmentNote
                    }
                    result
                    if usesBarbell {
                        barSelector
                    }
                    plateKeyboard
                }
                .padding(Spacing.xl)
            }
            .background(WorkoutPalette.background)
            .navigationTitle("Plate calculator")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .topLeading) {
                screenshotStateMarker("plate-calculator-screen", label: "Plate calculator open")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            synchronizeUnitsAndMinimumBarWeight()
        }
        .onChange(of: preferredUnitSystem) { _, _ in
            synchronizeUnitsAndMinimumBarWeight()
        }
    }

    private var plateDiagram: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("BAR LOAD")
                    .font(AppFont.captionBold)
                    .tracking(0.8)
                    .foregroundStyle(WorkoutPalette.subduedText)

                Spacer()

                selectedBarSummary
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    barSegment(width: 40)
                    collarSegment(height: 30, width: 8)

                    ForEach(diagramPlates) { item in
                        diagramPlateShape(item.weight)
                            .transition(reduceMotion
                                ? .opacity
                                : .scale(scale: 0.94).combined(with: .opacity))
                    }

                    collarSegment(height: 24, width: 6)
                    barSegment(width: 24)
                }
                .padding(.vertical, Spacing.s)
                .padding(.horizontal, Spacing.l)
                .frame(minHeight: 108)
                .animation(reduceMotion ? nil : AppMotion.compact, value: diagramPlates)
            }
            .defaultScrollAnchor(.center)

            Text(calculation.plates.isEmpty
                 ? "Bare \(selectedBar.title) bar · \(formatted(equipment.barWeight)) \(equipment.unitLabel)."
                 : "One side shown · Add or remove plates below.")
                .font(AppFont.caption)
                .foregroundStyle(WorkoutPalette.subduedText)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkoutPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Bar load diagram, one side shown")
    }

    private var diagramPlates: [DiagramPlate] {
        var occurrences: [Float: Int] = [:]
        return calculation.plates.map { weight in
            let occurrence = occurrences[weight, default: 0]
            occurrences[weight] = occurrence + 1
            return DiagramPlate(weight: weight, occurrence: occurrence)
        }
    }

    private var selectedBarSummary: some View {
        Text("\(selectedBar.title) · \(formatted(equipment.barWeight)) \(equipment.unitLabel)")
            .font(AppFont.captionSemiboldMonospaced)
            .foregroundStyle(WorkoutPalette.primary)
            .lineLimit(1)
        .accessibilityLabel("Bar type: \(selectedBar.title), \(formatted(equipment.barWeight)) \(equipment.unitLabel)")
    }

    private func barSegment(width: CGFloat) -> some View {
        Capsule()
            .fill(Self.barMetalColor)
            .frame(width: width, height: 9)
    }

    private func collarSegment(height: CGFloat, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Self.barMetalColor)
            .frame(width: width, height: height)
    }

    private func diagramPlateShape(_ plate: Float) -> some View {
        let maxPlate = CGFloat(equipment.plates.max() ?? 1)
        let ratio = CGFloat(plate) / maxPlate
        let plateHeight = 34 + ratio * 58
        let plateWidth = 7 + ratio * 11

        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(plateColor(for: plate))
            .frame(width: plateWidth, height: plateHeight)
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.black.opacity(0.18), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    // Real-world competition plate colors (IWF convention); intentionally not
    // design-system tokens because they identify physical plates.
    private static let barMetalColor = Color(red: 0.62, green: 0.63, blue: 0.66)

    private func plateColor(for plate: Float) -> Color {
        let isMetric = preferredUnitSystem == .metric
        switch (isMetric, plate) {
        case (true, 25), (false, 55): return Color(red: 0.85, green: 0.16, blue: 0.16)   // red
        case (true, 20), (false, 45): return Color(red: 0.16, green: 0.36, blue: 0.83)   // blue
        case (true, 15), (false, 35): return Color(red: 0.95, green: 0.77, blue: 0.06)   // yellow
        case (true, 10), (false, 25): return Color(red: 0.16, green: 0.62, blue: 0.33)   // green
        case (true, 5), (false, 10): return Color(red: 0.93, green: 0.93, blue: 0.91)    // white
        case (true, 2.5), (false, 5): return Color(red: 0.85, green: 0.16, blue: 0.16)   // red change plate
        case (false, 2.5): return Color(red: 0.16, green: 0.62, blue: 0.33)              // green change plate
        default: return Self.barMetalColor                                               // chrome minis (1.25 kg / 1 lb)
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
                            selectBar(bar)
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(LocalizedStringKey(bar.title))
                                    .font(AppFont.captionSemiboldMonospaced)
                                Text("\(formatted(bar.weight(for: preferredUnitSystem))) \(equipment.unitLabel)")
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
                        .accessibilityLabel("\(bar.title), \(formatted(bar.weight(for: preferredUnitSystem))) \(equipment.unitLabel)")
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

    private var plateLoadedEquipmentNote: some View {
        calculatorMessage(
            "Plate-loaded mode treats the entered weight as the total and splits it equally between both sides.",
            icon: AppIcon.info
        )
    }

    @ViewBuilder
    private var result: some View {
        if exerciseSet.weight <= 0 {
            calculatorMessage("Use the plate keyboard or enter a target weight.", icon: AppIcon.number)
        } else if usesBarbell && exerciseSet.weight < equipment.barWeight {
            calculatorMessage("The target is below the \(formatted(equipment.barWeight)) \(equipment.unitLabel) bar. The minimum loaded weight is \(formatted(equipment.barWeight)) \(equipment.unitLabel).", icon: AppIcon.warning)
        } else if calculation.remainingWeight > 0.01 {
            VStack(alignment: .leading, spacing: Spacing.md) {
                calculatorMessage("This cannot be loaded exactly with the standard plates.", icon: AppIcon.warning)
                loadingSummary(label: "Closest load")
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Load each side", systemImage: AppIcon.workout)
                    .font(AppFont.headline)
                Text(calculation.plates.isEmpty ? "No plates" : calculation.plates.map { "\(formatted($0)) \(equipment.unitLabel) each side" }.joined(separator: " + "))
                    .font(AppFont.titleSmallSemiboldMonospaced)
                    .foregroundStyle(WorkoutPalette.primary)
                if usesBarbell {
                    Text("On the \(selectedBar.title) bar · \(formatted(equipment.barWeight)) \(equipment.unitLabel)")
                        .font(AppFont.caption)
                        .foregroundStyle(WorkoutPalette.subduedText)
                }
                loadingSummary(label: "Total load")
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
                if usesBarbell {
                    Button("Bare bar · \(formatted(equipment.barWeight)) \(equipment.unitLabel)") {
                        exerciseSet.weight = equipment.barWeight
                    }
                }
                Button(usesBarbell ? "Remove plates" : "Clear", role: .destructive) {
                    exerciseSet.weight = usesBarbell ? equipment.barWeight : 0
                }
            }
            .buttonStyle(.bordered)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: Spacing.md)], spacing: Spacing.md) {
                ForEach(equipment.plates, id: \.self) { plate in
                    plateTile(for: plate)
                }
            }
        }
    }

    private func plateTile(for plate: Float) -> some View {
        let loadedCount = calculation.plates.filter { $0 == plate }.count

        return VStack(spacing: Spacing.s) {
            VStack(spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(plateColor(for: plate))
                        .frame(width: 10, height: 10)
                        .overlay {
                            Circle().stroke(Color.black.opacity(0.18), lineWidth: 0.5)
                        }
                    Text("\(formatted(plate)) \(equipment.unitLabel)")
                        .font(AppFont.headlineMonospaced)
                        .foregroundStyle(WorkoutPalette.text)
                }
                Text(loadedCount > 0 ? "×\(loadedCount) per side" : "per side")
                    .font(AppFont.caption)
                    .foregroundStyle(loadedCount > 0 ? WorkoutPalette.primary : WorkoutPalette.subduedText)
            }

            HStack(spacing: 0) {
                Button {
                    removePlatePair(plate)
                } label: {
                    Image(systemName: AppIcon.minus)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Remove \(formatted(plate)) \(equipment.unitLabel) each side")

                Divider()
                    .frame(height: 20)

                Button {
                    addPlatePair(plate)
                } label: {
                    Image(systemName: AppIcon.plus)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Add \(formatted(plate)) \(equipment.unitLabel) each side")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(WorkoutPalette.primary)
        }
        .padding(.vertical, Spacing.s)
        .padding(.horizontal, Spacing.xs)
        .background(WorkoutPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func addPlatePair(_ plate: Float) {
        if usesBarbell && exerciseSet.weight < equipment.barWeight {
            exerciseSet.weight = equipment.barWeight
        }
        exerciseSet.weight += plate * 2
    }

    private func removePlatePair(_ plate: Float) {
        exerciseSet.weight = max(usesBarbell ? equipment.barWeight : 0, exerciseSet.weight - plate * 2)
    }

    private func selectBar(_ bar: BarKind) {
        let previousBarWeight = selectedBar.weight(for: preferredUnitSystem)
        let plateLoad = max(0, exerciseSet.weight - previousBarWeight)
        selectedBarID = bar.id
        exerciseSet.weight = bar.weight(for: preferredUnitSystem) + plateLoad
    }

    private func synchronizeUnitsAndMinimumBarWeight() {
        let targetWeightType: WeightType = preferredUnitSystem == .metric ? .kg : .lbs
        if exerciseSet.weightType != targetWeightType {
            exerciseSet.weight = UnitConversion.weight(
                exerciseSet.weight,
                from: exerciseSet.weightType,
                to: targetWeightType
            )
            exerciseSet.weightType = targetWeightType
        }
        exerciseSet.usedMetric = preferredUnitSystem

        if usesBarbell, exerciseSet.weight < equipment.barWeight {
            exerciseSet.weight = equipment.barWeight
        }
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

    private func loadingSummary(label: String) -> some View {
        HStack(spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(label)
                    .font(AppFont.caption)
                    .foregroundStyle(WorkoutPalette.subduedText)
                Text("\(formatted(calculation.totalWeight)) \(equipment.unitLabel)")
                    .font(AppFont.headlineMonospaced)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                Text(usesBarbell ? "Per side · incl. ½ bar" : "Per side")
                    .font(AppFont.caption)
                    .foregroundStyle(WorkoutPalette.subduedText)
                Text("\(formatted(calculation.perSideWeight)) \(equipment.unitLabel)")
                    .font(AppFont.headlineMonospaced)
            }
        }
        .padding(Spacing.m)
        .background(WorkoutPalette.mutedSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }

    private func formatted(_ value: Float) -> String {
        Formatters.formatFloat(value)
    }
}

private struct DiagramPlate: Identifiable, Equatable {
    let weight: Float
    let occurrence: Int

    var id: String { "\(weight)-\(occurrence)" }
}

private struct PlateEquipment {
    let barWeight: Float
    let plates: [Float]
    let unitLabel: String

    init(unitSystem: UnitSystem, selectedBarID: String, usesBarbell: Bool) {
        let selectedBar = BarKind.allCases.first { $0.id == selectedBarID } ?? .mensOlympic

        switch unitSystem {
        case .metric:
            barWeight = usesBarbell ? selectedBar.metricWeight : 0
            plates = Constants.Barbell.metricPlates
            unitLabel = "kg"
        case .imperial:
            barWeight = usesBarbell ? selectedBar.imperialWeight : 0
            plates = Constants.Barbell.imperialPlates
            unitLabel = "lbs"
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
    let totalWeight: Float
    let perSideWeight: Float

    init(target: Float, barWeight: Float, plates availablePlates: [Float]) {
        guard target >= barWeight else {
            plates = []
            remainingWeight = 0
            totalWeight = 0
            perSideWeight = 0
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
        perSideWeight = barWeight / 2 + selectedPlates.reduce(0, +)
        totalWeight = barWeight + selectedPlates.reduce(0, +) * 2
    }
}
