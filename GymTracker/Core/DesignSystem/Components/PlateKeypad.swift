import SwiftUI

// `BarKind`, `PlateEquipment` and `PlateCalculation` all live behind this
// same guard in `PlateCalculatorModel`. The Live Activity extension compiles
// this folder too — `NumericKeypad` is deliberately dependency-free for that
// reason — so a keypad that reaches into the plate model has to be gated
// identically or the extension target stops building.
#if !GYMTRACKER_EXTENSION

/// Plate colours, in one place.
///
/// These are the IWF/IPF competition colours, which is why they are literals
/// rather than design tokens: a 20 kg plate is blue in every gym on earth, and
/// recolouring it to fit a palette would break the one thing the colour is for
/// — recognising the disc on the rack without reading the number.
///
/// Lifted out of `PlateCalculatorView`, where it was private, so the plate
/// keypad and the plate calculator cannot drift into showing the same plate in
/// two different colours.
enum PlateAppearance {
    static let barMetal = Color(red: 0.62, green: 0.63, blue: 0.66)

    static func color(for plate: Float, unitSystem: UnitSystem) -> Color {
        let isMetric = unitSystem == .metric
        switch (isMetric, plate) {
        case (true, 25), (false, 55): return Color(red: 0.85, green: 0.16, blue: 0.16)
        case (true, 20), (false, 45): return Color(red: 0.16, green: 0.36, blue: 0.83)
        case (true, 15), (false, 35): return Color(red: 0.95, green: 0.77, blue: 0.06)
        case (true, 10), (false, 25): return Color(red: 0.16, green: 0.62, blue: 0.33)
        case (true, 5), (false, 10): return Color(red: 0.93, green: 0.93, blue: 0.91)
        case (true, 2.5), (false, 5): return Color(red: 0.85, green: 0.16, blue: 0.16)
        case (false, 2.5): return Color(red: 0.16, green: 0.62, blue: 0.33)
        default: return barMetal
        }
    }

    /// White on every plate except the ones pale enough to lose it.
    static func textColor(for plate: Float, unitSystem: UnitSystem) -> Color {
        let isPale = (unitSystem == .metric && plate == 5)
        return isPale ? Color.trameText : .white
    }
}

/// A press on ``PlateKeypad``.
enum PlateKey: Hashable {
    /// Add this plate to **each** side, so the bar gains twice its face value.
    case plate(Float)
    /// Strip everything back to the empty bar.
    case bareBar
    /// Take the last plate back off each side.
    case removeLast
    /// Re-solve the same total into the fewest discs.
    case optimize
    case digits
}

/// The input surface for a loaded barbell.
///
/// A digit pad asks "what is the total?" — but nobody loads a bar by computing
/// a total. They think in discs: a twenty and a ten a side on top of the bar.
/// The arithmetic that turns that into 80 kg is work the app should be doing,
/// not the lifter, standing over a bar, mid-session.
///
/// So the keys *are* plates, in competition colours, and the stack above them
/// shows what is currently on one end. Loading and reading become the same
/// gesture, and the number stops being something you calculate and becomes
/// something you watch change.
struct PlateKeypad: View {
    let target: Float
    let barWeight: Float
    /// The plates this rack actually has, largest first.
    let availablePlates: [Float]
    /// What is actually on one side, **in the order it was loaded** — not a
    /// re-solve. Pressing 10 then 25 shows `10, 25`, because that is what is on
    /// the bar; silently rearranging it into `25, 10` would describe a bar the
    /// lifter did not build.
    let loadedPerSide: [Float]
    /// How few discs the same total could be made from, when that is fewer than
    /// what is currently loaded. `nil` hides the offer.
    let optimizedCount: Int?
    /// True when the plates cannot reach the target exactly — a weight typed on
    /// the digit pad, or a rack that has no small enough disc.
    let hasRemainder: Bool
    let unitSystem: UnitSystem
    let unitLabel: String
    /// The chosen bar, so the header can offer the other six.
    @Binding var selectedBarID: String
    let onKey: (PlateKey) -> Void

