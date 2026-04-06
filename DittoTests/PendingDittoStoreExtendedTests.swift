import Foundation
import SwiftData
import Testing
@testable import Ditto

/// Creates an in-memory PendingDittoStore for testing.
private func makeTestPendingStore() throws -> (PendingDittoStore, DittoStore) {
    let schema = Schema([Profile.self, DittoCategory.self, DittoItem.self])
    let config = ModelConfiguration("TestPendingExt", schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let store = DittoStore(modelContainer: container)
    let pendingStore = PendingDittoStore(dittoStore: store)
    return (pendingStore, store)
}

@Suite("PendingDittoStore Extended Tests")
struct PendingDittoStoreExtendedTests {

    @Test("addDitto queues to UserDefaults")
    func addDittoQueues() throws {
        let (pending, _) = try makeTestPendingStore()
        let defaults = UserDefaults(suiteName: PendingDittoStore.appGroupIdentifier)

        // Clean up first
        defaults?.removeObject(forKey: "pendingDittos")
        defaults?.removeObject(forKey: "pendingCategories")

        let catTitle = pending.categoryTitle(at: 0)
        pending.addDitto(text: "Pending test ditto", toCategoryAt: 0)

        let allPending = defaults?.dictionary(forKey: "pendingDittos") as? [String: [String]]
        let pendingCats = defaults?.array(forKey: "pendingCategories") as? [String]

        #expect(allPending?[catTitle]?.contains("Pending test ditto") == true)
        #expect(pendingCats?.contains(catTitle) == true)

        // Clean up
        defaults?.removeObject(forKey: "pendingDittos")
        defaults?.removeObject(forKey: "pendingCategories")
    }

    @Test("addDitto appends to existing pending category")
    func addDittoAppendsToExisting() throws {
        let (pending, _) = try makeTestPendingStore()
        let defaults = UserDefaults(suiteName: PendingDittoStore.appGroupIdentifier)

        // Clean up
        defaults?.removeObject(forKey: "pendingDittos")
        defaults?.removeObject(forKey: "pendingCategories")

        pending.addDitto(text: "First", toCategoryAt: 0)
        pending.addDitto(text: "Second", toCategoryAt: 0)

        let catTitle = pending.categoryTitle(at: 0)
        let allPending = defaults?.dictionary(forKey: "pendingDittos") as? [String: [String]]
        #expect(allPending?[catTitle]?.count == 2)
        #expect(allPending?[catTitle]?[0] == "First")
        #expect(allPending?[catTitle]?[1] == "Second")

        // Clean up
        defaults?.removeObject(forKey: "pendingDittos")
        defaults?.removeObject(forKey: "pendingCategories")
    }

    @Test("dittoCount includes pending dittos")
    func dittoCountIncludesPending() throws {
        let (pending, store) = try makeTestPendingStore()
        let defaults = UserDefaults(suiteName: PendingDittoStore.appGroupIdentifier)

        // Clean up
        defaults?.removeObject(forKey: "pendingDittos")
        defaults?.removeObject(forKey: "pendingCategories")

        let baseCount = store.dittoCount(inCategoryAt: 0)
        pending.addDitto(text: "Pending", toCategoryAt: 0)
        #expect(pending.dittoCount(inCategoryAt: 0) == baseCount + 1)

        // Clean up
        defaults?.removeObject(forKey: "pendingDittos")
        defaults?.removeObject(forKey: "pendingCategories")
    }

    @Test("dittos includes pending dittos")
    func dittosIncludesPending() throws {
        let (pending, store) = try makeTestPendingStore()
        let defaults = UserDefaults(suiteName: PendingDittoStore.appGroupIdentifier)

        // Clean up
        defaults?.removeObject(forKey: "pendingDittos")
        defaults?.removeObject(forKey: "pendingCategories")

        let baseCount = store.dittoCount(inCategoryAt: 0)
        pending.addDitto(text: "PendingItem", toCategoryAt: 0)
        let allDittos = pending.dittos(inCategoryAt: 0)
        #expect(allDittos.count == baseCount + 1)
        #expect(allDittos.last?.text == "PendingItem")

        // Clean up
        defaults?.removeObject(forKey: "pendingDittos")
        defaults?.removeObject(forKey: "pendingCategories")
    }

    @Test("ditto accessor returns correct item including pending")
    func dittoAccessorWithPending() throws {
        let (pending, store) = try makeTestPendingStore()
        let defaults = UserDefaults(suiteName: PendingDittoStore.appGroupIdentifier)

        // Clean up
        defaults?.removeObject(forKey: "pendingDittos")
        defaults?.removeObject(forKey: "pendingCategories")

        let baseCount = store.dittoCount(inCategoryAt: 0)
        pending.addDitto(text: "AccessTest", toCategoryAt: 0)
        let item = pending.ditto(inCategoryAt: 0, at: baseCount)
        #expect(item.text == "AccessTest")

        // Clean up
        defaults?.removeObject(forKey: "pendingDittos")
        defaults?.removeObject(forKey: "pendingCategories")
    }

    @Test("categories returns store categories")
    func categoriesAccessor() throws {
        let (pending, store) = try makeTestPendingStore()
        let pendingCats = pending.categories
        let storeCats = store.categories
        #expect(pendingCats.count == storeCats.count)
        for (p, s) in zip(pendingCats, storeCats) {
            #expect(p.title == s.title)
        }
    }

    @Test("category at index delegates correctly")
    func categoryAtIndex() throws {
        let (pending, store) = try makeTestPendingStore()
        for i in 0..<store.categoryCount {
            #expect(pending.category(at: i).title == store.category(at: i).title)
        }
    }

    @Test("appGroupIdentifier is correct")
    func appGroupIdentifier() {
        #expect(PendingDittoStore.appGroupIdentifier == "group.io.kern.ditto")
    }
}
