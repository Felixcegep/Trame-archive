import SwiftUI

/// A press on ``DurationKeypad``.
enum DurationKey: Hashable {
    /// Set the duration to this many seconds outright.
    case preset(TimeInterval)
    /// Move the duration by this many seconds.
    case adjust(TimeInterval)
    case backspace
    /// Hand the surface back to the digit pad for a value the presets cannot
    /// express.
    case digits
}

/// The keypad for timed work.
///
/// A digit pad is the wrong instrument for a duration. Nobody holds a plank for
/// 47 seconds on purpose — timed work clusters hard on half-minutes, and the
/// values people actually enter are a shortlist. Typing `9` then `0` to mean a
/// minute and a half is two presses plus a mental conversion, where "1:30" is
/// one press of a key that says what it does.
///
/// So the presets *are* the keyboard here, rather than a row of shortcuts above
/// one. The digit pad stays one tap away for the genuine exception — a 2:47
/// carry, a stopwatch reading copied off a machine — because a shortlist that
/// cannot be escaped is a cage.
struct DurationKeypad: View {
    /// Six values, laid out 3 × 2. Ordered by duration so the grid reads left to
    /// right, top to bottom, the way the numbers on a digit pad do.
    var presets: [TimeInterval] = Self.defaultPresets
    var adjustStep: TimeInterval = 15
    let onKey: (DurationKey) -> Void

    @State private var lastPressedKey: DurationKey?

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: Spacing.s),
        count: 3
    )

    var body: some View {
        VStack(spacing: Spacing.xs) {
            LazyVGrid(columns: columns, spacing: Spacing.xs) {
                ForEach(presets, id: \.self) { seconds in
                    key(.preset(seconds)) {
                        Text(ClockEntry.clockText(seconds: seconds))
                            .font(AppFont.titleMediumMonospaced)
                            .foregroundStyle(Color.trameText)
                    }
                }

                key(.adjust(-adjustStep)) {
                    Text("−\(Int(adjustStep))s")
                        .font(AppFont.subheadlineBold)
                        .monospacedDigit()
                        .foregroundStyle(Color.trameText)
                }

                key(.adjust(adjustStep)) {
                    Text("+\(Int(adjustStep))s")
                        .font(AppFont.subheadlineBold)
                        .monospacedDigit()
                        .foregroundStyle(Color.trameText)
                }

                key(.backspace) {
                    Image(systemName: AppIcon.backspace)
                        .font(AppFont.titleSmallSemibold)
                        .foregroundStyle(Color.trameSubdued)
                }
            }

            // The escape hatch, stated plainly rather than hidden behind a
            // gesture. It is the rarer path, so it is a text button rather than
            // a seventh key competing with the presets.
            Button {
                lastPressedKey = .digits
                onKey(.digits)
            } label: {
                Label("Enter an exact time", systemImage: AppIcon.keyboard)
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.trameText)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("duration-keypad-digits")
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity)
        .background(Color.trameCanvas)
        // The preset labels are already large; growing them further only steals
        // height from the set list without making a two-character clock easier
        // to read.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .gymFeedback(.keyPressed, trigger: lastPressedKey)
    }

    private func key<Content: View>(
        _ durationKey: DurationKey,
        @ViewBuilder label: () -> Content
    ) -> some View {
        Button {
            lastPressedKey = durationKey
            onKey(durationKey)
        } label: {
            label()
                .frame(maxWidth: .infinity)
                .frame(height: ComponentSize.keypadKeyHeight)
                .background(background(for: durationKey))
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .stroke(Color.trameSeparator, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityLabel(Text(accessibilityLabel(for: durationKey)))
        .accessibilityIdentifier(identifier(for: durationKey))
    }

    private func background(for key: DurationKey) -> Color {
        switch key {
        case .preset: Color.trameSurface
        case .adjust, .digits: Color.trameCurrent
        case .backspace: Color.trameRow
        }
    }

    private func accessibilityLabel(for key: DurationKey) -> String {
        switch key {
        case .preset(let seconds):
            return String(localized: "Set to \(Int(seconds)) seconds")
        case .adjust(let seconds):
            return seconds < 0
                ? String(localized: "Subtract \(Int(abs(seconds))) seconds")
                : String(localized: "Add \(Int(seconds)) seconds")
        case .backspace:
            return String(localized: "Clear")
        case .digits:
            return String(localized: "Enter an exact time")
        }
    }

    private func identifier(for key: DurationKey) -> String {
        switch key {
        case .preset(let seconds): "duration-key-\(Int(seconds))"
        case .adjust(let seconds): "duration-key-adjust-\(Int(seconds))"
        case .backspace: "duration-key-backspace"
        case .digits: "duration-keypad-digits"
        }
    }
}

extension DurationKeypad {
    /// The shortlist timed work actually clusters on.
    static let defaultPresets: [TimeInterval] = [30, 45, 60, 75, 90, 120]

    /// The shortlist with the prescribed hold guaranteed a key.
    ///
    /// A mobility hold written as 40 seconds is not on the standard grid, so the
    /// one duration the lifter was told to hit would be the only one needing the
    /// digit pad — the exception becoming the rule for exactly the exercise that
    /// prescribed it. The target replaces whichever preset is furthest from it,
    /// which keeps the count at six (the layout is 3 × 2) and keeps the
    /// remaining keys clustered around what this set is asking for.
    static func presets(
        including target: TimeInterval?,
        base: [TimeInterval] = defaultPresets
    ) -> [TimeInterval] {
        guard let target, target > 0 else { return base }
        let rounded = target.rounded()
        guard !base.contains(rounded) else { return base }
        guard let furthest = base.max(by: { abs($0 - rounded) < abs($1 - rounded) }) else {
            return base
        }
        return (base.filter { $0 != furthest } + [rounded]).sorted()
    }
}

#Preview {
    VStack {
        Spacer()
        DurationKeypad { _ in }
    }
    .background(Color.trameCanvas)
}
