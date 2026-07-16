import Foundation
import Observation
import UserNotifications

struct DailyBriefSummary: Equatable {
    let title: String
    let body: String

    @MainActor
    static func make(
        for day: Date,
        tasks: [PlannerTask],
        calendar: Calendar = .autoupdatingCurrent
    ) -> DailyBriefSummary {
        let openDailyTasks = tasks.filter {
            !$0.isCompleted
                && $0.scale == .daily
                && $0.scale.contains($0.scheduledDate, inPeriodContaining: day, calendar: calendar)
        }
        let overdueTasks = tasks.filter { $0.isOverdue(at: day, calendar: calendar) }

        let title = openDailyTasks.isEmpty
            ? "A clear start"
            : "Today · \(openDailyTasks.count) task\(openDailyTasks.count == 1 ? "" : "s")"

        var lines: [String] = openDailyTasks.prefix(3).map(\.title)
        if !overdueTasks.isEmpty {
            lines.append("\(overdueTasks.count) pending from an earlier period")
        }

        return DailyBriefSummary(
            title: title,
            body: lines.isEmpty ? "Take a moment to shape the day in Plancal." : lines.joined(separator: " · ")
        )
    }
}

@MainActor
@Observable
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var lastError: String?

    var authorizationTitle: String {
        switch authorizationStatus {
        case .notDetermined: "Not requested"
        case .denied: "Denied"
        case .authorized: "Allowed"
        case .provisional: "Provisional"
        case .ephemeral: "Temporary"
        @unknown default: "Unknown"
        }
    }

    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            lastError = nil
            await refreshAuthorization()
            return granted
        } catch {
            lastError = error.localizedDescription
            await refreshAuthorization()
            return false
        }
    }

    func refreshDailySummaries(
        tasks: [PlannerTask],
        enabled: Bool,
        hour: Int,
        minute: Int,
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = .now
    ) async {
        await removePendingSummaries()
        guard enabled, authorizationStatus == .authorized || authorizationStatus == .provisional else { return }

        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { continue }
            var components = calendar.dateComponents([.era, .year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute
            guard let deliveryDate = calendar.date(from: components), deliveryDate > now else { continue }

            let content = summaryContent(for: day, tasks: tasks, calendar: calendar)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "plancal.summary.\(day.formatted(.iso8601.year().month().day()))"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func summaryContent(for day: Date, tasks: [PlannerTask], calendar: Calendar) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let summary = DailyBriefSummary.make(for: day, tasks: tasks, calendar: calendar)
        content.title = summary.title
        content.body = summary.body
        content.sound = .default
        content.threadIdentifier = "plancal.daily-summary"
        content.userInfo = ["destination": "today"]
        return content
    }

    private func removePendingSummaries() async {
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests.map(\.identifier).filter { $0.hasPrefix("plancal.summary.") }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
