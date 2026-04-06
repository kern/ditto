import Foundation
import SwiftData
import Testing
@testable import Ditto

/// Creates an in-memory PendingDittoStore for testing.
private func makeTestPendingStore() throws -> (PendingDittoStore, DittoStore) {
    let schema = Schema([Profile.self, DittoCategory.self, DittoItem.self])
    let config = ModelConfiguration("PendingExt-\(UUID())", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: [config])
    let store = DittoStore(modelContainer: container)
    let defaults = UserDefaults(suiteName: "group.io.kern.ditto")
    defaults?.removeObject(forKey: "pendingDittos")
    defaults?.removeObject(forKey: "pendingCategories")
    let pendingStore = PendingDittoStore(dittoStore: store)
    return (pendingStore, store)
}

@Suite("PendingDittoStore Extended Tests", .serialized)
struct PendingDittoStoreExtendedTests {

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

    @Test("categoryTitle delegates to store")
    func categoryTitleDelegate() throws {
        let (pending, store) = try makeTestPendingStore()
        for i in 0..<store.categoryCount {
            #expect(pending.categoryTitle(at: i) == store.category(at: i).title)
        }
    }

    @Test("isEmpty mirrors store")
    func isEmptyMirror() throws {
        let (pending, store) = try makeTestPendingStore()
        #expect(pending.isEmpty == store.isEmpty)
    }

    @Test("hasOneCategory is false with preset categories")
    func hasOneCategoryPreset() throws {
        let (pending, _) = try makeTestPendingStore()
        #expect(!pending.hasOneCategory)
    }

    @Test("dittoCount without pending matches store")
    func dittoCountNoPending() throws {
        let (pending, store) = try makeTestPendingStore()
        // Clean any stale pending data
        let defaults = UserDefaults(suiteName: PendingDittoStore.appGroupIdentifier) ?? .standard
        defaults.removeObject(forKey: "pendingDittos")
        defaults.removeObject(forKey: "pendingCategories")
        defaults.synchronize()

        for i in 0..<store.categoryCount {
            #expect(pending.dittoCount(inCategoryAt: i) == store.dittoCount(inCategoryAt: i))
        }
    }

    @Test("dittoPreview returns non-empty for preset data")
    func dittoPreviewPreset() throws {
        let (pending, _) = try makeTestPendingStore()
        guard pending.dittoCount(inCategoryAt: 0) > 0 else { return }
        let preview = pending.dittoPreview(inCategoryAt: 0, at: 0)
        #expect(!preview.isEmpty)
    }

    @Test("ditto accessor returns correct item")
    func dittoAccessor() throws {
        let (pending, store) = try makeTestPendingStore()
        guard store.dittoCount(inCategoryAt: 0) > 0 else { return }
        let pendingItem = pending.ditto(inCategoryAt: 0, at: 0)
        let storeItem = store.ditto(inCategoryAt: 0, at: 0)
        #expect(pendingItem.text == storeItem.text)
    }
}
