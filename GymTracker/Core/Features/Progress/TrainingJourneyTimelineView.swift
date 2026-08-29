import SwiftUI

/// A visual projection of the same chapter facts exposed by
/// `TrainingJourneyView`. The List remains the accessibility baseline; this
/// view adds spatial comparison without replacing the complete chronology.
///
/// Diagram specification:
/// QUESTION: When did recorded plan, rotation, and free-training chapters occur
/// and overlap?
/// DATA: `TrainingJourneyTimelineProjection` chapter intervals and explicit
/// practice-transition markers; absent chapters remain absent, never zero.
/// ENCODING: normalized time -> x-position and segment width; chapter kind ->
/// labelled lane and hue; overlap -> sublane; selected date -> vertical rule.
/// INTERACTION: the native date picker, chapter segments, and transition markers
/// select an exact date.
/// DETAIL: the selected-date group lists exact chapter counts/status and
/// transition evidence; the List presentation opens chapter source evidence.
/// EMPTY STATE: the root renders the explicit no-history state instead of an
/// empty canvas.
/// ACCESSIBILITY: every segment/marker has a full label, selected-date detail is
/// textual, and the List presentation is the complete chronological equivalent.
struct TrainingJourneyTimelineView: View {
    let projection: TrainingJourneyTimelineProjection
    let practiceTransitions: TrainingJourneyPracticeTransitionProjection
    @Binding var selectedDate: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let labelWidth = Spacing.xxxl * 2 + Spacing.l
    private let barHeight = ComponentSize.minimumTouchTarget
    private let sublaneSpacing = Spacing.xs
    private let transitionMarkerHeight = ComponentSize.minimumTouchTarget

