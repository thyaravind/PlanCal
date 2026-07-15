import SwiftData
import SwiftUI

struct InlinePeriodNote: View {
    @Environment(\.modelContext) private var modelContext

    private let note: MarkdownNote?
    private let scale: PlanningScale
    private let anchorDate: Date
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
        onEditorFocusChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        let sourceMarkdown = note?.markdown ?? ""
        self.note = note
        self.scale = scale
        self.anchorDate = anchorDate
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

    private func saveIfNeeded() {
        if let persistedNote {
            guard persistedNote.markdown != markdown else { return }
            persistedNote.markdown = markdown
            persistedNote.title = "\(editingScale.label(for: editingAnchorDate)) notes"
            persistedNote.scope = .period
            persistedNote.scale = editingScale
            persistedNote.anchorDate = editingScale.interval(containing: editingAnchorDate).start
            persistedNote.updatedAt = .now
            try? modelContext.save()
            lastSavedAt = persistedNote.updatedAt
            return
        }

        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let note = MarkdownNote(
            title: "\(editingScale.label(for: editingAnchorDate)) notes",
            markdown: markdown,
            scope: .period,
            scale: editingScale,
            anchorDate: editingScale.interval(containing: editingAnchorDate).start
        )
        modelContext.insert(note)
        try? modelContext.save()
        persistedNote = note
        lastSavedAt = note.updatedAt
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
