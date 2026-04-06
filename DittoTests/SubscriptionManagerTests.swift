import Foundation
import Testing
@testable import Ditto

@Suite("SubscriptionManager Tests")
struct SubscriptionManagerTests {

    @Test("Initial state is not subscribed")
    func initialState() {
        let manager = SubscriptionManager(startListening: false)
        #expect(!manager.isProSubscriber)
        #expect(manager.products.isEmpty)
        #expect(manager.purchasedProductIDs.isEmpty)
    }

    @Test("isProSubscriber is false with empty purchases")
    func notSubscribed() {
        let manager = SubscriptionManager(startListening: false)
        #expect(!manager.isProSubscriber)
    }

    @Test("Product IDs are defined")
    func productIDs() {
        #expect(SubscriptionManager.proMonthlyProductID == "io.kern.ditto.pro.monthly")
        #expect(SubscriptionManager.proYearlyProductID == "io.kern.ditto.pro.yearly")
    }
}
