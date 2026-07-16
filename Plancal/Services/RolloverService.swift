import Foundation
import SwiftData

@MainActor
enum RolloverService {
    @discardableResult
    static func rollForwardOutstandingTasks(
        _ tasks: [PlannerTask],
        enabled: Bool = true,
        to date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent,
        modelContext: ModelContext? = nil
    ) -> Int {
        guard enabled else { return 0 }

        var changed = 0

        for task in tasks where !task.isCompleted {
            let scheduledInterval = task.scale.interval(containing: task.scheduledDate, calendar: calendar)
            guard scheduledInterval.end <= date else { continue }

            task.scheduledDate = task.scale.interval(containing: date, calendar: calendar).start
            task.carryCount += 1
            task.lastCarriedAt = date
            task.updatedAt = date
            changed += 1
        }

        if changed > 0 {
            try? modelContext?.save()
        }
        return changed
    }
}
