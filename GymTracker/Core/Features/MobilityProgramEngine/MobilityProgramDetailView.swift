import SwiftData
import SwiftUI

/// View a mobility plan's detail and activate it, mirroring
/// `ProgramCatalogDetailView`'s structural idiom for the workout side.
/// Mobility programs carry no intake inputs in this slice (the definition
/// graph has none), so activation is a single start-date choice.
struct MobilityProgramDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let record: MobilityProgramDefinitionRecord

    @State private var errorMessage: String?
    @State private var startDate = Date.now
    @State private var isActivating = false

    private var payload: MobilityProgramDefinitionPayload? { try? record.payload() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                overview
                weekPreview
                activation
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .folderScreenStyle()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("mobility-program-detail")
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(record.name)
                .font(AppFont.displayMedium)
                .foregroundStyle(Color.gymText)
            if let summary = record.summary {
                Text(summary)
                    .font(AppFont.body)
                    .foregroundStyle(Color.gymSubduedText)
            }
            HStack(spacing: Spacing.s) {
                ProgramMetaChip(text: "\(record.durationWeeks) weeks")
                ProgramMetaChip(text: record.supportedDaysPerWeek.map(String.init).joined(separator: "/") + " days/week")
            }
        }
    }

    @ViewBuilder
    private var weekPreview: some View {
        if let payload {
            let firstWeekSessions = payload.flattenedSessions.filter { $0.weekIndex == 0 }
            if !firstWeekSessions.isEmpty {
                sectionCard(title: "Week 1 preview") {
                    ForEach(Array(firstWeekSessions.enumerated()), id: \.offset) { index, session in
                        if index > 0 { Divider().overlay(Color.gymBorder) }
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(session.name)
                                    .font(AppFont.bodyMedium)
                                    .foregroundStyle(Color.gymText)
                                Spacer()
                                Text(movementCountText(session.recipe.occurrences.count))
                                    .font(AppFont.subheadlineMonospaced)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                            if session.isOptional {
                                Text("Optional")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymAccent)
                            }
                        }
                    }
                    if payload.flattenedSessions.count > firstWeekSessions.count {
                        Text("Plus \(payload.flattenedSessions.count - firstWeekSessions.count) more sessions across the plan")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
            }
        }
    }

    private func movementCountText(_ count: Int) -> String {
        count == 1 ? String(localized: "1 movement") : String(localized: "\(count) movements")
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(title)
                .font(AppFont.titleSmall)
                .foregroundStyle(Color.gymText)
            VStack(alignment: .leading, spacing: Spacing.m) {
                content()
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Radius.large)
                    .fill(Color.gymCard)
                    .stroke(Color.gymBorder, lineWidth: 1)
            }
        }
    }

    private var activation: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                .accessibilityIdentifier("mobility-program-start-date")
            if let errorMessage {
                Label(errorMessage, systemImage: AppIcon.warning)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymDestructive)
                    .accessibilityIdentifier("mobility-program-catalog-error")
            }
            Button {
                activate()
            } label: {
                HStack {
                    Spacer()
                    if isActivating { ProgressView() }
                    Label("Use this plan", systemImage: AppIcon.play)
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isActivating)
            .accessibilityIdentifier("use-mobility-program")
        }
    }

    private func activate() {
        guard let payload else {
            errorMessage = String(localized: "This plan could not be loaded.")
            return
        }
        isActivating = true
        do {
            _ = try MobilityProgramRunCoordinator.activate(
                program: payload,
                sourceProgramID: record.id,
                startDate: startDate,
                using: modelContext
            )
            errorMessage = nil
            dismiss()
        } catch {
            isActivating = false
            errorMessage = String(localized: "This plan could not be started. Try again.")
        }
    }
}
