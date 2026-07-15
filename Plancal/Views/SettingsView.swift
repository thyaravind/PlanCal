import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(PersistenceController.self) private var persistence
    @Environment(AppleCalendarService.self) private var calendarService
    @Environment(NotificationService.self) private var notificationService
    @Query(sort: \PlannerTask.updatedAt, order: .reverse) private var tasks: [PlannerTask]
    @AppStorage("notifications.enabled") private var notificationsEnabled = true
    @AppStorage("notifications.hour") private var notificationHour = 8
    @AppStorage("notifications.minute") private var notificationMinute = 0
    @AppStorage("planning.visibleScales") private var visibleScaleStorage = PlanningScale.defaultVisibleStorageValue

    private var visibleScales: [PlanningScale] {
        PlanningScale.visibleScales(from: visibleScaleStorage)
    }

    private var notificationTime: Binding<Date> {
        Binding {
            let calendar = Calendar.autoupdatingCurrent
            return calendar.date(bySettingHour: notificationHour, minute: notificationMinute, second: 0, of: .now) ?? .now
        } set: { newValue in
            let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: newValue)
            notificationHour = components.hour ?? 8
            notificationMinute = components.minute ?? 0
            Task { await refreshNotifications() }
        }
    }

    var body: some View {
        @Bindable var calendarService = calendarService

        ZStack {
            AtmosphericBackground()
            Form {
                Section("Planning horizons") {
                    ForEach(PlanningScale.allCases) { scale in
                        Toggle(isOn: visibilityBinding(for: scale)) {
                            PlancalIconLabel(title: scale.pluralTitle, icon: scale.icon, weight: .duotone)
                        }
                        .disabled(visibleScales.count == 1 && visibleScales.contains(scale))
                    }
                    Text("Choose which time scales appear in Plan. At least one horizon remains visible.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Daily brief") {
                    Toggle(isOn: $notificationsEnabled) {
                        PlancalIconLabel(title: "Morning task summary", icon: .morning, weight: .duotone)
                    }
                        .onChange(of: notificationsEnabled) { _, enabled in
                            Task {
                                if enabled && notificationService.authorizationStatus == .notDetermined {
                                    notificationsEnabled = await notificationService.requestAuthorization()
                                }
                                await refreshNotifications()
                            }
                        }
                    DatePicker("Delivery time", selection: notificationTime, displayedComponents: .hourAndMinute)
                        .disabled(!notificationsEnabled)
                    LabeledContent("Permission", value: notificationService.authorizationTitle)
                    Text("The brief includes that day’s daily tasks and incomplete work from earlier periods.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Apple Calendar") {
                    LabeledContent("Access", value: calendarService.authorizationTitle)
                    if calendarService.hasFullAccess {
                        Picker("Default calendar", selection: $calendarService.selectedCalendarIdentifier) {
                            ForEach(calendarService.writableCalendars) { calendar in
                                Text("\(calendar.title) · \(calendar.sourceTitle)")
                                    .tag(Optional(calendar.id))
                            }
                        }
                        Text("Existing events appear in Plancal. New Plancal events sync to the selected calendar by default.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button {
                            Task { _ = await calendarService.requestFullAccess() }
                        } label: {
                            PlancalIconLabel(title: "Allow full calendar access", icon: .calendarAccess, weight: .bold)
                        }
                        .buttonStyle(.glassProminent)
                        .plancalHoverEffect(scale: 1.025, lifts: true)
                    }
                }

                Section("Sync") {
                    LabeledContent("Storage", value: persistence.syncMode.title)
                    switch persistence.syncMode {
                    case .cloudKit:
                        PlancalIconLabel(
                            title: "Private iCloud sync is configured for iCloud.app.plancal.native.",
                            icon: .synced
                        )
                            .foregroundStyle(.secondary)
                    case .localFallback(let reason):
                        PlancalIconLabel(
                            title: "Plancal opened a local store because iCloud was unavailable.",
                            icon: .cloudWarning
                        )
                            .foregroundStyle(.orange)
                        Text(reason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    case .inMemory:
                        Text("Preview data is not persisted.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    LabeledContent("Bundle identifier", value: "app.plancal.native")
                    LabeledContent("Platforms", value: "iOS · iPadOS · macOS")
                    LabeledContent("Minimum version", value: "26.0")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: PlancalDesign.contentWidth)
        }
        .adaptiveNavigationTitle("Settings")
        .task {
            await notificationService.refreshAuthorization()
            calendarService.refreshAuthorization()
        }
    }

    private func visibilityBinding(for scale: PlanningScale) -> Binding<Bool> {
        Binding {
            visibleScales.contains(scale)
        } set: { isVisible in
            var selected = visibleScales
            if isVisible {
                if !selected.contains(scale) { selected.append(scale) }
            } else {
                guard selected.count > 1 else { return }
                selected.removeAll { $0 == scale }
            }
            visibleScaleStorage = PlanningScale.storageValue(for: selected)
        }
    }

    private func refreshNotifications() async {
        await notificationService.refreshAuthorization()
        await notificationService.refreshDailySummaries(
            tasks: tasks,
            enabled: notificationsEnabled,
            hour: notificationHour,
            minute: notificationMinute
        )
    }
}
