import SwiftData
import XCTest
@testable import Plancal

final class PersistenceControllerTests: XCTestCase {
    @MainActor
    func testInMemoryStoreRoundTrip() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        context.insert(PlannerTask(title: "Write the plan", scale: .weekly))
        try context.save()

        let tasks = try context.fetch(FetchDescriptor<PlannerTask>())
        XCTAssertEqual(tasks.map(\.title), ["Write the plan"])
        XCTAssertEqual(persistence.syncMode, .inMemory)
    }

    @MainActor
    func testStoreKeepsMultipleNotesForTheSamePeriod() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let anchor = PlanningScale.monthly.interval(containing: .now).start

        context.insert(
            MarkdownNote(
                title: "Default note",
                scope: .period,
                scale: .monthly,
                anchorDate: anchor
            )
        )
        context.insert(
            MarkdownNote(
                title: "Review notes",
                scope: .period,
                scale: .monthly,
                anchorDate: anchor
            )
        )
        try context.save()

        let notes = try context.fetch(FetchDescriptor<MarkdownNote>())
        XCTAssertEqual(notes.count, 2)
        XCTAssertEqual(Set(notes.map(\.title)), ["Default note", "Review notes"])
    }

    @MainActor
    func testIndependentNoteAutosaveCreatesAMeaningfulDraft() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let draft = NoteEditorDraft(
            title: "Research",
            markdown: "Capture the findings",
            scope: .independent,
            scale: .daily,
            anchorDate: .now,
            isPinned: false
        )

        let result = NoteEditorPersistence.persist(
            existing: nil,
            draft: draft,
            modelContext: context
        )

        XCTAssertTrue(result.didSave)
        XCTAssertEqual(result.note?.title, "Research")
        XCTAssertEqual(try context.fetch(FetchDescriptor<MarkdownNote>()).count, 1)
    }

    @MainActor
    func testIndependentNoteAutosaveDoesNotCreateAnEmptyDraft() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let draft = NoteEditorDraft(
            title: "  ",
            markdown: "\n",
            scope: .independent,
            scale: .daily,
            anchorDate: .now,
            isPinned: false
        )

        let result = NoteEditorPersistence.persist(
            existing: nil,
            draft: draft,
            modelContext: context
        )

        XCTAssertFalse(result.didSave)
        XCTAssertNil(result.note)
        XCTAssertTrue(try context.fetch(FetchDescriptor<MarkdownNote>()).isEmpty)
    }

    @MainActor
    func testIndependentNoteAutosaveUpdatesWithoutCreatingADuplicate() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let note = MarkdownNote(title: "Draft", markdown: "Before")
        context.insert(note)
        try context.save()

        let result = NoteEditorPersistence.persist(
            existing: note,
            draft: NoteEditorDraft(
                title: "Draft",
                markdown: "After",
                scope: .independent,
                scale: .daily,
                anchorDate: note.anchorDate,
                isPinned: true
            ),
            modelContext: context
        )

        let notes = try context.fetch(FetchDescriptor<MarkdownNote>())
        XCTAssertTrue(result.didSave)
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.markdown, "After")
        XCTAssertEqual(notes.first?.isPinned, true)
    }

    @MainActor
    func testPeriodNoteAutosaveCreatesAndNormalizesTheAssignedPeriod() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let selectedDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 23, hour: 18))
        )

        let result = NoteEditorPersistence.persist(
            existing: nil,
            draft: NoteEditorDraft(
                title: "August review",
                markdown: "Progress and decisions",
                scope: .period,
                scale: .monthly,
                anchorDate: selectedDate,
                isPinned: false
            ),
            modelContext: context
        )

        XCTAssertTrue(result.didSave)
        XCTAssertEqual(result.note?.scope, .period)
        XCTAssertEqual(result.note?.scale, .monthly)
        XCTAssertEqual(
            result.note?.anchorDate,
            PlanningScale.monthly.interval(containing: selectedDate).start
        )
        XCTAssertEqual(try context.fetch(FetchDescriptor<MarkdownNote>()).count, 1)
    }
}
