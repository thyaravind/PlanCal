import SwiftData
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case today
    case plan
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "Today"
        case .plan: "Calendar"
        case .settings: "Settings"
        }
    }

    var icon: PlancalIcon {
        switch self {
        case .today: .today
        case .plan: .plan
        case .settings: .settings
        }
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationService.self) private var notificationService
    @Query(sort: \PlannerTask.updatedAt, order: .reverse) private var tasks: [PlannerTask]
    @AppStorage("notifications.enabled") private var notificationsEnabled = true
    @AppStorage("notifications.hour") private var notificationHour = 8
    @AppStorage("notifications.minute") private var notificationMinute = 0
    @AppStorage("planning.carryOverdueTasks") private var carriesOverdueTasks = false
    @State private var selectedSection: AppSection? = .today
    @State private var selectedCompactSection = AppSection.today

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var taskRevision: String {
        let latest = tasks.first?.updatedAt.timeIntervalSinceReferenceDate ?? 0
        return "\(tasks.count)-\(latest)-\(carriesOverdueTasks)-\(notificationsEnabled)-\(notificationHour)-\(notificationMinute)"
    }

    var body: some View {
        Group {
            #if os(iOS)
            if horizontalSizeClass == .compact {
                compactTabs
            } else {
                splitNavigation
            }
            #else
            splitNavigation
            #endif
        }
        .task(id: taskRevision) {
            await prepareCurrentPlan()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await prepareCurrentPlan() }
        }
    }

    private var splitNavigation: some View {
        NavigationSplitView {
            ScrollView {
                VStack(spacing: 7) {
                    ForEach(AppSection.allCases) { section in
                        SidebarItem(
                            section: section,
                            isSelected: selectedSection == section
                        ) {
                            selectedSection = section
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .navigationTitle("Plancal")
            .navigationSplitViewColumnWidth(min: 210, ideal: 250, max: 300)
        } detail: {
            NavigationStack {
                sectionView(selectedSection ?? .today)
            }
        }
    }

    private var compactTabs: some View {
        TabView(selection: $selectedCompactSection) {
            compactTab(.today) { TodayView() }
            compactTab(.plan) { PlannerView() }
            compactTab(.settings) { SettingsView() }
        }
    }

    private func compactTab<Content: View>(
        _ section: AppSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack { content() }
            .tabItem {
                PlancalNativeIconLabel(
                    title: section.title,
                    icon: section.icon,
                    weight: selectedCompactSection == section ? .fill : .regular,
                    size: 22
                )
            }
            .tag(section)
    }

    @ViewBuilder
    private func sectionView(_ section: AppSection) -> some View {
        switch section {
        case .today: TodayView()
        case .plan: PlannerView()
        case .settings: SettingsView()
        }
    }

    private func prepareCurrentPlan() async {
        RolloverService.rollForwardOutstandingTasks(
            tasks,
            enabled: carriesOverdueTasks,
            modelContext: modelContext
        )
        await notificationService.refreshAuthorization()
        await notificationService.refreshDailySummaries(
            tasks: tasks,
            enabled: notificationsEnabled,
            hour: notificationHour,
            minute: notificationMinute
        )
    }
}

private struct SidebarItem: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var rowHeight: CGFloat {
        #if os(macOS)
        50
        #else
        56
        #endif
    }

    private var iconSize: CGFloat {
        #if os(macOS)
        23
        #else
        25
        #endif
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                PlancalGlyph(
                    icon: section.icon,
                    weight: isSelected ? .fill : .regular,
                    size: iconSize
                )
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)

                Text(section.title)
                    .font(sidebarFont)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .background {
                let shape = RoundedRectangle(cornerRadius: 17, style: .continuous)
                if isSelected {
                    shape
                        .fill(.thinMaterial)
                        .overlay {
                            shape.fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.18),
                                        Color.accentColor.opacity(0.08)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        }
                } else if isHovered {
                    shape.fill(Color.primary.opacity(0.065))
                }
            }
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 4, height: 24)
                        .padding(.leading, 5)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.28) : Color.clear,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.01 : 1)
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: isHovered)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(section.title)
    }

    private var sidebarFont: Font {
        #if os(macOS)
        .system(size: 17, weight: isSelected ? .semibold : .medium)
        #else
        .title3.weight(isSelected ? .semibold : .medium)
        #endif
    }

}
