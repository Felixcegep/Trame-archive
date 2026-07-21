import SwiftUI

struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                        calculatorCard
                    } else {
                        plateLoadedEquipmentNote
                    }
                }
                .padding(Spacing.xl)
                .padding(.bottom, Spacing.s)
            }
            .background(Color.gymBackground)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                plateControls
            }
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

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("TARGET WEIGHT")
                    .font(AppFont.captionBold)
                    .tracking(0.8)
                    .foregroundStyle(Color.gymSubduedText)
                Text("\(formatted(exerciseSet.weight)) \(equipment.unitLabel)")
                    .font(AppFont.displayLarge)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.s)

            if usesBarbell {
                Menu {
                    ForEach(BarKind.allCases) { bar in
                        Button {
                            selectBar(bar)
                        } label: {
                            if selectedBarID == bar.id {
                                Label(
                                    "\(bar.title) · \(formatted(bar.weight(for: preferredUnitSystem))) \(equipment.unitLabel)",
                                    systemImage: AppIcon.checkmark
                                )
                            } else {
                                Text("\(bar.title) · \(formatted(bar.weight(for: preferredUnitSystem))) \(equipment.unitLabel)")
                            }
                        }
                    }
                } label: {
                    Label {
                        Text("\(selectedBar.title) · \(formatted(equipment.barWeight)) \(equipment.unitLabel)")
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    } icon: {
                        Image(systemName: "chevron.down")
                    }
                    .font(AppFont.captionSemiboldMonospaced)
                    .foregroundStyle(Color.gymPrimary)
                    .frame(minHeight: 44, alignment: .trailing)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Bar type: \(selectedBar.title), \(formatted(equipment.barWeight)) \(equipment.unitLabel)")
                .accessibilityIdentifier("bar-type-menu")
            }
        }
    }

    private var calculatorCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("BAR LOAD · ONE SIDE")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)

            PlateDiagramView(
                barWeight: equipment.barWeight,
                plates: calculation.plates,
                availablePlates: equipment.plates,
                unitLabel: equipment.unitLabel,
                barColor: Self.barMetalColor,
                plateColor: plateColor(for:),
                plateTextColor: plateTextColor(for:),
                reduceMotion: reduceMotion
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(diagramAccessibilityLabel)

            Divider()

            summary
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .accessibilityIdentifier("plate-summary")
    }

    @ViewBuilder
    private var summary: some View {
        if exerciseSet.weight <= 0 {
            Label("Add plates below or enter a weight.", systemImage: AppIcon.number)
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymAccent)
        } else if exerciseSet.weight < equipment.barWeight {
            Label("Target is below the \(formatted(equipment.barWeight)) \(equipment.unitLabel) bar.", systemImage: AppIcon.warning)
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymAccent)
        } else {
            if calculation.remainingWeight > 0.01 {
                Label(
                    "Cannot load exactly — closest \(formatted(calculation.totalWeight)) \(equipment.unitLabel)",
                    systemImage: AppIcon.warning
                )
                .font(AppFont.caption)
                .foregroundStyle(Color.gymAccent)
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    loadEachSideSummary
                    totalSummary
                }
            } else {
                HStack(alignment: .lastTextBaseline, spacing: Spacing.m) {
                    loadEachSideSummary
                    Spacer(minLength: Spacing.s)
                    totalSummary
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private var loadEachSideSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("LOAD EACH SIDE")
                .font(AppFont.captionBold)
                .tracking(0.55)
                .foregroundStyle(Color.gymSubduedText)
            Text(loadEachSideText)
                .font(AppFont.titleSmallSemiboldMonospaced)
                .foregroundStyle(Color.gymPrimary)
                .lineLimit(2)
        }
    }

    private var totalSummary: some View {
        Text("Per side incl. ½ bar \(formatted(calculation.perSideWeight)) \(equipment.unitLabel) · Total \(formatted(calculation.totalWeight)) \(equipment.unitLabel)")
            .font(AppFont.caption)
            .foregroundStyle(Color.gymSubduedText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var loadEachSideText: String {
        guard !calculation.plates.isEmpty else {
            return "No plates — bare \(formatted(equipment.barWeight)) \(equipment.unitLabel) bar"
        }
        return calculation.plates
            .map { formatted($0) }
            .joined(separator: " + ") + " \(equipment.unitLabel)"
    }

    private var diagramAccessibilityLabel: String {
        let plateText = calculation.plates.isEmpty
            ? "no plates"
            : calculation.plates.map(formatted).joined(separator: ", ") + " \(equipment.unitLabel)"
        return "Bar load, one side: \(plateText) on a \(formatted(equipment.barWeight)) \(equipment.unitLabel) \(selectedBar.title) bar"
    }

    private var plateControls: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    ForEach(equipment.plates, id: \.self) { plate in
                        plateStepper(for: plate)
                    }
                }
                .padding(.horizontal, Spacing.xl)
            }

            HStack(spacing: Spacing.s) {
                if usesBarbell {
                    Button("Bare bar · \(formatted(equipment.barWeight)) \(equipment.unitLabel)") {
                        exerciseSet.weight = equipment.barWeight
                    }
                }

                Button(usesBarbell ? "Remove all plates" : "Clear", role: .destructive) {
                    exerciseSet.weight = usesBarbell ? equipment.barWeight : 0
                }
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, Spacing.xl)
        }
        .padding(.vertical, Spacing.s)
        .background(Color.gymBackground)
    }

    private func plateStepper(for plate: Float) -> some View {
        let loadedCount = calculation.plates.filter { $0 == plate }.count

        return HStack(spacing: Spacing.xxs) {
            Button {
                removePlatePair(plate)
            } label: {
                Image(systemName: AppIcon.minus)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(loadedCount == 0)
            .accessibilityLabel("Remove \(formatted(plate)) \(equipment.unitLabel) each side")

            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(plateColor(for: plate))
                    .frame(width: 10, height: 10)
                    .overlay { Circle().stroke(Color.black.opacity(0.18), lineWidth: 0.5) }
                Text("\(formatted(plate))")
                    .font(AppFont.headlineMonospaced)
                    .lineLimit(1)
                if loadedCount > 0 {
                    Text("×\(loadedCount)")
                        .font(AppFont.captionSemiboldMonospaced)
                        .foregroundStyle(Color.gymPrimary)
                }
            }
            .accessibilityHidden(true)

            Button {
                addPlatePair(plate)
            } label: {
                Image(systemName: AppIcon.plus)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Add \(formatted(plate)) \(equipment.unitLabel) each side")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(Color.gymPrimary)
        .background(Color.gymCard, in: Capsule())
        .overlay { Capsule().stroke(Color.gymBorder, lineWidth: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(formatted(plate)) \(equipment.unitLabel) plate, \(loadedCount) per side")
        .accessibilityIdentifier("plate-stepper-\(formatted(plate))")
    }

    private var plateLoadedEquipmentNote: some View {
        Label(
            "Plate-loaded mode treats the entered weight as the total and splits it equally between both sides.",
            systemImage: AppIcon.info
        )
        .font(AppFont.subheadline)
        .foregroundStyle(Color.gymAccent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .background(Color.gymAccentSurface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    // Real-world competition plate colors (IWF convention); intentionally not
    // design-system tokens because they identify physical plates.
    private static let barMetalColor = Color(red: 0.62, green: 0.63, blue: 0.66)

    private func plateColor(for plate: Float) -> Color {
        let isMetric = preferredUnitSystem == .metric
        switch (isMetric, plate) {
        case (true, 25), (false, 55): return Color(red: 0.85, green: 0.16, blue: 0.16)
        case (true, 20), (false, 45): return Color(red: 0.16, green: 0.36, blue: 0.83)
        case (true, 15), (false, 35): return Color(red: 0.95, green: 0.77, blue: 0.06)
        case (true, 10), (false, 25): return Color(red: 0.16, green: 0.62, blue: 0.33)
        case (true, 5), (false, 10): return Color(red: 0.93, green: 0.93, blue: 0.91)
        case (true, 2.5), (false, 5): return Color(red: 0.85, green: 0.16, blue: 0.16)
        case (false, 2.5): return Color(red: 0.16, green: 0.62, blue: 0.33)
        default: return Self.barMetalColor
        }
    }

    private func plateTextColor(for plate: Float) -> Color {
        let isLightPlate = (preferredUnitSystem == .metric && plate == 5)
        return isLightPlate ? Color.gymText : .white
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

    private func formatted(_ value: Float) -> String {
        Formatters.formatFloat(value)
    }
}

private struct PlateDiagramView: View {
    let barWeight: Float
    let plates: [Float]
    let availablePlates: [Float]
    let unitLabel: String
    let barColor: Color
    let plateColor: (Float) -> Color
    let plateTextColor: (Float) -> Color
    let reduceMotion: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                barSegment(width: 54)
                collarSegment(height: 30, width: 8)

                ForEach(diagramPlates) { item in
                    plateShape(item.weight)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.94).combined(with: .opacity))
                }

                collarSegment(height: 24, width: 6)
                barSegment(width: 28, showsLabel: false)
            }
            .padding(.vertical, Spacing.s)
            .padding(.horizontal, Spacing.l)
            .frame(minHeight: 118)
            .animation(reduceMotion ? nil : AppMotion.compact, value: diagramPlates)
        }
        .defaultScrollAnchor(.center)
    }

    private var diagramPlates: [DiagramPlate] {
        var occurrences: [Float: Int] = [:]
        return plates.map { weight in
            let occurrence = occurrences[weight, default: 0]
            occurrences[weight] = occurrence + 1
            return DiagramPlate(weight: weight, occurrence: occurrence)
        }
    }

    private func barSegment(width: CGFloat, showsLabel: Bool = true) -> some View {
        Capsule()
            .fill(barColor)
            .frame(width: width, height: 12)
            .overlay {
                if showsLabel {
                    Text(Formatters.formatFloat(barWeight))
                        .font(AppFont.captionSemiboldMonospaced)
                        .foregroundStyle(Color.gymText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityHidden(true)
                }
            }
    }

    private func collarSegment(height: CGFloat, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(barColor)
            .frame(width: width, height: height)
    }

    private func plateShape(_ plate: Float) -> some View {
        let maximum = CGFloat(availablePlates.max() ?? 1)
        let ratio = CGFloat(plate) / maximum
        let height = 34 + ratio * 58
        let width = 7 + ratio * 18
        let labelFitsOnPlate = width >= 17

        return VStack(spacing: Spacing.xxs) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(plateColor(plate))
                .frame(width: width, height: height)
                .overlay {
                    if labelFitsOnPlate {
                        Text(Formatters.formatFloat(plate))
                            .font(AppFont.captionSemiboldMonospaced)
                            .foregroundStyle(plateTextColor(plate))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .rotationEffect(.degrees(width < 24 ? -90 : 0))
                            .accessibilityHidden(true)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.black.opacity(0.18), lineWidth: 1)
                }

            if !labelFitsOnPlate {
                Text(Formatters.formatFloat(plate))
                    .font(AppFont.captionSemiboldMonospaced)
                    .foregroundStyle(Color.gymText)
                    .lineLimit(1)
                    .accessibilityHidden(true)
            }
        }
    }
}
