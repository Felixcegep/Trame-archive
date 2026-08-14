//
//  HistoryView.swift
//  GymTracker
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(
        filter: #Predicate<Workout> { $0.endTime != nil },
        sort: \Workout.startTime,
        order: .reverse
    ) private var workouts: [Workout]
    let viewModel: WorkoutViewModel
    var onStartFreeWorkout: (() -> Void)? = nil
    @State private var selectedTab: HistoryTab
    /// A workout the lifter has deleted but can still recover. It is withheld
    /// from every tab for the length of the undo window and only reaches
    /// `modelContext.delete` once that window closes, so "Undo" restores the
    /// row rather than rebuilding a destroyed object graph.
    @State private var pendingDeletion: PendingWorkoutDeletion?
    @State private var deletionTask: Task<Void, Never>?
    /// Increments once per committed deletion. Used only as a feedback trigger
    /// so the haptic fires on the irreversible step, never on the swipe.
    @State private var committedDeletionCount = 0

    init(
        viewModel: WorkoutViewModel,
        onStartFreeWorkout: (() -> Void)? = nil,
        initialTab: HistoryTab = .workouts
    ) {
        self.viewModel = viewModel
        self.onStartFreeWorkout = onStartFreeWorkout
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        // Evaluate the SwiftData graph once for this render. The same completed
        // snapshot is then shared by the empty state, list, and analytics tabs
        // so a deletion or completed-set update cannot make one branch render
        // against a different in-memory filter result.
        let completedWorkouts = self.completedWorkouts

        Group {
            if completedWorkouts.isEmpty {
                ContentUnavailableView {
                    Label("No Workout History", systemImage: AppIcon.history)
                } description: {
                    Text("Complete a workout to review performance, records, and progression here.")
                } actions: {
                    if let onStartFreeWorkout {
                        Button("Start a workout", action: onStartFreeWorkout)
                            .buttonStyle(.borderedProminent)
                            .tint(Color.gymPrimary)
                            .accessibilityIdentifier("history-start-workout")
                    }
                }
            } else {
                VStack(spacing: 0) {
                    Picker("History view", selection: $selectedTab) {
                        ForEach(HistoryTab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.m)

                    switch selectedTab {
                    case .workouts:
                        let sections = historySections(for: completedWorkouts)
                        List {
                            ForEach(sections) { section in
                                Section(section.title) {
                                    ForEach(section.workouts) { workout in
                                        NavigationLink(destination: HistoryWorkoutView(workout: workout)) {
                                            HistoryWorkoutRow(workout: workout)
                                        }
                                        .contentShape(Rectangle())
                                        .accessibilityIdentifier("history-workout-row")
                                        .listRowBackground(Color.gymCard)
                                        .listRowSeparator(.hidden)
                                        // Full swipe is deliberately disabled: a
                                        // drifting one-handed scroll must never be
                                        // able to destroy a completed session
                                        // without a deliberate second tap.
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                beginDeletion(of: workout)
                                            } label: {
                                                Label("Delete", systemImage: AppIcon.trash)
                                            }
                                            .accessibilityIdentifier("history-delete-workout")
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                    case .progress:
                        HistoryProgressView(workouts: completedWorkouts)
                    case .records:
                        HistoryRecordsView(workouts: completedWorkouts)
                    case .balance:
                        HistoryMuscleBalanceDestination()
                    }
                }
            }
        }
        .background(Color.gymBackground)
        .accessibilityIdentifier("history-screen")
        .navigationTitle("History")
        .overlay(alignment: .bottom) {
            if let pendingDeletion {
                undoBanner(for: pendingDeletion)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .move(edge: .bottom).combined(with: .opacity)
                    )
            }
        }
        .gymFeedback(.destructiveCommitted, trigger: committedDeletionCount)
        .onDisappear {
            // Leaving the screen honours the delete the lifter already asked
            // for. The alternative — cancelling on disappear — would leave a
            // row they watched animate away still present when they return.
            commitPendingDeletion()
        }
    }

    /// Deleted-but-recoverable workouts are withheld here rather than only in
    /// the list, so the Progress, Records, and Volume tabs never keep counting
    /// a session the lifter has just removed.
    private var completedWorkouts: [Workout] {
        workouts.filter { workout in
            workout.persistentModelID != pendingDeletion?.id
                && workout.status == .completed
                && workout.orderedExercises.contains { exercise in
                    exercise.orderedSets.contains(where: \.done)
                }
        }
    }

    // MARK: - Deletion with undo

    private struct PendingWorkoutDeletion {
        let id: PersistentIdentifier
        let workout: Workout
        let title: String
    }

    /// Longer while VoiceOver is running: the banner has to be found in the
    /// rotor and read before it can be acted on.
    private var undoWindowSeconds: TimeInterval {
        UIAccessibility.isVoiceOverRunning ? 16 : 8
    }

    private func undoBanner(for pending: PendingWorkoutDeletion) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: AppIcon.trash)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymSubduedText)
                .accessibilityHidden(true)

            Text("Deleted \(pending.title)")
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymText)
                .lineLimit(2)

            Spacer(minLength: Spacing.s)

            Button("Undo") {
                undoPendingDeletion()
            }
            .font(AppFont.subheadlineSemibold)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .accessibilityIdentifier("history-undo-delete")
            .accessibilityHint("Restores the deleted workout and all of its sets.")
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.section, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.section, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
        .shadow(color: Color.gymText.opacity(0.08), radius: 8, y: 2)
        .padding(.horizontal, Spacing.l)
        .padding(.bottom, Spacing.m)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history-undo-banner")
    }

    private func beginDeletion(of workout: Workout) {
        // A second delete during an open window commits the first rather than
        // silently dropping it: only one workout is ever recoverable at a time.
        commitPendingDeletion()

        let pending = PendingWorkoutDeletion(
            id: workout.persistentModelID,
            workout: workout,
            title: workout.displayTitle
        )
        withAnimation(reduceMotion ? nil : AppMotion.compact) {
            pendingDeletion = pending
        }
        UIAccessibility.post(
            notification: .announcement,
            argument: String(localized: "Deleted \(pending.title). Undo is available.")
        )

        deletionTask = Task {
            try? await Task.sleep(for: .seconds(undoWindowSeconds))
            guard !Task.isCancelled else { return }
            await MainActor.run { commitPendingDeletion() }
        }
    }

    private func undoPendingDeletion() {
        guard pendingDeletion != nil else { return }
        deletionTask?.cancel()
        deletionTask = nil
        withAnimation(reduceMotion ? nil : AppMotion.compact) {
            pendingDeletion = nil
        }
        UIAccessibility.post(
            notification: .announcement,
            argument: String(localized: "Deletion undone.")
        )
    }

    private func commitPendingDeletion() {
        guard let pending = pendingDeletion else { return }
        deletionTask?.cancel()
        deletionTask = nil
        pendingDeletion = nil
        viewModel.removeWorkout(using: modelContext, workout: pending.workout)
        committedDeletionCount += 1
    }

    private func historySections(for workouts: [Workout]) -> [HistorySection] {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date.now
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        var today: [Workout] = []
        var thisWeek: [Workout] = []
        var months: [Date: [Workout]] = [:]

        for workout in workouts {
            if calendar.isDateInToday(workout.startTime) {
                today.append(workout)
            } else if weekInterval?.contains(workout.startTime) == true {
                thisWeek.append(workout)
            } else if let monthStart = calendar.dateInterval(of: .month, for: workout.startTime)?.start {
                months[monthStart, default: []].append(workout)
            }
        }

        var sections: [HistorySection] = []
        if !today.isEmpty {
            sections.append(HistorySection(id: "today", title: "Today", workouts: today))
        }
        if !thisWeek.isEmpty {
            sections.append(HistorySection(id: "this-week", title: "This Week", workouts: thisWeek))
        }
        sections.append(contentsOf: months.keys.sorted(by: >).map { monthStart in
            HistorySection(
                id: "month-\(monthStart.timeIntervalSinceReferenceDate)",
                title: monthStart.formatted(.dateTime.month(.wide).year()),
                workouts: months[monthStart] ?? []
            )
        })
        return sections
    }
}

enum HistoryTab: String, CaseIterable, Identifiable {
    case workouts
    case progress
    case records
    case balance

    var id: Self { self }

    var title: String {
        switch self {
        case .workouts: "Workouts"
        case .progress: "Progress"
        case .records: "Records"
        case .balance: "Volume"
        }
    }
}

struct HistorySection: Identifiable {
    let id: String
    let title: String
    let workouts: [Workout]
}
