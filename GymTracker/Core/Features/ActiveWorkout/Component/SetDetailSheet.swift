//
//  SetDetailSheet.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-12.
//

import SwiftUI
import SwiftData

/// Plain-language meaning of each RPE value, shown alongside the slider so
/// lifters don't need to memorize the scale.
enum RPEScale {
    static func meaning(for value: Double) -> String {
        switch value {
        case 10.0: return String(localized: "Max effort — nothing left")
        case 9.5: return String(localized: "No reps left — could maybe load slightly more")
        case 9.0: return String(localized: "Could do 1 more rep")
        case 8.5: return String(localized: "Definitely 1, maybe 2 more reps")
        case 8.0: return String(localized: "Could do 2 more reps")
        case 7.5: return String(localized: "Definitely 2, maybe 3 more reps")
        case 7.0: return String(localized: "Could do 3 more reps")
        case 6.5: return String(localized: "Definitely 3, maybe 4 more reps")
        case 6.0: return String(localized: "Could do 4 more reps")
        case 5.5: return String(localized: "Could do 4–5 more reps")
        case 5.0: return String(localized: "Could do 5+ more reps")
        default:
            if value >= 10.0 {
                return String(localized: "Max effort — nothing left")
            } else if value <= 5.0 {
                return String(localized: "Very light — warm-up effort")
            } else {
                return String(localized: "RPE \(Formatters.formatFloat(Float(value)))")
            }
        }
    }
}

enum RIRScale {
    static func meaning(for value: Int) -> String {
        switch value {
        case 0: String(localized: "No reps left")
        case 1: String(localized: "One rep left")
        case 2: String(localized: "Two reps left")
        default: String(localized: "At least \(value) reps left")
        }
    }
}

extension SetType {
    var icon: String {
        switch self {
        case .normal: AppIcon.circle
        case .warmup: AppIcon.warmup
        case .dropSet: "arrow.down.right"
        case .failure: "bolt.fill"
        case .backoff: "arrow.uturn.down"
        case .topSet: "arrow.up"
        case .amrap: "infinity"
        case .technique: "figure.strengthtraining.traditional"
        case .dailyMaximum: "crown"
        case .test: "checkmark.seal"
        case .recovery: "heart"
        }
    }

    /// Accent used for the row chip and selection state; nil means the
    /// neutral text color (normal sets).
    var accentColor: Color? {
        switch self {
        case .normal: nil
        case .warmup: Color.gymAccent
        case .dropSet: Color.gymPrimary
        case .failure: Color.gymDestructive
        case .backoff: Color.gymSecondary
        case .topSet: Color.gymPrimary
        case .amrap: Color.gymAccent
        case .technique: Color.gymSecondary
        case .dailyMaximum: Color.gymPrimary
        case .test: Color.gymAccent
        case .recovery: Color.gymSecondary
        }
    }
}

