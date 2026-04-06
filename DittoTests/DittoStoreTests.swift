import Foundation
import SwiftData
import Testing
@testable import Ditto

/// Creates an in-memory DittoStore for testing.
private func makeTestStore() throws -> DittoStore {
    let schema = Schema([Profile.self, DittoCategory.self, DittoItem.self])
    let config = ModelConfiguration("TestStore-\(UUID())", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: [config])
    return DittoStore(modelContainer: container)
}

@Suite("DittoStore Tests", .serialized)
struct DittoStoreTests {

    // MARK: - Profile

    @Test("Store creates profile with preset data on init")
    func createsPresetData() throws {
        let store = try makeTestStore()
        #expect(store.categoryCount > 0)
        #expect(!store.isEmpty)
    }

    @Test("getProfile returns the same profile")
    func getProfileConsistent() throws {
        let store = try makeTestStore()
        let p1 = store.getProfile()
        let p2 = store.getProfile()
        #expect(p1.persistentModelID == p2.persistentModelID)
    }

    // MARK: - Categories

    @Test("Preset categories are created")
    func presetCategories() throws {
        let store = try makeTestStore()
        let titles = store.categories.map(\.title)
        for preset in DittoStore.presetCategories {
            #expect(titles.contains(preset))
        }
    }

    @Test("Add a new category")
    func addCategory() throws {
        let store = try makeTestStore()
        let initialCount = store.categoryCount
        store.addCategory(title: "New Category")
        #expect(store.categoryCount == initialCount + 1)
        #expect(store.categories.last?.title == "New Category")
    }

    @Test("Remove a category")
    func removeCategory() throws {
        let store = try makeTestStore()
        let initialCount = store.categoryCount
        store.removeCategory(at: 0)
        #expect(store.categoryCount == initialCount - 1)
    }

    @Test("Update category title")
    func updateCategory() throws {
        let store = try makeTestStore()
        store.updateCategory(at: 0, title: "Renamed")
        #expect(store.category(at: 0).title == "Renamed")
    }

    @Test("Move category changes order")
    func moveCategory() throws {
        let store = try makeTestStore()
        let firstTitle = store.category(at: 0).title
        let secondTitle = store.category(at: 1).title
        store.moveCategory(fromIndex: 0, toIndex: 1)
        #expect(store.category(at: 0).title == secondTitle)
        #expect(store.category(at: 1).title == firstTitle)
    }

    @Test("canCreateNewCategory respects max limit")
    func maxCategories() throws {
        let store = try makeTestStore()
        // Fill up to max
        while store.categoryCount < DittoStore.maxCategories {
            store.addCategory(title: "Cat \(store.categoryCount)")
        }
        #expect(!store.canCreateNewCategory)
    }

    // MARK: - Dittos

    @Test("Preset dittos are created in categories")
    func presetDittos() throws {
        let store = try makeTestStore()
        let instructionsCat = store.categories.first { $0.title == "Instructions" }
        #expect(instructionsCat != nil)
        #expect(!instructionsCat!.orderedDittos.isEmpty)
    }

    @Test("Add ditto to category")
    func addDitto() throws {
        let store = try makeTestStore()
        let initialCount = store.dittoCount(inCategoryAt: 0)
        store.addDitto(text: "New ditto text", toCategoryAt: 0)
        #expect(store.dittoCount(inCategoryAt: 0) == initialCount + 1)
    }

    @Test("Remove ditto from category")
    func removeDitto() throws {
        let store = try makeTestStore()
        let initialCount = store.dittoCount(inCategoryAt: 0)
        store.removeDitto(inCategoryAt: 0, at: 0)
        #expect(store.dittoCount(inCategoryAt: 0) == initialCount - 1)
    }

    @Test("Update ditto text")
    func updateDitto() throws {
        let store = try makeTestStore()
        store.updateDitto(inCategoryAt: 0, at: 0, text: "Updated text")
        #expect(store.ditto(inCategoryAt: 0, at: 0).text == "Updated text")
    }

    @Test("Move ditto within same category")
    func moveDittoSameCategory() throws {
        let store = try makeTestStore()
        guard store.dittoCount(inCategoryAt: 0) >= 2 else { return }
        let firstText = store.ditto(inCategoryAt: 0, at: 0).text
        let secondText = store.ditto(inCategoryAt: 0, at: 1).text
        store.moveDitto(fromCategory: 0, fromIndex: 0, toCategory: 0, toIndex: 1)
        #expect(store.ditto(inCategoryAt: 0, at: 0).text == secondText)
        #expect(store.ditto(inCategoryAt: 0, at: 1).text == firstText)
    }

    @Test("Move ditto to different category")
    func moveDittoDifferentCategory() throws {
        let store = try makeTestStore()
        guard store.categoryCount >= 2 else { return }
        let srcCount = store.dittoCount(inCategoryAt: 0)
        let dstCount = store.dittoCount(inCategoryAt: 1)
        let movedText = store.ditto(inCategoryAt: 0, at: 0).text

        store.moveDitto(fromCategory: 0, fromIndex: 0, toCategory: 1)

        #expect(store.dittoCount(inCategoryAt: 0) == srcCount - 1)
        #expect(store.dittoCount(inCategoryAt: 1) == dstCount + 1)
        // The moved ditto should be at the end of the destination category
        let lastDitto = store.ditto(inCategoryAt: 1, at: dstCount)
        #expect(lastDitto.text == movedText)
    }

    // MARK: - Edge Cases

    @Test("isEmpty is false after initialization with presets")
    func isNotEmpty() throws {
        let store = try makeTestStore()
        #expect(!store.isEmpty)
    }

    @Test("Store saves without error")
    func saveSucceeds() throws {
        let store = try makeTestStore()
        store.addCategory(title: "SaveTest")
        store.save()
        #expect(store.categories.contains { $0.title == "SaveTest" })
    }
}
