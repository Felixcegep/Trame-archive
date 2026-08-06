//
//  ExerciseView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-03.
//

import Foundation
import SwiftUI
import SwiftData

struct ExerciseDetailSnapshot {
    let name: String
    let primaryMuscles: [Muscle]
    let secondaryMuscles: [Muscle]
    let category: ExerciseCategory
    let trackingType: TrackingType
    let equipmentType: EquipmentType
    let resistanceType: ResistanceType?
    let movementPattern: MovementPattern?
    let forceType: ForceType?
    let mechanics: ExerciseMechanics?
    let gripStyle: GripStyle?
    let stance: ExerciseStance?
    let rangeOfMotion: RangeOfMotion?
    let setupAngleDegrees: Int?
    let laterality: Laterality
    let difficulty: Difficulty
    let usesWeightPlates: Bool

    init(exercise: Exercise) {
        name = exercise.name
        primaryMuscles = exercise.primaryMuscles
        secondaryMuscles = exercise.secondaryMuscles ?? []
        category = exercise.displayCategory
        trackingType = exercise.trackingType
        equipmentType = exercise.equipmentType ?? .other
        resistanceType = exercise.resistanceType
        movementPattern = exercise.movementPattern
        forceType = exercise.forceType
        mechanics = exercise.mechanics
        gripStyle = exercise.gripStyle
        stance = exercise.stance
        rangeOfMotion = exercise.rangeOfMotion
        setupAngleDegrees = exercise.setupAngleDegrees
        laterality = exercise.laterality
        difficulty = exercise.displayDifficulty
        usesWeightPlates = exercise.supportsPlateCalculator
    }
}

