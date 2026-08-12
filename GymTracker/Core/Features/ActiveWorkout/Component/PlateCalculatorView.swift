import SwiftUI

struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(DefaultsKey.useMetric) private var preferredUnitSystem: UnitSystem = .metric
    @Bindable var exerciseSet: ExerciseSet
    let usesBarbell: Bool
    @State private var selectedBarID = BarKind.mensOlympic.id
    @State private var manualComposition: PlateLoadComposition?

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

    private var displayedPlates: [Float] {
        manualComposition?.plates ?? calculation.plates
    }

    private var displayedTotalWeight: Float {
        manualComposition?.totalWeight(barWeight: equipment.barWeight) ?? calculation.totalWeight
    }

    private var displayedPerSideWeight: Float {
        equipment.barWeight / 2 + displayedPlates.reduce(0, +)
    }

    private var displayedRemainingWeight: Float {
        manualComposition == nil ? calculation.remainingWeight : 0
    }

    private var usesCompactPlateLayout: Bool {
        displayedPlates.count > PlateDiagramLayout.compactThreshold
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
                        Image(systemName: AppIcon.minimize)
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
            HStack(spacing: Spacing.s) {
                Text("BAR LOAD · ONE SIDE")
                    .font(AppFont.captionBold)
                    .tracking(0.8)
                    .foregroundStyle(Color.gymSubduedText)

                Spacer(minLength: Spacing.xs)

                if manualComposition != nil {
                    Button {
                        optimizePlateLoad()
                    } label: {
                        Label("Optimize", systemImage: AppIcon.reset)
                    }
                    .font(AppFont.captionBold)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.gymPrimary)
                    .accessibilityLabel("Optimize plates")
                    .accessibilityHint("Replaces the manual selection with the most space-efficient plate combination")
                    .accessibilityIdentifier("optimize-plate-load")
                }
            }

            PlateDiagramView(
                barWeight: equipment.barWeight,
                plates: displayedPlates,
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
            if displayedRemainingWeight > 0.01 {
                Label(
                    "Cannot load exactly — closest \(formatted(displayedTotalWeight)) \(equipment.unitLabel)",
                    systemImage: AppIcon.warning
                )
                .font(AppFont.caption)
                .foregroundStyle(Color.gymAccent)
            }

            if dynamicTypeSize.isAccessibilitySize || usesCompactPlateLayout {
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
                .font(usesCompactPlateLayout ? AppFont.subheadlineSemiboldMonospaced : AppFont.titleSmallSemiboldMonospaced)
                .foregroundStyle(Color.gymPrimary)
                .lineLimit(2)
        }
    }

    private var totalSummary: some View {
        Text("Per side incl. ½ bar \(formatted(displayedPerSideWeight)) \(equipment.unitLabel) · Total \(formatted(displayedTotalWeight)) \(equipment.unitLabel)")
            .font(AppFont.caption)
            .foregroundStyle(Color.gymSubduedText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var loadEachSideText: String {
        guard !displayedPlates.isEmpty else {
            return "No plates — bare \(formatted(equipment.barWeight)) \(equipment.unitLabel) bar"
        }
        return PlateDiagramLayout.items(for: displayedPlates)
            .map { item in
                item.count > 1
                    ? "\(formatted(item.weight)) × \(item.count)"
                    : formatted(item.weight)
            }
            .joined(separator: " + ") + " \(equipment.unitLabel)"
    }

    private var diagramAccessibilityLabel: String {
        let plateText = displayedPlates.isEmpty
            ? "no plates"
            : displayedPlates.map(formatted).joined(separator: ", ") + " \(equipment.unitLabel)"
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
                        manualComposition = PlateLoadComposition()
                        exerciseSet.weight = equipment.barWeight
                    }
                }

                Button(usesBarbell ? "Remove all plates" : "Clear", role: .destructive) {
                    manualComposition = PlateLoadComposition()
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
        let loadedCount = displayedPlates.filter { $0 == plate }.count

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
                    .overlay { Circle().stroke(Color.gymText.opacity(0.18), lineWidth: 0.5) }
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

    // Delegated to `PlateAppearance` so the calculator and the plate keypad
    // cannot drift into showing the same disc in two different colours.
    private func plateColor(for plate: Float) -> Color {
        PlateAppearance.color(for: plate, unitSystem: preferredUnitSystem)
    }

    private func plateTextColor(for plate: Float) -> Color {
        PlateAppearance.textColor(for: plate, unitSystem: preferredUnitSystem)
    }

    private func addPlatePair(_ plate: Float) {
        if usesBarbell && exerciseSet.weight < equipment.barWeight {
            exerciseSet.weight = equipment.barWeight
        }
        var composition = manualComposition ?? PlateLoadComposition(plates: calculation.plates)
        composition.add(plate)
        manualComposition = composition
        exerciseSet.weight = composition.totalWeight(barWeight: equipment.barWeight)
    }

    private func removePlatePair(_ plate: Float) {
        var composition = manualComposition ?? PlateLoadComposition(plates: calculation.plates)
        composition.remove(plate)
        manualComposition = composition
        exerciseSet.weight = composition.totalWeight(barWeight: equipment.barWeight)
    }

    private func optimizePlateLoad() {
        manualComposition = nil
    }

    private func selectBar(_ bar: BarKind) {
        let previousBarWeight = selectedBar.weight(for: preferredUnitSystem)
        selectedBarID = bar.id
        if let manualComposition {
            exerciseSet.weight = manualComposition.totalWeight(barWeight: bar.weight(for: preferredUnitSystem))
        } else {
            let plateLoad = max(0, exerciseSet.weight - previousBarWeight)
            exerciseSet.weight = bar.weight(for: preferredUnitSystem) + plateLoad
        }
    }

    private func synchronizeUnitsAndMinimumBarWeight() {
        let targetWeightType: WeightType = preferredUnitSystem == .metric ? .kg : .lbs
        if exerciseSet.weightType != targetWeightType {
            manualComposition = nil
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
            HStack(spacing: plates.count > PlateDiagramLayout.compactThreshold ? Spacing.m : Spacing.xxs) {
                barSegment(width: 54)
                collarSegment(height: 30, width: 8)

                ForEach(diagramPlates) { item in
                    plateGroup(item)
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
        PlateDiagramLayout.items(for: plates)
    }

    private func plateGroup(_ item: DiagramPlate) -> some View {
        plateShape(item.weight)
            .overlay(alignment: .topTrailing) {
                if item.count > 1 {
                    Text("×\(item.count)")
                        .font(AppFont.caption2Bold)
                        .foregroundStyle(Color.gymText)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxs)
                        .background(Color.gymCard, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.gymBorder, lineWidth: 1)
                        }
                        .offset(x: Spacing.m, y: -Spacing.s)
                        .accessibilityHidden(true)
                }
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
        // Keep the smallest change plates narrow, but wide enough to contain a
        // rotated numeric label instead of detaching the value below the plate.
        let width = 15 + ratio * 14

        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(plateColor(plate))
            .frame(width: width, height: height)
            .overlay {
                Text(Formatters.formatFloat(plate))
                    .font(AppFont.captionSemiboldMonospaced)
                    .foregroundStyle(plateTextColor(plate))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .rotationEffect(.degrees(width < 24 ? -90 : 0))
                    .accessibilityHidden(true)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.gymText.opacity(0.18), lineWidth: 1)
            }
    }
}
