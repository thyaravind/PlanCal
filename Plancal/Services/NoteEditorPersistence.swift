import Foundation
import SwiftData

struct NoteEditorDraft {
    let title: String
    let markdown: String
    let scope: NoteScope
    let scale: PlanningScale
    let anchorDate: Date
    let isPinned: Bool

    var hasMeaningfulContent: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || isPinned
    }

    func normalizedAnchor(calendar: Calendar = .autoupdatingCurrent) -> Date {
        scope == .period
            ? scale.interval(containing: anchorDate, calendar: calendar).start
            : anchorDate
    }
}

struct NoteEditorPersistenceResult {
    let note: MarkdownNote?
    let didSave: Bool
}

@MainActor
enum NoteEditorPersistence {
    static func persist(
        existing: MarkdownNote?,
        draft: NoteEditorDraft,
        now: Date = .now,
        modelContext: ModelContext
    ) -> NoteEditorPersistenceResult {
        let cleanTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedTitle = cleanTitle.isEmpty ? "Untitled note" : cleanTitle
        let normalizedAnchor = draft.normalizedAnchor()

        if let existing {
            let needsSave = existing.title != storedTitle
                || existing.markdown != draft.markdown
                || existing.scope != draft.scope
                || existing.scale != draft.scale
                || existing.anchorDate != normalizedAnchor
                || existing.isPinned != draft.isPinned
            guard needsSave else {
                return NoteEditorPersistenceResult(note: existing, didSave: false)
            }

            existing.title = storedTitle
            existing.markdown = draft.markdown
            existing.scope = draft.scope
            existing.scale = draft.scale
            existing.anchorDate = normalizedAnchor
            existing.isPinned = draft.isPinned
            existing.updatedAt = now
            do {
                try modelContext.save()
                return NoteEditorPersistenceResult(note: existing, didSave: true)
            } catch {
                return NoteEditorPersistenceResult(note: existing, didSave: false)
            }
        }

        guard draft.hasMeaningfulContent else {
            return NoteEditorPersistenceResult(note: nil, didSave: false)
        }

        let note = MarkdownNote(
            title: storedTitle,
            markdown: draft.markdown,
            scope: draft.scope,
            scale: draft.scale,
            anchorDate: normalizedAnchor
        )
        note.isPinned = draft.isPinned
        note.createdAt = now
        note.updatedAt = now
        modelContext.insert(note)
        do {
            try modelContext.save()
            return NoteEditorPersistenceResult(note: note, didSave: true)
        } catch {
            return NoteEditorPersistenceResult(note: note, didSave: false)
        }
    }
}
