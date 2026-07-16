import SwiftUI

struct PlanningScaleControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

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

    @ViewBuilder
    var body: some View {
        if requiresCompactLabels {
            scaleButtons(usesFullLabels: false)
        } else {
            ViewThatFits(in: .horizontal) {
                scaleButtons(usesFullLabels: true)
                scaleButtons(usesFullLabels: false)
            }
        }
    }

    private func scaleButtons(usesFullLabels: Bool) -> some View {
        HStack(spacing: 2) {
            ForEach(scales) { scale in
                PlanningScaleButton(
                    scale: scale,
                    isSelected: scale == selection,
                    usesFullLabel: usesFullLabels,
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

    private var requiresCompactLabels: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }
}

private struct PlanningScaleButton: View {
    let scale: PlanningScale
    let isSelected: Bool
    let usesFullLabel: Bool
    let selectionNamespace: Namespace.ID
    let action: () -> Void

    private var tint: Color {
        PlancalDesign.tint(for: scale)
    }

    var body: some View {
        Button(action: action) {
            Text(
                usesFullLabel
                    ? scale.shortTitle
                    : scale.toolbarLabel(isSelected: isSelected)
            )
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
                            .matchedGeometryEffect(
                                id: "selected-scale-\(usesFullLabel)",
                                in: selectionNamespace
                            )
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

struct GoToCurrentPeriodButton: View {
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                PlancalIconLabel(
                    title: "Go to today",
                    icon: .today,
                    weight: .bold,
                    size: 15
                )
                PlancalGlyph(icon: .today, weight: .bold, size: 17)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(minWidth: 36, minHeight: 36)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(tint.opacity(0.28), lineWidth: 0.8)
                    .allowsHitTesting(false)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .plancalHoverEffect(scale: 1.04, lifts: true)
        .accessibilityLabel("Go to today")
    }
}

struct RollingPeriodPicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let scale: PlanningScale
    @Binding var selection: Date

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
        selection: Binding<Date>
    ) {
        self.scale = scale
        _selection = selection
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
                                    isCurrent: scale.contains(.now, inPeriodContaining: date)
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
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.035),
                                .init(color: .black, location: 0.965),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
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
        .onChange(of: selection) { _, newSelection in
            let representedSelection = scale.offset(originDate, by: committedOffset)
            guard !scale.contains(
                newSelection,
                inPeriodContaining: representedSelection
            ) else {
                return
            }

            originDate = newSelection
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
    let action: () -> Void

    private var tint: Color { PlancalDesign.tint(for: scale) }

    @ViewBuilder
    var body: some View {
        #if os(macOS)
        Button(action: action) {
            periodContent
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onEnded { value in
                    let horizontalDistance = abs(value.translation.width)
                    let verticalDistance = abs(value.translation.height)
                    guard horizontalDistance < 6, verticalDistance < 6 else { return }
                    action()
                }
        )
        .plancalHoverEffect(scale: 1.025)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(accessibilityLabel)
        #else
        Button(action: action) {
            periodContent
        }
        .buttonStyle(.plain)
        .plancalHoverEffect(scale: 1.025)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        #endif
    }

    private var periodContent: some View {
        VStack(spacing: 6) {
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
        }
        .frame(width: buttonWidth, height: 68)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            if !isSelected && isCurrent {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(tint.opacity(0.62), lineWidth: 1.5)
                    .padding(1)
                    .allowsHitTesting(false)
            }
        }
    }

    private var topLabel: String {
        let calendar = Calendar.autoupdatingCurrent
        switch scale {
        case .daily:
            return date.formatted(.dateTime.weekday(.abbreviated)).uppercased()
        case .weekly:
            return "W\(calendar.component(.weekOfYear, from: date))"
        case .monthly:
            return date.formatted(.dateTime.year())
        case .quarterly:
            return date.formatted(.dateTime.year())
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
        case .monthly:
            return date.formatted(.dateTime.month(.abbreviated))
        case .quarterly:
            let quarter = ((calendar.component(.month, from: date) - 1) / 3) + 1
            return "Q\(quarter)"
        case .yearly:
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
        return "\(scale.label(for: date))\(currentSuffix)"
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
