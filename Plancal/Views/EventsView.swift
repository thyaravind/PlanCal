import SwiftData
import SwiftUI

struct EventsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(AppleCalendarService.self) private var calendarService
    @Query(sort: \PlannerEvent.startDate) private var events: [PlannerEvent]
    @State private var externalEvents: [CalendarEventSnapshot] = []
    @State private var isAddingEvent = false
    @State private var editingEvent: PlannerEvent?

    private var eventRevision: String {
        "\(events.count)-\(events.last?.updatedAt.timeIntervalSinceReferenceDate ?? 0)-\(calendarService.authorizationStatus.rawValue)"
    }

    private var unsyncedExternalEvents: [CalendarEventSnapshot] {
        let synced = Set(events.compactMap(\.appleCalendarIdentifier))
        return externalEvents.filter { !synced.contains($0.eventIdentifier) }
    }

    var body: some View {
        ZStack {
            AtmosphericBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    PageHeader(eyebrow: "Time", title: "Calendar", subtitle: "Single-day and multi-day events, together with Apple Calendar.")

                    if !calendarService.hasFullAccess {
                        AdaptiveActionCard(
                            icon: .calendarAccess,
                            title: "Bring in Apple Calendar",
                            message: "See existing events and keep new Plancal events in sync.",
                            actionTitle: "Allow access"
                        ) {
                            Task {
                                if await calendarService.requestFullAccess() { refreshExternalEvents() }
                            }
                        }
                    }

                    eventSection(title: "Plancal events", appEvents: events)

                    if calendarService.hasFullAccess {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Apple Calendar")
                                    .font(.title3.bold())
                                Spacer()
                                Text("Next 90 days")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if unsyncedExternalEvents.isEmpty {
                                EmptyStateCard(icon: .calendar, title: "No other events", message: "Apple Calendar has no additional events in this window.")
                            } else {
                                GlassCard {
                                    VStack(spacing: 16) {
                                        ForEach(unsyncedExternalEvents) { event in
                                            externalEventRow(event)
                                            if event.id != unsyncedExternalEvents.last?.id { Divider() }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: PlancalDesign.contentWidth)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
        .adaptiveNavigationTitle("Calendar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAddingEvent = true } label: {
                    PlancalGlyph(icon: .add, weight: .bold, size: 18)
                        .accessibilityLabel("New event")
                }
                    .buttonStyle(.glassProminent)
                    .plancalHoverEffect(scale: 1.06, lifts: true)
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $isAddingEvent) {
            EventEditor()
        }
        .sheet(item: $editingEvent) { event in
            EventEditor(event: event, initialDate: event.startDate)
        }
        .task(id: eventRevision) {
            calendarService.refreshAuthorization()
            refreshExternalEvents()
        }
    }

    @ViewBuilder
    private func eventSection(title: String, appEvents: [PlannerEvent]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold())
            if appEvents.isEmpty {
                EmptyStateCard(icon: .calendarAccess, title: "Open calendar", message: "Create an all-day, timed, or multi-day event.")
            } else {
                GlassCard {
                    VStack(spacing: 16) {
                        ForEach(appEvents) { event in
                            Button { editingEvent = event } label: {
                                eventRow(event)
                            }
                            .buttonStyle(.plain)
                            .plancalHoverEffect(scale: 1.012)
                            .contextMenu {
                                Button(role: .destructive) {
                                    delete(event)
                                } label: {
                                    PlancalNativeIconLabel(title: "Delete", icon: .delete)
                                }
                            }
                            if event.id != appEvents.last?.id { Divider() }
                        }
                    }
                }
            }
        }
    }

    private func eventRow(_ event: PlannerEvent) -> some View {
        HStack(alignment: .top, spacing: 13) {
            PlancalGlyph(icon: event.isAllDay ? .calendar : .clock, size: 21)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                EventDateLabel(startDate: event.startDate, endDate: event.endDate, isAllDay: event.isAllDay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { eventMetadata(event) }
                    VStack(alignment: .leading, spacing: 4) { eventMetadata(event) }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Edit event") { editingEvent = event }
    }

    @ViewBuilder
    private func eventMetadata(_ event: PlannerEvent) -> some View {
        if !event.location.isEmpty {
            PlancalIconLabel(title: event.location, icon: .location, size: 13)
        }
        if event.recurrence != .none {
            PlancalIconLabel(title: event.recurrence.title, icon: .recurrence, size: 13)
        }
        if event.appleCalendarIdentifier != nil {
            PlancalIconLabel(title: "Synced", icon: .synced, size: 13)
        }
    }

    private func externalEventRow(_ event: CalendarEventSnapshot) -> some View {
        HStack(alignment: .top, spacing: 13) {
            PlancalGlyph(icon: .calendar, size: 19)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(.body.weight(.medium))
                EventDateLabel(startDate: event.startDate, endDate: event.endDate, isAllDay: event.isAllDay)
                    .font(.caption)
                Text(event.calendarTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func refreshExternalEvents() {
        guard calendarService.hasFullAccess else {
            externalEvents = []
            return
        }
        let calendar = Calendar.autoupdatingCurrent
        let start = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        let end = calendar.date(byAdding: .day, value: 90, to: .now) ?? .now.addingTimeInterval(7_776_000)
        externalEvents = calendarService.fetchEvents(from: start, to: end)
    }

    private func delete(_ event: PlannerEvent) {
        if event.appleCalendarIdentifier != nil {
            try? calendarService.removeFromAppleCalendar(event)
        }
        withAnimation(reduceMotion ? nil : .snappy) { modelContext.delete(event) }
        try? modelContext.save()
        refreshExternalEvents()
    }
}
