import SwiftUI
import SwiftData

@main
struct DittoApp: App {

    @State private var subscriptionManager = SubscriptionManager()
    @State private var store: DittoStore

    init() {
        // Start with local-only; iCloud sync is enabled after verifying subscription
        let container = try! CloudSyncManager.makeModelContainer(cloudSyncEnabled: false)
        _store = State(initialValue: DittoStore(modelContainer: container))
    }

    var body: some Scene {
        WindowGroup {
            DittoListView(store: store, subscriptionManager: subscriptionManager)
                .task {
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
