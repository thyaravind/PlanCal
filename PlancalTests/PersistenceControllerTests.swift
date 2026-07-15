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
}
