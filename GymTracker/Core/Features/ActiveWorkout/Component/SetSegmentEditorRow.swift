import SwiftUI

/// Compact editor for one internal segment of a dropset, cluster, rest-pause,
/// or myo-rep set. It never creates a second top-level working set.
struct SetSegmentEditorRow: View {
    @Bindable var segment: ExerciseSetSegment
    let method: SetMethod
    let canDelete: Bool
    let onPersist: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(segmentLabel.uppercased())
                    .font(AppFont.micro)
                    .tracking(0.7)
                    .foregroundStyle(Color.trameSubdued)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Label("Remove", systemImage: AppIcon.trash)
                        .labelStyle(.iconOnly)
                        .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .disabled(!canDelete)
                .accessibilityLabel("Delete \(segmentLabel)")
                .accessibilityIdentifier("set-segment-delete-\(segment.orderIndex)")
            }

            HStack(alignment: .top, spacing: Spacing.m) {
                metricField("REPS", accessibilityLabel: "\(segmentLabel), reps", placeholder: "0", identifier: "set-segment-reps-\(segment.orderIndex)", value: Binding(
                    get: { segment.repetitions == 0 ? "" : String(segment.repetitions) },
                    set: { segment.repetitions = Float($0.replacingOccurrences(of: ",", with: ".")) ?? 0; onPersist() }
                ))
                metricField("LOAD", accessibilityLabel: "\(segmentLabel), load", placeholder: "0", identifier: "set-segment-load-\(segment.orderIndex)", value: Binding(
                    get: { segment.weight == 0 ? "" : String(segment.weight) },
                    set: { segment.weight = Float($0.replacingOccurrences(of: ",", with: ".")) ?? 0; onPersist() }
                ))
                metricField("REST · SEC", accessibilityLabel: "\(segmentLabel), rest in seconds", placeholder: "—", identifier: "set-segment-rest-\(segment.orderIndex)", keyboard: .numberPad, value: Binding(
                    get: { segment.restAfterSeconds.map { String($0) } ?? "" },
                    set: { segment.restAfterSeconds = Int($0); onPersist() }
                ))
            }

            TextField("Variation or cue (optional)", text: Binding(
                get: { segment.variationNote ?? "" },
                set: { segment.variationNote = $0.isEmpty ? nil : $0; onPersist() }
            ))
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("\(segmentLabel), variation or cue")
            .accessibilityIdentifier("set-segment-cue-\(segment.orderIndex)")
        }
        .padding(.vertical, Spacing.s)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.trameSeparator).frame(height: 1)
        }
        .accessibilityIdentifier("set-segment-\(segment.orderIndex)")
    }

    private var segmentLabel: String {
        let index = segment.orderIndex
        switch method {
        case .dropSet: return index == 0 ? String(localized: "Dropset start") : String(localized: "Drop \(index)")
        case .mechanicalDropSet: return String(localized: "Mechanical variation \(index + 1)")
        case .cluster: return String(localized: "Cluster \(index + 1)")
        case .restPause: return index == 0 ? String(localized: "Initial effort") : String(localized: "Burst \(index)")
        case .myoReps: return index == 0 ? String(localized: "Activation") : String(localized: "Mini-set \(index)")
        default: return String(localized: "Effort \(index + 1)")
        }
    }

    private func metricField(
        _ label: String,
        accessibilityLabel: String,
        placeholder: String,
        identifier: String,
        keyboard: UIKeyboardType = .decimalPad,
        value: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(AppFont.micro)
                .tracking(0.55)
                .foregroundStyle(Color.trameSubdued)
            TextField(placeholder, text: value)
                .keyboardType(keyboard)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityIdentifier(identifier)
                .font(AppFont.titleSmallSemibold.monospacedDigit())
                .textFieldStyle(.plain)
                .padding(.vertical, Spacing.s)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.trameSeparator).frame(height: 1)
                }
        }
        .frame(maxWidth: .infinity)
    }
}
