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

    func testPlanningPeriodsExcludeTheirEndBoundary() throws {
        let july16 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 16)))
        let july17 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 17)))

        XCTAssertTrue(PlanningScale.daily.contains(july16, inPeriodContaining: july16, calendar: calendar))
        XCTAssertFalse(PlanningScale.daily.contains(july17, inPeriodContaining: july16, calendar: calendar))
        XCTAssertTrue(PlanningScale.daily.contains(july17, inPeriodContaining: july17, calendar: calendar))
    }

    func testCurrentDailyAnchorAdvancesWhenTheDayChanges() throws {
        let july15 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 23)))
        let july16 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 16, hour: 1)))

        let resolved = CurrentPeriodAnchorResolver.resolvedAnchor(
            currentAnchor: PlanningScale.daily.interval(containing: july15, calendar: calendar).start,
            scale: .daily,
            previousNow: july15,
            currentNow: july16,
            calendar: calendar
        )

        XCTAssertEqual(
            resolved,
            PlanningScale.daily.interval(containing: july16, calendar: calendar).start
        )
    }

    func testCurrentMonthlyAnchorAdvancesWhenTheMonthChanges() throws {
        let july31 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 31, hour: 23)))
        let august1 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 1)))

        let resolved = CurrentPeriodAnchorResolver.resolvedAnchor(
            currentAnchor: PlanningScale.monthly.interval(containing: july31, calendar: calendar).start,
            scale: .monthly,
            previousNow: july31,
            currentNow: august1,
            calendar: calendar
        )

        XCTAssertEqual(
            resolved,
            PlanningScale.monthly.interval(containing: august1, calendar: calendar).start
        )
    }

    func testPeriodRolloverDoesNotMoveAnAnchorTheUserIsBrowsing() throws {
        let july10 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 10)))
        let july15 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 23)))
        let july16 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 16, hour: 1)))

        let resolved = CurrentPeriodAnchorResolver.resolvedAnchor(
            currentAnchor: july10,
            scale: .daily,
            previousNow: july15,
            currentNow: july16,
            calendar: calendar
        )

        XCTAssertEqual(resolved, july10)
    }

    @MainActor
    func testTaskAtNextPeriodBoundaryDoesNotBelongToPreviousPeriod() throws {
        let july16 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 16)))
        let july17 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 17)))
        let task = PlannerTask(title: "Tomorrow", scale: .daily, scheduledDate: july17)

        XCTAssertFalse(task.belongs(to: .daily, anchor: july16, calendar: calendar))
        XCTAssertTrue(task.belongs(to: .daily, anchor: july17, calendar: calendar))
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
    func testTodayCarryoverOnlyIncludesDailyTasks() throws {
        let current = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 9)))
        let tasks = [
            PlannerTask(
                title: "Daily carryover",
                scale: .daily,
                scheduledDate: try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 14)))
            ),
            PlannerTask(
                title: "Weekly carryover",
                scale: .weekly,
                scheduledDate: try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 6)))
            ),
            PlannerTask(
                title: "Monthly carryover",
                scale: .monthly,
                scheduledDate: try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
            ),
        ]

        XCTAssertEqual(
            RolloverService.rollForwardOutstandingTasks(tasks, to: current, calendar: calendar),
            3
        )

        let carriedDailyTasks = TodayTaskFilter.carriedDailyTasks(
            from: tasks,
            on: current,
            calendar: calendar
        )

        XCTAssertEqual(carriedDailyTasks.map(\.title), ["Daily carryover"])
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

    @MainActor
    func testDisabledRolloverLeavesOverdueTaskInOriginalPeriod() throws {
        let original = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 14)))
        let current = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 16)))
        let task = PlannerTask(title: "Leave me", scale: .daily, scheduledDate: original)

        let changed = RolloverService.rollForwardOutstandingTasks(
            [task],
            enabled: false,
            to: current,
            calendar: calendar
        )

        XCTAssertEqual(changed, 0)
        XCTAssertEqual(task.scheduledDate, original)
        XCTAssertEqual(task.carryCount, 0)
    }
}
