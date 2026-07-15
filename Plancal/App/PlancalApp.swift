import SwiftData
import SwiftUI

@main
struct PlancalApp: App {
    private let persistence = PersistenceController.shared
    @State private var appleCalendar = AppleCalendarService()
    @State private var notifications = NotificationService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(persistence)
                .environment(appleCalendar)
                .environment(notifications)
                .modelContainer(persistence.container)
                .tint(.accentColor)
        }
        .defaultSize(width: 1120, height: 760)

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(persistence)
                .environment(appleCalendar)
                .environment(notifications)
                .modelContainer(persistence.container)
                .frame(minWidth: 520, minHeight: 540)
        }
        #endif
    }
}
