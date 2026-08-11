#if os(macOS)
import AppKit
import SwiftData
import SwiftUI
import XCTest
@testable import Plancal

@MainActor
final class DesignSnapshotTests: XCTestCase {
    func testPopulatedPlannerRendersAtDesktopCompactAndAccessibleSizes() throws {
        UserDefaults.standard.set(PlanningScale.defaultVisibleStorageValue, forKey: "planning.visibleScales")
        let persistence = PersistenceController(inMemory: true)
        try seedPlanner(in: persistence.container.mainContext)
        var compactLayoutWidth: CGFloat?

        let desktop = PlannerView()
            .modelContainer(persistence.container)
            .frame(width: 1200, height: 900)
            .environment(\.colorScheme, .light)

        let compact = PlannerView()
            .background {
                GeometryReader { geometry in
                    Color.clear.onAppear {
                        compactLayoutWidth = geometry.size.width
                    }
                }
            }
            .modelContainer(persistence.container)
            .frame(width: 390, height: 844)
            .environment(\.colorScheme, .light)

        let accessible = PlannerView()
            .modelContainer(persistence.container)
            .frame(width: 390, height: 932)
            .environment(\.colorScheme, .dark)
            .environment(\.dynamicTypeSize, .accessibility2)

        try render(desktop, width: 1200, height: 900, to: "/tmp/plancal-planner-desktop.png")
        try render(compact, width: 390, height: 844, to: "/tmp/plancal-planner-compact.png")
        try render(accessible, width: 390, height: 932, to: "/tmp/plancal-planner-accessible.png")
        XCTAssertEqual(compactLayoutWidth, 390)
    }

    func testTodayRendersAtCompactAccessibilitySize() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        context.insert(
            PlannerTask(
                title: "Choose the one result that would make today meaningful",
                details: "Leave enough space to do it well.",
                scale: .daily,
                scheduledDate: .now,
                priority: .essential
            )
        )
        context.insert(
            PlannerEvent(
                title: "Design review",
                startDate: .now,
                endDate: Calendar.autoupdatingCurrent.date(byAdding: .hour, value: 1, to: .now) ?? .now,
                isAllDay: false,
                syncsWithAppleCalendar: false
            )
        )
        try context.save()

        var layoutWidth: CGFloat?
        let content = TodayView()
            .background {
                GeometryReader { geometry in
                    Color.clear.onAppear { layoutWidth = geometry.size.width }
                }
            }
            .environment(NotificationService())
            .modelContainer(persistence.container)
            .frame(width: 390, height: 932)
            .environment(\.colorScheme, .dark)
            .environment(\.dynamicTypeSize, .accessibility2)

        try render(content, width: 390, height: 932, to: "/tmp/plancal-today-accessible.png")
        XCTAssertEqual(layoutWidth, 390)
    }

    func testPeriodNoteCollectionRendersAsAGridAndCompactList() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let anchor = PlanningScale.monthly.interval(containing: .now).start
        let defaultNote = MarkdownNote(
            title: "Monthly direction",
            markdown: "## Focus\n\nBuild the smallest thing that makes the month feel meaningful.",
            scope: .period,
            scale: .monthly,
            anchorDate: anchor
        )
        defaultNote.createdAt = anchor
        let reviewNote = MarkdownNote(
            title: "Review notes",
            markdown: "### Learnings\n\n- Keep momentum visible\n- Protect deliberate work",
            scope: .period,
            scale: .monthly,
            anchorDate: anchor
        )
        reviewNote.isPinned = true
        reviewNote.createdAt = Calendar.autoupdatingCurrent.date(
            byAdding: .minute,
            value: 1,
            to: anchor
        ) ?? anchor
        context.insert(defaultNote)
        context.insert(reviewNote)
        try context.save()

        let notes = PeriodNoteResolver.notes(
            from: [reviewNote, defaultNote],
            scale: .monthly,
            anchorDate: anchor
        )
        let desktop = PeriodNotesSection(
            notes: notes,
            scale: .monthly,
            anchorDate: anchor
        )
        .modelContainer(persistence.container)
        .frame(width: 900, height: 420, alignment: .top)

        let compact = PeriodNotesSection(
            notes: notes,
            scale: .monthly,
            anchorDate: anchor
        )
        .modelContainer(persistence.container)
        .frame(width: 390, height: 680, alignment: .top)

        try render(
            desktop,
            width: 900,
            height: 420,
            to: "/tmp/plancal-period-notes-grid.png"
        )
        try render(
            compact,
            width: 390,
            height: 680,
            to: "/tmp/plancal-period-notes-list.png"
        )
    }

    private func seedPlanner(in context: ModelContext) throws {
        let interval = PlanningScale.weekly.interval(containing: .now)
        let firstDay = interval.start
        let secondDay = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: firstDay) ?? firstDay
        let thirdDay = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 2, to: firstDay) ?? firstDay

        context.insert(
            PlannerTask(
                title: "Shape the week around one meaningful outcome",
                details: "Protect two uninterrupted hours before accepting new work.",
                scale: .weekly,
                scheduledDate: firstDay,
                priority: .essential
            )
        )
        context.insert(
            PlannerTask(
                title: "Review the product direction",
                details: "Decide what deserves attention next.",
                scale: .weekly,
                scheduledDate: secondDay,
                priority: .important
            )
        )
        let completed = PlannerTask(
            title: "Clear the planning inbox",
            scale: .weekly,
            scheduledDate: thirdDay
        )
        completed.setCompleted(true)
        context.insert(completed)

        context.insert(
            MarkdownNote(
                title: "This week’s notes",
                markdown: "## Intention\n\nMake progress feel calm, visible, and deliberate.\n\n- Protect focus\n- Leave room to think",
                scope: .period,
                scale: .weekly,
                anchorDate: firstDay
            )
        )
        try context.save()
    }

    private func render<Content: View>(
        _ content: Content,
        width: CGFloat,
        height: CGFloat,
        to path: String
    ) throws {
        let hostingView = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: -20_000, y: -20_000, width: width, height: height),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
        window.setContentSize(NSSize(width: width, height: height))
        window.orderFront(nil)

        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.45))
        hostingView.layoutSubtreeIfNeeded()

        guard let representation = hostingView.bitmapImageRepForCachingDisplay(
            in: hostingView.bounds
        ) else {
            window.orderOut(nil)
            XCTFail("Unable to render \(path)")
            return
        }
        hostingView.cacheDisplay(
            in: hostingView.bounds,
            to: representation
        )
        window.orderOut(nil)

        guard let data = representation.representation(using: .png, properties: [:]) else {
            XCTFail("Unable to encode \(path)")
            return
        }

        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        XCTAssertGreaterThanOrEqual(representation.pixelsWide, Int(width))
        XCTAssertGreaterThanOrEqual(representation.pixelsHigh, Int(height))
    }
}
#endif
