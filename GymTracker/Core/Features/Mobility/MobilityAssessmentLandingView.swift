import SwiftData
import SwiftUI

/// Entry point for the mobility assessment.
///
/// The screen answers one question — *what have I observed, and how do I record
/// another observation the same way?* — so it has exactly one primary action in
/// every state. Primary actions live in the content rather than the toolbar:
/// this screen is pushed inside the Train browser, where a pushed-toolbar button
/// does not reliably fire on iOS 26.
struct MobilityAssessmentLandingView: View {
    @Environment(\.modelContext) private var modelContext
    /// Presentation is root-owned. This screen only asks for a session to be
    /// presented; the root presents it, dismisses it, and cleans up after it.
    let onStart: (MobilityAssessmentSession) -> Void

    @Query(sort: \MobilityAssessmentSession.startedAt, order: .reverse)
    private var sessions: [MobilityAssessmentSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                heroCard
                whatItRecordsCard
                historyLink
                MobilityAssessmentScopeNote()
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .background(Color.gymBackground)
        .navigationTitle("Assessment")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    /// Three states, one card. An assessment in progress outranks history,
    /// because resuming it is the only action that can lose work if missed.
    @ViewBuilder
    private var heroCard: some View {
        if let activeSession {
            GymCard(variant: .current) {
                GymEyebrow("In progress", tint: .gymPrimary)
                Text("Assessment in progress")
                    .font(AppFont.titleSmall)
                    .foregroundStyle(Color.gymText)
                Text(progressDetail(for: activeSession))
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Continue assessment") { onStart(activeSession) }
                    .buttonStyle(.gymPrimary)
                    .accessibilityIdentifier("resume-mobility-assessment")
            }
        } else if let lastRecordedSession {
            GymCard {
                GymEyebrow("Last assessment")
                Text(dateText(for: lastRecordedSession))
                    .font(AppFont.titleSmall)
                    .foregroundStyle(Color.gymText)
                Text(observationCountText(for: lastRecordedSession))
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)

                startLink(title: String(localized: "Record a new assessment"))
            }
        } else {
            GymCard {
                GymEyebrow("Mobility assessment")
                Text("Record your first observations")
                    .font(AppFont.titleSmall)
                    .foregroundStyle(Color.gymText)
                Text("Work through the assessments you choose and enter what you observe. Nothing is recorded until you save it.")
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)

                startLink(title: String(localized: "Choose assessments"))
            }
        }
    }

    private func startLink(title: String) -> some View {
        NavigationLink {
            MobilityAssessmentSelectionView(onStart: onStart)
        } label: {
            Text(title)
        }
        .buttonStyle(.gymPrimary)
        .accessibilityIdentifier("start-mobility-assessment")
    }

    // MARK: - Supporting content

    private var whatItRecordsCard: some View {
        GymCard {
            GymSectionHeader(title: String(localized: "What an assessment records"))

            // Each line is a property of the record, not a benefit claim. The
            // conditions line is the load-bearing one: without it a later
            // observation cannot be compared to this one at all.
            MobilityAssessmentBulletRow(
                systemImage: AppIcon.number,
                text: String(localized: "The value you observed, in its own unit, kept exactly as you entered it.")
            )
            MobilityAssessmentBulletRow(
                systemImage: AppIcon.relationship,
                text: String(localized: "Left and right stay separate observations and are never averaged together.")
            )
            MobilityAssessmentBulletRow(
                systemImage: AppIcon.info,
                text: String(localized: "The conditions you recorded under: setup, active or passive range, and before or after training.")
            )
            MobilityAssessmentBulletRow(
                systemImage: AppIcon.history,
                text: String(localized: "A difference from an earlier observation appears only when every condition matches.")
            )
            MobilityAssessmentBulletRow(
                systemImage: AppIcon.edit,
                text: String(localized: "In this version you enter every value yourself, and each observation is labelled that way.")
            )
        }
    }

    private var historyLink: some View {
        NavigationLink {
            MobilityAssessmentHistoryView()
        } label: {
            HStack(spacing: Spacing.m) {
                GymIconChip(systemImage: AppIcon.history)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Assessment history")
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.gymText)
                    Text(historyDetail)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
                Spacer(minLength: Spacing.s)
                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubtleText)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .padding(Spacing.l)
            .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.gymBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("open-mobility-assessment-history")
    }

    // MARK: - Derived state

    private var activeSession: MobilityAssessmentSession? {
        sessions.first { $0.status == .active }
    }

    /// The most recent finished session that actually holds observations. A
    /// session stopped before anything was saved is history, not a measurement.
    private var lastRecordedSession: MobilityAssessmentSession? {
        sessions.first { $0.status != .active && $0.results.isEmpty == false }
    }

    private var historyDetail: String {
        let recorded = sessions.filter { $0.results.isEmpty == false }.count
        guard recorded > 0 else {
            return String(localized: "No assessments recorded yet")
        }
        return String(
            localized: "mobility.assessment.history.count",
            defaultValue: "^[\(recorded) assessment](inflect: true) recorded"
        )
    }

    private func dateText(for session: MobilityAssessmentSession) -> String {
        session.startedAt.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private func observationCountText(for session: MobilityAssessmentSession) -> String {
        String(
            localized: "mobility.assessment.observation.count",
            defaultValue: "^[\(session.results.count) observation](inflect: true)"
        )
    }

    private func progressDetail(for session: MobilityAssessmentSession) -> String {
        String(
            localized: "mobility.assessment.progress.detail",
            defaultValue: "Started \(dateText(for: session)) · \(observationCountText(for: session)) saved so far"
        )
    }
}

