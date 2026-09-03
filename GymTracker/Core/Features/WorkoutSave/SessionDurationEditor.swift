import SwiftUI

/// Corrects how long the lifter was at the gym before the session is saved.
///
/// Active duration is a clock; historical duration is `endTime - startTime`.
/// This editor writes the clock by moving `startTime` so the forthcoming save
/// stamps the time they actually spent, not the time spent writing notes.
struct SessionDurationEditor: View {
    let onSave: (TimeInterval) -> Void
    let onCancel: () -> Void

    @State private var hours: Int
    @State private var minutes: Int

    init(
        duration: TimeInterval,
        onSave: @escaping (TimeInterval) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onCancel = onCancel
        let clamped = min(
            Constants.Session.maximumDuration,
            max(Constants.Session.minimumDuration, duration)
        )
        let totalMinutes = Int(clamped) / 60
        _hours = State(initialValue: totalMinutes / 60)
        _minutes = State(initialValue: totalMinutes % 60)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.l) {
                Text(Formatters.sessionDuration(selectedDuration))
                    .font(AppFont.displayMedium)
                    .monospacedDigit()
                    .foregroundStyle(Color.trameText)
                    .accessibilityLabel(Text("Time at the gym, \(Formatters.sessionDuration(selectedDuration))"))

                HStack(spacing: 0) {
                    Picker("Hours", selection: $hours) {
                        ForEach(0...11, id: \.self) { value in
                            Text("\(value)")
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Hours")

                    Text("h")
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.trameSubdued)
                        .accessibilityHidden(true)

                    Picker("Minutes", selection: $minutes) {
                        ForEach(0...59, id: \.self) { value in
                            Text(String(format: "%02d", value))
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Minutes")

                    Text("m")
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.trameSubdued)
                        .accessibilityHidden(true)
                }
                .frame(height: 164)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.l)
            .background(Color.trameCanvas.ignoresSafeArea())
            .navigationTitle("Time at the gym")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("session-duration-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedDuration)
                    }
                    .font(AppFont.headlineSemibold)
                    .accessibilityIdentifier("session-duration-save")
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .tint(Color.trameAction)
        .onChange(of: hours) { _, _ in
            if hours == 0, minutes == 0 {
                minutes = 1
            }
        }
        .onChange(of: minutes) { _, _ in
            if hours == 0, minutes == 0 {
                minutes = 1
            }
        }
    }

    private var selectedDuration: TimeInterval {
        TimeInterval((hours * 60 + minutes) * 60)
    }
}
