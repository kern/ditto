import Foundation
import SwiftData
import Testing
@testable import Ditto

/// Creates an in-memory PendingDittoStore for testing.
private func makeTestPendingStore() throws -> (PendingDittoStore, DittoStore) {
    let schema = Schema([Profile.self, DittoCategory.self, DittoItem.self])
    let config = ModelConfiguration("Pending-\(UUID())", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: [config])
    let store = DittoStore(modelContainer: container)
    // Clear any pending dittos from shared UserDefaults to avoid cross-test pollution
    let defaults = UserDefaults(suiteName: "group.io.kern.ditto")
    defaults?.removeObject(forKey: "pendingDittos")
    defaults?.removeObject(forKey: "pendingCategories")
    let pendingStore = PendingDittoStore(dittoStore: store)
    return (pendingStore, store)
}

@Suite("PendingDittoStore Tests", .serialized)
struct PendingDittoStoreTests {

    @Test("Categories delegates to DittoStore")
    func categoriesDelegate() throws {
        let (pending, store) = try makeTestPendingStore()
        #expect(pending.categoryCount == store.categoryCount)
    }

    @Test("Category title at index")
    func categoryTitle() throws {
        let (pending, store) = try makeTestPendingStore()
        for i in 0..<store.categoryCount {
            #expect(pending.categoryTitle(at: i) == store.category(at: i).title)
        }
    }

    @Test("isEmpty matches underlying store")
    func isEmpty() throws {
        let (pending, store) = try makeTestPendingStore()
        #expect(pending.isEmpty == store.isEmpty)
    }

    @Test("hasOneCategory is false with presets")
    func hasOneCategory() throws {
        let (pending, _) = try makeTestPendingStore()
        #expect(!pending.hasOneCategory)
    }

    @Test("dittoCount matches underlying store for fresh pending store")
    func dittoCount() throws {
        let (pending, store) = try makeTestPendingStore()
        for i in 0..<store.categoryCount {
            #expect(pending.dittoCount(inCategoryAt: i) == store.dittoCount(inCategoryAt: i))
        }
    }

    @Test("dittoPreview returns trimmed text")
    func dittoPreview() throws {
        let (pending, _) = try makeTestPendingStore()
        guard pending.dittoCount(inCategoryAt: 0) > 0 else { return }
        let preview = pending.dittoPreview(inCategoryAt: 0, at: 0)
        #expect(!preview.isEmpty)
        #expect(!preview.contains("\n"))
    }
}
