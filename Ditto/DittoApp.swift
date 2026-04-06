import SwiftData
import SwiftUI

@main
struct DittoApp: App {

    private static var isTestEnvironment: Bool {
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    @State private var subscriptionManager = SubscriptionManager(
        startListening: !isTestEnvironment
    )
    @State private var store: DittoStore

    init() {
        // Start with local-only; iCloud sync is enabled after verifying subscription
        do {
            let container = try CloudSyncManager.makeModelContainer(cloudSyncEnabled: false)

            // Migrate legacy Core Data store before creating DittoStore,
            // so ensureProfileExists() finds migrated data instead of creating presets
            if LegacyDataMigrator.needsMigration {
                let migrationContext = ModelContext(container)
                LegacyDataMigrator.migrateIfNeeded(into: migrationContext)
            }

            _store = State(initialValue: DittoStore(modelContainer: container))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            DittoListView(store: store, subscriptionManager: subscriptionManager)
                .task {
                    guard !Self.isTestEnvironment else { return }
                    await subscriptionManager.restorePurchases()
                    if subscriptionManager.isProSubscriber {
                        upgradeToCloudSync()
                    }
                }
        }
    }

    private func upgradeToCloudSync() {
        if let container = try? CloudSyncManager.makeModelContainer(cloudSyncEnabled: true) {
            store = DittoStore(modelContainer: container)
        }
    }
}
