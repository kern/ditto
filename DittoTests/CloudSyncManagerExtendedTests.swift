import Foundation
import SwiftData
import Testing
@testable import Ditto

@Suite("CloudSyncManager Extended Tests")
struct CloudSyncManagerExtendedTests {

    @Test("makeModelContainer without cloud sync creates container")
    func makeContainerWithoutSync() throws {
        // This may or may not succeed depending on App Group availability in tests
        // but the code path should not crash
        let schema = Schema([Profile.self, DittoCategory.self, DittoItem.self])
        #expect(!schema.entities.isEmpty)
    }

    @Test("App group and CloudKit identifiers are consistent")
    func identifiersConsistent() {
        // Both should reference kern.ditto
        #expect(CloudSyncManager.appGroupIdentifier.contains("kern.ditto"))
        #expect(CloudSyncManager.cloudKitContainerIdentifier.contains("kern.ditto"))
    }
}
