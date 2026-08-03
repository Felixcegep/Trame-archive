import SwiftData
import SwiftUI

/// One mobility plan run's progress, with the next session startable and
/// every lifecycle action reachable. iOS 26 note: toolbar buttons on pushed
/// screens do not reliably fire in this app, so every action here is an
/// in-content button, `Menu`, or `contextMenu` rather than a `ToolbarItem`.
struct MobilityProgramRunView: View {
    @Environment(\.modelContext) private var modelContext
    let run: MobilityProgramRun
    let onStartProgramSession: (MobilitySession) -> Void

    @Query(sort: \MobilityDefinition.name) private var mobilityDefinitions: [MobilityDefinition]
    @Query(sort: \MobilityProgressionRecommendationRecord.createdAt, order: .reverse)
    private var allRecommendations: [MobilityProgressionRecommendationRecord]

    @State private var errorMessage: String?
    @State private var reschedulingProgress: MobilityProgramSessionProgress?
    @State private var rescheduleDate = Date.now
    @State private var isShowingRestartChoice = false
    @State private var refreshToken = UUID()

    private var mobilityDefinitionsByID: [UUID: MobilityDefinition] {
        Dictionary(uniqueKeysWithValues: mobilityDefinitions.map { ($0.id, $0) })
    }

    private var nextSession: MobilityProgramSessionProgress? {
        _ = refreshToken
        return MobilityProgramRunCoordinator.nextSessionProgress(in: run)
    }

