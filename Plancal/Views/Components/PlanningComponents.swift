import SwiftData
import SwiftUI

struct PageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 18, height: 4)
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.45)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AdaptiveActionCard: View {
    let icon: PlancalIcon
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        GlassCard {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    actionDescription
                    Spacer(minLength: 16)
                    actionButton
                }

                VStack(alignment: .leading, spacing: 16) {
                    actionDescription
                    actionButton
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private var actionDescription: some View {
        HStack(spacing: 14) {
            PlancalGlyph(icon: icon, weight: .duotone, size: 23)
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actionButton: some View {
        Button(action: action) {
            Text(actionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .background(Color.accentColor.gradient, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 0.75)
                }
                .shadow(color: Color.accentColor.opacity(0.2), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .plancalHoverEffect(scale: 1.035, lifts: true)
        .accessibilityHint(message)
    }
}

struct TaskCompletionPie: View {
    let completed: Int
    let total: Int
    var tint: Color = .accentColor
    var size: CGFloat = 24

    private var completedFraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(completed) / Double(total)))
    }

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
                .insetBy(dx: 1, dy: 1)
            let center = CGPoint(x: rect.midX, y: rect.midY)

            context.fill(
                Path(ellipseIn: rect),
                with: .color(tint.opacity(total == 0 ? 0.12 : 0.2))
            )

            if completedFraction > 0 {
                var completedSlice = Path()
                completedSlice.move(to: center)
                completedSlice.addArc(
                    center: center,
                    radius: min(rect.width, rect.height) / 2,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + (360 * completedFraction)),
                    clockwise: false
                )
                completedSlice.closeSubpath()
                context.fill(completedSlice, with: .color(tint))
            }

            context.stroke(
                Path(ellipseIn: rect),
                with: .color(tint.opacity(0.34)),
                lineWidth: 1
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

enum TaskEditingSignals {
    static let dismissRequested = Notification.Name("Plancal.TaskEditing.dismissRequested")

    static func dismiss() {
        NotificationCenter.default.post(name: dismissRequested, object: nil)
    }
}

struct InlineTaskComposer: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @Binding var title: String
    @Binding var scale: PlanningScale
    @Binding var date: Date
    @Binding var priority: TaskPriority

    let placeholder: String
    let tint: Color
    var isCompleted = false
    var showsCloseButton = true
    var onToggleCompletion: (() -> Void)?
    var onSubmit: (() -> Void)?
    var onDelete: (() -> Void)?
    let onDismiss: () -> Void

    @FocusState private var isTitleFocused: Bool
    @State private var isChoosingDate = false
    @State private var titleSelection: TextSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                completionControl

                TextField(
                    placeholder,
                    text: $title,
                    selection: $titleSelection
                )
                    .textFieldStyle(.plain)
                    .font(.body.weight(.medium))
                    .focused($isTitleFocused)
                    .onSubmit {
                        onSubmit?()
                    }

                if showsCloseButton {
                    Button(action: onDismiss) {
                        PlancalGlyph(icon: .close, size: 16)
                            .foregroundStyle(.secondary)
                            .frame(width: 38, height: 38)
                            .background(Color.primary.opacity(0.055), in: Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.75)
                                    .allowsHitTesting(false)
                            }
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .plancalHoverEffect(scale: 1.07, lifts: true)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Close task editor")
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Menu {
                        ForEach(PlanningScale.allCases) { option in
                            Button {
                                scale = option
                            } label: {
                                PlancalNativeIconLabel(
                                    title: option.shortTitle,
                                    icon: option.icon,
                                    weight: option == scale ? .bold : .regular
                                )
                            }
                        }
                    } label: {
                        controlChip(title: scale.shortTitle, icon: scale.icon)
                    }
                    .buttonStyle(.plain)

                    Button {
                        isChoosingDate = true
                    } label: {
                        controlChip(
                            title: scale.taskLabel(for: date),
                            icon: .calendar
                        )
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $isChoosingDate, arrowEdge: .bottom) {
                        periodPickerPresentation
                    }

                    Menu {
                        ForEach(TaskPriority.allCases) { option in
                            Button {
                                priority = option
                            } label: {
                                PlancalNativeIconLabel(
                                    title: option.title,
                                    icon: option.icon,
                                    weight: option == priority ? .bold : .regular
                                )
                            }
                        }
                    } label: {
                        controlChip(
                            title: priority.title,
                            icon: priority.icon,
                            prominentColor: priorityProminentColor
                        )
                    }
                    .buttonStyle(.plain)

                    if let onDelete {
                        Button(role: .destructive, action: onDelete) {
                            controlChip(
                                title: "Delete",
                                icon: .delete,
                                prominentColor: .red
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete task")
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
            .padding(.leading, 34)
        }
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                isTitleFocused = true
                titleSelection = TextSelection(insertionPoint: title.endIndex)
                try? await Task.sleep(for: .milliseconds(40))
                titleSelection = TextSelection(insertionPoint: title.endIndex)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: TaskEditingSignals.dismissRequested)) { _ in
            isTitleFocused = false
            onDismiss()
        }
        .toolbar {
            #if os(iOS)
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    isTitleFocused = false
                    onDismiss()
                } label: {
                    PlancalGlyph(icon: .close, weight: .bold, size: 16)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close keyboard")
            }
            #endif
        }
    }

    @ViewBuilder
    private var periodPickerPresentation: some View {
        let picker = PlanningPeriodPicker(
            scale: scale,
            selection: $date,
            tint: tint
        ) {
            isChoosingDate = false
        }
        .id(scale)

        #if os(iOS)
        if horizontalSizeClass == .compact {
            picker
                .presentationCompactAdaptation(.sheet)
                .presentationDetents([.height(mobilePickerHeight)])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
                .presentationCornerRadius(28)
                .presentationBackground(.regularMaterial)
        } else {
            picker
                .presentationCompactAdaptation(.popover)
        }
        #else
        picker
        #endif
    }

    private var mobilePickerHeight: CGFloat {
        switch scale {
        case .daily: 430
        case .weekly: 480
        case .monthly: 330
        case .quarterly: 310
        case .yearly: 340
        }
    }

    @ViewBuilder
    private var completionControl: some View {
        if let onToggleCompletion {
            Button(action: onToggleCompletion) {
                PlancalGlyph(
                    icon: isCompleted ? .complete : .incomplete,
                    weight: isCompleted ? .fill : .regular,
                    size: 22
                )
            }
            .buttonStyle(.plain)
            .plancalHoverEffect(scale: 1.08)
            .accessibilityLabel(isCompleted ? "Mark incomplete" : "Mark complete")
        } else {
            PlancalGlyph(icon: .incomplete, size: 22)
                .foregroundStyle(.tertiary)
        }
    }

    private func controlChip(
        title: String,
        icon: PlancalIcon,
        prominentColor: Color? = nil
    ) -> some View {
        let chipColor = prominentColor ?? tint
        let isProminent = prominentColor != nil

        return PlancalIconLabel(
            title: title,
            icon: icon,
            weight: isProminent ? .bold : .regular,
            size: 15
        )
        .font(.caption.weight(.medium))
        .foregroundStyle(isProminent ? chipColor : Color.secondary)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            isProminent ? chipColor.opacity(0.11) : Color.primary.opacity(0.045),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .strokeBorder(
                    isProminent ? chipColor.opacity(0.24) : Color.primary.opacity(0.075),
                    lineWidth: 0.75
                )
                .allowsHitTesting(false)
        }
        .contentShape(Capsule())
    }

    private var priorityProminentColor: Color? {
        switch priority {
        case .gentle: nil
        case .important: .orange
        case .essential: .red
        }
    }
}

