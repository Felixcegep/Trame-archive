import SwiftUI

/// Compact editor for one internal segment of a dropset, cluster, rest-pause,
/// or myo-rep set. It never creates a second top-level working set.
struct SetSegmentEditorRow: View {
    @Bindable var segment: ExerciseSetSegment
    let canDelete: Bool
    let onPersist: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.s) {
                Text("\(segment.orderIndex + 1)")
                    .font(AppFont.captionSemiboldMonospaced)
                    .foregroundStyle(Color.gymSubduedText)
                    .frame(width: 18)
                decimalField("Reps", value: Binding(
                    get: { segment.repetitions == 0 ? "" : String(segment.repetitions) },
                    set: { segment.repetitions = Float($0.replacingOccurrences(of: ",", with: ".")) ?? 0; onPersist() }
                ))
                decimalField("Load", value: Binding(
                    get: { segment.weight == 0 ? "" : String(segment.weight) },
                    set: { segment.weight = Float($0.replacingOccurrences(of: ",", with: ".")) ?? 0; onPersist() }
                ))
                TextField("Rest", text: Binding(
                    get: { segment.restAfterSeconds.map { String($0) } ?? "" },
                    set: { segment.restAfterSeconds = Int($0); onPersist() }
                ))
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: AppIcon.trash)
                }
                .buttonStyle(.borderless)
                .disabled(!canDelete)
                .accessibilityLabel("Delete segment \(segment.orderIndex + 1)")
            }
            TextField("Variation or segment note", text: Binding(
                get: { segment.variationNote ?? "" },
                set: { segment.variationNote = $0.isEmpty ? nil : $0; onPersist() }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    private func decimalField(_ placeholder: String, value: Binding<String>) -> some View {
        TextField(placeholder, text: value)
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
    }
}
