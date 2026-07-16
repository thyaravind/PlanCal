import Foundation
import SwiftData

enum TaskPriority: String, CaseIterable, Codable, Identifiable, Sendable {
    case gentle
    case important
    case essential

    var id: Self { self }

    var title: String {
        switch self {
        case .gentle: "Gentle"
        case .important: "Important"
        case .essential: "Essential"
        }
    }

    var icon: PlancalIcon {
        switch self {
        case .gentle: .priorityGentle
        case .important: .priorityImportant
        case .essential: .priorityEssential
        }
    }
}

@Model
final class PlannerTask: Identifiable {
    var id: UUID = UUID()
    var title: String = ""
    var details: String = ""
    var scaleRaw: String = PlanningScale.daily.rawValue
    var scheduledDate: Date = Date.now
    var originalDate: Date = Date.now
    var priorityRaw: String = TaskPriority.gentle.rawValue
    var isCompleted: Bool = false
    var completedAt: Date?
    var carryCount: Int = 0
    var lastCarriedAt: Date?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        title: String,
        details: String = "",
        scale: PlanningScale = .daily,
        scheduledDate: Date = .now,
        priority: TaskPriority = .gentle
    ) {
        self.title = title
        self.details = details
        self.scaleRaw = scale.rawValue
        self.scheduledDate = scheduledDate
        self.originalDate = scheduledDate
        self.priorityRaw = priority.rawValue
    }

    var scale: PlanningScale {
        get { PlanningScale(rawValue: scaleRaw) ?? .daily }
        set { scaleRaw = newValue.rawValue }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .gentle }
        set { priorityRaw = newValue.rawValue }
    }

    func isOverdue(at date: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        !isCompleted && scale.interval(containing: originalDate, calendar: calendar).end <= date
    }

    func belongs(to scale: PlanningScale, anchor: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        self.scale == scale && scale.contains(scheduledDate, inPeriodContaining: anchor, calendar: calendar)
    }

    func setCompleted(_ completed: Bool) {
        isCompleted = completed
        completedAt = completed ? .now : nil
        updatedAt = .now
    }
}

enum NoteScope: String, CaseIterable, Codable, Identifiable, Sendable {
    case independent
    case period

    var id: Self { self }
    var title: String { self == .independent ? "Independent" : "Planning period" }
}

@Model
final class MarkdownNote: Identifiable {
    var id: UUID = UUID()
    var title: String = ""
    var markdown: String = ""
    var scopeRaw: String = NoteScope.independent.rawValue
    var scaleRaw: String = PlanningScale.daily.rawValue
    var anchorDate: Date = Date.now
    var isPinned: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        title: String,
        markdown: String = "",
        scope: NoteScope = .independent,
        scale: PlanningScale = .daily,
        anchorDate: Date = .now
    ) {
        self.title = title
        self.markdown = markdown
        self.scopeRaw = scope.rawValue
        self.scaleRaw = scale.rawValue
        self.anchorDate = anchorDate
    }

    var scope: NoteScope {
        get { NoteScope(rawValue: scopeRaw) ?? .independent }
        set { scopeRaw = newValue.rawValue }
    }

    var scale: PlanningScale {
        get { PlanningScale(rawValue: scaleRaw) ?? .daily }
        set { scaleRaw = newValue.rawValue }
    }
}

enum EventRecurrence: String, CaseIterable, Codable, Identifiable, Sendable {
    case none
    case daily
    case weekly
    case monthly
    case yearly

    var id: Self { self }
    var title: String { rawValue.capitalized }
}

@Model
final class PlannerEvent: Identifiable {
    var id: UUID = UUID()
    var title: String = ""
    var details: String = ""
    var location: String = ""
    var startDate: Date = Date.now
    var endDate: Date = Date.now
    var isAllDay: Bool = true
    var recurrenceRaw: String = EventRecurrence.none.rawValue
    var syncsWithAppleCalendar: Bool = true
    var appleCalendarIdentifier: String?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        title: String,
        details: String = "",
        location: String = "",
        startDate: Date = .now,
        endDate: Date = .now,
        isAllDay: Bool = true,
        recurrence: EventRecurrence = .none,
        syncsWithAppleCalendar: Bool = true
    ) {
        self.title = title
        self.details = details
        self.location = location
        self.startDate = startDate
        self.endDate = max(startDate, endDate)
        self.isAllDay = isAllDay
        self.recurrenceRaw = recurrence.rawValue
        self.syncsWithAppleCalendar = syncsWithAppleCalendar
    }

    var recurrence: EventRecurrence {
        get { EventRecurrence(rawValue: recurrenceRaw) ?? .none }
        set { recurrenceRaw = newValue.rawValue }
    }
}
