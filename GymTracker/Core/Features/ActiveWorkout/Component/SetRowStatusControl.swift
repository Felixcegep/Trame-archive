import SwiftUI
import SwiftData

struct SetRowStatusControl: View {
    let index: Int
    @Bindable var exerciseSet: ExerciseSet
    let exerciseEntry: ExerciseEntry
    let isCurrentSet: Bool
    let isEditingCompletedSet: Bool
    let handleCompletionButton: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isEditingCompletedSet {
                editingIndicator
            } else {
                doneButton
            }
            setTypeAccessory
        }
    }

    /// Editing a completed set used to leave this slot empty, so the state was
    /// carried by the row's tinted fill and border plus a single announcement
    /// posted at the moment editing began — nothing a lifter who looked away
    /// and back, or who cannot separate those tints, can read. The slot that
    /// holds the checkmark holds a pencil instead.
    private var editingIndicator: some View {
        Image(systemName: AppIcon.edit)
            .font(AppFont.subheadlineSemiboldMonospaced)
            .foregroundStyle(Color.trameStrength)
            .frame(width: 36, height: 36)
            .overlay {
                Circle().stroke(Color.trameStrength, lineWidth: 1.5)
            }
            .frame(width: 44, height: 44)
            .accessibilityLabel(String(localized: "Editing set \(index + 1)"))
            .accessibilityIdentifier("editing-set-\(exerciseEntry.exercise.name)-\(index)")
    }

    private var doneButton: some View {
        Button(action: handleCompletionButton) {
            Group {
                if exerciseSet.done {
                    Image(systemName: AppIcon.checkmark)
                } else {
                    Text("\(index + 1)")
                }
            }
            .font(AppFont.subheadlineSemiboldMonospaced)
            .foregroundStyle(badgeForeground)
            .frame(width: 36, height: 36)
            .background(badgeFill)
            .clipShape(Circle())
            .overlay {
                Circle().stroke(badgeStroke, lineWidth: badgeStrokeWidth)
            }
        }
        .buttonStyle(.borderless)
        .frame(width: 44, height: 44)
        .contentTransition(.symbolEffect(.replace))
        .accessibilityLabel(completionAccessibilityLabel)
        // Which set am I on is the most important question on this screen, and it
        // was answerable only by sight: the label read "Complete set 3" whether
        // or not that set was the current one. VoiceOver now gets in words what
        // the pointer and the tinted fill say visually.
        .accessibilityValue(isMarkedCurrent ? Text("Current set") : Text(verbatim: ""))
        .accessibilityHint(exerciseSet.done ? "Opens confirmation before marking this set incomplete." : "Marks this set complete.")
        .accessibilityIdentifier("complete-set-\(exerciseEntry.exercise.name)-\(index)")
    }

    /// The row-level marker in `SetRowView` uses the same three conditions, so
    /// the pointer and this value can never disagree about which set is current.
    private var isMarkedCurrent: Bool {
        isCurrentSet && !exerciseSet.done && !isEditingCompletedSet
    }

    // The badge's four appearance values are named rather than written as
    // nested ternaries inside the modifiers. Three states share one control, and
    // inline conditionals made the whole chain expensive to type-check.

    private var badgeForeground: Color {
        if exerciseSet.done { return .trameSemanticFieldInk }
        return isCurrentSet ? Color.trameActionOutline : Color.trameSubdued
    }

    private var badgeFill: Color {
        exerciseSet.done ? Color.trameCompleted : Color.clear
    }

    private var badgeStroke: Color {
        if exerciseSet.done { return .clear }
        return isCurrentSet ? Color.trameActionOutline : Color.trameSeparator
    }

    private var badgeStrokeWidth: CGFloat {
        isCurrentSet && !exerciseSet.done ? 1.5 : 1
    }

    private var completionAccessibilityLabel: String {
        let base = exerciseSet.done
            ? String(localized: "Completed set \(index + 1)")
            : String(localized: "Complete set \(index + 1)")
        guard exerciseSet.setType != .normal else { return base }
        return "\(base), \(exerciseSet.setType.title)"
    }

    @ViewBuilder
    private var setTypeAccessory: some View {
        if let shortLabel = exerciseSet.setType.shortLabel {
            Text(shortLabel)
                .font(AppFont.caption2Bold)
                .foregroundStyle(exerciseSet.setType.accentColor ?? Color.trameSubdued)
                .frame(width: 18, height: 18)
                .background(Color.trameSurface)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(Color.trameSeparator, lineWidth: 1)
                }
                .accessibilityLabel("\(exerciseSet.setType.title) badge \(shortLabel)")
                .accessibilityIdentifier("set-type-badge-\(exerciseEntry.exercise.name)-\(index)")
        }
    }
}