struct PlanningPeriodPicker: View {
    let scale: PlanningScale
    @Binding var selection: Date
    let tint: Color
    let onSelect: () -> Void

    @State private var displayedYear: Int
    @State private var displayedDecadeStart: Int

    private let calendar = Calendar.autoupdatingCurrent
    private let gridColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    init(
        scale: PlanningScale,
        selection: Binding<Date>,
        tint: Color,
        onSelect: @escaping () -> Void
    ) {
        self.scale = scale
        _selection = selection
        self.tint = tint
        self.onSelect = onSelect

        let calendar = Calendar.autoupdatingCurrent
        let yearComponent: Calendar.Component = scale == .weekly
            ? .yearForWeekOfYear
            : .year
        let year = calendar.component(yearComponent, from: selection.wrappedValue)
        _displayedYear = State(initialValue: year)
        _displayedDecadeStart = State(initialValue: (year / 12) * 12)
    }

    var body: some View {
        VStack(spacing: 14) {
            if scale == .daily {
                dailyPicker
            } else {
                pickerHeader
                Divider()
                periodGrid
            }
        }
        .padding(16)
        .frame(minWidth: 330, idealWidth: 360, maxWidth: 390)
    }

    private var dailyPicker: some View {
        VStack(spacing: 12) {
            DatePicker(
                "Task date",
                selection: $selection,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()

            HStack {
                Spacer()
                Button("Done", action: onSelect)
                    .buttonStyle(.glassProminent)
                    .tint(tint)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var pickerHeader: some View {
        HStack(spacing: 12) {
            Button {
                moveBackward()
            } label: {
                PlancalGlyph(icon: .previous, weight: .bold, size: 16)
                    .frame(width: 34, height: 34)
                    .background(Color.primary.opacity(0.055), in: Circle())
            }
            .buttonStyle(.plain)
            .plancalHoverEffect(scale: 1.06)
            .accessibilityLabel("Previous \(scale.shortTitle.lowercased()) range")

            Spacer()

            Text(headerTitle)
                .font(.headline.monospacedDigit())
                .contentTransition(.numericText())

            Spacer()

            Button {
                moveForward()
            } label: {
                PlancalGlyph(icon: .next, weight: .bold, size: 16)
                    .frame(width: 34, height: 34)
                    .background(Color.primary.opacity(0.055), in: Circle())
            }
            .buttonStyle(.plain)
            .plancalHoverEffect(scale: 1.06)
            .accessibilityLabel("Next \(scale.shortTitle.lowercased()) range")
        }
    }

    @ViewBuilder
    private var periodGrid: some View {
        switch scale {
        case .daily:
            EmptyView()
        case .weekly:
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(gridColumns.prefix(2)), spacing: 8) {
                        ForEach(weekStarts, id: \.self) { date in
                            periodButton(date: date) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("W\(calendar.component(.weekOfYear, from: date))")
                                        .font(.caption.weight(.bold))
                                    Text(scale.taskLabel(for: date))
                                        .font(.caption2)
                                        .foregroundStyle(isSelected(date) ? .white.opacity(0.8) : .secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .id(date)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .frame(height: 330)
                .scrollIndicators(.hidden)
                .onAppear {
                    scrollToRelevantWeek(using: proxy)
                }
                .onChange(of: displayedYear) { _, _ in
                    Task { @MainActor in
                        await Task.yield()
                        scrollToRelevantWeek(using: proxy)
                    }
                }
            }
        case .monthly:
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(1...12, id: \.self) { month in
                    if let date = date(year: displayedYear, month: month) {
                        periodButton(date: date) {
                            Text(date.formatted(.dateTime.month(.abbreviated)))
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        case .quarterly:
            LazyVGrid(columns: Array(gridColumns.prefix(2)), spacing: 8) {
                ForEach(0..<4, id: \.self) { quarterIndex in
                    if let date = date(
                        year: displayedYear,
                        month: (quarterIndex * 3) + 1
                    ) {
                        periodButton(date: date, minHeight: 68) {
                            VStack(spacing: 4) {
                                Text("Q\(quarterIndex + 1)")
                                    .font(.headline)
                                Text(quarterMonthRange(quarterIndex))
                                    .font(.caption2)
                                    .foregroundStyle(isSelected(date) ? .white.opacity(0.8) : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        case .yearly:
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(displayedDecadeStart..<(displayedDecadeStart + 12), id: \.self) { year in
                    if let date = date(year: year, month: 1) {
                        periodButton(date: date) {
                            Text(year, format: .number.grouping(.never))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func periodButton<Content: View>(
        date: Date,
        minHeight: CGFloat = 48,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let selected = isSelected(date)
        return Button {
            selection = scale.interval(containing: date).start
            onSelect()
        } label: {
            content()
                .foregroundStyle(selected ? Color.white : Color.primary)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Color.primary.opacity(0.045)))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            selected ? Color.white.opacity(0.2) : Color.primary.opacity(0.07),
                            lineWidth: 0.75
                        )
                        .allowsHitTesting(false)
                }
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .plancalHoverEffect(scale: 1.025, lifts: true)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(scale.label(for: date))
    }

    private var headerTitle: String {
        if scale == .yearly {
            return "\(displayedDecadeStart)–\(displayedDecadeStart + 11)"
        }
        return displayedYear.formatted(.number.grouping(.never))
    }

    private var weekStarts: [Date] {
        (1...53).compactMap { week in
            var components = DateComponents()
            components.calendar = calendar
            components.yearForWeekOfYear = displayedYear
            components.weekOfYear = week
            components.weekday = calendar.firstWeekday
            guard let date = calendar.date(from: components),
                  calendar.component(.yearForWeekOfYear, from: date) == displayedYear else {
                return nil
            }
            return scale.interval(containing: date).start
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        scale.contains(selection, inPeriodContaining: date)
    }

    private func scrollToRelevantWeek(using proxy: ScrollViewProxy) {
        let selectedYear = calendar.component(
            .yearForWeekOfYear,
            from: selection
        )
        let target = selectedYear == displayedYear
            ? scale.interval(containing: selection).start
            : weekStarts.first
        guard let target else { return }
        proxy.scrollTo(target, anchor: .center)
    }

    private func date(year: Int, month: Int) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }

    private func quarterMonthRange(_ quarterIndex: Int) -> String {
        guard let start = date(
            year: displayedYear,
            month: (quarterIndex * 3) + 1
        ),
        let end = calendar.date(byAdding: .month, value: 2, to: start) else {
            return ""
        }
        return "\(start.formatted(.dateTime.month(.abbreviated)))–\(end.formatted(.dateTime.month(.abbreviated)))"
    }

    private func moveBackward() {
        if scale == .yearly {
            displayedDecadeStart -= 12
        } else {
            displayedYear -= 1
        }
    }

    private func moveForward() {
        if scale == .yearly {
            displayedDecadeStart += 12
        } else {
            displayedYear += 1
        }
    }
}

struct GlobalTaskComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var scale: PlanningScale
    @State private var date: Date
    @State private var priority = TaskPriority.gentle

    init(initialScale: PlanningScale = .daily, initialDate: Date = .now) {
        _scale = State(initialValue: initialScale)
        _date = State(initialValue: initialScale.interval(containing: initialDate).start)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack {
                    InlineTaskComposer(
                        title: $title,
                        scale: $scale,
                        date: $date,
                        priority: $priority,
                        placeholder: "Task title",
                        tint: PlancalDesign.tint(for: scale),
                        showsCloseButton: false,
                        onDismiss: dismiss.callAsFunction
                    )
                    .padding(28)
                    .frame(maxWidth: 720)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                Divider()

                HStack(spacing: 12) {
                    Spacer()

                    Button("Discard", role: .cancel) {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                    Button("Save") {
                        save()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(PlancalDesign.tint(for: scale))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                }
                .font(.body.weight(.semibold))
                .controlSize(.large)
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(.bar)
            }
            .background(.thinMaterial)
            .navigationTitle("New task")
        }
        .platformEditorFrame(minWidth: 560, idealWidth: 680, minHeight: 320)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let normalizedDate = scale.interval(containing: date).start
        let task = PlannerTask(
            title: cleanTitle,
            scale: scale,
            scheduledDate: normalizedDate,
            priority: priority
        )
        modelContext.insert(task)

        try? modelContext.save()
        dismiss()
    }
}

struct CompletedTasksSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var isExpanded: Bool
    let tasks: [PlannerTask]
    let onDelete: (PlannerTask) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 9) {
                    PlancalGlyph(icon: .disclosure, weight: .bold, size: 15)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text("Completed")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(tasks.count, format: .number)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .frame(minHeight: 46)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .plancalHoverEffect(scale: 1.008)
            .accessibilityLabel(
                isExpanded
                    ? "Collapse completed tasks"
                    : "Expand completed tasks"
            )

            if isExpanded {
                Divider().padding(.horizontal, 20)
                ForEach(tasks) { task in
                    TaskRow(task: task) {
                        onDelete(task)
                    }
                    if task.id != tasks.last?.id {
                        Divider().padding(.horizontal, 20)
                    }
                }
            }
        }
    }
}

struct TaskRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: PlannerTask
    var onDelete: (() -> Void)?

    @State private var isEditing = false
    @State private var draftTitle = ""
    @State private var draftScale = PlanningScale.daily
    @State private var draftDate = Date.now
    @State private var draftPriority = TaskPriority.gentle
    @State private var isHovered = false

    var body: some View {
        Group {
            if isEditing {
                inlineEditor
            } else {
                taskRowSummary
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background {
            if !isEditing {
                Button(action: beginEditing) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isHovered ? Color.accentColor.opacity(0.055) : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit \(task.title)")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(action: beginEditing) {
                PlancalNativeIconLabel(title: "Edit", icon: .edit)
            }
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    PlancalNativeIconLabel(title: "Delete", icon: .delete)
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: isEditing)
        .task(id: editRevision) {
            guard isEditing else { return }
            do {
                try await Task.sleep(for: .milliseconds(450))
                persistEditsIfValid()
            } catch {
                // A newer edit superseded this pending autosave.
            }
        }
    }

    private var taskRowSummary: some View {
        HStack(alignment: .top, spacing: 13) {
            Button {
                TaskEditingSignals.dismiss()
                toggleCompletion()
            } label: {
                PlancalGlyph(
                    icon: task.isCompleted ? .complete : .incomplete,
                    weight: task.isCompleted ? .fill : .regular,
                    size: 22
                )
                .symbolEffect(.bounce, value: reduceMotion ? false : task.isCompleted)
            }
            .buttonStyle(.plain)
            .plancalHoverEffect(scale: 1.08)
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")

            taskSummary
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .allowsHitTesting(false)
        }
    }

    private func toggleCompletion() {
        withAnimation(reduceMotion ? nil : .snappy) {
            task.setCompleted(!task.isCompleted)
        }
        try? modelContext.save()
    }

    private var taskSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(task.title)
                .font(.body.weight(.medium))
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
            if !task.details.isEmpty {
                Text(task.details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 7) { taskMetadata }
                VStack(alignment: .leading, spacing: 4) { taskMetadata }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var taskMetadata: some View {
        PlancalIconLabel(
            title: task.scale.taskLabel(for: task.scheduledDate),
            icon: task.scale.icon,
            size: 13
        )
        if task.carryCount > 0 && !task.isCompleted {
            PlancalIconLabel(title: "Carried forward", icon: .carriedForward, size: 13)
                .foregroundStyle(.orange)
        }
        if task.priority != .gentle {
            PlancalIconLabel(
                title: task.priority.title,
                icon: task.priority.icon,
                weight: task.priority == .important ? .fill : .bold,
                size: 13
            )
                .foregroundStyle(task.priority == .essential ? .red : .secondary)
        }
    }

    private var inlineEditor: some View {
        InlineTaskComposer(
            title: $draftTitle,
            scale: $draftScale,
            date: $draftDate,
            priority: $draftPriority,
            placeholder: "Task title",
            tint: PlancalDesign.tint(for: draftScale),
            isCompleted: task.isCompleted,
            onToggleCompletion: toggleCompletion,
            onDelete: inlineDeleteAction,
            onDismiss: finishEditing
        )
    }

    private var inlineDeleteAction: (() -> Void)? {
        guard onDelete != nil else { return nil }
        return { deleteTask() }
    }

    private func beginEditing() {
        TaskEditingSignals.dismiss()
        draftTitle = task.title
        draftScale = task.scale
        draftDate = task.scheduledDate
        draftPriority = task.priority
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
            isEditing = true
        }
    }

    private func finishEditing() {
        persistEditsIfValid()
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
            isEditing = false
        }
    }

    private func deleteTask() {
        guard let onDelete else { return }
        isEditing = false
        onDelete()
    }

    private var editRevision: String {
        guard isEditing else { return "inactive" }
        return [
            draftTitle,
            draftScale.rawValue,
            String(draftDate.timeIntervalSinceReferenceDate),
            draftPriority.rawValue
        ].joined(separator: "|")
    }

    private func persistEditsIfValid() {
        let cleanTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let normalizedDate = draftScale.interval(containing: draftDate).start
        task.title = cleanTitle
        task.scale = draftScale
        task.scheduledDate = normalizedDate
        task.priority = draftPriority
        if task.carryCount == 0 {
            task.originalDate = normalizedDate
        }
        task.updatedAt = .now
        try? modelContext.save()
    }
}

struct MarkdownText: View {
    let markdown: String

    private var rendered: AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .full)))
            ?? AttributedString(markdown)
    }

    var body: some View {
        Text(rendered)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NoteCard: View {
    let note: MarkdownNote

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if note.isPinned {
                        PlancalGlyph(icon: .pin, weight: .fill, size: 16)
                            .foregroundStyle(Color.accentColor)
                    }
                    Text(note.title.isEmpty ? "Untitled note" : note.title)
                        .font(.headline)
                    Spacer()
                    if note.scope == .period {
                        Text(note.scale.shortTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if note.markdown.isEmpty {
                    Text("Empty note")
                        .foregroundStyle(.tertiary)
                } else {
                    MarkdownText(markdown: note.markdown)
                        .lineLimit(6)
                }
                Text(note.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct EventDateLabel: View {
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool

    var body: some View {
        let calendar = Calendar.autoupdatingCurrent
        if isAllDay {
            if calendar.isDate(startDate, inSameDayAs: endDate) {
                Text(startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
            } else {
                Text("\(startDate.formatted(.dateTime.month(.abbreviated).day())) – \(endDate.formatted(.dateTime.month(.abbreviated).day()))")
            }
        } else {
            Text("\(startDate.formatted(.dateTime.month(.abbreviated).day().hour().minute())) – \(endDate.formatted(.dateTime.hour().minute()))")
        }
    }
}
