//
//  HistoryView.swift
//  GymTracker
//

import Foundation
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    let viewModel: WorkoutViewModel
    var onStartFreeWorkout: (() -> Void)? = nil
    @State private var selectedTab: HistoryTab

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
                        List {
                            ForEach(historySections) { section in
                                Section(section.title) {
                                    ForEach(section.workouts) { workout in
                                        NavigationLink(destination: HistoryWorkoutView(workout: workout)) {
                                            HistoryWorkoutRow(workout: workout)
                                        }
                                        .contentShape(Rectangle())
                                        .accessibilityIdentifier("history-workout-row")
                                        .listRowBackground(Color.gymCard)
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                viewModel.removeWorkout(using: modelContext, workout: workout)
                                            } label: {
                                                Label("Delete", systemImage: AppIcon.trash)
                                            }
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
    }

    private var completedWorkouts: [Workout] {
        workouts.filter { workout in
            workout.status == .completed && workout.orderedExercises.contains { exercise in
                exercise.orderedSets.contains(where: \.done)
            }
        }
    }

    private var historySections: [HistorySection] {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date.now
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        var today: [Workout] = []
        var thisWeek: [Workout] = []
        var months: [Date: [Workout]] = [:]

        for workout in completedWorkouts {
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
