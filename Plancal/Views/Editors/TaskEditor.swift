import SwiftData
import SwiftUI

struct TaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let task: PlannerTask?
    @State private var title: String
    @State private var details: String
    @State private var scale: PlanningScale
    @State private var scheduledDate: Date
    @State private var priority: TaskPriority

    init(task: PlannerTask? = nil, initialScale: PlanningScale, initialDate: Date) {
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _details = State(initialValue: task?.details ?? "")
        _scale = State(initialValue: task?.scale ?? initialScale)
        _scheduledDate = State(initialValue: task?.scheduledDate ?? initialDate)
        _priority = State(initialValue: task?.priority ?? .gentle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("What needs doing?", text: $title)
                        .font(.title3.weight(.semibold))
                    TextEditor(text: $details)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if details.isEmpty {
                                Text("Details (optional)")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section("Horizon") {
                    Picker("Scale", selection: $scale) {
                        ForEach(PlanningScale.allCases) { option in
                            PlancalNativeIconLabel(title: option.pluralTitle, icon: option.icon)
                                .tag(option)
                        }
                    }
                    DatePicker("Period", selection: $scheduledDate, displayedComponents: .date)
                    Text(scale.label(for: scheduledDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Emphasis") {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases) { option in
                            PlancalNativeIconLabel(
                                title: option.title,
                                icon: option.icon,
                                weight: option == .important ? .fill : .regular
                            )
                            .tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(task == nil ? "New task" : "Edit task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .buttonStyle(.glassProminent)
                        .keyboardShortcut("s", modifiers: .command)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .platformEditorFrame(minWidth: 360, idealWidth: 520, minHeight: 470)
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let task {
            task.title = cleanTitle
            task.details = details
            task.scale = scale
            task.scheduledDate = scheduledDate
            task.priority = priority
            task.updatedAt = .now
        } else {
            modelContext.insert(
                PlannerTask(
                    title: cleanTitle,
                    details: details,
                    scale: scale,
                    scheduledDate: scheduledDate,
                    priority: priority
                )
            )
        }
        try? modelContext.save()
        dismiss()
    }
}