struct SetDetailSheet: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(DefaultsKey.effortMeasure) private var effortMeasure: EffortMeasure = .rir
    @AppStorage(DefaultsKey.recentSetTypes) private var recentSetTypesRaw: String = ""
    @State private var isShowingMoreSetTypes = false
    let index: Int
    @Bindable var exerciseSet: ExerciseSet
    let exerciseName: String
    let onPersist: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingEffortMeasure: EffortMeasure?
    @State private var isShowingEffortSwitchConfirmation = false
    @State private var isShowingAdvancedOptions = false
    @State private var isRecordingVelocity = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header
                setTypeSection
                effortSection
                advancedOptionsSection
                deleteButton
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.l)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymBackground)
        .overlay(alignment: .topLeading) {
            screenshotStateMarker("set-details-screen", label: "Set details open")
        }
        .onAppear {
            isRecordingVelocity = hasVelocityDataOrPrescription
            isShowingAdvancedOptions = hasRecordedOrPrescribedAdvancedData
            // A disclosure must never hide the current answer: if this set is
            // already one of the rarer types, the group opens showing it.
            isShowingMoreSetTypes = exerciseSet.setType.group == .more
        }
        .confirmationDialog(
            "Switch to \(pendingEffortMeasure == .rpe ? "RPE" : "RIR")?",
            isPresented: $isShowingEffortSwitchConfirmation,
            titleVisibility: .visible
        ) {
            Button("Switch and remove \(effortMeasure == .rpe ? "RPE" : "RIR")", role: .destructive) {
                guard let pendingEffortMeasure else { return }
                clearActiveEffortValue()
                effortMeasure = pendingEffortMeasure
                self.pendingEffortMeasure = nil
                onPersist()
            }
            Button("Cancel", role: .cancel) {
                pendingEffortMeasure = nil
            }
        } message: {
            Text("This set has \(activeEffortValueText). Recording \(pendingEffortMeasure == .rpe ? "RPE" : "RIR") will remove it from this set.")
        }
    }

    private var showsVelocity: Bool {
        isRecordingVelocity || hasVelocityDataOrPrescription
    }

    private var hasVelocityDataOrPrescription: Bool {
        exerciseSet.isVelocityProbe
            || exerciseSet.meanVelocity != nil
            || exerciseSet.peakVelocity != nil
            || exerciseSet.velocityMeasurementSource != nil
            || exerciseSet.prescribedVelocityMinimum != nil
            || exerciseSet.prescribedVelocityMaximum != nil
            || exerciseSet.prescribedVelocityLossStopPercent != nil
    }

    private var hasRecordedOrPrescribedAdvancedData: Bool {
        exerciseSet.resolvedSetMethod != .standard
            || showsVelocity
            || exerciseSet.resolvedSpecializedMetricKind != .none
            || exerciseSet.liftQuality != nil
            || exerciseSet.isUserOverridden
    }

    private var advancedSummary: String {
        var values: [String] = []

        if exerciseSet.resolvedSetMethod != .standard {
            values.append(exerciseSet.resolvedSetMethod.title)
        }
        if showsVelocity {
            values.append(String(localized: "Velocity"))
        }
        if exerciseSet.resolvedSpecializedMetricKind != .none {
            values.append(exerciseSet.resolvedSpecializedMetricKind.title)
        }
        if exerciseSet.liftQuality != nil {
            values.append(String(localized: "Lift quality"))
        }
        if exerciseSet.isUserOverridden {
            values.append(String(localized: "Override"))
        }

        return values.isEmpty
            ? String(localized: "Optional methods and performance measurements")
            : values.joined(separator: " · ")
    }

    private var advancedOptionsSection: some View {
        // An explicit expander instead of DisclosureGroup: the header is a real
        // Button that owns the `set-advanced-options` identifier (so UI tests can
        // tap it), and the content is a sibling. A group-level identifier on a
        // DisclosureGroup would otherwise propagate to every child and clobber
        // their own identifiers (drop-set-structure, set-method-picker, …).
        VStack(alignment: .leading, spacing: Spacing.l) {
            Button {
                withAnimation { isShowingAdvancedOptions.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Advanced options")
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(Color.gymText)
                        Text(advancedSummary)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: AppIcon.chevronRight)
                        .font(AppFont.footnoteMedium)
                        .foregroundStyle(Color.gymSubduedText)
                        .rotationEffect(.degrees(isShowingAdvancedOptions ? 90 : 0))
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("set-advanced-options")
            .accessibilityHint("Reveals set method and optional performance measurements")

            if isShowingAdvancedOptions {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    setMethodSection
                    if showsVelocity {
                        velocitySection
                    } else {
                        Button("Record velocity") {
                            isRecordingVelocity = true
                        }
                        .font(AppFont.footnoteMedium)
                        .foregroundStyle(Color.gymPrimary)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("record-set-velocity")
                    }
                    specializedMetricsSection
                    liftQualitySection
                    if exerciseSet.prescriptionDefinitionData != nil || exerciseSet.prescribedCalories != nil {
                        overrideSection
                    }
                }
            }
        }
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.section))
    }

    private var velocitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            eyebrow(exerciseSet.isVelocityProbe ? "Readiness probe · Mean velocity" : "Mean velocity")
            HStack(spacing: Spacing.s) {
                TextField("0.00", text: velocityBinding)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Mean velocity in metres per second")
                    .accessibilityIdentifier("set-mean-velocity")
                Text("m/s")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.gymSubduedText)
            }
            HStack(spacing: Spacing.s) {
                TextField("Peak 0.00", text: peakVelocityBinding)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Peak velocity in metres per second")
                    .accessibilityIdentifier("set-peak-velocity")
                Text("m/s")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.gymSubduedText)
            }
            measurementSourcePicker(selection: Binding(
                get: { exerciseSet.velocityMeasurementSource ?? .manual },
                set: {
                    exerciseSet.velocityMeasurementSource = $0
                    onPersist()
                }
            ))
            if let minimum = exerciseSet.prescribedVelocityMinimum,
               let maximum = exerciseSet.prescribedVelocityMaximum {
                Text("Target \(minimum.formatted(.number.precision(.fractionLength(2))))–\(maximum.formatted(.number.precision(.fractionLength(2)))) m/s")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
            if let loss = exerciseSet.prescribedVelocityLossStopPercent {
                Text("Stop the set if velocity loss reaches \(loss.formatted(.number.precision(.fractionLength(0...1))))%.")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
    }

    private var velocityBinding: Binding<String> {
        Binding(
            get: { exerciseSet.meanVelocity.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "" },
            set: { text in
                let value = Double(text.replacingOccurrences(of: ",", with: "."))
                exerciseSet.meanVelocity = value.flatMap { $0 > 0 ? $0 : nil }
                if exerciseSet.meanVelocity != nil, exerciseSet.velocityMeasurementSource == nil {
                    exerciseSet.velocityMeasurementSource = .manual
                }
                onPersist()
            }
        )
    }

    private var peakVelocityBinding: Binding<String> {
        Binding(
            get: { exerciseSet.peakVelocity.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "" },
            set: { text in
                let value = Double(text.replacingOccurrences(of: ",", with: "."))
                exerciseSet.peakVelocity = value.flatMap { $0 > 0 ? $0 : nil }
                if exerciseSet.peakVelocity != nil, exerciseSet.velocityMeasurementSource == nil {
                    exerciseSet.velocityMeasurementSource = .manual
                }
                onPersist()
            }
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Set \(index + 1)")
                    .font(AppFont.titleSmall)
                    .foregroundStyle(Color.gymText)
                Text(exerciseName)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .font(AppFont.subheadlineSemibold)
            .foregroundStyle(Color.gymPrimary)
            .accessibilityIdentifier("close-set-details")
        }
    }

    /// Eleven types shown at once made a routine mid-set choice into a scanning
    /// problem. They are grouped by how often a session actually needs them,
    /// and the rarest four sit behind a disclosure — never hidden when one of
    /// them is the current selection.
    private var setTypeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            eyebrow("Set type")

            if recentSetTypes.isEmpty == false {
                setTypeGroup(
                    title: String(localized: "Recently used"),
                    types: recentSetTypes,
                    identifier: "recent"
                )
            }

            setTypeGroup(
                title: SetTypeGroup.common.title,
                types: SetTypeGroup.common.members,
                identifier: SetTypeGroup.common.rawValue
            )

            setTypeGroup(
                title: SetTypeGroup.special.title,
                types: SetTypeGroup.special.members,
                identifier: SetTypeGroup.special.rawValue
            )

            DisclosureGroup(isExpanded: $isShowingMoreSetTypes) {
                setTypeGrid(SetTypeGroup.more.members)
                    .padding(.top, Spacing.s)
            } label: {
                Text(SetTypeGroup.more.title)
                    .font(AppFont.caption2Bold)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(Color.gymSubtleText)
                    .frame(minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .tint(Color.gymPrimary)
            .accessibilityIdentifier("set-type-more-toggle")
        }
    }

    private func setTypeGroup(title: String, types: [SetType], identifier: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(AppFont.caption2Bold)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Color.gymSubtleText)
                .accessibilityIdentifier("set-type-group-\(identifier)")
            setTypeGrid(types, isShortcut: identifier == "recent")
        }
    }

    /// `isShortcut` keeps the Recently used row's chips addressable separately.
    /// A type shown there is deliberately also present in its own group, and two
    /// live elements answering to one identifier is ambiguous for VoiceOver and
    /// unusable from a UI test.
    private func setTypeGrid(_ types: [SetType], isShortcut: Bool = false) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 104), spacing: Spacing.s)],
            alignment: .leading,
            spacing: Spacing.s
        ) {
            ForEach(types, id: \.self) { type in
                setTypeChip(type, isShortcut: isShortcut)
            }
        }
    }

    private var recentSetTypes: [SetType] {
        // The current selection is already visible in its own group, so it
        // never also occupies a shortcut slot.
        RecentSetTypes.decode(recentSetTypesRaw).filter { $0 != exerciseSet.setType }
    }

    private var setMethodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            eyebrow("Set method")
            if exerciseSet.resolvedSetMethod == .dropSet {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Drop set structure")
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.gymText)
                    Text("Configured by the Drop set type above.")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("drop-set-structure")
            } else {
                Picker("Method", selection: Binding(
                    get: { exerciseSet.resolvedSetMethod },
                    set: selectSetMethod
                )) {
                    ForEach(SetMethod.allCases.filter { $0 != .dropSet }, id: \.self) { method in
                        Text(method.title).tag(method)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("set-method-picker")
            }

            if exerciseSet.resolvedSetMethod != .standard {
                Text(exerciseSet.resolvedSetMethod.detail)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                segmentEditor
            }
        }
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.section))
    }

    private var segmentEditor: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ForEach(exerciseSet.orderedSegments, id: \.persistentModelID) { segment in
                SetSegmentEditorRow(
                    segment: segment,
                    canDelete: exerciseSet.orderedSegments.count > exerciseSet.resolvedSetMethod.minimumSegmentCount,
                    onPersist: onPersist
                ) {
                    exerciseSet.segments.removeAll { $0 === segment }
                    exerciseSet.normalizeSegmentOrder()
                    onPersist()
                }
            }
            Button {
                exerciseSet.segments.append(
                    ExerciseSetSegment(
                        orderIndex: exerciseSet.orderedSegments.count,
                        repetitions: exerciseSet.repetitions,
                        weight: exerciseSet.weight,
                        weightType: exerciseSet.weightType
                    )
                )
                onPersist()
            } label: {
                Label("Add segment", systemImage: AppIcon.plus)
                    .font(AppFont.footnoteMedium)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.gymPrimary)
            .accessibilityIdentifier("add-set-segment")
        }
    }

    private var specializedMetricsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            eyebrow("Specialized performance")
            Picker("Metric", selection: Binding(
                get: { exerciseSet.resolvedSpecializedMetricKind },
                set: { kind in
                    exerciseSet.specializedMetricKind = kind
                    if kind == .none {
                        exerciseSet.specializedMetricMeasurementSource = nil
                    } else if exerciseSet.specializedMetricMeasurementSource == nil {
                        exerciseSet.specializedMetricMeasurementSource = .manual
                    }
                    onPersist()
                }
            )) {
                ForEach(SpecializedPerformanceMetricKind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("specialized-metric-picker")

            if exerciseSet.resolvedSpecializedMetricKind != .none {
                HStack(spacing: Spacing.s) {
                    TextField(metricPlaceholder, text: specializedMetricBinding)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    Text(metricUnit)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.gymSubduedText)
                }
                measurementSourcePicker(selection: Binding(
                    get: { exerciseSet.specializedMetricMeasurementSource ?? .manual },
                    set: {
                        exerciseSet.specializedMetricMeasurementSource = $0
                        onPersist()
                    }
                ))
            }
        }
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.section))
    }

    private var metricPlaceholder: String {
        switch exerciseSet.resolvedSpecializedMetricKind {
        case .jumpHeight: "0.00"
        case .contactTime: "0"
        case .throwDistance: "0.00"
        case .kettlebellCadence: "0"
        case .none: ""
        }
    }

    private var metricUnit: String {
        switch exerciseSet.resolvedSpecializedMetricKind {
        case .jumpHeight, .throwDistance: "m"
        case .contactTime: "ms"
        case .kettlebellCadence: "rpm"
        case .none: ""
        }
    }

    private var specializedMetricBinding: Binding<String> {
        Binding(
            get: {
                let value: Double?
                switch exerciseSet.resolvedSpecializedMetricKind {
                case .jumpHeight: value = exerciseSet.jumpHeightMeters
                case .contactTime: value = exerciseSet.contactTimeMilliseconds
                case .throwDistance: value = exerciseSet.throwDistanceMeters
                case .kettlebellCadence: value = exerciseSet.kettlebellCadenceRPM
                case .none: value = nil
                }
                return value.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? ""
            },
            set: { text in
                let value = Double(text.replacingOccurrences(of: ",", with: ".")).flatMap { $0 > 0 ? $0 : nil }
                switch exerciseSet.resolvedSpecializedMetricKind {
                case .jumpHeight: exerciseSet.jumpHeightMeters = value
                case .contactTime: exerciseSet.contactTimeMilliseconds = value
                case .throwDistance: exerciseSet.throwDistanceMeters = value
                case .kettlebellCadence: exerciseSet.kettlebellCadenceRPM = value
                case .none: break
                }
                if value != nil, exerciseSet.specializedMetricMeasurementSource == nil {
                    exerciseSet.specializedMetricMeasurementSource = .manual
                }
                onPersist()
            }
        )
    }

    private func measurementSourcePicker(selection: Binding<MeasurementSource>) -> some View {
        Picker("Source", selection: selection) {
            ForEach(MeasurementSource.allCases, id: \.self) { source in
                Text(source.title).tag(source)
            }
        }
        .pickerStyle(.menu)
    }

    private var overrideSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            eyebrow("Prescription override")
            Toggle("Use this value in future sessions", isOn: $exerciseSet.userOverrideAffectsFuture)
                .font(AppFont.subheadline)
                .tint(Color.gymPrimary)
                .onChange(of: exerciseSet.userOverrideAffectsFuture) { _, _ in
                    exerciseSet.isUserOverridden = true
                    onPersist()
                }
                .accessibilityIdentifier("set-override-future")

            TextField("Reason (optional)", text: Binding(
                get: { exerciseSet.userOverrideReason ?? "" },
                set: {
                    exerciseSet.userOverrideReason = $0.isEmpty ? nil : $0
                    exerciseSet.isUserOverridden = true
                    onPersist()
                }
            ))
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier("set-override-reason")
        }
    }

    private func setTypeChip(_ type: SetType, isShortcut: Bool = false) -> some View {
        let isSelected = exerciseSet.setType == type
        let accent = type.accentColor ?? Color.gymPrimary

        return Button {
            selectSetType(type)
        } label: {
            Label(type.title, systemImage: type.icon)
                .font(AppFont.footnoteMedium)
                .lineLimit(1)
                .foregroundStyle(isSelected ? accent : Color.gymSubduedText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? accent.opacity(0.14) : Color.gymCard)
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .strokeBorder(isSelected ? accent.opacity(0.5) : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(
            isShortcut ? "set-type-recent-\(type.rawValue)" : "set-type-option-\(type.rawValue)"
        )
    }

    private func selectSetType(_ type: SetType) {
        exerciseSet.setType = type
        recentSetTypesRaw = RecentSetTypes.recording(type, into: recentSetTypesRaw)
        if type == .dropSet {
            exerciseSet.setMethod = .dropSet
            exerciseSet.ensureSegmentsForMethod()
            isShowingAdvancedOptions = true
        } else if exerciseSet.resolvedSetMethod == .dropSet {
            exerciseSet.setMethod = .standard
        }
        onPersist()
    }

    private func selectSetMethod(_ method: SetMethod) {
        exerciseSet.setMethod = method
        exerciseSet.ensureSegmentsForMethod()
        onPersist()
    }

    private var effortSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                eyebrow(effortMeasure == .rir ? "Effort · Reps in reserve" : "Effort · RPE")
                Spacer(minLength: Spacing.s)
                Menu {
                    ForEach(EffortMeasure.allCases, id: \.self) { measure in
                        Button {
                            selectEffortMeasure(measure)
                        } label: {
                            if measure == effortMeasure {
                                Label(measure.title, systemImage: AppIcon.checkmark)
                            } else {
                                Text(measure.title)
                            }
                        }
                    }
                } label: {
                    Label(effortMeasure == .rir ? "Use RPE" : "Use RIR", systemImage: "chevron.down")
                        .font(AppFont.footnoteMedium)
                        .foregroundStyle(Color.gymPrimary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Effort measure: \(effortMeasure.title)")
                .accessibilityHint("Switches between RIR and RPE")

                if hasActiveEffortValue {
                    Button("Clear") {
                        clearActiveEffortValue()
                        onPersist()
                    }
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.gymPrimary)
                    .accessibilityIdentifier(effortMeasure == .rir ? "clear-rir" : "clear-rpe")
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(formattedActiveEffortValue)
                    .font(AppFont.displayMedium)
                    .monospacedDigit()
                    .foregroundStyle(hasActiveEffortValue ? Color.gymText : Color.gymSubduedText)
                    .contentTransition(.numericText())
                Text(activeEffortMeaning)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .animation(reduceMotion ? nil : AppMotion.compact, value: hasActiveEffortValue)

            if effortMeasure == .rir {
                Slider(value: rirBinding, in: 0...6, step: 1) {
                    Text("RIR")
                } minimumValueLabel: {
                    sliderBound("0")
                } maximumValueLabel: {
                    sliderBound("6+")
                }
                .tint(Color.gymSecondary)
                .accessibilityIdentifier("rir-slider")
            } else {
                Slider(value: rpeBinding, in: 1...10, step: 0.5) {
                    Text("RPE")
                } minimumValueLabel: {
                    sliderBound("1")
                } maximumValueLabel: {
                    sliderBound("10")
                }
                .tint(Color.gymPrimary)
                .accessibilityIdentifier("rpe-slider")
            }

            if let historicalEffortCaption {
                Text(historicalEffortCaption)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.section))
    }

    private var hasActiveEffortValue: Bool {
        effortMeasure == .rir ? exerciseSet.rir != nil : exerciseSet.rpe != nil
    }

    private var formattedActiveEffortValue: String {
        if effortMeasure == .rir {
            return exerciseSet.rir.map(String.init) ?? "—"
        } else {
            return exerciseSet.rpe.map { Formatters.formatFloat(Float($0)) } ?? "—"
        }
    }

    private var activeEffortValueText: String {
        if effortMeasure == .rir {
            guard let rir = exerciseSet.rir else { return "an RIR value" }
            return "RIR \(rir)"
        } else {
            guard let rpe = exerciseSet.rpe else { return "an RPE value" }
            return "RPE \(Formatters.formatFloat(Float(rpe)))"
        }
    }

    private var activeEffortMeaning: String {
        if effortMeasure == .rir {
            guard let rir = exerciseSet.rir else {
                return String(localized: "Slide to record reps left after this set")
            }
            return RIRScale.meaning(for: rir)
        } else {
            guard let rpe = exerciseSet.rpe else {
                return String(localized: "Slide to rate how hard this set felt")
            }
            return RPEScale.meaning(for: rpe)
        }
    }

    private var historicalEffortCaption: String? {
        if effortMeasure == .rir, let rpe = exerciseSet.rpe {
            return "RPE \(Formatters.formatFloat(Float(rpe))) recorded earlier on this set"
        }
        if effortMeasure == .rpe, let rir = exerciseSet.rir {
            return "RIR \(rir) recorded earlier on this set"
        }
        return nil
    }

    private var rirBinding: Binding<Double> {
        Binding(
            get: { Double(exerciseSet.rir ?? 2) },
            set: {
                exerciseSet.recordRIR(Int($0.rounded()))
                onPersist()
            }
        )
    }

    private var rpeBinding: Binding<Double> {
        Binding(
            get: { exerciseSet.rpe ?? 7.0 },
            set: {
                exerciseSet.recordRPE($0)
                onPersist()
            }
        )
    }

    private func selectEffortMeasure(_ measure: EffortMeasure) {
        guard measure != effortMeasure else { return }
        if hasActiveEffortValue {
            pendingEffortMeasure = measure
            isShowingEffortSwitchConfirmation = true
        } else {
            effortMeasure = measure
        }
    }

    private func clearActiveEffortValue() {
        if effortMeasure == .rir {
            exerciseSet.recordRIR(nil)
        } else {
            exerciseSet.recordRPE(nil)
        }
    }

    private var liftQualitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                eyebrow("Lift quality")
                Spacer()
                if exerciseSet.liftQuality != nil {
                    Button("Clear") {
                        exerciseSet.liftQuality = nil
                        onPersist()
                    }
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.gymPrimary)
                    .accessibilityLabel("Clear lift quality")
                    .accessibilityIdentifier("clear-lift-quality")
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: Spacing.s)], spacing: Spacing.s) {
                ForEach(LiftQuality.allCases, id: \.self) { quality in
                    Button {
                        exerciseSet.liftQuality = quality
                        onPersist()
                    } label: {
                        Text(quality.title)
                            .font(AppFont.footnoteMedium)
                            .foregroundStyle(exerciseSet.liftQuality == quality ? Color.gymText : Color.gymSubduedText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(exerciseSet.liftQuality == quality ? Color.gymPrimary.opacity(0.14) : Color.gymCard)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                                    .strokeBorder(exerciseSet.liftQuality == quality ? Color.gymPrimary.opacity(0.5) : .clear, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(exerciseSet.liftQuality == quality ? .isSelected : [])
                    .accessibilityIdentifier("lift-quality-\(quality.rawValue)")
                }
            }
        }
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.section))
    }

    private func sliderBound(_ text: String) -> some View {
        Text(text)
            .font(AppFont.captionSemiboldMonospaced)
            .foregroundStyle(Color.gymSubduedText)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            dismiss()
            onDelete()
        } label: {
            Label("Delete set", systemImage: AppIcon.trash)
                .font(AppFont.subheadlineSemibold)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(Color.gymDestructive)
        .accessibilityIdentifier("delete-set-\(exerciseName)-\(index)")
    }

    private func eyebrow(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(AppFont.caption2Bold)
            .textCase(.uppercase)
            .tracking(0.55)
            .foregroundStyle(Color.gymSubduedText)
    }
}
