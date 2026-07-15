import SwiftData
import SwiftUI

struct NotesView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MarkdownNote.updatedAt, order: .reverse) private var notes: [MarkdownNote]
    @State private var query = ""
    @State private var isAddingNote = false
    @State private var editingNote: MarkdownNote?

    private var visibleNotes: [MarkdownNote] {
        let filtered = query.isEmpty ? notes : notes.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.markdown.localizedCaseInsensitiveContains(query)
        }
        return filtered.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    var body: some View {
        ZStack {
            AtmosphericBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    PageHeader(eyebrow: "Markdown", title: "Notes", subtitle: "Ideas, reflections, and context—kept close to the plan.")
                    if visibleNotes.isEmpty {
                        EmptyStateCard(icon: .notes, title: "A quiet page", message: query.isEmpty ? "Create a Markdown note whenever an idea arrives." : "No notes match your search.")
                    } else {
                        ForEach(visibleNotes) { note in
                            Button { editingNote = note } label: {
                                NoteCard(note: note)
                            }
                            .buttonStyle(.plain)
                            .plancalHoverEffect(scale: 1.012, lifts: true)
                            .contextMenu {
                                Button {
                                    note.isPinned.toggle()
                                    note.updatedAt = .now
                                } label: {
                                    PlancalNativeIconLabel(title: note.isPinned ? "Unpin" : "Pin", icon: .pin)
                                }
                                Button(role: .destructive) {
                                    withAnimation(reduceMotion ? nil : .snappy) { modelContext.delete(note) }
                                } label: {
                                    PlancalNativeIconLabel(title: "Delete", icon: .delete)
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
        .adaptiveNavigationTitle("Notes")
        .searchable(text: $query, prompt: "Search notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAddingNote = true } label: {
                    PlancalGlyph(icon: .newNote, weight: .bold, size: 18)
                        .accessibilityLabel("New note")
                }
                    .buttonStyle(.glassProminent)
                    .plancalHoverEffect(scale: 1.06, lifts: true)
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $isAddingNote) {
            NoteEditor()
        }
        .sheet(item: $editingNote) { note in
            NoteEditor(note: note)
        }
    }
}
