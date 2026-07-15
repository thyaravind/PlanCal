import XCTest
@testable import Plancal

@MainActor
final class NotificationSummaryTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    func testBriefNamesTodaysDailyTasks() throws {
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 8)))
        let task = PlannerTask(title: "Finish the launch brief", scale: .daily, scheduledDate: day)

        let summary = DailyBriefSummary.make(for: day, tasks: [task], calendar: calendar)

        XCTAssertEqual(summary.title, "Today · 1 task")
        XCTAssertEqual(summary.body, "Finish the launch brief")
    }

    func testBriefCountsPendingWorkFromEarlierPeriods() throws {
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 8)))
        let earlierMonth = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let overdue = PlannerTask(title: "Close the June review", scale: .monthly, scheduledDate: earlierMonth)

        let summary = DailyBriefSummary.make(for: day, tasks: [overdue], calendar: calendar)

        XCTAssertEqual(summary.title, "A clear start")
        XCTAssertEqual(summary.body, "1 pending from an earlier period")
    }

    func testCompletedWorkIsExcludedFromBrief() throws {
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 8)))
        let earlierDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 14)))
        let completed = PlannerTask(title: "Already done", scale: .daily, scheduledDate: earlierDay)
        completed.setCompleted(true)

        let summary = DailyBriefSummary.make(for: day, tasks: [completed], calendar: calendar)

        XCTAssertEqual(summary.title, "A clear start")
        XCTAssertEqual(summary.body, "Take a moment to shape the day in Plancal.")
    }
}