struct ExerciseView : View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var availableExercises: [Exercise]

    private let editableExercise: Exercise?
    private let snapshot: ExerciseDetailSnapshot?
    @State private var isShowingEditor = false
    @State private var isShowingInsights = false
    @State private var isShowingRelationshipEditor = false
    @State private var quickStats: ExerciseQuickStats?
    @State private var deletionFeedbackReason: String?
    @State private var isShowingDeletionFeedback = false

    init(exercise: Exercise) {
        editableExercise = exercise
        snapshot = nil
    }

    init(exercise: ExerciseDetailSnapshot) {
        editableExercise = nil
        snapshot = exercise
    }

    private var exercise: ExerciseDetailSnapshot {
        if let editableExercise {
            return ExerciseDetailSnapshot(exercise: editableExercise)
        }
        return snapshot!
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                identityCard

                if editableExercise != nil {
                    performanceSection
                }

                musclesSection
                setupSection

                if !variations.isEmpty {
                    variationsSection
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.xxxl)
        }
        .background(Color.gymBackground.ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if editableExercise != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        toggleFavorite()
                    } label: {
                        Image(systemName: editableExercise?.isFavorite == true ? AppIcon.favoriteFilled : AppIcon.favorite)
                    }
                    .accessibilityLabel(editableExercise?.isFavorite == true ? "Remove from favorites" : "Add to favorites")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        isShowingEditor = true
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingRelationshipEditor = true
                    } label: {
                        Image(systemName: AppIcon.relationship)
                    }
                    .accessibilityLabel("Manage exercise relationships")
                    .accessibilityIdentifier("exercise-relationships")
                }

                if editableExercise?.isCustom == true {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            deleteExercise()
                        } label: {
                            Image(systemName: AppIcon.trash)
                                .foregroundStyle(Color.gymDestructive)
                        }
                        .accessibilityLabel("Delete exercise")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            if let editableExercise {
                NavigationStack {
                    ExerciseFormView(exercise: editableExercise) { _ in
                        saveModelContext(modelContext)
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingRelationshipEditor) {
            if let editableExercise {
                NavigationStack {
                    ExerciseRelationshipEditorView(exercise: editableExercise)
                }
            }
        }
        .navigationDestination(isPresented: $isShowingInsights) {
            if let editableExercise {
                ExerciseDetailInsightsDestination(exercise: editableExercise)
            }
        }
        .alert("Exercise Archived", isPresented: $isShowingDeletionFeedback) {
            Button("OK") {
                dismiss()
            }
        } message: {
            if let deletionFeedbackReason {
                Text(deletionFeedbackReason)
            }
        }
        .task(id: editableExercise?.persistentModelID) {
            await loadQuickStats()
        }
    }

    // MARK: - Identity

    private var identityCard: some View {
        GymCard {
            HStack(alignment: .top, spacing: Spacing.m) {
                GymIconChip(systemImage: categoryIcon, tint: categoryTint)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(exercise.name)
                        .font(AppFont.titleSmall)
                        .foregroundStyle(Color.gymText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(LocalizedStringKey(exercise.trackingType.rawValue))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }

                Spacer(minLength: 0)
            }

            ChipFlowLayout(spacing: Spacing.s) {
                GymTagChip(title: exercise.category.rawValue, tint: categoryTint)
                GymTagChip(
                    title: exercise.equipmentType.rawValue,
                    systemImage: AppIcon.workout,
                    tint: .gymAccent
                )
                GymTagChip(title: exercise.difficulty.rawValue, tint: .gymSecondary)
                if exercise.usesWeightPlates {
                    GymTagChip(
                        title: "Plate calculator",
                        systemImage: AppIcon.plateCalculator,
                        tint: .gymPrimary
                    )
                }
            }
        }
        .accessibilityIdentifier("exercise-identity")
    }

    // MARK: - Performance

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymSectionHeader(title: "Performance")

            Button {
                showExerciseStats()
            } label: {
                GymCard {
                    if let quickStats, quickStats.hasHistory {
                        quickStatsGrid(quickStats)
                        Divider()
                        performanceFooter(
                            title: "View full performance",
                            subtitle: "History, volume trend, records, notes, and progression"
                        )
                    } else if quickStats == nil {
                        HStack(spacing: Spacing.s) {
                            ProgressView()
                                .tint(Color.gymPrimary)
                            Text("Reading completed history…")
                                .font(AppFont.subheadline)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("No completed sets yet")
                                .font(AppFont.subheadlineSemibold)
                                .foregroundStyle(Color.gymText)
                            Text("Log this exercise in a workout to unlock records, estimated 1RM, and volume trend.")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Divider()
                        performanceFooter(
                            title: "View performance",
                            subtitle: "Opens the insights screen"
                        )
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("exercise-stats")
            .accessibilityHint("Opens full performance insights")
        }
    }

    private func quickStatsGrid(_ stats: ExerciseQuickStats) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Spacing.m, alignment: .topLeading),
                GridItem(.flexible(), spacing: Spacing.m, alignment: .topLeading)
            ],
            alignment: .leading,
            spacing: Spacing.m
        ) {
            ForEach(stats.metrics) { metric in
                QuickStatTile(metric: metric)
            }
        }
    }

    private func performanceFooter(title: String, subtitle: String) -> some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Label(title, systemImage: AppIcon.chart)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymPrimary)
                Text(subtitle)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: AppIcon.chevronRight)
                .font(AppFont.captionBold)
                .foregroundStyle(Color.gymSubduedText)
        }
    }

    // MARK: - Muscles

    private var musclesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymSectionHeader(title: "Muscles worked")

            GymCard {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    GymEyebrow("Primary")
                    if exercise.primaryMuscles.isEmpty {
                        Text("Not set")
                            .font(AppFont.subheadline)
                            .foregroundStyle(Color.gymSubduedText)
                    } else {
                        ChipFlowLayout(spacing: Spacing.s) {
                            ForEach(exercise.primaryMuscles, id: \.self) { muscle in
                                GymTagChip(title: muscle.displayName, tint: .gymPrimary)
                            }
                        }
                    }
                }

                if !exercise.secondaryMuscles.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        GymEyebrow("Supporting")
                        ChipFlowLayout(spacing: Spacing.s) {
                            ForEach(exercise.secondaryMuscles, id: \.self) { muscle in
                                GymTagChip(title: muscle.displayName, style: .outlined)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("exercise-muscles")
    }

    // MARK: - Setup

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymSectionHeader(title: "Setup")

            GymCard {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Spacing.m, alignment: .topLeading),
                        GridItem(.flexible(), spacing: Spacing.m, alignment: .topLeading)
                    ],
                    alignment: .leading,
                    spacing: Spacing.l
                ) {
                    ForEach(specifiedAttributes, id: \.label) { attribute in
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            GymEyebrow(LocalizedStringKey(attribute.label))
                            Text(LocalizedStringKey(attribute.value))
                                .font(AppFont.subheadlineSemibold)
                                .foregroundStyle(Color.gymText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }

                if !unspecifiedAttributes.isEmpty {
                    Divider()
                    Text("Not set: \(unspecifiedAttributes.joined(separator: " · "))")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("exercise-setup")
    }

    // MARK: - Variations

    private var variationsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymSectionHeader(
                title: "Variations",
                detail: "Related variants share a movement family. They are not automatic substitutions."
            )

            GymCard {
                ForEach(Array(variations.enumerated()), id: \.element.persistentModelID) { index, variation in
                    if index > 0 { Divider() }
                    NavigationLink {
                        ExerciseView(exercise: variation)
                    } label: {
                        HStack(spacing: Spacing.s) {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(variation.name)
                                    .font(AppFont.bodyMedium)
                                    .foregroundStyle(Color.gymText)
                                    .multilineTextAlignment(.leading)
                                Text(variationSubtitle(for: variation))
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: AppIcon.chevronRight)
                                .font(AppFont.captionBold)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("exercise-variation-\(variation.name)")
                }
            }
        }
    }

    // MARK: - Attributes

    private struct DetailAttribute {
        let label: String
        let value: String
    }

    private var attributes: [(label: String, value: String?)] {
        [
            ("Resistance", exercise.resistanceType?.rawValue),
            ("Movement", exercise.movementPattern?.rawValue),
            ("Mechanics", exercise.mechanics?.rawValue),
            ("Force", exercise.forceType?.rawValue),
            ("Laterality", exercise.laterality.rawValue),
            ("Grip", exercise.gripStyle?.rawValue),
            ("Stance", exercise.stance?.rawValue),
            ("Range of Motion", exercise.rangeOfMotion?.rawValue),
            ("Setup Angle", exercise.setupAngleDegrees.map { "\($0)°" }),
            ("Weight entry", weightEntryValue)
        ]
    }

    private var specifiedAttributes: [DetailAttribute] {
        attributes.compactMap { attribute in
            attribute.value.map { DetailAttribute(label: attribute.label, value: $0) }
        }
    }

    private var unspecifiedAttributes: [String] {
        attributes.filter { $0.value == nil }.map(\.label)
    }

    private var weightEntryValue: String? {
        guard exercise.trackingType.usesWeight else { return nil }
        return exercise.usesWeightPlates ? "Plate calculator" : "Direct weight entry"
    }

    private var categoryIcon: String {
        switch exercise.category {
        case .strength: AppIcon.workout
        case .cardio: AppIcon.progression
        case .mobility, .flexibility: AppIcon.mobility
        case .balance: AppIcon.effort
        case .sport, .other: AppIcon.muscles
        }
    }

    private var categoryTint: Color {
        switch exercise.category {
        case .strength: .gymPrimary
        case .cardio: .gymAccent
        case .mobility, .flexibility, .balance: .gymSecondary
        case .sport, .other: .gymPrimary
        }
    }

    // MARK: - Actions

    private func loadQuickStats() async {
        guard let editableExercise else { return }
        quickStats = (try? ExerciseQuickStatsBuilder.make(for: editableExercise, using: modelContext)) ?? .empty
    }

    private func toggleFavorite() {
        guard let editableExercise else { return }
        editableExercise.isFavorite.toggle()
        saveModelContext(modelContext)
    }

    private func showExerciseStats() {
        guard editableExercise != nil else { return }
        isShowingInsights = true
    }

    private func deleteExercise() {
        guard let editableExercise else { return }
        do {
            let outcome = try ExerciseArchiveService.hideOrDeleteResult(editableExercise, using: modelContext)
            switch outcome {
            case .deleted:
                dismiss()
            case .archived(let reason):
                deletionFeedbackReason = reason
                isShowingDeletionFeedback = true
            }
        } catch {
            print("Failed to delete exercise: \(error)")
        }
    }

    private var variations: [Exercise] {
        guard let editableExercise,
              let familyID = editableExercise.variationFamilyID,
              !familyID.isEmpty else {
            return []
        }

        return availableExercises
            .filter { $0.persistentModelID != editableExercise.persistentModelID && $0.variationFamilyID == familyID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func variationSubtitle(for exercise: Exercise) -> String {
        [
            exercise.equipmentType?.rawValue,
            exercise.gripStyle?.rawValue,
            exercise.stance?.rawValue,
            exercise.setupAngleDegrees.map { "\($0)°" }
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

/// Compact metric tile: a colored rail, the value, what it measures, and the
/// comparison line. Direction is carried by an arrow glyph and wording, never
/// by color alone.
private struct QuickStatTile: View {
    let metric: ExerciseQuickStats.Metric

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Capsule()
                .fill(tint)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(metric.value)
                    .font(AppFont.subheadlineSemiboldMonospaced)
                    .foregroundStyle(Color.gymText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(LocalizedStringKey(metric.label))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)

                if let detail = metric.detail {
                    HStack(spacing: Spacing.xxs) {
                        if let directionIcon {
                            Image(systemName: directionIcon)
                                .font(AppFont.captionBold)
                        }
                        Text(detail)
                            .font(AppFont.caption)
                    }
                    .foregroundStyle(directionTint)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch metric.accent {
        case .primary: .gymPrimary
        case .secondary: .gymSecondary
        case .accent: .gymAccent
        case .neutral: .gymSubduedText
        }
    }

    private var directionIcon: String? {
        switch metric.direction {
        case .up: AppIcon.trendUp
        case .down: AppIcon.trendDown
        case .flat: nil
        }
    }

    private var directionTint: Color {
        switch metric.direction {
        case .up: .gymSecondary
        case .down: .gymAccent
        case .flat: .gymSubduedText
        }
    }
}
