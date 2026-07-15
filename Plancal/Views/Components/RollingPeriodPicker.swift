import SwiftUI

struct PlanningScaleControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let scales: [PlanningScale]
    @Binding var selection: PlanningScale
    @Namespace private var selectedScale

    init(
        scales: [PlanningScale] = PlanningScale.allCases,
        selection: Binding<PlanningScale>
    ) {
        self.scales = scales.isEmpty ? [.daily] : scales
        _selection = selection
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(scales) { scale in
                PlanningScaleButton(
                    scale: scale,
                    isSelected: scale == selection,
                    selectionNamespace: selectedScale
                ) {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
                        selection = scale
                    }
                }
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.75)
                .allowsHitTesting(false)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: 38)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Planning scale")
    }
}

private struct PlanningScaleButton: View {
    let scale: PlanningScale
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
    let action: () -> Void

    private var tint: Color {
        PlancalDesign.tint(for: scale)
    }

    var body: some View {
        Button(action: action) {
            Text(scale.toolbarLabel(isSelected: isSelected))
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .lineLimit(1)
                .contentTransition(.opacity)
                .padding(.horizontal, isSelected ? 10 : 8)
                .frame(minHeight: 32)
                .contentShape(Capsule())
                .background {
                    if isSelected {
                        Capsule()
                            .fill(tint.gradient)
                            .matchedGeometryEffect(id: "selected-scale", in: selectionNamespace)
                            .shadow(color: tint.opacity(0.2), radius: 6, y: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .plancalHoverEffect(scale: 1.045)
        .accessibilityLabel(scale.shortTitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct RollingPeriodPicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let scale: PlanningScale
    @Binding var selection: Date
    let openTaskCount: (Date) -> Int

    @State private var originDate: Date
    @State private var centeredOffset: Int? = 0
    @State private var committedOffset = 0
    @State private var isScrolling = false
    @State private var lowerLoadedOffset = -18
    @State private var upperLoadedOffset = 18
    @State private var scrollResetID = UUID()

    private let loadChunk = 18
    private let preloadThreshold = 5
    private let maximumLoadedPeriodCount = 145

    private var loadedOffsets: ClosedRange<Int> {
        lowerLoadedOffset...upperLoadedOffset
    }

    init(
        scale: PlanningScale,
        selection: Binding<Date>,
        openTaskCount: @escaping (Date) -> Int = { _ in 0 }
    ) {
        self.scale = scale
        _selection = selection
        self.openTaskCount = openTaskCount
        _originDate = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        GeometryReader { geometry in
            let buttonWidth = scale.rollerButtonWidth
            let centerInset = max(18, (geometry.size.width - buttonWidth) / 2)

            ZStack {
                RoundedRectangle(cornerRadius: PlancalDesign.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PlancalDesign.tint(for: scale).gradient)
                    .frame(width: buttonWidth, height: 68)
                    .shadow(color: PlancalDesign.tint(for: scale).opacity(0.24), radius: 12, y: 5)
                    .allowsHitTesting(false)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 8) {
                            ForEach(loadedOffsets, id: \.self) { offset in
                                let date = scale.offset(originDate, by: offset)
                                PeriodButton(
                                    scale: scale,
                                    date: date,
                                    isSelected: offset == centeredOffset,
                                    isCurrent: scale.contains(.now, inPeriodContaining: date),
                                    openTaskCount: openTaskCount(date)
                                ) {
                                    guard offset != centeredOffset else { return }
                                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.32)) {
                                        centeredOffset = offset
                                    }
                                    commitSelection(at: offset)
                                }
                                .id(offset)
                                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1 : 0.52)
                                        .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, centerInset, for: .scrollContent)
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                    .scrollPosition(id: $centeredOffset, anchor: .center)
                    .onScrollPhaseChange { _, newPhase in
                        isScrolling = newPhase.isScrolling
                        if !newPhase.isScrolling {
                            commitSelection(at: centeredOffset)
                            if let centeredOffset {
                                trimLoadedOffsetsIfNeeded(around: centeredOffset)
                            }
                        }
                    }
                    .onAppear {
                        let targetOffset = committedOffset
                        Task { @MainActor in
                            await Task.yield()
                            proxy.scrollTo(targetOffset, anchor: .center)
                        }
                    }
                    .id(scrollResetID)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: PlancalDesign.cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: PlancalDesign.cornerRadius, style: .continuous))
        }
        .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 76)
        .onChange(of: centeredOffset) { _, newOffset in
            guard let newOffset else { return }
            extendLoadedOffsets(around: newOffset)
            if !isScrolling {
                commitSelection(at: newOffset)
            }
        }
        .onChange(of: scale) { _, _ in
            originDate = selection
            centeredOffset = 0
            committedOffset = 0
            isScrolling = false
            resetLoadedOffsets()
            scrollResetID = UUID()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(scale.title) periods")
    }

    private func commitSelection(at offset: Int?) {
        guard let offset else { return }
        committedOffset = offset

        let newSelection = scale.offset(originDate, by: offset)
        guard !scale.contains(selection, inPeriodContaining: newSelection) else { return }
        selection = newSelection
    }

    private func resetLoadedOffsets() {
        lowerLoadedOffset = -loadChunk
        upperLoadedOffset = loadChunk
    }

    private func extendLoadedOffsets(around offset: Int) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if offset - lowerLoadedOffset <= preloadThreshold {
                lowerLoadedOffset -= loadChunk
            }
            if upperLoadedOffset - offset <= preloadThreshold {
                upperLoadedOffset += loadChunk
            }
        }
    }

