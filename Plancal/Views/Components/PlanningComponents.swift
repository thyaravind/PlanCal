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

struct InlineTaskCancelButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PlancalGlyph(icon: .close, size: 17)
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
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
        .accessibilityLabel("Cancel quick task")
    }
}

struct InlineTaskSubmitButton: View {
    let title: String
    let tint: Color
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 17)
                .frame(minWidth: 72, minHeight: 40, maxHeight: 40)
                .background(tint.gradient, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.75)
                        .allowsHitTesting(false)
                }
                .shadow(color: tint.opacity(0.2), radius: 8, y: 3)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .plancalHoverEffect(scale: 1.035, lifts: true)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }
}

struct TaskRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: PlannerTask
    var onDelete: (() -> Void)?

    @State private var isEditing = false
    @State private var draftTitle = ""
    @State private var draftDetails = ""
    @State private var draftScale = PlanningScale.daily
    @State private var draftDate = Date.now
    @State private var isHovered = false
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Button(action: toggleCompletion) {
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

            VStack(alignment: .leading, spacing: 5) {
                if isEditing {
                    inlineEditor
                } else {
                    taskSummary
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            .allowsHitTesting(isEditing)
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
        VStack(alignment: .leading, spacing: 10) {
            TextField("Task title", text: $draftTitle)
                .textFieldStyle(.roundedBorder)
                .font(.body.weight(.medium))
                .focused($isTitleFocused)
                .onSubmit(saveEdits)

            TextField("Details (optional)", text: $draftDetails)
                .textFieldStyle(.roundedBorder)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { editControls }
                VStack(alignment: .leading, spacing: 10) { editControls }
            }

            HStack {
                Text(draftScale.taskLabel(for: draftDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: cancelEditing)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .frame(minWidth: 72, minHeight: 36)
                    .plancalHoverEffect(scale: 1.035)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: saveEdits)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .frame(minWidth: 72, minHeight: 36)
                    .plancalHoverEffect(scale: 1.04, lifts: true)
                    .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var editControls: some View {
        Picker("Scale", selection: $draftScale) {
            ForEach(PlanningScale.allCases) { scale in
                PlancalNativeIconLabel(title: scale.pluralTitle, icon: scale.icon)
                    .tag(scale)
            }
        }
        DatePicker("Date", selection: $draftDate, displayedComponents: .date)
    }

    private func beginEditing() {
        draftTitle = task.title
        draftDetails = task.details
        draftScale = task.scale
        draftDate = task.scheduledDate
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
            isEditing = true
        }
        Task { @MainActor in
            await Task.yield()
            isTitleFocused = true
        }
    }

    private func cancelEditing() {
        isTitleFocused = false
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
            isEditing = false
        }
    }

    private func saveEdits() {
        let cleanTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        task.title = cleanTitle
        task.details = draftDetails
        task.scale = draftScale
        task.scheduledDate = draftDate
        task.updatedAt = .now
        try? modelContext.save()
        isTitleFocused = false
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
            isEditing = false
        }
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