    private var unresolvedRecommendations: [MobilityProgressionRecommendationRecord] {
        allRecommendations.filter { $0.runID == run.id && $0.isResolved == false }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header
                if !unresolvedRecommendations.isEmpty {
                    recommendationsSection
                }
                nextSessionCard
                sessionsSection
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .folderScreenStyle()
        .navigationTitle(run.sourceProgramName)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("mobility-program-run")
        .onAppear(perform: reconcile)
        .alert("Couldn’t update this plan", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .sheet(item: $reschedulingProgress) { progress in
            rescheduleSheet(for: progress)
        }
        .confirmationDialog(
            "Restart this plan?",
            isPresented: $isShowingRestartChoice,
            titleVisibility: .visible
        ) {
            Button("Restart with progress") { restart(carryingState: true) }
                .accessibilityIdentifier("mobility-program-restart-with-state")
            Button("Restart from scratch") { restart(carryingState: false) }
                .accessibilityIdentifier("mobility-program-restart-without-state")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Restarting with progress keeps every duration, repetition, and load you’ve earned. Restarting from scratch begins every movement at its original prescription.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(run.sourceProgramName)
                        .font(AppFont.displayMedium)
                        .foregroundStyle(Color.gymText)
                    Text(statusText)
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                }
                Spacer()
                manageMenu
            }
            ProgressView(value: progressFraction)
                .tint(Color.gymPrimary)
                .accessibilityIdentifier("mobility-program-progress")
        }
    }

    private var progressFraction: Double {
        let total = run.sessionProgress.count
        guard total > 0 else { return 0 }
        let completed = run.sessionProgress.filter { $0.status == .completed }.count
        return Double(completed) / Double(total)
    }

    private var statusText: String {
        let completed = run.sessionProgress.filter { $0.status == .completed }.count
        let total = run.sessionProgress.count
        switch run.status {
        case .active: return String(localized: "Following · \(completed) of \(total) sessions")
        case .paused: return String(localized: "Paused · \(completed) of \(total) sessions")
        case .completed: return String(localized: "Completed · \(completed) of \(total) sessions")
        case .archived: return String(localized: "Archived · \(completed) of \(total) sessions")
        }
    }

    /// An in-content `Menu`, not a `ToolbarItem` — see this file's header
    /// comment.
    private var manageMenu: some View {
        Menu {
            switch run.status {
            case .active:
                Button("Pause plan", systemImage: AppIcon.pause) { pause() }
                    .accessibilityIdentifier("mobility-program-pause")
                Button("Archive plan", systemImage: AppIcon.archive, role: .destructive) { archive() }
                    .accessibilityIdentifier("mobility-program-archive")
            case .paused:
                Button("Resume plan", systemImage: AppIcon.play) { resume() }
                    .accessibilityIdentifier("mobility-program-resume")
                Button("Archive plan", systemImage: AppIcon.archive, role: .destructive) { archive() }
                    .accessibilityIdentifier("mobility-program-archive")
            case .completed, .archived:
                Button("Restart plan", systemImage: AppIcon.reschedule) { isShowingRestartChoice = true }
                    .accessibilityIdentifier("mobility-program-restart")
            }
        } label: {
            Label("Manage", systemImage: AppIcon.settings)
                .labelStyle(.iconOnly)
                .font(AppFont.titleSmall)
                .foregroundStyle(Color.gymSubduedText)
                .frame(width: 44, height: 44)
        }
        .accessibilityIdentifier("mobility-program-manage-menu")
        .accessibilityLabel("Manage plan")
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Progression")
                .font(AppFont.titleSmall)
                .foregroundStyle(Color.gymText)
            VStack(alignment: .leading, spacing: Spacing.m) {
                ForEach(unresolvedRecommendations) { record in
                    recommendationRow(record)
                    if record.id != unresolvedRecommendations.last?.id {
                        Divider().overlay(Color.gymBorder)
                    }
                }
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

    private func recommendationRow(_ record: MobilityProgressionRecommendationRecord) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(record.reason)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymText)
            Text(sideLabel(record.side))
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
            HStack(spacing: Spacing.s) {
                Button("Accept") { accept(record) }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.gymPrimary)
                    .accessibilityIdentifier("mobility-program-recommendation-accept-\(record.id)")
                Button("Decline") { decline(record) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("mobility-program-recommendation-decline-\(record.id)")
            }
        }
    }

    private func sideLabel(_ side: MobilitySide) -> String {
        switch side {
        case .none: String(localized: "This movement")
        case .left: String(localized: "Left side")
        case .right: String(localized: "Right side")
        case .bilateral: String(localized: "Both sides")
        case .alternating: String(localized: "Alternating sides")
        }
    }

    // MARK: - Next session

    @ViewBuilder
    private var nextSessionCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Next session")
                .font(AppFont.titleSmall)
                .foregroundStyle(Color.gymText)
            if let nextSession {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(nextSession.sessionNameSnapshot)
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(Color.gymText)
                        if let scheduledDate = nextSession.scheduledDate {
                            Text(scheduledDate.formatted(date: .abbreviated, time: .omitted))
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                        if nextSession.isOptional {
                            Text("Optional")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymAccent)
                        }
                    }
                    if run.status == .active {
                        Button {
                            startSession(nextSession)
                        } label: {
                            Label("Start session", systemImage: AppIcon.play)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(Color.gymPrimary)
                        .accessibilityIdentifier("mobility-program-start-session")
                    } else {
                        Text("Resume this plan to start your next session.")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                .padding(Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: Radius.large)
                        .fill(Color.gymCard)
                        .stroke(Color.gymAccent.opacity(0.24), lineWidth: 1)
                }
            } else {
                ContentUnavailableView(
                    "All sessions accounted for",
                    systemImage: AppIcon.checkmarkCircle,
                    description: Text("Every session in this plan has been completed, skipped, or marked missed.")
                )
            }
        }
    }

    // MARK: - Sessions

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Sessions")
                .font(AppFont.titleSmall)
                .foregroundStyle(Color.gymText)
            VStack(alignment: .leading, spacing: Spacing.m) {
                ForEach(run.orderedSessionProgress) { progress in
                    sessionRow(progress)
                    if progress.id != run.orderedSessionProgress.last?.id {
                        Divider().overlay(Color.gymBorder)
                    }
                }
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

    private func sessionRow(_ progress: MobilityProgramSessionProgress) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(progress.sessionNameSnapshot)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
                if let scheduledDate = progress.scheduledDate {
                    Text(scheduledDate.formatted(date: .abbreviated, time: .omitted))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
            }
            Spacer()
            Text(sessionStatusText(progress))
                .font(AppFont.caption2Bold)
                .foregroundStyle(Color.gymSubduedText)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xxs)
                .background(Color.gymRowSurface, in: Capsule())
        }
        .contentShape(Rectangle())
        .contextMenu {
            if MobilityProgramRunCoordinator.canEditSchedule(progress, in: run) {
                Button("Reschedule", systemImage: AppIcon.reschedule) {
                    rescheduleDate = progress.scheduledDate ?? .now
                    reschedulingProgress = progress
                }
                Button("Skip session", systemImage: AppIcon.skip) { skip(progress) }
                Button("Mark missed", systemImage: AppIcon.warning) { markMissed(progress) }
            }
            if progress.status == .completed {
                Button("Request progression review", systemImage: AppIcon.chart) {
                    requestApprovalReview(progress)
                }
            }
        }
        .accessibilityIdentifier("mobility-program-session-\(progress.id)")
    }

    private func sessionStatusText(_ progress: MobilityProgramSessionProgress) -> String {
        switch progress.status {
        case .pending: String(localized: "Pending")
        case .completed: String(localized: "Completed")
        case .skipped: String(localized: "Skipped")
        case .missed: String(localized: "Missed")
        }
    }

    private func rescheduleSheet(for progress: MobilityProgramSessionProgress) -> some View {
        NavigationStack {
            Form {
                DatePicker("Scheduled date", selection: $rescheduleDate, displayedComponents: .date)
            }
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { reschedulingProgress = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveReschedule(progress) }
                }
            }
        }
    }

    // MARK: - Actions

    private func reconcile() {
        MobilityProgramRunCoordinator.reconcileTerminalSessions(using: modelContext)
        refreshToken = UUID()
    }

    private func startSession(_ progress: MobilityProgramSessionProgress) {
        do {
            guard let session = try MobilityProgramRunCoordinator.startSession(
                progress,
                in: run,
                mobilityDefinitionsByID: mobilityDefinitionsByID,
                using: modelContext
            ) else {
                errorMessage = String(localized: "This session could not be started. Try again.")
                return
            }
            onStartProgramSession(session)
        } catch {
            errorMessage = String(localized: "This session could not be started. Try again.")
        }
    }

    private func pause() {
        guard MobilityProgramRunCoordinator.pause(run, using: modelContext) else {
            errorMessage = String(localized: "This plan could not be paused. Try again.")
            return
        }
        refreshToken = UUID()
    }

    private func resume() {
        guard MobilityProgramRunCoordinator.resume(run, using: modelContext) else {
            errorMessage = String(localized: "This plan could not be resumed. Try again.")
            return
        }
        refreshToken = UUID()
    }

    private func archive() {
        guard MobilityProgramRunCoordinator.archive(run, using: modelContext) else {
            errorMessage = String(localized: "This plan could not be archived. Try again.")
            return
        }
        refreshToken = UUID()
    }

    private func restart(carryingState: Bool) {
        do {
            guard try MobilityProgramRunCoordinator.restart(run, carryingState: carryingState, using: modelContext) != nil else {
                errorMessage = String(localized: "This plan could not be restarted. Try again.")
                return
            }
        } catch {
            errorMessage = String(localized: "This plan could not be restarted. Try again.")
        }
    }

    private func skip(_ progress: MobilityProgramSessionProgress) {
        guard MobilityProgramRunCoordinator.skip(progress, in: run, using: modelContext) else {
            errorMessage = String(localized: "This session could not be skipped. Try again.")
            return
        }
        refreshToken = UUID()
    }

    private func markMissed(_ progress: MobilityProgramSessionProgress) {
        guard MobilityProgramRunCoordinator.markMissed(progress, in: run, using: modelContext) else {
            errorMessage = String(localized: "This session could not be marked missed. Try again.")
            return
        }
        refreshToken = UUID()
    }

    private func saveReschedule(_ progress: MobilityProgramSessionProgress) {
        guard MobilityProgramRunCoordinator.reschedule(progress, to: rescheduleDate, in: run, using: modelContext) else {
            errorMessage = String(localized: "This session could not be rescheduled. Try again.")
            reschedulingProgress = nil
            return
        }
        reschedulingProgress = nil
        refreshToken = UUID()
    }

    private func requestApprovalReview(_ progress: MobilityProgramSessionProgress) {
        _ = MobilityProgressionRecommendationService.requestApprovalReview(for: progress, in: run, using: modelContext)
        refreshToken = UUID()
    }

    private func accept(_ record: MobilityProgressionRecommendationRecord) {
        guard MobilityProgressionRecommendationService.accept(record, in: run, using: modelContext) else {
            errorMessage = String(localized: "This recommendation could not be applied. Try again.")
            return
        }
        refreshToken = UUID()
    }

    private func decline(_ record: MobilityProgressionRecommendationRecord) {
        guard MobilityProgressionRecommendationService.decline(record, using: modelContext) else {
            errorMessage = String(localized: "This recommendation could not be declined. Try again.")
            return
        }
        refreshToken = UUID()
    }
}
