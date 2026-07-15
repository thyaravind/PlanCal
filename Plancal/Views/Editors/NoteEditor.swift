import SwiftData
import SwiftUI

struct NoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let note: MarkdownNote?
    @State private var title: String
    @State private var markdown: String
    @State private var scope: NoteScope
    @State private var scale: PlanningScale
    @State private var anchorDate: Date
    @State private var isPinned: Bool

    init(
        note: MarkdownNote? = nil,
        initialScope: NoteScope = .independent,
        initialScale: PlanningScale = .daily,
        initialDate: Date = .now
    ) {
        self.note = note
        _title = State(initialValue: note?.title ?? "")
        _markdown = State(initialValue: note?.markdown ?? "")
        _scope = State(initialValue: note?.scope ?? initialScope)
        _scale = State(initialValue: note?.scale ?? initialScale)
        _anchorDate = State(initialValue: note?.anchorDate ?? initialDate)
        _isPinned = State(initialValue: note?.isPinned ?? false)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section {
                        TextField("Note title", text: $title)
                            .font(.title3.weight(.semibold))
                        Toggle(isOn: $isPinned) {
                            PlancalIconLabel(title: "Pinned", icon: .pin)
                        }
                    }
                    Section("Belongs to") {
                        Picker("Scope", selection: $scope) {
                            ForEach(NoteScope.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        if scope == .period {
                            Picker("Scale", selection: $scale) {
                                ForEach(PlanningScale.allCases) { option in
                                    PlancalNativeIconLabel(title: option.title, icon: option.icon)
                                        .tag(option)
                                }
                            }
                            DatePicker("Period", selection: $anchorDate, displayedComponents: .date)
                        }
                    }
                }
                .formStyle(.grouped)
                .frame(maxHeight: scope == .period ? 250 : 190)

                RichMarkdownEditor(
                    markdown: $markdown,
                    placeholder: "Write naturally—formatting stays visible as you type.",
                    minHeight: 300
                )
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding([.horizontal, .bottom])
            }
            .navigationTitle(note == nil ? "New note" : "Edit note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .buttonStyle(.glassProminent)
                        .keyboardShortcut("s", modifiers: .command)
                }
            }
        }
        .platformEditorFrame(minWidth: 420, idealWidth: 680, minHeight: 620)
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let note {
            note.title = cleanTitle.isEmpty ? "Untitled note" : cleanTitle
            note.markdown = markdown
            note.scope = scope
            note.scale = scale
            note.anchorDate = anchorDate
            note.isPinned = isPinned
            note.updatedAt = .now
        } else {
            let newNote = MarkdownNote(
                title: cleanTitle.isEmpty ? "Untitled note" : cleanTitle,
                markdown: markdown,
                scope: scope,
                scale: scale,
                anchorDate: anchorDate
            )
            newNote.isPinned = isPinned
            modelContext.insert(newNote)
        }
        try? modelContext.save()
        dismiss()
    }
}