    init(
        projection: TrainingJourneyTimelineProjection,
        selectedDate: Binding<Date>,
        practiceTransitions: TrainingJourneyPracticeTransitionProjection = .init(markers: [])
    ) {
        self.projection = projection
        self._selectedDate = selectedDate
        self.practiceTransitions = practiceTransitions
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                HStack(alignment: .center, spacing: Spacing.m) {
                    TrameSectionRule(title: "Recorded chapters")
                    DatePicker("Selected date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .accessibilityLabel("Timeline date")
                        .accessibilityIdentifier("training-journey-timeline-date")
                }

                if let segment = singleJourneySegment {
                    singleChapterMilestone(segment)
                } else {
                    GeometryReader { geometry in
                        let chartWidth = max(
                            1,
                            geometry.size.width - labelWidth - Spacing.s - Spacing.m * 2
                        )
                        timelineCanvas(chartWidth: chartWidth)
                            .padding(.horizontal, Spacing.m)
                    }
                    .frame(height: canvasHeight)
                    .accessibilityIdentifier("training-journey-timeline-chart")

                    selectionDetail
                }
            }
            .padding(.horizontal, Spacing.screenInset)
            .padding(.vertical, Spacing.l)
        }
        .scrollIndicators(.hidden)
        .background(Color.trameCanvas)
        .accessibilityIdentifier("training-journey-timeline")
        .animation(reduceMotion ? nil : AppMotion.compact, value: selectedDate)
    }

    private var visibleLanes: [TrainingJourneyTimelineLaneProjection] {
        projection.lanes.filter { $0.segments.isEmpty == false }
    }

    private var singleJourneySegment: TrainingJourneyTimelineSegment? {
        guard practiceTransitions.markers.isEmpty else { return nil }
        let segments = visibleLanes.flatMap(\.segments)
        return segments.count == 1 ? segments[0] : nil
    }

    private func singleChapterMilestone(
        _ segment: TrainingJourneyTimelineSegment
    ) -> some View {
        let selection = projection.selection(for: selectedDate)
        let selectedHit = selection.hits.first { $0.chapterID == segment.chapterID }
        let tint = laneTint(segment.lane)

        return VStack(alignment: .leading, spacing: Spacing.m) {
            Text(segment.title)
                .font(AppFont.sectionTitle)
                .foregroundStyle(Color.trameText)
                .fixedSize(horizontal: false, vertical: true)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.trameSeparator)
                    .frame(height: 1)

                Rectangle()
                    .fill(tint)
                    .frame(height: Spacing.xs)

                Circle()
                    .fill(Color.trameCanvas)
                    .frame(width: Spacing.l, height: Spacing.l)
                    .overlay {
                        Circle().stroke(tint, lineWidth: 2)
                    }
                    .overlay {
                        Circle().fill(tint).frame(width: Spacing.xs, height: Spacing.xs)
                    }
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(milestoneDateLabel(segment))
                Spacer(minLength: Spacing.s)
                if let selectedHit {
                    Text(hitSummary(selectedHit))
                } else {
                    Text("No activity on this date")
                }
            }
            .font(AppFont.metadata)
            .foregroundStyle(Color.trameSubdued)
        }
        .padding(.vertical, Spacing.m)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.trameSeparator).frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [
                segmentAccessibilityLabel(segment),
                selectedHit.map(hitAccessibilityLabel)
            ]
            .compactMap { $0 }
            .joined(separator: ". ")
        )
        .accessibilityIdentifier("training-journey-single-milestone")
    }

    private func milestoneDateLabel(_ segment: TrainingJourneyTimelineSegment) -> String {
        if Calendar.current.isDateInToday(segment.originalStart) {
            return String(localized: "Started today")
        }
        if segment.isOpenEnded {
            return String(localized: "Since \(segment.originalStart.formatted(.dateTime.month(.abbreviated).day()))")
        }
        return segment.originalStart.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private var canvasHeight: CGFloat {
        let markerRowsHeight = CGFloat(transitionMarkerRows.count)
            * (transitionMarkerHeight + Spacing.xxs)
        let lanesHeight = visibleLanes.reduce(CGFloat.zero) { partial, lane in
            partial + laneHeight(for: lane)
        }
        let visibleRowGaps = visibleLanes.count + (practiceTransitions.markers.isEmpty ? 0 : 1)
        return tickRowHeight
            + markerRowsHeight
            + lanesHeight
            + CGFloat(visibleRowGaps) * Spacing.s
            + Spacing.s * 2
    }

    private func timelineCanvas(chartWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            tickRow(chartWidth: chartWidth)

            if practiceTransitions.markers.isEmpty == false {
                transitionMarkerRow(chartWidth: chartWidth)
            }

            ForEach(visibleLanes) { lane in
                HStack(alignment: .center, spacing: Spacing.s) {
                    laneLabel(lane.lane)
                        .frame(width: labelWidth, height: laneHeight(for: lane), alignment: .leading)
                    laneTrack(lane, chartWidth: chartWidth)
                }
                .frame(height: laneHeight(for: lane))
            }
        }
        .padding(.vertical, Spacing.s)
    }

    private func tickRow(chartWidth: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Color.clear.frame(height: tickRowHeight)
            ForEach(visibleTicks(chartWidth: chartWidth)) { tick in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Rectangle()
                        .fill(tick.kind == .year ? Color.trameText : Color.trameSeparator)
                        .frame(width: Spacing.xxs, height: tick.kind == .year ? Spacing.m : Spacing.s)
                    Text(tickLabel(tick))
                        .font(tick.kind == .year ? AppFont.captionSemiboldMonospaced : AppFont.caption2)
                        .foregroundStyle(tick.kind == .year ? Color.trameText : Color.trameSubdued)
                        .fixedSize()
                }
                .offset(x: min(tick.position * chartWidth, max(0, chartWidth - Spacing.xxxl)))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(tickLabel(tick))
            }
        }
        .frame(width: chartWidth, height: tickRowHeight, alignment: .leading)
        .padding(.leading, labelWidth + Spacing.s)
    }

    /// Compact date ranges can project month and year ticks onto effectively
    /// the same pixel. Keep labels readable by retaining one marker per visual
    /// slot, preferring the higher-level year marker when two collide.
    private func visibleTicks(chartWidth: CGFloat) -> [TrainingJourneyTimelineTick] {
        let minimumSeparation = Spacing.xxxl + Spacing.l
        return projection.ticks
            .sorted { lhs, rhs in
                if lhs.position != rhs.position { return lhs.position < rhs.position }
                return lhs.kind == .year && rhs.kind != .year
            }
            .reduce(into: []) { result, tick in
                guard let previous = result.last else {
                    result.append(tick)
                    return
                }
                let separation = abs(tick.position - previous.position) * chartWidth
                guard separation < minimumSeparation else {
                    result.append(tick)
                    return
                }
                if tick.kind == .year, previous.kind != .year {
                    result[result.count - 1] = tick
                }
            }
    }

    private var transitionMarkerRows: [[TrainingJourneyPracticeTransitionMarker]] {
        TrainingJourneyTimelineTransitionPresentation.collisionRows(practiceTransitions.markers)
    }

    private func transitionMarkerRow(chartWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            ForEach(Array(transitionMarkerRows.enumerated()), id: \.offset) { _, row in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.trameSeparator)
                        .frame(height: Spacing.xxs)
                        .offset(y: transitionMarkerHeight - Spacing.xs)

                    ForEach(row) { marker in
                        transitionMarkerButton(marker, chartWidth: chartWidth)
                    }
                }
                .frame(width: chartWidth, height: transitionMarkerHeight)
            }
        }
        .frame(
            width: chartWidth,
            height: CGFloat(transitionMarkerRows.count) * (transitionMarkerHeight + Spacing.xxs)
        )
        .padding(.leading, labelWidth + Spacing.s)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Practice transitions")
    }

    private func transitionMarkerButton(
        _ marker: TrainingJourneyPracticeTransitionMarker,
        chartWidth: CGFloat
    ) -> some View {
        let markerWidth = Spacing.xxxl + Spacing.m
        let rawOffset = marker.position * chartWidth - markerWidth / 2
        let offset = max(0, min(chartWidth - markerWidth, rawOffset))
        let label = TrainingJourneyTimelineTransitionPresentation.accessibilityLabel(marker)
        let identifier = "training-journey-timeline-transition-\(marker.id)"
        return Button {
            selectedDate = marker.date
        } label: {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: transitionIcon(marker))
                    .font(AppFont.captionSemiboldMonospaced)
                Text(TrainingJourneyTimelineTransitionPresentation.shortLabel(marker))
                    .font(AppFont.caption2)
                    .lineLimit(1)
            }
            .foregroundStyle(transitionTint(marker))
            .frame(width: markerWidth, height: transitionMarkerHeight)
            .background(transitionSurface(marker))
            .clipShape(RoundedRectangle(cornerRadius: Radius.small))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.small)
                    .stroke(
                        isMarkerSelected(marker) ? Color.trameText : transitionTint(marker),
                        lineWidth: isMarkerSelected(marker) ? Spacing.xs : Spacing.xxs
                    )
            }
        }
        .buttonStyle(.gymPress)
        .frame(width: markerWidth, height: transitionMarkerHeight)
        .offset(x: offset)
        .accessibilityLabel(label)
        .accessibilityHint("Select this transition date. This marker is descriptive and does not explain causality.")
        .accessibilityIdentifier(identifier)
    }

    private func laneLabel(_ lane: TrainingJourneyTimelineLane) -> some View {
        let copy: (visible: String, spoken: String, icon: String) = {
            switch lane {
            case .fixedPlan: ("Plan", "Fixed plan", AppIcon.plan)
            case .repeatingPlan: ("Rotation", "Rotation", AppIcon.repeatingPlan)
            case .freeTraining: ("Free", "Free training", AppIcon.workout)
            }
        }()
        return Label(copy.visible, systemImage: copy.icon)
            .font(AppFont.captionBold)
            .foregroundStyle(Color.trameText)
            .labelStyle(.titleAndIcon)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(copy.spoken)
    }

    private func laneTrack(
        _ lane: TrainingJourneyTimelineLaneProjection,
        chartWidth: CGFloat
    ) -> some View {
        let trackHeight = laneHeight(for: lane)
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.trameSeparator)
                .frame(height: Spacing.xxs)
                .offset(y: trackHeight - Spacing.xxs)

            ForEach(lane.segments) { segment in
                let segmentWidth = max(
                    Spacing.xs,
                    (segment.positionEnd - segment.positionStart) * chartWidth
                )
                let interactionWidth = max(ComponentSize.minimumTouchTarget, segmentWidth)
                Button {
                    selectedDate = segment.originalStart
                } label: {
                    Group {
                        if segmentWidth >= Spacing.xxxl * 2 {
                            HStack(spacing: Spacing.xs) {
                                Text(segment.title)
                                    .font(AppFont.captionBold)
                                    .foregroundStyle(Color.trameText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                if segment.isOpenEnded,
                                   segmentWidth >= Spacing.xxxl * 3 {
                                    Circle()
                                        .fill(laneTint(segment.lane))
                                        .frame(width: Spacing.xs, height: Spacing.xs)
                                        .accessibilityHidden(true)
                                }
                            }
                            .padding(.horizontal, Spacing.s)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(
                        width: segmentWidth,
                        height: barHeight,
                        alignment: .leading
                    )
                    .background(laneSurface(segment.lane))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.small)
                            .stroke(laneTint(segment.lane), lineWidth: 1.5)
                    }
                }
                .buttonStyle(.plain)
                .frame(width: interactionWidth, height: barHeight, alignment: .leading)
                .contentShape(Rectangle())
                .offset(
                    x: segment.positionStart * chartWidth,
                    y: CGFloat(segment.sublane) * (barHeight + sublaneSpacing)
                )
                .accessibilityLabel(segmentAccessibilityLabel(segment))
                .accessibilityHint("Selects this chapter's start date")
                .accessibilityIdentifier("training-journey-timeline-segment-\(segment.chapterID)")
            }

            Rectangle()
                .fill(Color.trameText)
                .frame(width: Spacing.xxs, height: trackHeight - Spacing.xs)
                .offset(x: cursorPosition * chartWidth)
                .accessibilityHidden(true)
        }
        .frame(width: chartWidth, height: trackHeight)
    }

    private var tickRowHeight: CGFloat { Spacing.xxxl }

    private func laneHeight(for lane: TrainingJourneyTimelineLaneProjection) -> CGFloat {
        let sublaneCount = (lane.segments.map(\.sublane).max() ?? 0) + 1
        return CGFloat(sublaneCount) * barHeight
            + CGFloat(max(0, sublaneCount - 1)) * sublaneSpacing
            + Spacing.s
    }

    private var cursorPosition: Double {
        guard projection.domain.duration > 0 else { return 0 }
        return min(
            1,
            max(0, selectedDate.timeIntervalSince(projection.domain.start) / projection.domain.duration)
        )
    }

    private var selectionDetail: some View {
        let selection = projection.selection(for: selectedDate)
        return VStack(alignment: .leading, spacing: Spacing.m) {
            TrameSectionRule(title: "Selected date")

            if selection.hits.isEmpty {
                Text("No chapter on this date")
                    .font(AppFont.body)
                    .foregroundStyle(Color.trameSubdued)
            } else {
                ForEach(selection.hits) { hit in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                        Text(hit.title)
                            .font(AppFont.body.weight(.semibold))
                            .foregroundStyle(Color.trameText)
                        Spacer(minLength: Spacing.s)
                        Text(hitSummary(hit))
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.trameSubdued)
                            .multilineTextAlignment(.trailing)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(hitAccessibilityLabel(hit))
                }
            }

            let selectedTransitions = transitionMarkers(on: selectedDate)
            if selectedTransitions.isEmpty == false {
                Divider()
                    .accessibilityHidden(true)
                Text("Practice transitions")
                    .font(AppFont.eyebrow)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.trameSubdued)
                ForEach(selectedTransitions) { marker in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(TrainingJourneyTimelineTransitionPresentation.title(marker))
                            .font(AppFont.body.weight(.semibold))
                            .foregroundStyle(Color.trameText)
                        Text(TrainingJourneyTimelineTransitionPresentation.evidenceSummary(marker))
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.trameSubdued)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(TrainingJourneyTimelineTransitionPresentation.accessibilityLabel(marker))
                }
            }
        }
        .accessibilityIdentifier("training-journey-timeline-selection")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selectionAccessibilityLabel(selection))
    }

    private func selectionAccessibilityLabel(_ selection: TrainingJourneyTimelineSelection) -> String {
        let date = selectedDate.formatted(date: .complete, time: .omitted)
        var parts = [date]
        if selection.hits.isEmpty {
            parts.append("No chapter")
        } else {
            parts.append(contentsOf: selection.hits.map(hitAccessibilityLabel))
        }
        parts.append(contentsOf: transitionMarkers(on: selectedDate).map {
            TrainingJourneyTimelineTransitionPresentation.accessibilityLabel($0)
        })
        return parts.joined(separator: ". ")
    }

    private func transitionMarkers(on date: Date) -> [TrainingJourneyPracticeTransitionMarker] {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        return practiceTransitions.markers
            .filter { $0.normalizedDate == normalizedDate }
            .sorted { TrainingJourneyTimelineTransitionPresentation.order($0, $1) }
    }

    private func tickLabel(_ tick: TrainingJourneyTimelineTick) -> String {
        guard let month = tick.month else { return String(tick.year) }
        let date = Calendar.current.date(from: DateComponents(year: tick.year, month: month)) ?? tick.date
        return date.formatted(.dateTime.month(.abbreviated))
    }

    private func laneTint(_ lane: TrainingJourneyTimelineLane) -> Color {
        switch lane {
        case .fixedPlan: .chartAqua
        case .repeatingPlan: .chartViolet
        case .freeTraining: .chartOrange
        }
    }

    private func laneSurface(_: TrainingJourneyTimelineLane) -> Color {
        Color.trameRow
    }

    private func segmentAccessibilityLabel(_ segment: TrainingJourneyTimelineSegment) -> String {
        [
            segment.title,
            segment.isOpenEnded ? "Current" : nil,
            segment.originalStart.formatted(date: .abbreviated, time: .omitted),
            segment.originalEnd?.formatted(date: .abbreviated, time: .omitted),
            segment.statusText,
            segmentSummary(segment)
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }

    private func segmentSummary(_ segment: TrainingJourneyTimelineSegment) -> String {
        "\(workoutCountText(segment.completedWorkouts)), \(recordCountText(segment.personalRecords))"
    }

    private func hitSummary(_ hit: TrainingJourneyTimelineHit) -> String {
        "\(workoutCountText(hit.completedWorkouts)) · \(recordCountText(hit.personalRecords))"
    }

    private func workoutCountText(_ count: Int) -> String {
        count == 1 ? String(localized: "1 workout") : String(localized: "\(count) workouts")
    }

    private func recordCountText(_ count: Int) -> String {
        count == 1 ? String(localized: "1 record") : String(localized: "\(count) records")
    }

    private func hitAccessibilityLabel(_ hit: TrainingJourneyTimelineHit) -> String {
        [hit.title, hit.statusText, hitSummary(hit)]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private func transitionIcon(_ marker: TrainingJourneyPracticeTransitionMarker) -> String {
        marker.kind.isDeclared ? AppIcon.plan : (marker.isObserved ? AppIcon.checkmarkCircle : AppIcon.info)
    }

    private func transitionTint(_ marker: TrainingJourneyPracticeTransitionMarker) -> Color {
        marker.kind.isDeclared ? .trameStrength : (marker.isObserved ? .trameCompleted : .trameAttention)
    }

    private func transitionSurface(_: TrainingJourneyPracticeTransitionMarker) -> Color {
        .trameRow
    }

    private func isMarkerSelected(_ marker: TrainingJourneyPracticeTransitionMarker) -> Bool {
        Calendar.current.startOfDay(for: selectedDate) == marker.normalizedDate
    }
}
