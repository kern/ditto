import Foundation
import SwiftData

/// Manages iCloud sync configuration for SwiftData.
/// When the user is a Pro subscriber, the ModelContainer is configured with CloudKit sync enabled.
enum CloudSyncManager {

    static let appGroupIdentifier = "group.io.kern.ditto"
    static let cloudKitContainerIdentifier = "iCloud.io.kern.ditto"

    /// Creates a ModelContainer with or without CloudKit sync based on subscription status.
    static func makeModelContainer(cloudSyncEnabled: Bool) throws -> ModelContainer {
        let schema = Schema([Profile.self, DittoCategory.self, DittoItem.self])

        let storeURL: URL? = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("Ditto.store")

        let config: ModelConfiguration

        if cloudSyncEnabled, let url = storeURL {
            config = ModelConfiguration(
                "Ditto",
                schema: schema,
                url: url,
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
        } else if let url = storeURL {
            config = ModelConfiguration(
                "Ditto",
                schema: schema,
                url: url,
                cloudKitDatabase: .none
            )
        } else {
            config = ModelConfiguration("Ditto", schema: schema, cloudKitDatabase: .none)
        }

        return try ModelContainer(for: schema, configurations: [config])
    }
}
