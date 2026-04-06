import Testing
import Foundation
import SwiftData
@testable import Ditto

@Suite("CloudSyncManager Tests")
struct CloudSyncManagerTests {

    @Test("App group identifier is correct")
    func appGroupIdentifier() {
        #expect(CloudSyncManager.appGroupIdentifier == "group.io.kern.ditto")
    }

    @Test("CloudKit container identifier is correct")
    func cloudKitIdentifier() {
        #expect(CloudSyncManager.cloudKitContainerIdentifier == "iCloud.io.kern.ditto")
    }
}
