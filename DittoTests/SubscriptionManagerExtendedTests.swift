import Foundation
import Testing
@testable import Ditto

@Suite("SubscriptionManager Extended Tests")
struct SubscriptionManagerExtendedTests {

    @Test("StoreError.failedVerification exists")
    func storeErrorExists() {
        let error = SubscriptionManager.StoreError.failedVerification
        #expect(error is SubscriptionManager.StoreError)
    }

    @Test("isLoading starts false")
    func isLoadingDefault() {
        let manager = SubscriptionManager()
        #expect(!manager.isLoading)
    }

    @Test("isProSubscriber is false when purchasedProductIDs is empty")
    func notProByDefault() {
        let manager = SubscriptionManager()
        #expect(manager.purchasedProductIDs.isEmpty)
        #expect(!manager.isProSubscriber)
    }

    @Test("Products list starts empty")
    func productsEmpty() {
        let manager = SubscriptionManager()
        #expect(manager.products.isEmpty)
    }
}
