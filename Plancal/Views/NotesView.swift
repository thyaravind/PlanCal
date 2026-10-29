import SwiftData
import SwiftUI

struct NotesView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MarkdownNote.updatedAt, order: .reverse) private var notes: [MarkdownNote]
    @State private var query = ""
    @State private var editorPresentation: StandaloneNoteEditorPresentation?

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
                    notesSearchField
                    if visibleNotes.isEmpty {
                        EmptyStateCard(icon: .notes, title: "A quiet page", message: query.isEmpty ? "Create a Markdown note whenever an idea arrives." : "No notes match your search.")
                    } else {
                        ForEach(visibleNotes) { note in
                            Button {
                                editorPresentation = StandaloneNoteEditorPresentation(note: note)
                            } label: {
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorPresentation = StandaloneNoteEditorPresentation(note: nil)
                } label: {
                    PlancalGlyph(icon: .newNote, weight: .bold, size: 18)
                        .accessibilityLabel("New note")
                }
                    .buttonStyle(.glassProminent)
                    .plancalHoverEffect(scale: 1.06, lifts: true)
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
        .navigationDestination(item: $editorPresentation) { presentation in
            NoteEditor(
                note: presentation.note
            )
        }
    }

    private var notesSearchField: some View {
        HStack(spacing: 10) {
            PlancalGlyph(icon: .search, size: 18)
                .foregroundStyle(.secondary)

            TextField("Search notes", text: $query)
                .textFieldStyle(.plain)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    PlancalGlyph(icon: .close, weight: .bold, size: 14)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: 360, minHeight: 42)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StandaloneNoteEditorPresentation: Identifiable, Hashable {
    let id = UUID()
    let note: MarkdownNote?

    static func == (
        lhs: StandaloneNoteEditorPresentation,
        rhs: StandaloneNoteEditorPresentation
    ) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