    private func trimLoadedOffsetsIfNeeded(around offset: Int) {
        let loadedPeriodCount = upperLoadedOffset - lowerLoadedOffset + 1
        guard loadedPeriodCount > maximumLoadedPeriodCount else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            let retainedRadius = maximumLoadedPeriodCount / 2
            lowerLoadedOffset = offset - retainedRadius
            upperLoadedOffset = offset + retainedRadius
        }
    }
}

private struct PeriodButton: View {
    let scale: PlanningScale
    let date: Date
    let isSelected: Bool
    let isCurrent: Bool
    let openTaskCount: Int
    let action: () -> Void

    private var tint: Color { PlancalDesign.tint(for: scale) }

    @ViewBuilder
    var body: some View {
        #if os(macOS)
        periodButton
            .highPriorityGesture(TapGesture().onEnded { action() })
        #else
        periodButton
        #endif
    }

    private var periodButton: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(topLabel)
                    .font(.caption2.weight(.bold))
                    .tracking(0.35)
                    .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                    .lineLimit(1)

                Text(primaryLabel)
                    .font(primaryFont)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .contentTransition(.numericText())

                HStack(spacing: 5) {
                    Circle()
                        .fill(isSelected ? Color.white : tint)
                        .frame(width: 5, height: 5)
                        .opacity(isCurrent ? 1 : 0)

                    if openTaskCount > 0 {
                        Text(openTaskCount, format: .number)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(isSelected ? Color.white : tint)
                            .padding(.horizontal, 5)
                            .frame(minHeight: 15)
                            .background(
                                isSelected ? Color.white.opacity(0.18) : tint.opacity(0.11),
                                in: Capsule()
                            )
                            .accessibilityHidden(true)
                    }
                }
                .frame(height: 15)
            }
            .frame(width: buttonWidth, height: 68)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background {
                if !isSelected && isCurrent {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tint.opacity(0.08))
                }
            }
        }
        .buttonStyle(.plain)
        .plancalHoverEffect(scale: 1.025)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(accessibilityLabel)
    }

    private var topLabel: String {
        let calendar = Calendar.autoupdatingCurrent
        switch scale {
        case .daily:
            return date.formatted(.dateTime.weekday(.abbreviated)).uppercased()
        case .weekly:
            return "W\(calendar.component(.weekOfYear, from: date))"
        case .monthly:
            return date.formatted(.dateTime.month(.abbreviated)).uppercased()
        case .quarterly:
            let quarter = ((calendar.component(.month, from: date) - 1) / 3) + 1
            return "Q\(quarter)"
        case .yearly:
            return isCurrent ? "CURRENT" : "YEAR"
        }
    }

    private var primaryLabel: String {
        let calendar = Calendar.autoupdatingCurrent
        switch scale {
        case .daily:
            return date.formatted(.dateTime.day())
        case .weekly:
            let interval = scale.interval(containing: date)
            let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let sameMonth = calendar.component(.month, from: interval.start) == calendar.component(.month, from: end)
            if sameMonth {
                return "\(interval.start.formatted(.dateTime.day()))–\(end.formatted(.dateTime.day())) \(end.formatted(.dateTime.month(.abbreviated)))"
            }
            return "\(interval.start.formatted(.dateTime.day().month(.abbreviated)))–\(end.formatted(.dateTime.day().month(.abbreviated)))"
        case .monthly, .quarterly, .yearly:
            return date.formatted(.dateTime.year())
        }
    }

    private var primaryFont: Font {
        switch scale {
        case .daily:
            return .title3.weight(.bold)
        default:
            return .subheadline.weight(.semibold)
        }
    }

    private var buttonWidth: CGFloat {
        scale.rollerButtonWidth
    }

    private var accessibilityLabel: String {
        let currentSuffix = isCurrent ? ", current period" : ""
        let taskSuffix = openTaskCount == 0 ? "" : ", \(openTaskCount) open \(openTaskCount == 1 ? "task" : "tasks")"
        return "\(scale.label(for: date))\(currentSuffix)\(taskSuffix)"
    }
}

private extension PlanningScale {
    var rollerButtonWidth: CGFloat {
        switch self {
        case .daily: 58
        case .weekly: 106
        case .monthly: 78
        case .quarterly: 78
        case .yearly: 82
        }
    }
}