    private var barSelection: Binding<String> {
        Binding(get: { selectedBarID }, set: { selectedBarID = $0 })
    }

    @State private var lastPressedKey: PlateKey?

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: Spacing.s),
        count: 3
    )

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            header
                // A container identifier here would replace the identities of
                // the exact-entry and plate keys in the accessibility tree.
                .accessibilityIdentifier("plate-keypad")
            stack
            plateGrid

            HStack(spacing: Spacing.xs) {
                utilityKey(.bareBar, title: String(localized: "Bare bar"), icon: AppIcon.minus)
                utilityKey(.removeLast, title: String(localized: "Remove"), icon: AppIcon.backspace)
            }

            Button {
                lastPressedKey = .digits
                onKey(.digits)
            } label: {
                Label("Enter an exact weight", systemImage: AppIcon.keyboard)
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.trameText)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("plate-keypad-digits")
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.trameCanvas)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .gymFeedback(.keyPressed, trigger: lastPressedKey)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("BAR LOAD")
                    .font(AppFont.caption2Bold)
                    .tracking(0.6)
                    .foregroundStyle(Color.trameSubdued)

                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(Formatters.formatFloat(target))
                        .font(AppFont.displayMedium)
                        .monospacedDigit()
                        .foregroundStyle(Color.trameText)
                    Text(unitLabel)
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.trameSubdued)
                }
            }

            Spacer(minLength: Spacing.s)

            // The bar is part of every total on this keypad, so choosing it
            // belongs here rather than two taps away in the calculator sheet.
            // A 15 kg women's bar and a 20 kg men's bar put the same discs at
            // different weights, and picking the wrong one is wrong by five
            // kilos on every set of the session.
            Menu {
                Picker("Bar", selection: barSelection) {
                    ForEach(BarKind.allCases) { bar in
                        Text("\(bar.title) · \(Formatters.formatFloat(barWeight(of: bar))) \(unitLabel)")
                            .tag(bar.id)
                    }
                }
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Text("\(Formatters.formatFloat(barWeight)) \(unitLabel) bar")
                        .monospacedDigit()
                    Image(systemName: AppIcon.chevronDown)
                        .font(AppFont.caption2Bold)
                }
                .font(AppFont.caption)
                .foregroundStyle(Color.trameText)
                .padding(.horizontal, Spacing.s)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .background(
                    Color.trameCurrent,
                    in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                )
                .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Bar type, \(Formatters.formatFloat(barWeight)) \(unitLabel)"))
            .accessibilityIdentifier("plate-keypad-bar")
        }
    }

    private func barWeight(of bar: BarKind) -> Float {
        unitSystem == .metric ? bar.metricWeight : bar.imperialWeight
    }

    // MARK: - Stack

    /// One end of the bar, drawn. This is the part a lifter checks against the
    /// rack, so it shows a side rather than the total — the same quantity the
    /// keys below add.
    @ViewBuilder
    private var stack: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xxs) {
                // The sleeve, so the discs read as being *on* something.
                Capsule()
                    .fill(PlateAppearance.barMetal)
                    .frame(width: 14, height: 8)

                if loadedPerSide.isEmpty {
                    Text(target <= barWeight ? "Empty bar" : "No plates fit")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.trameSubdued)
                        .padding(.leading, Spacing.xs)
                } else {
                    ForEach(Array(loadedPerSide.enumerated()), id: \.offset) { _, plate in
                        Text(Formatters.formatFloat(plate))
                            .font(AppFont.caption2Bold)
                            .monospacedDigit()
                            .foregroundStyle(PlateAppearance.textColor(for: plate, unitSystem: unitSystem))
                            .frame(width: 30, height: plateHeight(for: plate))
                            .background(
                                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                                    .fill(PlateAppearance.color(for: plate, unitSystem: unitSystem))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                                    .stroke(Color.gymText.opacity(0.12), lineWidth: 1)
                            }
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(height: 48)

            if hasRemainder {
                // Silence here would be the failure: the stack would show a
                // plausible load that does not add up to the number above it.
                Label("Plates don’t reach this exactly", systemImage: AppIcon.warning)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameAttention)
            }

            // Offered, never imposed. A lifter who has just walked to a bar
            // already carrying a 10 and a 25 wants those counted, not
            // rearranged into a tidier stack they would then have to physically
            // rebuild. The offer appears only when it would genuinely save
            // discs, and says how many.
            if let optimizedCount, optimizedCount < loadedPerSide.count {
                Button {
                    lastPressedKey = .optimize
                    onKey(.optimize)
                } label: {
                    Label(
                        "Use \(optimizedCount) plates instead of \(loadedPerSide.count)",
                        systemImage: AppIcon.relationship
                    )
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameText)
                    .frame(minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.gymPress)
                .accessibilityIdentifier("plate-key-optimize")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(stackAccessibilityLabel))
    }

    /// Bigger discs are drawn taller, the way they are on a rack. Purely a
    /// recognition aid — the number is still on every plate.
    private func plateHeight(for plate: Float) -> CGFloat {
        guard let largest = availablePlates.max(), largest > 0 else { return 48 }
        let ratio = CGFloat(plate / largest)
        return 26 + (22 * min(1, max(0, ratio)))
    }

    private var stackAccessibilityLabel: String {
        guard !loadedPerSide.isEmpty else {
            return String(localized: "Empty bar")
        }
        let list = loadedPerSide.map { Formatters.formatFloat($0) }.joined(separator: ", ")
        return String(localized: "Per side: \(list). Total \(Formatters.formatFloat(target)) \(unitLabel).")
    }

    // MARK: - Keys

    private var plateGrid: some View {
        LazyVGrid(columns: columns, spacing: Spacing.xs) {
            ForEach(availablePlates, id: \.self) { plate in
                Button {
                    lastPressedKey = .plate(plate)
                    onKey(.plate(plate))
                } label: {
                    Text(Formatters.formatFloat(plate))
                        .font(AppFont.titleSmallSemiboldMonospaced)
                        .foregroundStyle(PlateAppearance.textColor(for: plate, unitSystem: unitSystem))
                        .frame(maxWidth: .infinity)
                        .frame(height: ComponentSize.keypadKeyHeight)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                                .fill(PlateAppearance.color(for: plate, unitSystem: unitSystem))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                                .stroke(Color.trameSeparator, lineWidth: 1)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.gymPress)
                .accessibilityLabel(
                    Text("Add \(Formatters.formatFloat(plate)) \(unitLabel) per side, \(Formatters.formatFloat(plate * 2)) on the bar")
                )
                .accessibilityIdentifier("plate-key-\(Formatters.formatFloat(plate))")
            }
        }
    }

    private func utilityKey(_ key: PlateKey, title: String, icon: String) -> some View {
        Button {
            lastPressedKey = key
            onKey(key)
        } label: {
            Label(title, systemImage: icon)
                .font(AppFont.footnoteMedium)
                .foregroundStyle(Color.trameText)
                .frame(maxWidth: .infinity)
                .frame(height: ComponentSize.keypadKeyHeight)
                .background(Color.trameSurface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .stroke(Color.trameSeparator, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier(key == .bareBar ? "plate-key-bare-bar" : "plate-key-remove")
    }
}

#Preview {
    VStack {
        Spacer()
        PlateKeypad(
            target: 100,
            barWeight: 20,
            availablePlates: [25, 20, 15, 10, 5, 2.5],
            loadedPerSide: [20, 15, 5],
            optimizedCount: 3,
            hasRemainder: false,
            unitSystem: .metric,
            unitLabel: "kg",
            selectedBarID: .constant(BarKind.mensOlympic.id),
            onKey: { _ in }
        )
    }
    .background(Color.trameCanvas)
}

#endif
