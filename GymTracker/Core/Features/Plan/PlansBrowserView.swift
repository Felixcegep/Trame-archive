import SwiftData
import SwiftUI

struct PlansBrowserView: View {
    @Query private var plans: [WorkoutPlan]

    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void
    let onStartPlan: (WorkoutPlan, Date) -> Void
    let onResumePlan: (PlanRun) -> Void
    let onStartTestDay: (PlanRun) -> Void
    let onCreateProgram: () -> Void

    var body: some View {
        List {
            if activePlans.isEmpty && archivedPlans.isEmpty {
                ContentUnavailableView {
                    Label("No training plans yet", systemImage: AppIcon.planAdd)
                } description: {
                    Text("A training plan schedules your saved workouts across the week so you always know what to train next.")
                } actions: {
                    Button("Create a plan", action: onCreateProgram)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.gymPrimary)
                        .accessibilityIdentifier("create-program-empty-state")
                }
            } else {
                Section("Active") {
                    ForEach(activePlans) { plan in
                        NavigationLink {
                            PlanDetailView(
                                plan: plan,
                                onStartPlannedWorkout: onStartPlannedWorkout,
                                onStartPlan: onStartPlan,
                                onResumePlan: onResumePlan,
                                onStartTestDay: onStartTestDay
                            )
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
                                PlanDetailView(
                                    plan: plan,
                                    onStartPlannedWorkout: onStartPlannedWorkout,
                                    onStartPlan: onStartPlan,
                                    onResumePlan: onResumePlan,
                                    onStartTestDay: onStartTestDay
                                )
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
        .navigationTitle("My Plans")
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
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
    }
}
