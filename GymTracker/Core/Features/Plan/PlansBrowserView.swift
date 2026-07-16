import SwiftData
import SwiftUI

struct PlansBrowserView: View {
    @Query private var plans: [WorkoutPlan]

    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void
    let onCreateProgram: () -> Void

    var body: some View {
        List {
            if activePlans.isEmpty && archivedPlans.isEmpty {
                ContentUnavailableView {
                    Label("No programs yet", systemImage: AppIcon.planAdd)
                } description: {
                    Text("Build a multi-week program from your saved workouts.")
                } actions: {
                    Button("Create program", action: onCreateProgram)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.gymPrimary)
                        .accessibilityIdentifier("create-program-empty-state")
                }
            } else {
                Section("Programs") {
                    ForEach(activePlans) { plan in
                        NavigationLink {
                            PlanDetailView(plan: plan, onStartPlannedWorkout: onStartPlannedWorkout)
                        } label: {
                            planRow(plan)
                        }
                        .accessibilityIdentifier("plan-row-\(plan.name)")
                    }
                }

                if !archivedPlans.isEmpty {
                    Section("Archived") {
                        ForEach(archivedPlans) { plan in
                            NavigationLink {
                                PlanDetailView(plan: plan, onStartPlannedWorkout: onStartPlannedWorkout)
                            } label: {
                                planRow(plan)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Programs")
    }

    private var activePlans: [WorkoutPlan] {
        plans.filter { !$0.isArchived }.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var archivedPlans: [WorkoutPlan] {
        plans.filter(\.isArchived).sorted { $0.updatedAt > $1.updatedAt }
    }

    private func planRow(_ plan: WorkoutPlan) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: AppIcon.plan)
                .foregroundStyle(Color.gymAccent)
                .frame(width: 32, height: 32)
                .background(Color.gymAccentSurface, in: Circle())
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(plan.name)
                    .font(AppFont.subheadlineSemibold)
                Text("\(plan.durationWeeks) weeks · \(plan.daysPerWeek) days per week")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
