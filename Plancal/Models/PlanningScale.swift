import Foundation

enum PlanningScale: String, CaseIterable, Codable, Identifiable, Sendable {
    case daily
    case weekly
    case monthly
    case quarterly
    case yearly

    var id: Self { self }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .yearly: "Yearly"
        }
    }

    nonisolated var shortTitle: String {
        switch self {
        case .daily: "Day"
        case .weekly: "Week"
        case .monthly: "Month"
        case .quarterly: "Quarter"
        case .yearly: "Year"
        }
    }

    nonisolated var pluralTitle: String {
        switch self {
        case .daily: "Days"
        case .weekly: "Weeks"
        case .monthly: "Months"
        case .quarterly: "Quarters"
        case .yearly: "Years"
        }
    }

    nonisolated func toolbarLabel(isSelected: Bool) -> String {
        isSelected ? shortTitle : String(shortTitle.prefix(1))
    }

    nonisolated static let defaultVisibleStorageValue = [daily, weekly, monthly]
        .map(\.rawValue)
        .joined(separator: ",")

    nonisolated static func visibleScales(from storageValue: String) -> [PlanningScale] {
        let requested = Set(
            storageValue
                .split(separator: ",")
                .compactMap { PlanningScale(rawValue: String($0)) }
        )
        let ordered = allCases.filter(requested.contains)
        return ordered.isEmpty ? [.daily, .weekly, .monthly] : ordered
    }

    nonisolated static func storageValue(for scales: [PlanningScale]) -> String {
        let selected = Set(scales)
        let ordered = allCases.filter(selected.contains)
        return (ordered.isEmpty ? [.daily] : ordered)
            .map(\.rawValue)
            .joined(separator: ",")
    }

    var icon: PlancalIcon {
        switch self {
        case .daily: .day
        case .weekly: .week
        case .monthly: .month
        case .quarterly: .quarter
        case .yearly: .year
        }
    }

    nonisolated func interval(containing date: Date, calendar: Calendar = .autoupdatingCurrent) -> DateInterval {
        switch self {
        case .daily:
            return calendar.dateInterval(of: .day, for: date) ?? fallbackInterval(from: date, days: 1, calendar: calendar)
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: date) ?? fallbackInterval(from: date, days: 7, calendar: calendar)
        case .monthly:
            return calendar.dateInterval(of: .month, for: date) ?? fallbackInterval(from: date, days: 30, calendar: calendar)
        case .quarterly:
            let components = calendar.dateComponents([.era, .year, .month], from: date)
            let month = components.month ?? 1
            let firstMonth = ((month - 1) / 3) * 3 + 1
            var startComponents = DateComponents()
            startComponents.era = components.era
            startComponents.year = components.year
            startComponents.month = firstMonth
            startComponents.day = 1
            let start = calendar.date(from: startComponents) ?? calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .month, value: 3, to: start) ?? start.addingTimeInterval(7_776_000)
            return DateInterval(start: start, end: end)
        case .yearly:
            return calendar.dateInterval(of: .year, for: date) ?? fallbackInterval(from: date, days: 365, calendar: calendar)
        }
    }

    nonisolated func offset(_ date: Date, by amount: Int, calendar: Calendar = .autoupdatingCurrent) -> Date {
        let component: Calendar.Component
        let value: Int
        switch self {
        case .daily:
            component = .day
            value = amount
        case .weekly:
            component = .weekOfYear
            value = amount
        case .monthly:
            component = .month
            value = amount
        case .quarterly:
            component = .month
            value = amount * 3
        case .yearly:
            component = .year
            value = amount
        }
        return calendar.date(byAdding: component, value: value, to: date) ?? date
    }

    nonisolated func contains(_ candidate: Date, inPeriodContaining anchor: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        let interval = interval(containing: anchor, calendar: calendar)
        return candidate >= interval.start && candidate < interval.end
    }

    nonisolated func label(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let interval = interval(containing: date, calendar: calendar)
        switch self {
        case .daily:
            return interval.start.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        case .weekly:
            let inclusiveEnd = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
            let sameMonth = calendar.component(.month, from: interval.start) == calendar.component(.month, from: inclusiveEnd)
            if sameMonth {
                return "\(interval.start.formatted(.dateTime.month(.abbreviated))) \(interval.start.formatted(.dateTime.day()))–\(inclusiveEnd.formatted(.dateTime.day())), \(inclusiveEnd.formatted(.dateTime.year()))"
            }
            return "\(interval.start.formatted(.dateTime.month(.abbreviated).day())) – \(inclusiveEnd.formatted(.dateTime.month(.abbreviated).day().year()))"
        case .monthly:
            return interval.start.formatted(.dateTime.month(.wide).year())
        case .quarterly:
            let month = calendar.component(.month, from: interval.start)
            let quarter = ((month - 1) / 3) + 1
            return "Q\(quarter) \(calendar.component(.year, from: interval.start))"
        case .yearly:
            return interval.start.formatted(.dateTime.year())
        }
    }

    nonisolated func taskLabel(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let interval = interval(containing: date, calendar: calendar)
        switch self {
        case .daily:
            return interval.start.formatted(.dateTime.month(.abbreviated).day().year())
        case .weekly:
            let inclusiveEnd = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let sameMonth = calendar.component(.month, from: interval.start) == calendar.component(.month, from: inclusiveEnd)
            if sameMonth {
                return "\(interval.start.formatted(.dateTime.month(.abbreviated))) \(interval.start.formatted(.dateTime.day()))–\(inclusiveEnd.formatted(.dateTime.day())), \(inclusiveEnd.formatted(.dateTime.year()))"
            }
            return "\(interval.start.formatted(.dateTime.month(.abbreviated).day()))–\(inclusiveEnd.formatted(.dateTime.month(.abbreviated).day().year()))"
        case .monthly:
            return interval.start.formatted(.dateTime.month(.wide).year())
        case .quarterly:
            let month = calendar.component(.month, from: interval.start)
            let quarter = ((month - 1) / 3) + 1
            return "Q\(quarter) \(calendar.component(.year, from: interval.start))"
        case .yearly:
            return interval.start.formatted(.dateTime.year())
        }
    }

    nonisolated private func fallbackInterval(from date: Date, days: Int, calendar: Calendar) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: days, to: start) ?? start.addingTimeInterval(TimeInterval(days * 86_400))
        return DateInterval(start: start, end: end)
    }
}

enum CurrentPeriodAnchorResolver {
    nonisolated static func resolvedAnchor(
        currentAnchor: Date,
        scale: PlanningScale,
        previousNow: Date,
        currentNow: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        guard scale.contains(
            previousNow,
            inPeriodContaining: currentAnchor,
            calendar: calendar
        ) else {
            return currentAnchor
        }

        return scale.interval(containing: currentNow, calendar: calendar).start
    }
}
