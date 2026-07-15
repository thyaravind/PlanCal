import XCTest
@testable import Plancal

final class PlanningScaleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    func testQuarterIntervalStartsOnQuarterBoundary() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15)))
        let interval = PlanningScale.quarterly.interval(containing: date, calendar: calendar)

        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: interval.start), DateComponents(year: 2026, month: 7, day: 1))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: interval.end), DateComponents(year: 2026, month: 10, day: 1))
        XCTAssertEqual(PlanningScale.quarterly.label(for: date, calendar: calendar), "Q3 2026")
    }

    func testWeeklyOffsetMovesExactlyOnePlanningWeek() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15)))
        let next = PlanningScale.weekly.offset(date, by: 1, calendar: calendar)

        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: next), DateComponents(year: 2026, month: 7, day: 22))
    }

    func testDefaultVisibleScalesAreDaysWeeksAndMonths() {
        XCTAssertEqual(PlanningScale.defaultVisibleStorageValue, "daily,weekly,monthly")
        XCTAssertEqual(
            PlanningScale.visibleScales(from: PlanningScale.defaultVisibleStorageValue),
            [.daily, .weekly, .monthly]
        )
    }

    func testVisibleScalesPreservePlanningOrderAndRecoverFromInvalidStorage() {
        XCTAssertEqual(
            PlanningScale.visibleScales(from: "yearly,daily,quarterly"),
            [.daily, .quarterly, .yearly]
        )
        XCTAssertEqual(
            PlanningScale.visibleScales(from: "unknown"),
            [.daily, .weekly, .monthly]
        )
        XCTAssertEqual(
            PlanningScale.storageValue(for: [.monthly, .daily]),
            "daily,monthly"
        )
    }

    func testScaleOptionsUsePluralNouns() {
        XCTAssertEqual(PlanningScale.allCases.map(\.pluralTitle), ["Days", "Weeks", "Months", "Quarters", "Years"])
    }

    func testToolbarUsesFullSelectedLabelAndInitialsForOtherScales() {
        XCTAssertEqual(PlanningScale.daily.toolbarLabel(isSelected: true), "Day")
        XCTAssertEqual(PlanningScale.weekly.toolbarLabel(isSelected: false), "W")
        XCTAssertEqual(PlanningScale.monthly.toolbarLabel(isSelected: false), "M")
        XCTAssertEqual(PlanningScale.quarterly.toolbarLabel(isSelected: false), "Q")
        XCTAssertEqual(PlanningScale.yearly.toolbarLabel(isSelected: false), "Y")
    }

    func testTaskLabelsDescribeTheConcretePeriod() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15)))
        let labels = PlanningScale.allCases.map { $0.taskLabel(for: date, calendar: calendar) }

        XCTAssertTrue(labels.allSatisfy { $0.contains("2026") })
        XCTAssertFalse(labels.contains("Day"))
        XCTAssertFalse(labels.contains("Week"))
        XCTAssertFalse(labels.contains("Month"))
        XCTAssertFalse(labels.contains("Quarter"))
        XCTAssertFalse(labels.contains("Year"))
        XCTAssertEqual(labels[3], "Q3 2026")
    }

    @MainActor
    func testRolloverPreservesOriginalPeriod() throws {
        let original = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 14)))
        let current = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 9)))
        let task = PlannerTask(title: "Carry me", scale: .daily, scheduledDate: original)

        let changed = RolloverService.rollForwardOutstandingTasks([task], to: current, calendar: calendar)

        XCTAssertEqual(changed, 1)
        XCTAssertEqual(task.originalDate, original)
        XCTAssertEqual(calendar.startOfDay(for: task.scheduledDate), calendar.startOfDay(for: current))
        XCTAssertEqual(task.carryCount, 1)
        XCTAssertTrue(task.isOverdue(at: current, calendar: calendar))
    }

    @MainActor
    func testCompletedTaskDoesNotRollForward() throws {
        let original = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let current = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15)))
        let task = PlannerTask(title: "Already done", scale: .monthly, scheduledDate: original)
        task.setCompleted(true)

        let changed = RolloverService.rollForwardOutstandingTasks([task], to: current, calendar: calendar)

        XCTAssertEqual(changed, 0)
        XCTAssertEqual(task.scheduledDate, original)
    }
}