/// A short factual line inside a card. Icon plus text, never the glyph alone.
struct MobilityAssessmentBulletRow: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: systemImage)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .frame(width: Spacing.xl, alignment: .center)
                .accessibilityHidden(true)
            Text(text)
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Choosing what to record. Everything is selected by default because the
/// catalogue is short and a partial assessment is a deliberate choice, not the
/// starting point.
struct MobilityAssessmentSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    let onStart: (MobilityAssessmentSession) -> Void

    @State private var catalogue: [MobilityAssessmentDefinition] = []
    @State private var selectedKeys: Set<String> = []
    @State private var hasLoaded = false
    @State private var error: String?

    var body: some View {
        List {
            ForEach(zones, id: \.self) { zone in
                Section {
                    ForEach(definitions(in: zone), id: \.catalogueKey) { definition in
                        selectionRow(definition)
                    }
                } header: {
                    Text(zone.displayName)
                        .accessibilityIdentifier("mobility-assessment-zone-\(zone.rawValue)")
                }
            }

            if hasLoaded, catalogue.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No assessments available",
                        systemImage: AppIcon.mobilityAssessment,
                        description: Text("The assessment catalogue could not be loaded.")
                    )
                }
            }

            Section {
                Button("Start assessment", action: start)
                    .buttonStyle(.gymPrimary)
                    .disabled(selectedKeys.isEmpty)
                    .accessibilityIdentifier("begin-mobility-assessment")
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } footer: {
                Text(selectionFooter)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Choose assessments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(areAllSelected ? "Clear all" : "Select all") {
                    if areAllSelected {
                        selectedKeys.removeAll()
                    } else {
                        selectedKeys = Set(catalogue.map(\.catalogueKey))
                    }
                }
                .accessibilityIdentifier("toggle-all-mobility-assessments")
            }
        }
        .task { load() }
        .alert(
            "Couldn’t start the assessment",
            isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
        ) {
            Button("OK", role: .cancel) { error = nil }
        } message: {
            Text(error ?? MobilityAssessmentErrorCopy.generic)
        }
    }

    private func selectionRow(_ definition: MobilityAssessmentDefinition) -> some View {
        let key = definition.catalogueKey
        let isSelected = selectedKeys.contains(key)
        return Button {
            if isSelected {
                selectedKeys.remove(key)
            } else {
                selectedKeys.insert(key)
            }
        } label: {
            HStack(spacing: Spacing.m) {
                // Selection carries a checkmark and a filled/empty circle, so it
                // survives greyscale and VoiceOver alike.
                Image(systemName: isSelected ? AppIcon.checkmarkCircle : AppIcon.circle)
                    .font(AppFont.subheadline)
                    .foregroundStyle(isSelected ? Color.gymPrimary : Color.gymSubtleText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(MobilityAssessmentCopy.name(for: definition))
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.gymText)
                    Text(sidesDetail(definition))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("mobility-assessment-select-\(key)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func sidesDetail(_ definition: MobilityAssessmentDefinition) -> String {
        let sides = definition.supportedSides.map(\.displayName).formatted(.list(type: .and))
        return String(
            localized: "mobility.assessment.selection.detail",
            defaultValue: "\(sides) · \(definition.manualMode.displayName)"
        )
    }

    private var selectionFooter: String {
        guard selectedKeys.isEmpty == false else {
            return String(localized: "Choose at least one assessment to record.")
        }
        return String(
            localized: "mobility.assessment.selection.footer",
            defaultValue: "^[\(selectedKeys.count) assessment](inflect: true) selected. You can skip any of them while recording, and stop at any point without losing what you saved."
        )
    }

    private var zones: [MobilityAssessmentZone] {
        MobilityAssessmentZone.displayOrder.filter { definitions(in: $0).isEmpty == false }
    }

    private func definitions(in zone: MobilityAssessmentZone) -> [MobilityAssessmentDefinition] {
        catalogue.filter { $0.zone == zone }
    }

    private var areAllSelected: Bool {
        catalogue.isEmpty == false && selectedKeys.count == catalogue.count
    }

    /// The catalogue is system-seeded and stable for the life of the screen, so
    /// it is read once through the service that owns its ordering rather than
    /// re-sorted here.
    private func load() {
        catalogue = (try? MobilityAssessmentCatalogService.definitions(using: modelContext)) ?? []
        if hasLoaded == false {
            selectedKeys = Set(catalogue.map(\.catalogueKey))
            hasLoaded = true
        } else {
            selectedKeys = selectedKeys.intersection(catalogue.map(\.catalogueKey))
        }
    }

    private func start() {
        // Catalogue order, not tap order: the session's step sequence is the
        // authored one.
        let chosen = catalogue.filter { selectedKeys.contains($0.catalogueKey) }
        do {
            let session = try MobilityAssessmentSessionService.start(
                definitions: chosen,
                using: modelContext
            )
            onStart(session)
        } catch {
            self.error = MobilityAssessmentErrorCopy.message(for: error)
        }
    }
}
