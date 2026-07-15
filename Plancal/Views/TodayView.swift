import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationService.self) private var notificationService
    @Query(sort: \PlannerTask.createdAt) private var tasks: [PlannerTask]
    @Query(sort: \PlannerEvent.startDate) private var events: [PlannerEvent]
    @AppStorage("notifications.enabled") private var notificationsEnabled = true
    @AppStorage("notifications.hour") private var notificationHour = 8
    @AppStorage("notifications.minute") private var notificationMinute = 0
    @AppStorage("planning.visibleScales") private var visibleScaleStorage = PlanningScale.defaultVisibleStorageValue
    @AppStorage("today.selectedHorizonScale") private var selectedHorizonScaleStorage = PlanningScale.weekly.rawValue
    @State private var isAddingTask = false
    @State private var isQuickAddingTodayTask = false
    @State private var quickTodayTaskTitle = ""
    @State private var selectedHorizonScale: PlanningScale = .weekly
    @FocusState private var isQuickTodayTaskFocused: Bool
    private let today = Date.now

    private var enabledHorizonScales: [PlanningScale] {
        PlanningScale.visibleScales(from: visibleScaleStorage).filter { $0 != .daily }
    }

    private var freshDailyTasks: [PlannerTask] {
        tasks.filter { !$0.isCompleted && $0.scale == .daily && $0.carryCount == 0 && $0.belongs(to: .daily, anchor: today) }
    }

    private var carriedTasks: [PlannerTask] {
        tasks.filter { !$0.isCompleted && $0.carryCount > 0 && $0.scale.interval(containing: today).contains($0.scheduledDate) }
    }

    private var horizonTasks: [PlannerTask] {
        tasks.filter {
            !$0.isCompleted
                && $0.scale == selectedHorizonScale
                && $0.carryCount == 0
                && $0.belongs(to: selectedHorizonScale, anchor: today)
        }
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
                    PageHeader(
                        eyebrow: today.formatted(.dateTime.weekday(.wide)),
                        title: "Good \(dayPart)",
                        subtitle: today.formatted(.dateTime.month(.wide).day().year())
                    )

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
        }
        .adaptiveNavigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
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
            TaskEditor(initialScale: .daily, initialDate: today)
        }
        .onAppear {
            restoreSelectedHorizonScale()
        }
        .onChange(of: visibleScaleStorage) { _, _ in
            restoreSelectedHorizonScale()
        }
        .onChange(of: selectedHorizonScale) { _, newScale in
            selectedHorizonScaleStorage = newScale.rawValue
        }
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PlancalDesign.compactCornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }

    @ViewBuilder
    private var metrics: some View {
        metricCard(value: freshDailyTasks.count + carriedTasks.count, label: "Open today", icon: .checklist)
        metricCard(value: carriedTasks.count, label: "Carried", icon: .carriedForward)
        metricCard(value: todayEvents.count, label: "Events", icon: .calendar)
    }

    private var todayTaskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                todayTaskHeader(compact: false)
                todayTaskHeader(compact: true)
            }

            if freshDailyTasks.isEmpty && !isQuickAddingTodayTask {
                EmptyStateCard(icon: .confirm, title: "Space to breathe", message: "Nothing assigned to today yet.")
            } else {
                GlassCard(contentPadding: 0) {
                    VStack(spacing: 0) {
                        if isQuickAddingTodayTask {
                            quickTodayTaskEntry
                            if !freshDailyTasks.isEmpty {
                                Divider().padding(.horizontal, 20)
                            }
                        }

                        ForEach(freshDailyTasks) { task in
                            TaskRow(task: task) {
                                withAnimation(reduceMotion ? nil : .snappy) { modelContext.delete(task) }
                            }
                            if task.id != freshDailyTasks.last?.id {
                                Divider().padding(.horizontal, 20)
                            }
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
                if isQuickAddingTodayTask {
                    cancelQuickTodayTask()
                } else {
                    beginQuickTodayTask()
                }
            } label: {
                Group {
                    if compact {
                        PlancalGlyph(icon: isQuickAddingTodayTask ? .confirm : .add, weight: .bold, size: 17)
                    } else {
                        PlancalIconLabel(
                            title: isQuickAddingTodayTask ? "Done" : "Add task",
                            icon: isQuickAddingTodayTask ? .confirm : .add,
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
            .accessibilityLabel(isQuickAddingTodayTask ? "Finish adding today tasks" : "Add today task inline")
        }
    }

    private var quickTodayTaskEntry: some View {
        HStack(spacing: 12) {
            PlancalGlyph(icon: .incomplete, size: 21)
                .foregroundStyle(.tertiary)

            TextField("New task for today", text: $quickTodayTaskTitle)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .focused($isQuickTodayTaskFocused)
                .onSubmit(addQuickTodayTask)

            InlineTaskCancelButton(action: cancelQuickTodayTask)

            InlineTaskSubmitButton(
                title: "Add",
                tint: PlancalDesign.tint(for: .daily),
                isDisabled: quickTodayTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                action: addQuickTodayTask
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func beginQuickTodayTask() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            isQuickAddingTodayTask = true
        }
        Task { @MainActor in
            await Task.yield()
            isQuickTodayTaskFocused = true
        }
    }

    private func cancelQuickTodayTask() {
        isQuickTodayTaskFocused = false
        quickTodayTaskTitle = ""
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
            isQuickAddingTodayTask = false
        }
    }

    private func addQuickTodayTask() {
        let cleanTitle = quickTodayTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let todayStart = PlanningScale.daily.interval(containing: today).start
        modelContext.insert(PlannerTask(title: cleanTitle, scale: .daily, scheduledDate: todayStart))
        try? modelContext.save()
        quickTodayTaskTitle = ""

        Task { @MainActor in
            await Task.yield()
            isQuickTodayTaskFocused = true
        }
    }

    private var horizonTaskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TodayHorizonScaleControl(
                scales: enabledHorizonScales,
                selection: $selectedHorizonScale
            )

            if horizonTasks.isEmpty {
                EmptyStateCard(
                    icon: selectedHorizonScale.icon,
                    title: "Nothing planned for \(selectedHorizonScale.todayHorizonTitle.lowercased())",
                    message: "Open tasks for this horizon will appear here."
                )
            } else {
                GlassCard(contentPadding: 0) {
                    VStack(spacing: 0) {
                        ForEach(horizonTasks) { task in
                            TaskRow(task: task) {
                                withAnimation(reduceMotion ? nil : .snappy) { modelContext.delete(task) }
                            }
                            if task.id != horizonTasks.last?.id {
                                Divider().padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
        }
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
