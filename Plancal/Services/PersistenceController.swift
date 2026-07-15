import Foundation
import Observation
#if os(macOS)
import Security
#endif
import SwiftData

@MainActor
@Observable
final class PersistenceController {
    enum SyncMode: Equatable {
        case cloudKit
        case localFallback(String)
        case inMemory

        var title: String {
            switch self {
            case .cloudKit: "iCloud Sync"
            case .localFallback: "On This Device"
            case .inMemory: "Preview"
            }
        }
    }

    static let shared = PersistenceController()

    let container: ModelContainer
    let syncMode: SyncMode

    init(inMemory: Bool = false) {
        let schema = Schema([
            PlannerTask.self,
            MarkdownNote.self,
            PlannerEvent.self
        ])

        if inMemory {
            do {
                let configuration = ModelConfiguration("PlancalPreview", schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: [configuration])
                syncMode = .inMemory
                return
            } catch {
                fatalError("Unable to create Plancal preview store: \(error)")
            }
        }

        let cloudError: String
        if Self.hasCloudKitEntitlement {
            do {
                let configuration = ModelConfiguration(
                    "PlancalCloud",
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .private("iCloud.app.plancal.native")
                )
                container = try ModelContainer(for: schema, configurations: [configuration])
                syncMode = .cloudKit
                return
            } catch {
                cloudError = error.localizedDescription
            }
        } else {
            cloudError = "The running build is not signed with the CloudKit entitlement. Choose an Apple Developer team in Xcode to enable iCloud sync."
        }

        do {
            let fallback = ModelConfiguration("PlancalLocal", schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
            container = try ModelContainer(for: schema, configurations: [fallback])
            syncMode = .localFallback(cloudError)
        } catch {
            fatalError("Unable to create Plancal data store: \(error)")
        }
    }

    private static var hasCloudKitEntitlement: Bool {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil),
              let services = SecTaskCopyValueForEntitlement(
                task,
                "com.apple.developer.icloud-services" as CFString,
                nil
              ) as? [String] else {
            return false
        }
        return services.contains("CloudKit") || services.contains("CloudKit-Anonymous")
        #else
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil || environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return false
        }
        // The iOS target always declares the CloudKit capability. Device and
        // simulator builds are signed by Xcode before they can be launched.
        return true
        #endif
    }
}
