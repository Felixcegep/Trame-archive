import SwiftUI

/// A visual projection of the same chapter facts exposed by
/// `TrainingJourneyView`. The List remains the accessibility baseline; this
/// view adds spatial comparison without replacing the complete chronology.
struct TrainingJourneyTimelineView: View {
    let projection: TrainingJourneyTimelineProjection
    let practiceTransitions: TrainingJourneyPracticeTransitionProjection
    @Binding var selectedDate: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let labelWidth = Spacing.xxxl * 3 + Spacing.m
    private let minimumChartWidth = Spacing.xxxl * 22 + Spacing.m
    private let barHeight = Spacing.xxxl + Spacing.m
    private let sublaneSpacing = Spacing.xs
    private let transitionMarkerHeight = Spacing.xxxl + Spacing.s

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
        VStack(alignment: .leading, spacing: Spacing.m) {
            DatePicker("Selected date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding(.horizontal, Spacing.l)
                .accessibilityIdentifier("training-journey-timeline-date")

            GeometryReader { geometry in
                let chartWidth = max(minimumChartWidth, geometry.size.width - labelWidth)
                ScrollView(.horizontal) {
                    timelineCanvas(chartWidth: chartWidth)
                        // `timelineCanvas` owns horizontal content padding.
                        // Include it in the scrollable width so the leading
                        // lane icons and trailing segment edges are never
                        // clipped by the explicit canvas frame.
                        .frame(width: labelWidth + chartWidth + Spacing.l * 2)
                }
                .scrollIndicators(.visible)
                .accessibilityIdentifier("training-journey-timeline-scroll")
            }
            .frame(height: canvasHeight)

            selectionCard
                .padding(.horizontal, Spacing.l)
        }
        .padding(.vertical, Spacing.s)
        .background(Color.gymBackground)
        .accessibilityIdentifier("training-journey-timeline")
        .animation(reduceMotion ? nil : AppMotion.compact, value: selectedDate)
    }

    private var canvasHeight: CGFloat {
        let markerRowsHeight = CGFloat(transitionMarkerRows.count)
            * (transitionMarkerHeight + Spacing.xxs)
        let lanesHeight = projection.lanes.reduce(CGFloat.zero) { partial, lane in
            partial + laneHeight(for: lane)
        }
        return tickRowHeight + markerRowsHeight + lanesHeight + Spacing.m
    }

    private func timelineCanvas(chartWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            tickRow(chartWidth: chartWidth)

            if practiceTransitions.markers.isEmpty == false {
                transitionMarkerRow(chartWidth: chartWidth)
            }

            ForEach(projection.lanes) { lane in
                HStack(alignment: .center, spacing: Spacing.s) {
                    laneLabel(lane.lane)
                        .frame(width: labelWidth, height: laneHeight(for: lane), alignment: .leading)
                    laneTrack(lane, chartWidth: chartWidth)
                }
                .frame(height: laneHeight(for: lane))
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
    }

    private func tickRow(chartWidth: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Color.clear.frame(height: tickRowHeight)
            ForEach(visibleTicks(chartWidth: chartWidth)) { tick in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Rectangle()
                        .fill(tick.kind == .year ? Color.gymText : Color.gymBorder)
                        .frame(width: Spacing.xxs, height: tick.kind == .year ? Spacing.m : Spacing.s)
                    Text(tickLabel(tick))
                        .font(tick.kind == .year ? AppFont.captionSemiboldMonospaced : AppFont.caption2)
                        .foregroundStyle(tick.kind == .year ? Color.gymText : Color.gymSubduedText)
                        .fixedSize()
                }
                .offset(x: tick.position * chartWidth)
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
                        .fill(Color.gymBorder)
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
                        isMarkerSelected(marker) ? Color.gymText : transitionTint(marker),
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
        let copy: (String, String) = {
            switch lane {
            case .fixedPlan: ("Fixed plan", AppIcon.plan)
            case .repeatingPlan: ("Rotation", AppIcon.repeatingPlan)
            case .freeTraining: ("Free training", AppIcon.workout)
            }
        }()
        return Label(copy.0, systemImage: copy.1)
            .font(AppFont.footnoteMedium)
            .foregroundStyle(Color.gymText)
            .labelStyle(.titleAndIcon)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(copy.0)
    }

    private func laneTrack(
        _ lane: TrainingJourneyTimelineLaneProjection,
        chartWidth: CGFloat
    ) -> some View {
        let trackHeight = laneHeight(for: lane)
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.gymBorder)
                .frame(height: Spacing.xxs)
                .offset(y: trackHeight - Spacing.xxs)

            ForEach(lane.gaps) { gap in
                Rectangle()
                    .fill(Color.gymMutedSurface)
                    .frame(
                        width: max(Spacing.xxs, (gap.positionEnd - gap.positionStart) * chartWidth),
                        height: Spacing.m
                    )
                    .offset(x: gap.positionStart * chartWidth)
                    .accessibilityHidden(true)
            }

            ForEach(lane.segments) { segment in
                let segmentWidth = max(
                    Spacing.xxxl + Spacing.m,
                    (segment.positionEnd - segment.positionStart) * chartWidth
                )
                Button {
                    selectedDate = segment.originalStart
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(segment.title)
                            .font(AppFont.footnoteMedium)
                            .foregroundStyle(Color.gymText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if segment.isOpenEnded {
                            Text("Current")
                                .font(AppFont.caption2)
                                .foregroundStyle(Color.gymSubduedText)
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, Spacing.xxs)
                                .background(Color.gymBackground.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                            Image(systemName: AppIcon.chevronRight)
                                .font(AppFont.caption2)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.horizontal, Spacing.s)
                    .frame(
                        width: segmentWidth,
                        height: barHeight,
                        alignment: .leading
                    )
                    .background(laneSurface(segment.lane))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.small)
                            .stroke(laneTint(segment.lane), lineWidth: Spacing.xxs)
                    }
                }
                .buttonStyle(.plain)
                .frame(width: segmentWidth, height: barHeight)
                .offset(
                    x: segment.positionStart * chartWidth,
                    y: CGFloat(segment.sublane) * (barHeight + sublaneSpacing)
                )
                .accessibilityLabel(segmentAccessibilityLabel(segment))
                .accessibilityHint("Select this chapter's evidence")
                .accessibilityIdentifier("training-journey-timeline-segment-\(segment.chapterID)")
            }

