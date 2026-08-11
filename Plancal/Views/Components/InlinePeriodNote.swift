import SwiftData
import SwiftUI

@MainActor
enum PeriodNoteResolver {
    static func notes(
        from candidates: [MarkdownNote],
        scale: PlanningScale,
        anchorDate: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [MarkdownNote] {
        candidates
            .filter {
                $0.scope == .period
                    && $0.scale == scale
                    && scale.contains(
                        $0.anchorDate,
                        inPeriodContaining: anchorDate,
                        calendar: calendar
                    )
            }
            .sorted {
                if $0.isPinned != $1.isPinned {
                    return $0.isPinned
                }
                if $0.createdAt != $1.createdAt {
                    return $0.createdAt < $1.createdAt
                }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    static func defaultNote(from candidates: [MarkdownNote]) -> MarkdownNote? {
        candidates.min {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}

struct PeriodNotesSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext

    let notes: [MarkdownNote]
    let scale: PlanningScale
    let anchorDate: Date
    var onEditorFocusChanged: (Bool) -> Void = { _ in }

    @State private var revealsCollection = false
    @State private var editorPresentation: PeriodNoteEditorPresentation?

    private var periodIdentity: String {
        let periodStart = scale.interval(containing: anchorDate).start.timeIntervalSinceReferenceDate
        return "\(scale.rawValue)-\(periodStart)"
    }

    private var defaultNote: MarkdownNote? {
        PeriodNoteResolver.defaultNote(from: notes)
    }

    private var showsCollection: Bool {
        revealsCollection || notes.count > 1
    }

    var body: some View {
        Group {
            if showsCollection {
                collection
                    .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
            } else {
                InlinePeriodNote(
                    note: defaultNote,
                    scale: scale,
                    anchorDate: anchorDate,
                    onCreateNewNote: createAdditionalNote,
                    onEditorFocusChanged: onEditorFocusChanged
                )
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: showsCollection)
        .navigationDestination(item: $editorPresentation) { presentation in
            NoteEditor(
                note: presentation.note,
                initialScope: .period,
                initialScale: scale,
                initialDate: scale.interval(containing: anchorDate).start,
                locksPeriodAssignment: true,
                showsCancelAction: false,
                onSave: { _ in
                    revealsCollection = true
                },
                onCancel: {
                    if notes.count <= 1 {
                        revealsCollection = false
                    }
                }
            )
        }
        .onChange(of: periodIdentity) { _, _ in
            editorPresentation = nil
            revealsCollection = false
        }
    }

    private var collection: some View {
        VStack(alignment: .leading, spacing: 12) {
            collectionHeader

            if notes.isEmpty {
                EmptyStateCard(
                    icon: .notes,
                    title: "No notes yet",
                    message: "Create a note for this \(scale.shortTitle.lowercased())."
                )
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(minimum: 280, maximum: 480),
                            spacing: 14,
                            alignment: .top
                        )
                    ],
                    alignment: .leading,
                    spacing: 14
                ) {
                    ForEach(notes) { note in
                        Button {
                            edit(note)
                        } label: {
                            PeriodNoteCard(
                                note: note,
                                isDefault: note.id == defaultNote?.id
                            )
                        }
                        .buttonStyle(.plain)
                        .plancalHoverEffect(scale: 1.012, lifts: true)
                        .accessibilityHint("Opens the note and its editable title")
                        .contextMenu {
                            Button {
                                edit(note)
                            } label: {
                                PlancalNativeIconLabel(
                                    title: "Edit title and note",
                                    icon: .edit
                                )
                            }

                            if note.id != defaultNote?.id {
                                Button(role: .destructive) {
                                    delete(note)
                                } label: {
                                    PlancalNativeIconLabel(title: "Delete", icon: .delete)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var collectionHeader: some View {
        ViewThatFits(in: .horizontal) {
            collectionHeaderContent(compact: false)
            collectionHeaderContent(compact: true)
        }
    }

    private func collectionHeaderContent(compact: Bool) -> some View {
        HStack(spacing: 10) {
            PlancalIconLabel(title: "Notes", icon: .notes, weight: .bold, size: 20)
                .font(.title3.bold())

            Text("\(notes.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .frame(height: 26)
                .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Button(action: createAdditionalNote) {
                Group {
                    if compact {
                        PlancalGlyph(icon: .newNote, weight: .bold, size: 17)
                    } else {
                        PlancalIconLabel(
                            title: "New note",
                            icon: .newNote,
                            weight: .bold,
                            size: 17
                        )
                    }
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, compact ? 9 : 12)
                .frame(height: 36)
                .foregroundStyle(.white)
                .background(PlancalDesign.tint(for: scale).gradient, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.75)
                }
            }
            .buttonStyle(.plain)
            .plancalHoverEffect(scale: 1.035, lifts: true)
            .accessibilityLabel("Create another note")
        }
    }

    private func createAdditionalNote() {
        revealsCollection = true
        editorPresentation = PeriodNoteEditorPresentation(note: nil)
    }

    private func edit(_ note: MarkdownNote) {
        editorPresentation = PeriodNoteEditorPresentation(note: note)
    }

    private func delete(_ note: MarkdownNote) {
        guard note.id != defaultNote?.id else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
            modelContext.delete(note)
            try? modelContext.save()
            if notes.count <= 2 {
                revealsCollection = false
            }
        }
    }
}

private struct PeriodNoteEditorPresentation: Identifiable, Hashable {
    let id = UUID()
    let note: MarkdownNote?

    static func == (
        lhs: PeriodNoteEditorPresentation,
        rhs: PeriodNoteEditorPresentation
    ) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct PeriodNoteCard: View {
    let note: MarkdownNote
    let isDefault: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(note.title.isEmpty ? "Untitled note" : note.title)
                        .font(.headline)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    if isDefault {
                        Text("Default")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PlancalDesign.tint(for: note.scale))
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(
                                PlancalDesign.tint(for: note.scale).opacity(0.1),
                                in: Capsule()
                            )
                    }
                }

                if note.markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Empty note")
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
                } else {
                    Text(previewText)
                        .lineSpacing(3)
                        .lineLimit(5)
                        .frame(minHeight: 76, alignment: .topLeading)
                }

                Divider()

                HStack(spacing: 7) {
                    if note.isPinned {
                        PlancalGlyph(icon: .pin, weight: .fill, size: 14)
                            .foregroundStyle(PlancalDesign.tint(for: note.scale))
                            .accessibilityLabel("Pinned")
                    }
                    Spacer()
                    Text(note.updatedAt.formatted(.relative(presentation: .named)))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: PlancalDesign.cornerRadius))
    }

    private var previewText: String {
        var preview = note.markdown
        preview = preview.replacingOccurrences(
            of: #"(?m)^\s{0,3}#{1,6}\s+"#,
            with: "",
            options: .regularExpression
        )
        preview = preview.replacingOccurrences(
            of: #"(?m)^\s*[-+*]\s+"#,
            with: "• ",
            options: .regularExpression
        )
        preview = preview.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        for marker in ["**", "__", "~~", "`"] {
            preview = preview.replacingOccurrences(of: marker, with: "")
        }
        preview = preview.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
        return preview.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct InlinePeriodNote: View {
    @Environment(\.modelContext) private var modelContext

    private let note: MarkdownNote?
    private let scale: PlanningScale
    private let anchorDate: Date
    private let onCreateNewNote: () -> Void
    private let onEditorFocusChanged: (Bool) -> Void

    @State private var persistedNote: MarkdownNote?
    @State private var markdown: String
    @State private var lastSavedAt: Date?
    @State private var editingScale: PlanningScale
    @State private var editingAnchorDate: Date

    init(
        note: MarkdownNote?,
        scale: PlanningScale,
        anchorDate: Date,
        onCreateNewNote: @escaping () -> Void = {},
        onEditorFocusChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        let sourceMarkdown = note?.markdown ?? ""
        self.note = note
        self.scale = scale
        self.anchorDate = anchorDate
        self.onCreateNewNote = onCreateNewNote
        self.onEditorFocusChanged = onEditorFocusChanged
        _persistedNote = State(initialValue: note)
        _markdown = State(initialValue: sourceMarkdown)
        _lastSavedAt = State(initialValue: note?.updatedAt)
        _editingScale = State(initialValue: scale)
        _editingAnchorDate = State(initialValue: anchorDate)
    }

    private var periodIdentity: String {
        let periodStart = scale.interval(containing: anchorDate).start.timeIntervalSinceReferenceDate
        return "\(scale.rawValue)-\(periodStart)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                noteHeader(compact: false)
                noteHeader(compact: true)
            }

            GlassCard {
                RichMarkdownEditor(
                    markdown: $markdown,
                    placeholder: "Add context, intentions, links, or a reflection for this \(scale.shortTitle.lowercased())…",
                    minHeight: 220,
                    onFocusChanged: onEditorFocusChanged
                )
            }
        }
        .task(id: markdown) {
            do {
                try await Task.sleep(for: .milliseconds(600))
                saveIfNeeded()
            } catch {
                // A new edit or period change cancels the pending autosave.
            }
        }
        .onChange(of: periodIdentity) { _, _ in
            loadCurrentPeriod()
        }
        .onDisappear {
            saveIfNeeded()
        }
    }

    private func noteHeader(compact: Bool) -> some View {
        HStack(spacing: 10) {
            PlancalIconLabel(title: "Notes", icon: .notes, weight: .bold, size: 20)
                .font(.title3.bold())

            Spacer()

            HStack(spacing: 5) {
                PlancalGlyph(icon: saveStatusIcon, size: 14)
                if !compact {
                    Text(saveStatusText)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(saveStatusText)

            Button {
                saveIfNeeded(forceCreation: true)
                onCreateNewNote()
            } label: {
                if compact {
                    PlancalGlyph(icon: .newNote, weight: .bold, size: 17)
                        .frame(width: 36, height: 36)
                } else {
                    PlancalIconLabel(
                        title: "New note",
                        icon: .newNote,
                        weight: .bold,
                        size: 16
                    )
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 11)
                    .frame(height: 36)
                }
            }
            .foregroundStyle(PlancalDesign.tint(for: scale))
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        PlancalDesign.tint(for: scale).opacity(0.24),
                        lineWidth: 0.8
                    )
            }
            .buttonStyle(.plain)
            .plancalHoverEffect(scale: 1.035, lifts: true)
            .accessibilityLabel("Create another note")
        }
    }

    private var saveStatusIcon: PlancalIcon {
        lastSavedAt == nil ? .cloud : .synced
    }

    private var saveStatusText: String {
        if let lastSavedAt {
            return "Saved \(lastSavedAt.formatted(.relative(presentation: .named)))"
        }
        return "Saved automatically as you write"
    }

    @discardableResult
    private func saveIfNeeded(forceCreation: Bool = false) -> MarkdownNote? {
        let normalizedAnchor = editingScale.interval(containing: editingAnchorDate).start

        if let persistedNote {
            let needsSave = persistedNote.markdown != markdown
                || persistedNote.scope != .period
                || persistedNote.scale != editingScale
                || persistedNote.anchorDate != normalizedAnchor
            guard needsSave else { return persistedNote }

            persistedNote.markdown = markdown
            persistedNote.scope = .period
            persistedNote.scale = editingScale
            persistedNote.anchorDate = normalizedAnchor
            persistedNote.updatedAt = .now
            try? modelContext.save()
            lastSavedAt = persistedNote.updatedAt
            return persistedNote
        }

        guard forceCreation
                || !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        let note = MarkdownNote(
            title: "\(editingScale.label(for: editingAnchorDate)) notes",
            markdown: markdown,
            scope: .period,
            scale: editingScale,
            anchorDate: normalizedAnchor
        )
        modelContext.insert(note)
        try? modelContext.save()
        persistedNote = note
        lastSavedAt = note.updatedAt
        return note
    }

    private func loadCurrentPeriod() {
        saveIfNeeded()
        persistedNote = note
        markdown = note?.markdown ?? ""
        lastSavedAt = note?.updatedAt
        editingScale = scale
        editingAnchorDate = anchorDate
    }
}
