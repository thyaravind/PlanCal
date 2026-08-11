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
}
