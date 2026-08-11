import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct PlannerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PlannerTask.createdAt, order: .reverse) private var tasks: [PlannerTask]
    @Query(sort: \MarkdownNote.updatedAt, order: .reverse) private var notes: [MarkdownNote]
    @AppStorage("planning.visibleScales") private var visibleScaleStorage = PlanningScale.defaultVisibleStorageValue
    @AppStorage("planning.selectedScale") private var selectedScaleStorage = PlanningScale.daily.rawValue
    @AppStorage("calendar.completedTasksExpanded") private var showsCompletedTasks = true
    @State private var scale: PlanningScale = .daily
    @State private var anchorDate = Date.now
    @State private var isQuickAddingTask = false
    @State private var quickTaskTitle = ""
    @State private var quickTaskScale = PlanningScale.daily
    @State private var quickTaskDate = Date.now
    @State private var quickTaskPriority = TaskPriority.gentle
    @State private var quickPersistedTask: PlannerTask?
    @State private var quickComposerID = UUID()

    private var visibleScales: [PlanningScale] {
        PlanningScale.visibleScales(from: visibleScaleStorage)
    }

    private var periodTasks: [PlannerTask] {
        tasks.filter { $0.belongs(to: scale, anchor: anchorDate) }
    }

    private var openPeriodTasks: [PlannerTask] {
        periodTasks.filter { !$0.isCompleted }
    }

    private var completedPeriodTasks: [PlannerTask] {
        periodTasks.filter(\.isCompleted)
    }

    private var displayedPeriodTasks: [PlannerTask] {
        openPeriodTasks.filter { $0.id != quickPersistedTask?.id }
    }

    private var periodNotes: [MarkdownNote] {
        PeriodNoteResolver.notes(
            from: notes,
            scale: scale,
            anchorDate: anchorDate
        )
    }

    private var periodIdentity: String {
        let periodStart = scale.interval(containing: anchorDate).start.timeIntervalSinceReferenceDate
        return "\(scale.rawValue)-\(periodStart)"
    }

    private var completedTaskCount: Int {
        periodTasks.filter(\.isCompleted).count
    }

    private var quickTaskHasText: Bool {
        !quickTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var horizonTint: Color {
        PlancalDesign.tint(for: scale)
    }

    private var isCurrentPeriod: Bool {
        scale.contains(.now, inPeriodContaining: anchorDate)
    }

    private var showsPageHeader: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        true
        #endif
    }

    private var isCompactMobile: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    var body: some View {
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

                            RollingPeriodPicker(scale: scale, selection: $anchorDate)
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
                                                    if !displayedPeriodTasks.isEmpty
                                                        || !completedPeriodTasks.isEmpty {
                                                        Divider().padding(.horizontal, 20)
                                                    }
                                                }

                                                ForEach(displayedPeriodTasks) { task in
                                                    TaskRow(task: task) {
                                                        withAnimation(reduceMotion ? nil : .snappy) { modelContext.delete(task) }
                                                    }
                                                    if task.id != displayedPeriodTasks.last?.id {
                                                        Divider().padding(.horizontal, 20)
                                                    }
                                                }

                                                if !completedPeriodTasks.isEmpty {
                                                    if !displayedPeriodTasks.isEmpty {
                                                        Divider().padding(.horizontal, 20)
                                                    }
                                                    CompletedTasksSection(
                                                        isExpanded: $showsCompletedTasks,
                                                        tasks: completedPeriodTasks
                                                    ) { task in
                                                        withAnimation(reduceMotion ? nil : .snappy) {
                                                            modelContext.delete(task)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            .frame(width: contentWidth, alignment: .leading)

                            PeriodNotesSection(
                                notes: periodNotes,
                                scale: scale,
                                anchorDate: anchorDate
                            ) { isFocused in
                                guard isFocused else { return }
                                TaskEditingSignals.dismiss()
                                revealPeriodNote(using: pageProxy)
                            }
                            .id("period-note-editor")
                            .frame(width: contentWidth, alignment: .leading)
                        }
                        .frame(width: contentWidth, alignment: .leading)
                        .frame(width: geometry.size.width, alignment: .center)
                        .padding(.vertical, showsPageHeader ? 28 : 12)
                    }
                    .background {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                TaskEditingSignals.dismiss()
                            }
                    }
                }
            }
        }
        .tint(horizonTint)
        .adaptiveNavigationTitle("Calendar")
        .toolbar {
            #if os(iOS)
            if isCompactMobile {
                ToolbarItem(placement: .topBarLeading) {
                    PlanningScaleControl(scales: visibleScales, selection: $scale)
                }

                if !isCurrentPeriod {
                    ToolbarItem(placement: .topBarTrailing) {
                        GoToCurrentPeriodButton(
                            tint: horizonTint,
                            action: goToToday
                        )
                    }
                }
            }
            #endif
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
            TaskEditingSignals.dismiss()
            finishQuickAdd()
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

            HStack(spacing: 10) {
                #if os(iOS)
                if !isCurrentPeriod {
                    GoToCurrentPeriodButton(
                        tint: horizonTint,
                        action: goToToday
                    )
                }
                #else
                GoToCurrentPeriodButton(
                    tint: horizonTint,
                    action: goToToday
                )
                .opacity(isCurrentPeriod ? 0 : 1)
                .allowsHitTesting(!isCurrentPeriod)
                .accessibilityHidden(isCurrentPeriod)
                #endif

                PlanningScaleControl(scales: visibleScales, selection: $scale)
            }
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

            HStack(spacing: 7) {
                TaskCompletionPie(
                    completed: completedTaskCount,
                    total: periodTasks.count,
                    tint: horizonTint,
                    size: 20
                )
                Text("\(completedTaskCount)/\(periodTasks.count)")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Button {
                if isQuickAddingTask, quickTaskHasText {
                    beginNextQuickAdd()
                } else if !isQuickAddingTask {
                    beginQuickAdd()
                }
            } label: {
                Group {
                    if compact {
                        PlancalGlyph(icon: .add, weight: .bold, size: 17)
                    } else {
                        PlancalIconLabel(
                            title: "Add task",
                            icon: .add,
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
            .accessibilityLabel("Add task inline")
        }
    }

    private var quickTaskEntry: some View {
        InlineTaskComposer(
            title: $quickTaskTitle,
            scale: $quickTaskScale,
            date: $quickTaskDate,
            priority: $quickTaskPriority,
            placeholder: "New \(scale.shortTitle.lowercased()) task",
            tint: PlancalDesign.tint(for: quickTaskScale),
            showsCloseButton: !quickTaskHasText,
            onSubmit: {
                guard quickTaskHasText else { return }
                beginNextQuickAdd()
            },
            onDismiss: finishQuickAdd
        )
        .id(quickComposerID)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .task(id: quickTaskRevision) {
            guard isQuickAddingTask else { return }
            do {
                try await Task.sleep(for: .milliseconds(450))
                persistQuickTaskIfValid()
            } catch {
                // A newer draft superseded this pending autosave.
            }
        }
    }

    private func beginQuickAdd() {
        TaskEditingSignals.dismiss()
        quickTaskTitle = ""
        quickTaskScale = scale
        quickTaskDate = scale.interval(containing: anchorDate).start
        quickTaskPriority = .gentle
        quickPersistedTask = nil
        quickComposerID = UUID()
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            isQuickAddingTask = true
        }
    }

    private func beginNextQuickAdd() {
        persistQuickTaskIfValid()
        quickTaskTitle = ""
        quickTaskScale = scale
        quickTaskDate = scale.interval(containing: anchorDate).start
        quickTaskPriority = .gentle
        quickPersistedTask = nil
        quickComposerID = UUID()
    }

    private func finishQuickAdd() {
        guard isQuickAddingTask else { return }

        let cleanTitle = quickTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty, let quickPersistedTask {
            modelContext.delete(quickPersistedTask)
            try? modelContext.save()
        } else {
            persistQuickTaskIfValid()
        }

        quickTaskTitle = ""
        quickPersistedTask = nil
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
            isQuickAddingTask = false
        }
    }

    private var quickTaskRevision: String {
        guard isQuickAddingTask else { return "inactive" }
        return [
            quickTaskTitle,
            quickTaskScale.rawValue,
            String(quickTaskDate.timeIntervalSinceReferenceDate),
            quickTaskPriority.rawValue
        ].joined(separator: "|")
    }

    private func persistQuickTaskIfValid() {
        let cleanTitle = quickTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let normalizedDate = quickTaskScale.interval(containing: quickTaskDate).start
        if let quickPersistedTask {
            quickPersistedTask.title = cleanTitle
            quickPersistedTask.scale = quickTaskScale
            quickPersistedTask.scheduledDate = normalizedDate
            quickPersistedTask.originalDate = normalizedDate
            quickPersistedTask.priority = quickTaskPriority
            quickPersistedTask.updatedAt = .now
        } else {
            let task = PlannerTask(
                title: cleanTitle,
                scale: quickTaskScale,
                scheduledDate: normalizedDate,
                priority: quickTaskPriority
            )
            modelContext.insert(task)
            quickPersistedTask = task
        }

        try? modelContext.save()
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

    private func goToToday() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) {
            anchorDate = scale.interval(containing: .now).start
        }
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
