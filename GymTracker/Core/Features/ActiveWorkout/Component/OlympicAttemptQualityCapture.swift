import SwiftUI
import SwiftData

/// Gym-floor answer for one Olympic attempt: did the movement go well?
///
/// Three large targets, not a menu. Chalked hands cannot hunt through a
/// nested list between attempts. Inspect-level quality (technically poor vs
/// acceptable) stays on set details; Glance only needs well / made / missed.
struct OlympicAttemptQualityCapture: View {
    @Bindable var set: ExerciseSet
    let onChange: () -> Void

    private static let options: [LiftQuality] = [.excellent, .acceptable, .missed]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("DID IT GO?")
                .font(AppFont.eyebrow)
                .tracking(0.8)

            HStack(spacing: Spacing.s) {
                ForEach(Self.options, id: \.self) { quality in
                    qualityButton(quality)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("olympic-quality-capture")
    }

    private func qualityButton(_ quality: LiftQuality) -> some View {
        let isSelected = set.liftQuality == quality
        return Button {
            set.liftQuality = isSelected ? nil : quality
            onChange()
        } label: {
            Text(quality.gymFloorTitle)
                .font(AppFont.footnoteMedium)
                .foregroundStyle(isSelected ? Color.trameText : Color.trameSubdued)
                .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                .background(isSelected ? Color.trameCurrent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.trameActionOutline : Color.trameSeparator,
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.gymPress)
        .accessibilityLabel(quality.gymFloorTitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Records whether this lift went well")
        .accessibilityIdentifier("olympic-quality-\(quality.rawValue)")
    }
}
