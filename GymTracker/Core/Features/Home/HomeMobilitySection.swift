import SwiftData
import SwiftUI

struct HomeMobilitySection: View {
    let activeWorkout: Workout?
    let onStartMobility: (MobilityRoutine, MobilitySessionContext, UUID?) -> Void
    let onResumeMobility: (MobilitySession) -> Void
    let onOpenTrainMobility: () -> Void

    @Query(sort: \MobilityRoutine.updatedAt, order: .reverse) private var mobilityRoutines: [MobilityRoutine]
    @Query(sort: \MobilitySession.updatedAt, order: .reverse) private var mobilitySessions: [MobilitySession]

    private var activeMobilitySession: MobilitySession? {
        mobilitySessions.first { $0.status == .active }
    }

    private var availableMobilityRoutine: MobilityRoutine? {
        mobilityRoutines.first { $0.isArchived == false && $0.items.isEmpty == false }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("MOBILITY")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)

            mobilityAction

            Button("Manage mobility routines", action: onOpenTrainMobility)
                .font(AppFont.captionBold)
                .accessibilityIdentifier("manage-mobility-routines")
        }
    }

    @ViewBuilder
    private var mobilityAction: some View {
        if let activeMobilitySession {
            Button {
                onResumeMobility(activeMobilitySession)
            } label: {
                HomeDailyContextRow(
                    icon: AppIcon.mobility,
                    iconColor: Color.gymAccent,
                    title: "Resume mobility",
                    detail: "\(activeMobilitySession.nameSnapshot) · Movement \(min(activeMobilitySession.currentEntryIndex + 1, activeMobilitySession.entries.count)) of \(activeMobilitySession.entries.count)",
                    completion: false
                )
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("resume-mobility-session")
        } else if let routine = availableMobilityRoutine {
            Button {
                let context: MobilitySessionContext = activeWorkout == nil ? .standalone : .warmup
                onStartMobility(routine, context, activeWorkout?.id)
            } label: {
                HomeDailyContextRow(
                    icon: AppIcon.mobility,
                    iconColor: Color.gymAccent,
                    title: activeWorkout == nil ? "Start mobility" : "Start mobility warm-up",
                    detail: "\(routine.name) · \(routine.items.count) movement\(routine.items.count == 1 ? "" : "s")",
                    completion: false
                )
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("start-mobility-routine")
        } else {
            Button(action: onOpenTrainMobility) {
                HomeDailyContextRow(
                    icon: AppIcon.mobility,
                    iconColor: Color.gymAccent,
                    title: "Create a mobility routine",
                    detail: "Build a short warm-up or recovery sequence",
                    completion: false
                )
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("create-mobility-routine-from-today")
        }
    }
}
