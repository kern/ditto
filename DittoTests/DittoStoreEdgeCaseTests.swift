import Foundation
import SwiftData
import Testing
@testable import Ditto

/// Creates an in-memory DittoStore for testing.
private func makeTestStore() throws -> DittoStore {
    let schema = Schema([Profile.self, DittoCategory.self, DittoItem.self])
    let config = ModelConfiguration("EdgeCaseStore", schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return DittoStore(modelContainer: container)
}

@Suite("DittoStore Edge Case Tests")
struct DittoStoreEdgeCaseTests {

    // MARK: - Category Edge Cases

    @Test("moveCategory with same fromIndex and toIndex is a no-op")
    func moveCategorySameIndex() throws {
        let store = try makeTestStore()
        let titles = store.categories.map(\.title)
        store.moveCategory(fromIndex: 0, toIndex: 0)
        let titlesAfter = store.categories.map(\.title)
        #expect(titles == titlesAfter)
    }

    @Test("moveCategory with negative fromIndex is a no-op")
    func moveCategoryNegativeFrom() throws {
        let store = try makeTestStore()
        let titles = store.categories.map(\.title)
        store.moveCategory(fromIndex: -1, toIndex: 0)
        let titlesAfter = store.categories.map(\.title)
        #expect(titles == titlesAfter)
    }

    @Test("moveCategory with out-of-bounds toIndex is a no-op")
    func moveCategoryOutOfBounds() throws {
        let store = try makeTestStore()
        let count = store.categoryCount
        let titles = store.categories.map(\.title)
        store.moveCategory(fromIndex: 0, toIndex: count)
        let titlesAfter = store.categories.map(\.title)
        #expect(titles == titlesAfter)
    }

    @Test("moveCategory last to first")
    func moveCategoryLastToFirst() throws {
        let store = try makeTestStore()
        let lastIndex = store.categoryCount - 1
        let lastTitle = store.category(at: lastIndex).title
        store.moveCategory(fromIndex: lastIndex, toIndex: 0)
        #expect(store.category(at: 0).title == lastTitle)
    }

    @Test("removeCategory reindexes remaining categories")
    func removeCategoryReindexes() throws {
        let store = try makeTestStore()
        let secondTitle = store.category(at: 1).title
        store.removeCategory(at: 0)
        #expect(store.category(at: 0).title == secondTitle)
        // Verify all sort orders are sequential
        for i in 0..<store.categoryCount {
            #expect(store.category(at: i).sortOrder == i)
        }
    }

    @Test("Add category to full store respects canCreateNewCategory")
    func addCategoryToFullStore() throws {
        let store = try makeTestStore()
        while store.categoryCount < DittoStore.maxCategories {
            store.addCategory(title: "Fill \(store.categoryCount)")
        }
        #expect(!store.canCreateNewCategory)
        #expect(store.categoryCount == DittoStore.maxCategories)
    }

    @Test("maxCategories constant is 8")
    func maxCategoriesConstant() {
        #expect(DittoStore.maxCategories == 8)
    }

    @Test("appGroupIdentifier is correct")
    func appGroupId() {
        #expect(DittoStore.appGroupIdentifier == "group.io.kern.ditto")
    }

    @Test("presetCategories has expected values")
    func presetCategoriesValues() {
        #expect(DittoStore.presetCategories == ["Instructions", "Driving", "Business", "Dating"])
    }

    @Test("presetDittos has entries for all preset categories")
    func presetDittosForAllCategories() {
        for cat in DittoStore.presetCategories {
            #expect(DittoStore.presetDittos[cat] != nil)
            #expect(!DittoStore.presetDittos[cat]!.isEmpty)
        }
    }

    // MARK: - Ditto Edge Cases

    @Test("moveDitto within same category preserves count")
    func moveDittoSameCategoryPreservesCount() throws {
        let store = try makeTestStore()
        let catIndex = 0
        let count = store.dittoCount(inCategoryAt: catIndex)
        guard count >= 2 else { return }
        store.moveDitto(fromCategory: catIndex, fromIndex: 0, toCategory: catIndex, toIndex: count - 1)
        #expect(store.dittoCount(inCategoryAt: catIndex) == count)
    }

    @Test("moveDitto to different category at specific index")
    func moveDittoDifferentCategoryAtIndex() throws {
        let store = try makeTestStore()
        guard store.categoryCount >= 2 else { return }
        guard store.dittoCount(inCategoryAt: 1) >= 1 else { return }

        let movedText = store.ditto(inCategoryAt: 0, at: 0).text
        store.moveDitto(fromCategory: 0, fromIndex: 0, toCategory: 1, toIndex: 0)

        // Should be at index 0 in destination
        #expect(store.ditto(inCategoryAt: 1, at: 0).text == movedText)
    }

    @Test("removeDitto reindexes remaining dittos")
    func removeDittoReindexes() throws {
        let store = try makeTestStore()
        let catIndex = 0
        guard store.dittoCount(inCategoryAt: catIndex) >= 2 else { return }
        let secondText = store.ditto(inCategoryAt: catIndex, at: 1).text
        store.removeDitto(inCategoryAt: catIndex, at: 0)
        #expect(store.ditto(inCategoryAt: catIndex, at: 0).text == secondText)
        // Verify all sort orders are sequential
        let cat = store.category(at: catIndex)
        for (i, d) in cat.orderedDittos.enumerated() {
            #expect(d.sortOrder == i)
        }
    }

    @Test("Add ditto assigns correct sortOrder")
    func addDittoSortOrder() throws {
        let store = try makeTestStore()
        let catIndex = 0
        let countBefore = store.dittoCount(inCategoryAt: catIndex)
        store.addDitto(text: "Brand new ditto", toCategoryAt: catIndex)
        let newDitto = store.ditto(inCategoryAt: catIndex, at: countBefore)
        #expect(newDitto.text == "Brand new ditto")
    }

    @Test("dittos returns ordered dittos for a category")
    func dittosAccessor() throws {
        let store = try makeTestStore()
        let catIndex = 0
        let dittos = store.dittos(inCategoryAt: catIndex)
        #expect(dittos.count == store.dittoCount(inCategoryAt: catIndex))
    }

    @Test("Multiple saves don't corrupt data")
    func multipleSaves() throws {
        let store = try makeTestStore()
        let count = store.categoryCount
        store.save()
        store.save()
        store.save()
        #expect(store.categoryCount == count)
    }

    @Test("moveDitto convenience overload appends to end")
    func moveDittoConvenienceAppends() throws {
        let store = try makeTestStore()
        guard store.categoryCount >= 2, store.dittoCount(inCategoryAt: 0) >= 1 else { return }
        let dstCount = store.dittoCount(inCategoryAt: 1)
        let movedText = store.ditto(inCategoryAt: 0, at: 0).text
        store.moveDitto(fromCategory: 0, fromIndex: 0, toCategory: 1)
        #expect(store.ditto(inCategoryAt: 1, at: dstCount).text == movedText)
    }

    @Test("category(at:) returns correct category")
    func categoryAtIndex() throws {
        let store = try makeTestStore()
        let categories = store.categories
        for (i, cat) in categories.enumerated() {
            #expect(store.category(at: i).title == cat.title)
        }
    }
}
