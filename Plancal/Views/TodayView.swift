import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationService.self) private var notificationService
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @Query(sort: \PlannerTask.createdAt, order: .reverse) private var tasks: [PlannerTask]
    @Query(sort: \PlannerEvent.startDate) private var events: [PlannerEvent]
    @AppStorage("notifications.enabled") private var notificationsEnabled = true
    @AppStorage("notifications.hour") private var notificationHour = 8
    @AppStorage("notifications.minute") private var notificationMinute = 0
    @AppStorage("planning.visibleScales") private var visibleScaleStorage = PlanningScale.defaultVisibleStorageValue
    @AppStorage("today.selectedHorizonScale") private var selectedHorizonScaleStorage = PlanningScale.weekly.rawValue
    @AppStorage("today.completedTasksExpanded") private var showsCompletedTodayTasks = false
    @State private var isAddingTask = false
    @State private var isQuickAddingTodayTask = false
    @State private var quickTodayTaskTitle = ""
    @State private var quickTodayTaskScale = PlanningScale.daily
    @State private var quickTodayTaskDate = Date.now
    @State private var quickTodayTaskPriority = TaskPriority.gentle
    @State private var quickPersistedTodayTask: PlannerTask?
    @State private var quickTodayComposerID = UUID()
    @State private var selectedHorizonScale: PlanningScale = .weekly
    @State private var isQuickAddingHorizonTask = false
    @State private var quickHorizonTaskTitle = ""
    @State private var quickHorizonTaskScale = PlanningScale.weekly
    @State private var quickHorizonTaskDate = Date.now
    @State private var quickHorizonTaskPriority = TaskPriority.gentle
    @State private var quickPersistedHorizonTask: PlannerTask?
    @State private var quickHorizonComposerID = UUID()
    private let today = Date.now

    private var enabledHorizonScales: [PlanningScale] {
        PlanningScale.visibleScales(from: visibleScaleStorage).filter { $0 != .daily }
    }

    private var freshDailyTasks: [PlannerTask] {
        tasks.filter { !$0.isCompleted && $0.scale == .daily && $0.carryCount == 0 && $0.belongs(to: .daily, anchor: today) }
    }

    private var displayedFreshDailyTasks: [PlannerTask] {
        freshDailyTasks.filter { $0.id != quickPersistedTodayTask?.id }
    }

    private var completedDailyTasks: [PlannerTask] {
        tasks.filter {
            $0.isCompleted
                && $0.scale == .daily
                && $0.belongs(to: .daily, anchor: today)
        }
    }

    private var carriedTasks: [PlannerTask] {
        tasks.filter {
            !$0.isCompleted
                && $0.carryCount > 0
                && $0.scale.contains($0.scheduledDate, inPeriodContaining: today)
        }
    }

    private var horizonTasks: [PlannerTask] {
        tasks.filter {
            !$0.isCompleted
                && $0.scale == selectedHorizonScale
                && $0.carryCount == 0
                && $0.belongs(to: selectedHorizonScale, anchor: today)
        }
    }

    private var displayedHorizonTasks: [PlannerTask] {
        horizonTasks.filter { $0.id != quickPersistedHorizonTask?.id }
    }

    private var todayScheduledTasks: [PlannerTask] {
        tasks.filter { $0.scale == .daily && $0.belongs(to: .daily, anchor: today) }
    }

    private var todayOpenCount: Int {
        todayScheduledTasks.filter { !$0.isCompleted }.count
    }

    private var todayCompletedCount: Int {
        todayScheduledTasks.filter(\.isCompleted).count
    }

    private var quickTodayTaskHasText: Bool {
        !quickTodayTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var quickHorizonTaskHasText: Bool {
        !quickHorizonTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var overdueTasks: [PlannerTask] {
        tasks.filter { $0.isOverdue(at: today) }
    }

    private var todayEvents: [PlannerEvent] {
        let day = PlanningScale.daily.interval(containing: today)
        return events.filter { $0.startDate < day.end && $0.endDate >= day.start }
    }

    var body: some View {
        ZStack {
            AtmosphericBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if showsPageHeader {
                        PageHeader(
                            eyebrow: today.formatted(.dateTime.weekday(.wide)),
                            title: "Good \(dayPart)",
                            subtitle: today.formatted(.dateTime.month(.wide).day().year())
                        )
                    }

                    if !showsCompactMobileSummary {
                        GlassEffectContainer(spacing: 14) {
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 14) {
                                    metrics
                                }

                                VStack(spacing: 10) {
                                    metrics
                                }
                            }
                        }
                    }

                    if notificationsEnabled && notificationService.authorizationStatus == .notDetermined {
                        AdaptiveActionCard(
                            icon: .morning,
                            title: "Start with a morning brief",
                            message: "Today’s tasks and earlier unfinished work, delivered at 8:00 AM.",
                            actionTitle: "Enable"
                        ) {
                            Task {
                                guard await notificationService.requestAuthorization() else { return }
                                await notificationService.refreshDailySummaries(
                                    tasks: tasks,
                                    enabled: notificationsEnabled,
                                    hour: notificationHour,
                                    minute: notificationMinute
                                )
                            }
                        }
                    }

                    todayTaskSection

                    if !carriedTasks.isEmpty {
                        taskSection("Carried forward", tasks: carriedTasks, emptyMessage: "")
                    }

                    if !enabledHorizonScales.isEmpty {
                        horizonTaskSection
                    }

                    if !todayEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("On your calendar")
                                .font(.title3.bold())
                            GlassCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach(todayEvents) { event in
                                        HStack(alignment: .top, spacing: 12) {
                                            PlancalGlyph(icon: event.isAllDay ? .calendar : .clock, size: 19)
                                                .foregroundStyle(Color.accentColor)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(event.title).font(.body.weight(.medium))
                                                EventDateLabel(startDate: event.startDate, endDate: event.endDate, isAllDay: event.isAllDay)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: PlancalDesign.contentWidth)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        TaskEditingSignals.dismiss()
                    }
            }
        }
        .adaptiveNavigationTitle("Today")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                if showsCompactMobileSummary {
                    compactMobileSummary
                        .padding(.horizontal, 2.5)
                        .padding(.vertical, 1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            #endif

            ToolbarItem(placement: .primaryAction) {
                Button {
                    TaskEditingSignals.dismiss()
                    isAddingTask = true
                } label: {
                    PlancalGlyph(icon: .add, weight: .bold, size: 18)
                        .accessibilityLabel("New task")
                }
                .buttonStyle(.glassProminent)
                .plancalHoverEffect(scale: 1.06, lifts: true)
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $isAddingTask) {
            GlobalTaskComposerSheet(initialScale: .daily, initialDate: today)
        }
        .onAppear {
            restoreSelectedHorizonScale()
        }
        .onChange(of: visibleScaleStorage) { _, _ in
            restoreSelectedHorizonScale()
        }
        .onChange(of: selectedHorizonScale) { _, newScale in
            TaskEditingSignals.dismiss()
            finishQuickHorizonTask()
            selectedHorizonScaleStorage = newScale.rawValue
        }
        .onDisappear {
            finishQuickTodayTask()
            finishQuickHorizonTask()
        }
    }

    private var showsCompactMobileSummary: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    private var compactMobileSummary: some View {
        HStack(spacing: 6) {
            Text(today.formatted(.dateTime.month(.abbreviated).day()))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.leading, 5)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(3)

            HStack(spacing: 5) {
                TaskCompletionPie(
                    completed: todayCompletedCount,
                    total: todayScheduledTasks.count,
                    tint: PlancalDesign.tint(for: .daily),
                    size: 16
                )
                Text("\(todayCompletedCount)/\(todayScheduledTasks.count)")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 7)
            .frame(height: 28)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75)
                    .allowsHitTesting(false)
            }

            if !overdueTasks.isEmpty {
                NavigationLink {
                    OverdueTasksView()
                } label: {
                    HStack(spacing: 4) {
                        PlancalGlyph(
                            icon: .priorityEssential,
                            weight: .bold,
                            size: 14
                        )
                        Text("\(overdueTasks.count) overdue")
                            .font(.caption2.bold().monospacedDigit())
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(Color.red.opacity(0.1), in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.red.opacity(0.22), lineWidth: 0.75)
                            .allowsHitTesting(false)
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(overdueTasks.count) overdue tasks")
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var showsPageHeader: Bool {
        #if os(iOS)
        false
        #else
        true
        #endif
    }

    private var dayPart: String {
        switch Calendar.autoupdatingCurrent.component(.hour, from: today) {
        case 0..<12: "morning"
        case 12..<17: "afternoon"
        default: "evening"
        }
    }

    private func metricCard(value: Int, label: String, icon: PlancalIcon) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            PlancalGlyph(icon: icon, weight: .duotone, size: 20)
                .foregroundStyle(Color.accentColor)
            Text(value, format: .number)
                .font(.title2.bold())
                .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PlancalDesign.compactCornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }

    private var todayCompletionMetricCard: some View {
        HStack(spacing: 13) {
            TaskCompletionPie(
                completed: todayCompletedCount,
                total: todayScheduledTasks.count,
                tint: PlancalDesign.tint(for: .daily),
                size: 38
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.headline)
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
                Text("\(todayOpenCount) open · \(todayCompletedCount) completed")
                    .font(.caption)
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
        .glassEffect(
            .regular,
            in: RoundedRectangle(
                cornerRadius: PlancalDesign.compactCornerRadius,
                style: .continuous
            )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Today, \(todayOpenCount) open, \(todayCompletedCount) completed"
        )
    }

    @ViewBuilder
    private var metrics: some View {
        todayCompletionMetricCard
        NavigationLink {
            OverdueTasksView()
        } label: {
            metricCard(value: overdueTasks.count, label: "Overdue", icon: .essential)
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: PlancalDesign.compactCornerRadius,
                        style: .continuous
                    )
                )
        }
        .frame(maxWidth: .infinity)
        .contentShape(
            RoundedRectangle(
                cornerRadius: PlancalDesign.compactCornerRadius,
                style: .continuous
            )
        )
        .buttonStyle(.plain)
        .plancalHoverEffect(scale: 1.015, lifts: true)
        .accessibilityHint("Shows all overdue tasks")
        metricCard(value: todayEvents.count, label: "Events", icon: .calendar)
    }

    private var todayTaskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                todayTaskHeader(compact: false)
                todayTaskHeader(compact: true)
            }

            if freshDailyTasks.isEmpty
                && completedDailyTasks.isEmpty
                && !isQuickAddingTodayTask {
                EmptyStateCard(icon: .confirm, title: "Space to breathe", message: "Nothing assigned to today yet.")
            } else {
                GlassCard(contentPadding: 0) {
                    VStack(spacing: 0) {
                        if isQuickAddingTodayTask {
                            quickTodayTaskEntry
                            if !displayedFreshDailyTasks.isEmpty || !completedDailyTasks.isEmpty {
                                Divider().padding(.horizontal, 20)
                            }
                        }

                        ForEach(displayedFreshDailyTasks) { task in
                            TaskRow(task: task) {
                                withAnimation(reduceMotion ? nil : .snappy) { modelContext.delete(task) }
                            }
                            if task.id != displayedFreshDailyTasks.last?.id {
                                Divider().padding(.horizontal, 20)
                            }
                        }

                        if !completedDailyTasks.isEmpty {
                            if !displayedFreshDailyTasks.isEmpty {
                                Divider().padding(.horizontal, 20)
                            }
                            completedTodaySection
                        }
                    }
                }
            }
        }
    }

    private func todayTaskHeader(compact: Bool) -> some View {
        HStack(spacing: 12) {
            Text("Today")
                .font(.title3.bold())

            Spacer()

            Button {
                if isQuickAddingTodayTask, quickTodayTaskHasText {
                    beginNextQuickTodayTask()
                } else if !isQuickAddingTodayTask {
                    beginQuickTodayTask()
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
                .background(PlancalDesign.tint(for: .daily).gradient, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.75)
                        .allowsHitTesting(false)
                }
                .shadow(color: PlancalDesign.tint(for: .daily).opacity(0.2), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .plancalHoverEffect(scale: 1.035, lifts: true)
            .accessibilityLabel("Add today task inline")
        }
    }

    private var completedTodaySection: some View {
        CompletedTasksSection(
            isExpanded: $showsCompletedTodayTasks,
            tasks: completedDailyTasks
        ) { task in
            withAnimation(reduceMotion ? nil : .snappy) {
                modelContext.delete(task)
            }
        }
    }

    private var quickTodayTaskEntry: some View {
        InlineTaskComposer(
            title: $quickTodayTaskTitle,
            scale: $quickTodayTaskScale,
            date: $quickTodayTaskDate,
            priority: $quickTodayTaskPriority,
            placeholder: "New task for today",
            tint: PlancalDesign.tint(for: quickTodayTaskScale),
            showsCloseButton: !quickTodayTaskHasText,
            onSubmit: {
                guard quickTodayTaskHasText else { return }
                beginNextQuickTodayTask()
            },
            onDismiss: finishQuickTodayTask
        )
        .id(quickTodayComposerID)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .task(id: quickTodayTaskRevision) {
            guard isQuickAddingTodayTask else { return }
            do {
                try await Task.sleep(for: .milliseconds(450))
                persistQuickTodayTaskIfValid()
            } catch {
                // A newer draft superseded this pending autosave.
            }
        }
    }

    private func beginQuickTodayTask() {
        TaskEditingSignals.dismiss()
        quickTodayTaskTitle = ""
        quickTodayTaskScale = .daily
        quickTodayTaskDate = PlanningScale.daily.interval(containing: today).start
        quickTodayTaskPriority = .gentle
        quickPersistedTodayTask = nil
        quickTodayComposerID = UUID()
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            isQuickAddingTodayTask = true
        }
    }

    private func beginNextQuickTodayTask() {
        persistQuickTodayTaskIfValid()
        quickTodayTaskTitle = ""
        quickTodayTaskScale = .daily
        quickTodayTaskDate = PlanningScale.daily.interval(containing: today).start
        quickTodayTaskPriority = .gentle
        quickPersistedTodayTask = nil
        quickTodayComposerID = UUID()
    }

    private func finishQuickTodayTask() {
        guard isQuickAddingTodayTask else { return }

        let cleanTitle = quickTodayTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty, let quickPersistedTodayTask {
            modelContext.delete(quickPersistedTodayTask)
            try? modelContext.save()
        } else {
            persistQuickTodayTaskIfValid()
        }

        quickTodayTaskTitle = ""
        quickPersistedTodayTask = nil
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
            isQuickAddingTodayTask = false
        }
    }

    private var quickTodayTaskRevision: String {
        guard isQuickAddingTodayTask else { return "inactive" }
        return [
            quickTodayTaskTitle,
            quickTodayTaskScale.rawValue,
            String(quickTodayTaskDate.timeIntervalSinceReferenceDate),
            quickTodayTaskPriority.rawValue
        ].joined(separator: "|")
    }

    private func persistQuickTodayTaskIfValid() {
        let cleanTitle = quickTodayTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let normalizedDate = quickTodayTaskScale.interval(containing: quickTodayTaskDate).start
        if let quickPersistedTodayTask {
            quickPersistedTodayTask.title = cleanTitle
            quickPersistedTodayTask.scale = quickTodayTaskScale
            quickPersistedTodayTask.scheduledDate = normalizedDate
            quickPersistedTodayTask.originalDate = normalizedDate
            quickPersistedTodayTask.priority = quickTodayTaskPriority
            quickPersistedTodayTask.updatedAt = .now
        } else {
            let task = PlannerTask(
                title: cleanTitle,
                scale: quickTodayTaskScale,
                scheduledDate: normalizedDate,
                priority: quickTodayTaskPriority
            )
            modelContext.insert(task)
            quickPersistedTodayTask = task
        }

        try? modelContext.save()
    }

    private var horizonTaskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                TodayHorizonScaleControl(
                    scales: enabledHorizonScales,
                    selection: $selectedHorizonScale
                )
                .layoutPriority(1)

                Spacer(minLength: 0)

                Button {
                    if isQuickAddingHorizonTask, quickHorizonTaskHasText {
                        beginNextQuickHorizonTask()
                    } else if !isQuickAddingHorizonTask {
                        beginQuickHorizonTask()
                    }
                } label: {
                    PlancalGlyph(icon: .add, weight: .bold, size: 17)
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(
                            PlancalDesign.tint(for: selectedHorizonScale).gradient,
                            in: Circle()
                        )
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.75)
                                .allowsHitTesting(false)
                        }
                        .shadow(
                            color: PlancalDesign.tint(for: selectedHorizonScale).opacity(0.2),
                            radius: 8,
                            y: 3
                        )
                }
                .buttonStyle(.plain)
                .plancalHoverEffect(scale: 1.06, lifts: true)
                .accessibilityLabel(
                    "Add task for \(selectedHorizonScale.todayHorizonTitle.lowercased())"
                )
            }

            if horizonTasks.isEmpty && !isQuickAddingHorizonTask {
                EmptyStateCard(
                    icon: selectedHorizonScale.icon,
                    title: "Nothing planned for \(selectedHorizonScale.todayHorizonTitle.lowercased())",
                    message: "Open tasks for this horizon will appear here."
                )
            } else {
                GlassCard(contentPadding: 0) {
                    VStack(spacing: 0) {
                        if isQuickAddingHorizonTask {
                            quickHorizonTaskEntry
                            if !displayedHorizonTasks.isEmpty {
                                Divider().padding(.horizontal, 20)
                            }
                        }

                        ForEach(displayedHorizonTasks) { task in
                            TaskRow(task: task) {
                                withAnimation(reduceMotion ? nil : .snappy) { modelContext.delete(task) }
                            }
                            if task.id != displayedHorizonTasks.last?.id {
                                Divider().padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
        }
    }

    private var quickHorizonTaskEntry: some View {
        InlineTaskComposer(
            title: $quickHorizonTaskTitle,
            scale: $quickHorizonTaskScale,
            date: $quickHorizonTaskDate,
            priority: $quickHorizonTaskPriority,
            placeholder: "New \(selectedHorizonScale.shortTitle.lowercased()) task",
            tint: PlancalDesign.tint(for: quickHorizonTaskScale),
            showsCloseButton: !quickHorizonTaskHasText,
            onSubmit: {
                guard quickHorizonTaskHasText else { return }
                beginNextQuickHorizonTask()
            },
            onDismiss: finishQuickHorizonTask
        )
        .id(quickHorizonComposerID)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .task(id: quickHorizonTaskRevision) {
            guard isQuickAddingHorizonTask else { return }
            do {
                try await Task.sleep(for: .milliseconds(450))
                persistQuickHorizonTaskIfValid()
            } catch {
                // A newer draft superseded this pending autosave.
            }
        }
    }

    private func beginQuickHorizonTask() {
        TaskEditingSignals.dismiss()
        quickHorizonTaskTitle = ""
        quickHorizonTaskScale = selectedHorizonScale
        quickHorizonTaskDate = selectedHorizonScale.interval(containing: today).start
        quickHorizonTaskPriority = .gentle
        quickPersistedHorizonTask = nil
        quickHorizonComposerID = UUID()
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            isQuickAddingHorizonTask = true
        }
    }

    private func beginNextQuickHorizonTask() {
        persistQuickHorizonTaskIfValid()
        quickHorizonTaskTitle = ""
        quickHorizonTaskScale = selectedHorizonScale
        quickHorizonTaskDate = selectedHorizonScale.interval(containing: today).start
        quickHorizonTaskPriority = .gentle
        quickPersistedHorizonTask = nil
        quickHorizonComposerID = UUID()
    }

    private func finishQuickHorizonTask() {
        guard isQuickAddingHorizonTask else { return }

        let cleanTitle = quickHorizonTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty, let quickPersistedHorizonTask {
            modelContext.delete(quickPersistedHorizonTask)
            try? modelContext.save()
        } else {
            persistQuickHorizonTaskIfValid()
        }

        quickHorizonTaskTitle = ""
        quickPersistedHorizonTask = nil
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
            isQuickAddingHorizonTask = false
        }
    }

    private var quickHorizonTaskRevision: String {
        guard isQuickAddingHorizonTask else { return "inactive" }
        return [
            quickHorizonTaskTitle,
            quickHorizonTaskScale.rawValue,
            String(quickHorizonTaskDate.timeIntervalSinceReferenceDate),
            quickHorizonTaskPriority.rawValue
        ].joined(separator: "|")
    }

    private func persistQuickHorizonTaskIfValid() {
        let cleanTitle = quickHorizonTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let normalizedDate = quickHorizonTaskScale.interval(containing: quickHorizonTaskDate).start
        if let quickPersistedHorizonTask {
            quickPersistedHorizonTask.title = cleanTitle
            quickPersistedHorizonTask.scale = quickHorizonTaskScale
            quickPersistedHorizonTask.scheduledDate = normalizedDate
            quickPersistedHorizonTask.originalDate = normalizedDate
            quickPersistedHorizonTask.priority = quickHorizonTaskPriority
            quickPersistedHorizonTask.updatedAt = .now
        } else {
            let task = PlannerTask(
                title: cleanTitle,
                scale: quickHorizonTaskScale,
                scheduledDate: normalizedDate,
                priority: quickHorizonTaskPriority
            )
            modelContext.insert(task)
            quickPersistedHorizonTask = task
        }

        try? modelContext.save()
    }

    @ViewBuilder
    private func taskSection(_ title: String, tasks sectionTasks: [PlannerTask], emptyMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
            if sectionTasks.isEmpty {
                EmptyStateCard(icon: .confirm, title: "Space to breathe", message: emptyMessage)
            } else {
                GlassCard(contentPadding: 0) {
                    VStack(spacing: 0) {
                        ForEach(sectionTasks) { task in
                            TaskRow(task: task) {
                                withAnimation(reduceMotion ? nil : .snappy) { modelContext.delete(task) }
                            }
                            if task.id != sectionTasks.last?.id {
                                Divider().padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
        }
    }

    private func restoreSelectedHorizonScale() {
        if let storedScale = PlanningScale(rawValue: selectedHorizonScaleStorage),
           enabledHorizonScales.contains(storedScale) {
            selectedHorizonScale = storedScale
            return
        }

        guard let firstEnabledScale = enabledHorizonScales.first else { return }
        selectedHorizonScale = firstEnabledScale
        selectedHorizonScaleStorage = firstEnabledScale.rawValue
    }
}

private struct OverdueTasksView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlannerTask.originalDate) private var tasks: [PlannerTask]

    private var overdueTasks: [PlannerTask] {
        tasks.filter { $0.isOverdue(at: .now) }
    }

    var body: some View {
        ZStack {
            AtmosphericBackground(accent: .red)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if overdueTasks.isEmpty {
                        EmptyStateCard(
                            icon: .confirm,
                            title: "Nothing overdue",
                            message: "You’re caught up."
                        )
                    } else {
                        GlassCard(contentPadding: 0) {
                            VStack(spacing: 0) {
                                ForEach(overdueTasks) { task in
                                    TaskRow(task: task) {
                                        withAnimation(reduceMotion ? nil : .snappy) {
                                            modelContext.delete(task)
                                        }
                                    }
                                    if task.id != overdueTasks.last?.id {
                                        Divider().padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: PlancalDesign.contentWidth)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        TaskEditingSignals.dismiss()
                    }
            }
        }
        .navigationTitle("Overdue")
    }
}

private struct TodayHorizonScaleControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let scales: [PlanningScale]
    @Binding var selection: PlanningScale
    @Namespace private var selectedScale

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 2) {
                ForEach(scales) { scale in
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.26)) {
                            selection = scale
                        }
                    } label: {
                        Text(scale.todayHorizonTitle)
                            .font(.subheadline.weight(scale == selection ? .semibold : .medium))
                            .foregroundStyle(scale == selection ? Color.white : Color.secondary)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 34)
                            .background {
                                if scale == selection {
                                    Capsule()
                                        .fill(PlancalDesign.tint(for: scale).gradient)
                                        .matchedGeometryEffect(id: "today-horizon", in: selectedScale)
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .plancalHoverEffect(scale: 1.035)
                    .accessibilityAddTraits(scale == selection ? .isSelected : [])
                }
            }
            .padding(3)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Planning horizon")
    }
}

private extension PlanningScale {
    var todayHorizonTitle: String {
        switch self {
        case .daily: "Today"
        case .weekly: "This week"
        case .monthly: "This month"
        case .quarterly: "This quarter"
        case .yearly: "This year"
        }
    }
}
