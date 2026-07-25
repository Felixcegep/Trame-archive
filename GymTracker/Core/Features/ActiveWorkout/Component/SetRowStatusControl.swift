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
                Color.clear.frame(width: 44, height: 44)
            } else {
                doneButton
            }
            setTypeAccessory
        }
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
            .foregroundStyle(exerciseSet.done ? .white : (isCurrentSet ? Color.gymPrimary : Color.gymSubduedText))
            .frame(width: 36, height: 36)
            .background(exerciseSet.done ? Color.gymSecondary : Color.clear)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(
                        exerciseSet.done ? Color.clear : (isCurrentSet ? Color.gymPrimary : Color.gymBorder),
                        lineWidth: isCurrentSet && !exerciseSet.done ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.borderless)
        .frame(width: 44, height: 44)
        .contentTransition(.symbolEffect(.replace))
        .accessibilityLabel(completionAccessibilityLabel)
        .accessibilityHint(exerciseSet.done ? "Opens confirmation before marking this set incomplete." : "Marks this set complete.")
        .accessibilityIdentifier("complete-set-\(exerciseEntry.exercise.name)-\(index)")
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
        if exerciseSet.setType != .normal {
            Image(systemName: exerciseSet.setType.icon)
                .font(AppFont.caption2Bold)
                .foregroundStyle(exerciseSet.setType.accentColor ?? Color.gymSubduedText)
                .frame(width: 18, height: 18)
                .background(Color.gymCard)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(Color.gymBorder, lineWidth: 1)
                }
                .accessibilityHidden(true)
                .accessibilityIdentifier("set-type-\(exerciseEntry.exercise.name)-\(index)")
        }
    }
}
