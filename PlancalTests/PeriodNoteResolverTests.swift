import XCTest
@testable import Plancal

final class PeriodNoteResolverTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    @MainActor
    func testExistingSinglePeriodNoteRemainsTheDefault() throws {
        let july16 = try date(year: 2026, month: 7, day: 16)
        let existing = MarkdownNote(
            title: "Existing title",
            markdown: "# Existing content",
            scope: .period,
            scale: .daily,
            anchorDate: july16
        )

        let resolved = PeriodNoteResolver.notes(
            from: [existing],
            scale: .daily,
            anchorDate: july16,
            calendar: calendar
        )

        XCTAssertEqual(resolved.map(\.id), [existing.id])
        XCTAssertEqual(resolved.first?.title, "Existing title")
        XCTAssertEqual(resolved.first?.markdown, "# Existing content")
    }

    @MainActor
    func testOldestPeriodNoteIsTheStableDefault() throws {
        let july16 = try date(year: 2026, month: 7, day: 16)
        let oldest = MarkdownNote(
            title: "Default note",
            scope: .period,
            scale: .daily,
            anchorDate: july16
        )
        oldest.createdAt = try XCTUnwrap(
            calendar.date(byAdding: .hour, value: -2, to: july16)
        )

        let newest = MarkdownNote(
            title: "Second note",
            scope: .period,
            scale: .daily,
            anchorDate: july16
        )
        newest.createdAt = try XCTUnwrap(
            calendar.date(byAdding: .hour, value: -1, to: july16)
        )

        let resolved = PeriodNoteResolver.notes(
            from: [newest, oldest],
            scale: .daily,
            anchorDate: july16,
            calendar: calendar
        )

        XCTAssertEqual(resolved.map(\.id), [oldest.id, newest.id])
    }

    @MainActor
    func testPinnedNotesAppearFirstWithoutReplacingTheStableDefault() throws {
        let july16 = try date(year: 2026, month: 7, day: 16)
        let oldest = MarkdownNote(
            title: "Default note",
            scope: .period,
            scale: .daily,
            anchorDate: july16
        )
        oldest.createdAt = try XCTUnwrap(
            calendar.date(byAdding: .hour, value: -2, to: july16)
        )

        let pinned = MarkdownNote(
            title: "Pinned note",
            scope: .period,
            scale: .daily,
            anchorDate: july16
        )
        pinned.createdAt = try XCTUnwrap(
            calendar.date(byAdding: .hour, value: -1, to: july16)
        )
        pinned.isPinned = true

        let resolved = PeriodNoteResolver.notes(
            from: [oldest, pinned],
            scale: .daily,
            anchorDate: july16,
            calendar: calendar
        )

        XCTAssertEqual(resolved.map(\.id), [pinned.id, oldest.id])
        XCTAssertEqual(
            PeriodNoteResolver.defaultNote(from: resolved)?.id,
            oldest.id
        )
    }

    @MainActor
    func testResolverExcludesOtherPeriodsScalesAndIndependentNotes() throws {
        let july16 = try date(year: 2026, month: 7, day: 16)
        let july17 = try date(year: 2026, month: 7, day: 17)
        let matching = MarkdownNote(
            title: "Matching",
            scope: .period,
            scale: .daily,
            anchorDate: july16
        )
        let tomorrow = MarkdownNote(
            title: "Tomorrow",
            scope: .period,
            scale: .daily,
            anchorDate: july17
        )
        let weekly = MarkdownNote(
            title: "Weekly",
            scope: .period,
            scale: .weekly,
            anchorDate: july16
        )
        let independent = MarkdownNote(
            title: "Independent",
            scope: .independent,
            scale: .daily,
            anchorDate: july16
        )

        let resolved = PeriodNoteResolver.notes(
            from: [tomorrow, weekly, independent, matching],
            scale: .daily,
            anchorDate: july16,
            calendar: calendar
        )

        XCTAssertEqual(resolved.map(\.id), [matching.id])
    }

    private func date(year: Int, month: Int, day: Int) throws -> Date {
        try XCTUnwrap(
            calendar.date(from: DateComponents(year: year, month: month, day: day))
        )
    }
}
