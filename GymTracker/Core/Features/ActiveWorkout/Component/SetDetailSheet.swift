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
    static func meaning(for value: Int) -> String {
        switch value {
        case 10: String(localized: "Max effort — nothing left")
        case 9: String(localized: "Could do 1 more rep")
        case 8: String(localized: "Could do 2 more reps")
        case 7: String(localized: "Could do 3 more reps")
        case 6: String(localized: "Could do 4 more reps")
        case 5: String(localized: "Could do 5+ more reps")
        default: String(localized: "Very light — warm-up effort")
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
    let index: Int
    @Bindable var exerciseSet: ExerciseSet
    let exerciseName: String
    let onPersist: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingEffortMeasure: EffortMeasure?
    @State private var isShowingEffortSwitchConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header
                setTypeSection
                setMethodSection
                if showsVelocity { velocitySection }
                specializedMetricsSection
                effortSection
                liftQualitySection
                if exerciseSet.prescriptionDefinitionData != nil || exerciseSet.prescribedCalories != nil {
                    overrideSection
                }
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
        true
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

    private var setTypeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            eyebrow("Set type")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 104), spacing: Spacing.s)],
                alignment: .leading,
                spacing: Spacing.s
            ) {
                ForEach(SetType.allCases, id: \.self) { type in
                    setTypeChip(type)
                }
            }
        }
    }

    private var setMethodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            eyebrow("Set method")
            Picker("Method", selection: Binding(
                get: { exerciseSet.setMethod },
                set: { method in
                    exerciseSet.setMethod = method
                    exerciseSet.ensureSegmentsForMethod()
                    onPersist()
                }
            )) {
                ForEach(SetMethod.allCases, id: \.self) { method in
                    Text(method.title).tag(method)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("set-method-picker")

            if exerciseSet.setMethod != .standard {
                Text(exerciseSet.setMethod.detail)
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
                    canDelete: exerciseSet.orderedSegments.count > exerciseSet.setMethod.minimumSegmentCount,
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
                get: { exerciseSet.specializedMetricKind },
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

            if exerciseSet.specializedMetricKind != .none {
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
        switch exerciseSet.specializedMetricKind {
        case .jumpHeight: "0.00"
        case .contactTime: "0"
        case .throwDistance: "0.00"
        case .kettlebellCadence: "0"
        case .none: ""
        }
    }

    private var metricUnit: String {
        switch exerciseSet.specializedMetricKind {
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
                switch exerciseSet.specializedMetricKind {
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
                switch exerciseSet.specializedMetricKind {
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

    private func setTypeChip(_ type: SetType) -> some View {
        let isSelected = exerciseSet.setType == type
        let accent = type.accentColor ?? Color.gymPrimary

        return Button {
            exerciseSet.setType = type
            onPersist()
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
        .accessibilityIdentifier("set-type-option-\(type.rawValue)")
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

                if activeEffortValue != nil {
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
                Text(activeEffortValue.map(String.init) ?? "—")
                    .font(AppFont.displayMedium)
                    .monospacedDigit()
                    .foregroundStyle(activeEffortValue == nil ? Color.gymSubduedText : Color.gymText)
                    .contentTransition(.numericText())
                Text(activeEffortMeaning)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .animation(reduceMotion ? nil : AppMotion.compact, value: activeEffortValue)

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
                Slider(value: rpeBinding, in: 1...10, step: 1) {
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

    private var activeEffortValue: Int? {
        effortMeasure == .rir ? exerciseSet.rir : exerciseSet.rpe
    }

    private var activeEffortValueText: String {
        guard let activeEffortValue else { return effortMeasure == .rir ? "an RIR value" : "an RPE value" }
        return "\(effortMeasure == .rir ? "RIR" : "RPE") \(activeEffortValue)"
    }

    private var activeEffortMeaning: String {
        guard let activeEffortValue else {
            return effortMeasure == .rir
                ? String(localized: "Slide to record reps left after this set")
                : String(localized: "Slide to rate how hard this set felt")
        }
        return effortMeasure == .rir ? RIRScale.meaning(for: activeEffortValue) : RPEScale.meaning(for: activeEffortValue)
    }

    private var historicalEffortCaption: String? {
        if effortMeasure == .rir, let rpe = exerciseSet.rpe {
            return "RPE \(rpe) recorded earlier on this set"
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
            get: { Double(exerciseSet.rpe ?? 7) },
            set: {
                exerciseSet.recordRPE(Int($0.rounded()))
                onPersist()
            }
        )
    }

    private func selectEffortMeasure(_ measure: EffortMeasure) {
        guard measure != effortMeasure else { return }
        if activeEffortValue != nil {
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
