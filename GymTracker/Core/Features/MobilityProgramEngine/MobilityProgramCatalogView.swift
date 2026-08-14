import SwiftData
import SwiftUI

/// Browse ready-made and followed mobility plans, mirroring `PlansBrowserView
/// `/`ProgramCatalogView`'s structural idiom for the workout side. User-facing
/// copy says "plan"; the underlying types stay `MobilityProgram*`.
struct MobilityProgramCatalogView: View {
    /// Bubbles a freshly started session up to the app root, which owns the
    /// single centralized `activeMobilitySession` presentation — mirroring
    /// exactly how `MobilityLibraryView.onStart` already works. This screen
    /// never presents its own mobility session UI.
    let onStartProgramSession: (MobilitySession) -> Void

    @Query(
        filter: #Predicate<MobilityProgramDefinitionRecord> { !$0.isArchived },
        sort: \MobilityProgramDefinitionRecord.updatedAt,
        order: .reverse
    ) private var definitions: [MobilityProgramDefinitionRecord]
    @Query private var runs: [MobilityProgramRun]

    private struct CatalogueSections {
        let followedRuns: [MobilityProgramRun]
        let pastRuns: [MobilityProgramRun]
        let readyMadeDefinitions: [MobilityProgramDefinitionRecord]
    }

    var body: some View {
        let sections = makeCatalogueSections()

        List {
            if !sections.followedRuns.isEmpty {
                Section("Following") {
                    ForEach(sections.followedRuns) { run in
                        NavigationLink {
                            MobilityProgramRunView(run: run, onStartProgramSession: onStartProgramSession)
                        } label: {
                            runRow(run)
                        }
                        .accessibilityIdentifier("mobility-program-run-\(run.id)")
                    }
                }
            }

            Section {
                if sections.readyMadeDefinitions.isEmpty {
                    ContentUnavailableView(
                        "No mobility plans available",
                        systemImage: AppIcon.mobility,
                        description: Text("Ready-made mobility plans will appear here once they’re available.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(sections.readyMadeDefinitions) { record in
                        NavigationLink {
                            MobilityProgramDetailView(record: record)
                        } label: {
                            definitionRow(record)
                        }
                        .accessibilityIdentifier("mobility-program-catalog-\(record.name)")
                    }
                }
            } header: {
                Text("Ready-made")
            }

            if !sections.pastRuns.isEmpty {
                Section("History") {
                    ForEach(sections.pastRuns) { run in
                        NavigationLink {
                            MobilityProgramRunView(run: run, onStartProgramSession: onStartProgramSession)
                        } label: {
                            runRow(run)
                        }
                        .accessibilityIdentifier("mobility-program-run-\(run.id)")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Mobility Plans")
        .accessibilityIdentifier("mobility-program-catalog")
    }

    /// Partitions the run query once, then orders each mutually exclusive
    /// section once for this render. The previous computed properties were
    /// each evaluated for both `isEmpty` and `ForEach`.
    private func makeCatalogueSections() -> CatalogueSections {
        var followedRuns: [MobilityProgramRun] = []
        var pastRuns: [MobilityProgramRun] = []
        followedRuns.reserveCapacity(runs.count)
        pastRuns.reserveCapacity(runs.count)

        for run in runs {
            switch run.status {
            case .active, .paused:
                followedRuns.append(run)
            case .completed, .archived:
                pastRuns.append(run)
            }
        }

        followedRuns.sort { $0.updatedAt > $1.updatedAt }
        pastRuns.sort { $0.updatedAt > $1.updatedAt }
        let readyMadeDefinitions = definitions.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        return CatalogueSections(
            followedRuns: followedRuns,
            pastRuns: pastRuns,
            readyMadeDefinitions: readyMadeDefinitions
        )
    }

    private func runRow(_ run: MobilityProgramRun) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: AppIcon.mobility)
                .foregroundStyle(Color.gymAccent)
                .frame(width: 32, height: 32)
                .background(Color.gymAccentSurface, in: Circle())
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(run.sourceProgramName)
                    .font(AppFont.subheadlineSemibold)
                Text(runDetail(run))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
            Spacer(minLength: Spacing.s)
            Text(runStatusBadge(run))
                .font(AppFont.caption2Bold)
                .foregroundStyle(Color.gymSubduedText)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xxs)
                .background(Color.gymRowSurface, in: Capsule())
        }
    }

    private func runDetail(_ run: MobilityProgramRun) -> String {
        var completed = 0
        for progress in run.sessionProgress where progress.status == .completed {
            completed += 1
        }
        let total = run.sessionProgress.count
        return String(localized: "\(completed) of \(total) sessions")
    }

    private func runStatusBadge(_ run: MobilityProgramRun) -> String {
        switch run.status {
        case .active: String(localized: "Following")
        case .paused: String(localized: "Paused")
        case .completed: String(localized: "Completed")
        case .archived: String(localized: "Archived")
        }
    }

    private func definitionRow(_ record: MobilityProgramDefinitionRecord) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: AppIcon.mobility)
                .foregroundStyle(Color.gymAccent)
                .frame(width: 32, height: 32)
                .background(Color.gymAccentSurface, in: Circle())
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(record.name)
                    .font(AppFont.subheadlineSemibold)
                Text("\(record.durationWeeks) weeks · \(record.supportedDaysPerWeek.map(String.init).joined(separator: "/")) days per week")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
            Spacer(minLength: Spacing.s)
        }
    }
}