            Rectangle()
                .fill(Color.gymAccent)
                .frame(width: Spacing.xxs, height: trackHeight - Spacing.s)
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

    private var selectionCard: some View {
        let selection = projection.selection(for: selectedDate)
        return GymCard {
            GymEyebrow("Selected date")
            Text(selectedDate.formatted(date: .complete, time: .omitted))
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymText)

            if selection.hits.isEmpty {
                Text("No chapter on this date")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            } else {
                ForEach(selection.hits) { hit in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                        Text(hit.title)
                            .font(AppFont.footnoteMedium)
                            .foregroundStyle(Color.gymText)
                        Spacer(minLength: Spacing.s)
                        Text(hitSummary(hit))
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
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
                GymEyebrow("Practice transitions")
                ForEach(selectedTransitions) { marker in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(TrainingJourneyTimelineTransitionPresentation.title(marker))
                            .font(AppFont.footnoteMedium)
                            .foregroundStyle(Color.gymText)
                        Text(TrainingJourneyTimelineTransitionPresentation.evidenceSummary(marker))
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(TrainingJourneyTimelineTransitionPresentation.accessibilityLabel(marker))
                }
            }
        }
        .accessibilityIdentifier("training-journey-timeline-selection")
    }

    private func transitionMarkers(on date: Date) -> [TrainingJourneyPracticeTransitionMarker] {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        return practiceTransitions.markers
            .filter { $0.normalizedDate == normalizedDate }
            .sorted(by: TrainingJourneyTimelineTransitionPresentation.order)
    }

    private func tickLabel(_ tick: TrainingJourneyTimelineTick) -> String {
        guard let month = tick.month else { return String(tick.year) }
        let date = Calendar.current.date(from: DateComponents(year: tick.year, month: month)) ?? tick.date
        return date.formatted(.dateTime.month(.abbreviated))
    }

    private func laneTint(_ lane: TrainingJourneyTimelineLane) -> Color {
        switch lane {
        case .fixedPlan: .gymPrimary
        case .repeatingPlan: .gymSecondary
        case .freeTraining: .gymAccent
        }
    }

    private func laneSurface(_ lane: TrainingJourneyTimelineLane) -> Color {
        switch lane {
        case .fixedPlan: .gymPrimarySurface
        case .repeatingPlan: .gymSecondarySurface
        case .freeTraining: .gymAccentSurface
        }
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
        "\(segment.completedWorkouts) workouts, \(segment.personalRecords) records"
    }

    private func hitSummary(_ hit: TrainingJourneyTimelineHit) -> String {
        "\(hit.completedWorkouts) workouts · \(hit.personalRecords) records"
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
        marker.kind.isDeclared ? .gymPrimary : (marker.isObserved ? .gymSecondary : .gymAccent)
    }

    private func transitionSurface(_ marker: TrainingJourneyPracticeTransitionMarker) -> Color {
        marker.kind.isDeclared ? .gymPrimarySurface : (marker.isObserved ? .gymSecondarySurface : .gymAccentSurface)
    }

    private func isMarkerSelected(_ marker: TrainingJourneyPracticeTransitionMarker) -> Bool {
        Calendar.current.startOfDay(for: selectedDate) == marker.normalizedDate
    }
}
