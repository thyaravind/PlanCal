import SwiftData
import SwiftUI

struct PlannerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlannerTask.createdAt) private var tasks: [PlannerTask]
    @Query(sort: \MarkdownNote.updatedAt, order: .reverse) private var notes: [MarkdownNote]
    @AppStorage("planning.visibleScales") private var visibleScaleStorage = PlanningScale.defaultVisibleStorageValue
    @AppStorage("planning.selectedScale") private var selectedScaleStorage = PlanningScale.daily.rawValue
    @State private var scale: PlanningScale = .daily
    @State private var anchorDate = Date.now
    @State private var isAddingTask = false
    @State private var isQuickAddingTask = false
    @State private var quickTaskTitle = ""
    @FocusState private var isQuickTaskFocused: Bool

    private var visibleScales: [PlanningScale] {
        PlanningScale.visibleScales(from: visibleScaleStorage)
    }

    private var periodTasks: [PlannerTask] {
        tasks.filter { $0.belongs(to: scale, anchor: anchorDate) }
    }

    private var periodNote: MarkdownNote? {
        notes.first {
            $0.scope == .period && $0.scale == scale && scale.interval(containing: anchorDate).contains($0.anchorDate)
        }
    }

    private var periodIdentity: String {
        let periodStart = scale.interval(containing: anchorDate).start.timeIntervalSinceReferenceDate
        return "\(scale.rawValue)-\(periodStart)"
    }

    private var openTaskCount: Int {
        periodTasks.filter { !$0.isCompleted }.count
    }

    private var openTaskCountsByPeriodStart: [Date: Int] {
        tasks.reduce(into: [:]) { counts, task in
            guard !task.isCompleted, task.scale == scale else { return }
            let periodStart = scale.interval(containing: task.scheduledDate).start
            counts[periodStart, default: 0] += 1
        }
    }

    private var horizonTint: Color {
        PlancalDesign.tint(for: scale)
    }

    private var showsPageHeader: Bool {
        #if os(iOS)
        false
        #else
        true
        #endif
    }

    var body: some View {
        let openTaskCounts = openTaskCountsByPeriodStart

        ZStack {
            AtmosphericBackground(accent: horizonTint)
            GeometryReader { geometry in
                let contentWidth = min(
                    PlancalDesign.plannerContentWidth,
                    max(0, geometry.size.width - (PlancalDesign.pagePadding * 2))
                )

                ScrollViewReader { pageProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 26) {
                            if showsPageHeader {
                                planHeader
                                .frame(width: contentWidth, alignment: .leading)
                            }

                            RollingPeriodPicker(scale: scale, selection: $anchorDate) { date in
                                let periodStart = scale.interval(containing: date).start
                                return openTaskCounts[periodStart, default: 0]
                            }
                            .frame(width: contentWidth)

                            VStack(alignment: .leading, spacing: 12) {
                                taskSectionHeader

                                Group {
                                    if periodTasks.isEmpty && !isQuickAddingTask {
                                        EmptyStateCard(
                                            icon: scale.icon,
                                            title: "A fresh \(scale.shortTitle.lowercased())",
                                            message: "Add the first task when you’re ready."
                                        )
                                    } else {
                                        GlassCard(contentPadding: 0) {
                                            VStack(spacing: 0) {
                                                if isQuickAddingTask {
                                                    quickTaskEntry
                                                    if !periodTasks.isEmpty {
                                                        Divider().padding(.horizontal, 20)
                                                    }
                                                }

                                                ForEach(periodTasks) { task in
                                                    TaskRow(task: task) {
                                                        withAnimation(reduceMotion ? nil : .snappy) { modelContext.delete(task) }
                                                    }
                                                    if task.id != periodTasks.last?.id {
                                                        Divider().padding(.horizontal, 20)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            .frame(width: contentWidth, alignment: .leading)

                            InlinePeriodNote(
                                note: periodNote,
                                scale: scale,
                                anchorDate: anchorDate
                            ) { isFocused in
                                guard isFocused else { return }
                                revealPeriodNote(using: pageProxy)
                            }
                            .id("period-note-editor")
                            .frame(width: contentWidth, alignment: .leading)
                        }
                        .frame(width: contentWidth, alignment: .leading)
                        .frame(width: geometry.size.width, alignment: .center)
                        .padding(.vertical, showsPageHeader ? 28 : 12)
                    }
                }
            }
        }
        .tint(horizonTint)
        .adaptiveNavigationTitle("Plan")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                PlanningScaleControl(scales: visibleScales, selection: $scale)
            }
            #endif

            ToolbarItem(placement: .primaryAction) {
                Button { isAddingTask = true } label: {
                    PlancalGlyph(icon: .add, weight: .bold, size: 18)
                        .accessibilityLabel("New task")
                }
                    .buttonStyle(.glassProminent)
                    .tint(horizonTint)
                    .plancalHoverEffect(scale: 1.06, lifts: true)
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $isAddingTask) {
            TaskEditor(initialScale: scale, initialDate: anchorDate)
        }
        .onAppear {
            restoreSelectedScale()
        }
        .onChange(of: visibleScaleStorage) { _, _ in
            restoreSelectedScale()
        }
        .onChange(of: scale) { _, newScale in
            selectedScaleStorage = newScale.rawValue
        }
        .onChange(of: periodIdentity) { _, _ in
            cancelQuickAdd()
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: periodIdentity)
    }

    private var planHeader: some View {
        HStack(alignment: .bottom, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Capsule()
                        .fill(horizonTint)
                        .frame(width: 18, height: 4)
                    Text(scale.title.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.45)
                        .foregroundStyle(.secondary)
                }

                Text(scale.label(for: anchorDate))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 24)

            PlanningScaleControl(scales: visibleScales, selection: $scale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var taskSectionHeader: some View {
        ViewThatFits(in: .horizontal) {
            taskSectionHeaderContent(compact: false)
            taskSectionHeaderContent(compact: true)
        }
    }

    private func taskSectionHeaderContent(compact: Bool) -> some View {
        HStack(spacing: compact ? 9 : 12) {
            Text("Tasks")
                .font(.title3.bold())

            HStack(spacing: 6) {
                Circle()
                    .fill(openTaskCount == 0 ? Color.secondary : horizonTint)
                    .frame(width: 6, height: 6)
                Text("\(openTaskCount) open")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Button {
                if isQuickAddingTask {
                    cancelQuickAdd()
                } else {
                    beginQuickAdd()
                }
            } label: {
                Group {
                    if compact {
                        PlancalGlyph(icon: isQuickAddingTask ? .confirm : .add, weight: .bold, size: 17)
                    } else {
                        PlancalIconLabel(
                            title: isQuickAddingTask ? "Done" : "Add task",
                            icon: isQuickAddingTask ? .confirm : .add,
                            weight: .bold,
                            size: 17
                        )
                    }
                }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, compact ? 9 : 12)
                    .frame(height: 36)
                    .foregroundStyle(.white)
                    .background(horizonTint.gradient, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 0.75)
                    }
                    .shadow(color: horizonTint.opacity(0.2), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .plancalHoverEffect(scale: 1.035, lifts: true)
            .accessibilityLabel(isQuickAddingTask ? "Finish adding tasks" : "Add task inline")
        }
    }

    private var quickTaskEntry: some View {
        HStack(spacing: 12) {
            PlancalGlyph(icon: .incomplete, size: 21)
                .foregroundStyle(.tertiary)

            TextField("New \(scale.shortTitle.lowercased()) task", text: $quickTaskTitle)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .focused($isQuickTaskFocused)
                .onSubmit(addQuickTask)

            InlineTaskCancelButton(action: cancelQuickAdd)

            InlineTaskSubmitButton(
                title: "Add",
                tint: horizonTint,
                isDisabled: quickTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                action: addQuickTask
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func beginQuickAdd() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            isQuickAddingTask = true
        }
        Task { @MainActor in
            await Task.yield()
            isQuickTaskFocused = true
        }
    }

    private func cancelQuickAdd() {
        isQuickTaskFocused = false
        quickTaskTitle = ""
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
            isQuickAddingTask = false
        }
    }

    private func addQuickTask() {
        let cleanTitle = quickTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let periodStart = scale.interval(containing: anchorDate).start
        modelContext.insert(PlannerTask(title: cleanTitle, scale: scale, scheduledDate: periodStart))
        try? modelContext.save()
        quickTaskTitle = ""

        Task { @MainActor in
            await Task.yield()
            isQuickTaskFocused = true
        }
    }

    private func restoreSelectedScale() {
        if let storedScale = PlanningScale(rawValue: selectedScaleStorage),
           visibleScales.contains(storedScale) {
            scale = storedScale
            return
        }

        guard let firstVisibleScale = visibleScales.first else { return }
        scale = firstVisibleScale
        selectedScaleStorage = firstVisibleScale.rawValue
    }

    private func revealPeriodNote(using proxy: ScrollViewProxy) {
        #if os(iOS)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
                proxy.scrollTo("period-note-editor", anchor: .bottom)
            }
        }
        #endif
    }
}
