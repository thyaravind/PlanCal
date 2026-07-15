import EventKit
import Foundation
import Observation

struct CalendarChoice: Identifiable, Hashable {
    let id: String
    let title: String
    let sourceTitle: String
}

struct CalendarEventSnapshot: Identifiable, Hashable {
    let id: String
    let eventIdentifier: String
    let title: String
    let location: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let calendarIdentifier: String
    let canEdit: Bool
}

@MainActor
@Observable
final class AppleCalendarService {
    private let eventStore = EKEventStore()
    private let defaults: UserDefaults

    private(set) var authorizationStatus: EKAuthorizationStatus
    private(set) var writableCalendars: [CalendarChoice] = []
    private(set) var lastError: String?
    var selectedCalendarIdentifier: String? {
        didSet {
            defaults.set(selectedCalendarIdentifier, forKey: Self.selectedCalendarKey)
        }
    }

    private static let selectedCalendarKey = "calendar.selectedIdentifier"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        selectedCalendarIdentifier = defaults.string(forKey: Self.selectedCalendarKey)
        refreshCalendars()
    }

    var hasFullAccess: Bool {
        authorizationStatus == .fullAccess
    }

    var authorizationTitle: String {
        switch authorizationStatus {
        case .notDetermined: "Not requested"
        case .restricted: "Restricted"
        case .denied: "Denied"
        case .fullAccess: "Full access"
        case .writeOnly: "Write only"
        default: "Unknown"
        }
    }

    func refreshAuthorization() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        refreshCalendars()
    }

    @discardableResult
    func requestFullAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            lastError = nil
            refreshAuthorization()
            return granted
        } catch {
            lastError = error.localizedDescription
            refreshAuthorization()
            return false
        }
    }

    func refreshCalendars() {
        guard hasFullAccess || authorizationStatus == .writeOnly else {
            writableCalendars = []
            return
        }

        writableCalendars = eventStore.calendars(for: .event)
            .filter(\.allowsContentModifications)
            .map {
                CalendarChoice(
                    id: $0.calendarIdentifier,
                    title: $0.title,
                    sourceTitle: $0.source.title
                )
            }
            .sorted {
                if $0.sourceTitle == $1.sourceTitle {
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                return $0.sourceTitle.localizedStandardCompare($1.sourceTitle) == .orderedAscending
            }

        if let selectedCalendarIdentifier,
           writableCalendars.contains(where: { $0.id == selectedCalendarIdentifier }) {
            return
        }
        selectedCalendarIdentifier = eventStore.defaultCalendarForNewEvents?.calendarIdentifier ?? writableCalendars.first?.id
    }

    func fetchEvents(from start: Date, to end: Date) -> [CalendarEventSnapshot] {
        guard hasFullAccess else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        return eventStore.events(matching: predicate)
            .map { event in
                let visibleEnd: Date
                if event.isAllDay {
                    visibleEnd = Calendar.autoupdatingCurrent.date(byAdding: .second, value: -1, to: event.endDate) ?? event.endDate
                } else {
                    visibleEnd = event.endDate
                }
                return CalendarEventSnapshot(
                    id: "\(event.eventIdentifier ?? event.calendarItemIdentifier)-\(event.startDate.timeIntervalSinceReferenceDate)",
                    eventIdentifier: event.eventIdentifier ?? event.calendarItemIdentifier,
                    title: event.title ?? "Untitled event",
                    location: event.location ?? "",
                    startDate: event.startDate,
                    endDate: visibleEnd,
                    isAllDay: event.isAllDay,
                    calendarTitle: event.calendar.title,
                    calendarIdentifier: event.calendar.calendarIdentifier,
                    canEdit: event.calendar.allowsContentModifications
                )
            }
            .sorted { $0.startDate < $1.startDate }
    }

    func save(_ plannerEvent: PlannerEvent) throws {
        guard hasFullAccess || authorizationStatus == .writeOnly else {
            throw CalendarIntegrationError.accessRequired
        }

        let event: EKEvent
        if let identifier = plannerEvent.appleCalendarIdentifier,
           let existing = eventStore.event(withIdentifier: identifier) {
            event = existing
        } else {
            event = EKEvent(eventStore: eventStore)
        }

        let calendar = selectedCalendarIdentifier.flatMap(eventStore.calendar(withIdentifier:))
            ?? eventStore.defaultCalendarForNewEvents
        guard let calendar else { throw CalendarIntegrationError.noWritableCalendar }

        event.calendar = calendar
        event.title = plannerEvent.title
        event.notes = plannerEvent.details.isEmpty ? nil : plannerEvent.details
        event.location = plannerEvent.location.isEmpty ? nil : plannerEvent.location
        event.isAllDay = plannerEvent.isAllDay

        if plannerEvent.isAllDay {
            let systemCalendar = Calendar.autoupdatingCurrent
            event.startDate = systemCalendar.startOfDay(for: plannerEvent.startDate)
            let inclusiveEnd = systemCalendar.startOfDay(for: max(plannerEvent.startDate, plannerEvent.endDate))
            event.endDate = systemCalendar.date(byAdding: .day, value: 1, to: inclusiveEnd) ?? inclusiveEnd.addingTimeInterval(86_400)
        } else {
            event.startDate = plannerEvent.startDate
            event.endDate = max(plannerEvent.startDate, plannerEvent.endDate)
        }

        for recurrenceRule in event.recurrenceRules ?? [] {
            event.removeRecurrenceRule(recurrenceRule)
        }
        if let frequency = plannerEvent.recurrence.eventKitFrequency {
            event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: frequency, interval: 1, end: nil))
        }

        try eventStore.save(event, span: .thisEvent, commit: true)
        plannerEvent.appleCalendarIdentifier = event.eventIdentifier
        plannerEvent.updatedAt = .now
        lastError = nil
    }

    func removeFromAppleCalendar(_ plannerEvent: PlannerEvent) throws {
        guard let identifier = plannerEvent.appleCalendarIdentifier,
              let event = eventStore.event(withIdentifier: identifier) else {
            plannerEvent.appleCalendarIdentifier = nil
            return
        }
        try eventStore.remove(event, span: .thisEvent, commit: true)
        plannerEvent.appleCalendarIdentifier = nil
        plannerEvent.updatedAt = .now
    }
}

enum CalendarIntegrationError: LocalizedError {
    case accessRequired
    case noWritableCalendar

    var errorDescription: String? {
        switch self {
        case .accessRequired: "Apple Calendar access is required for this event."
        case .noWritableCalendar: "No writable Apple Calendar is available."
        }
    }
}

private extension EventRecurrence {
    var eventKitFrequency: EKRecurrenceFrequency? {
        switch self {
        case .none: nil
        case .daily: .daily
        case .weekly: .weekly
        case .monthly: .monthly
        case .yearly: .yearly
        }
    }
}
