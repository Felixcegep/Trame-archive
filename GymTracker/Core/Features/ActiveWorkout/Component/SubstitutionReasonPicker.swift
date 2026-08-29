import SwiftUI

/// Step one of a swap: why is the lifter replacing this exercise?
///
/// The reason is a structured code, never free text, because it drives
/// evaluation and has to survive a backup round trip and later localization.
///
/// "Not sure" is a first-class option. The alternative — inferring intent from
/// a free/template workout that never stated one — would manufacture context
/// the app does not have, and the whole feature depends on never doing that.
///
/// Implemented as a plain list of buttons rather than a `Menu` or `Picker` in a
/// `Form` row: menus in form rows do not open reliably under synthesized taps
/// on this project's simulator, and this step must stay drivable by UI tests.
struct SubstitutionReasonPicker: View {
    let exerciseName: String
    let onSelect: (SubstitutionReason) -> Void

    var body: some View {
        List {
            Section {
                ForEach(SubstitutionReason.allCases.filter { $0 != .notSure }, id: \.self) { reason in
                    reasonButton(reason)
                }
            } header: {
                Text(headerText)
            }

            Section {
                reasonButton(.notSure)
            } footer: {
                Text(SubstitutionPresentation.notSureFootnote)
            }
        }
        .navigationTitle("Why are you swapping?")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerText: String {
        let format = String(
            localized: "substitution.reason.header",
            defaultValue: "Replacing %@"
        )
        return String(format: format, exerciseName)
    }

    private func reasonButton(_ reason: SubstitutionReason) -> some View {
        Button {
            onSelect(reason)
        } label: {
            HStack {
                Text(SubstitutionPresentation.reasonTitle(reason))
                    .font(AppFont.body)
                    .foregroundStyle(Color.trameText)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Spacing.s)
                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("swap-reason-\(reason.rawValue)")
    }
}
