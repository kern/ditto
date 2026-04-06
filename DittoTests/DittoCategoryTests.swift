import Testing
import Foundation
@testable import Ditto

@Suite("DittoCategory Model Tests")
struct DittoCategoryTests {

    @Test("Initialize with title")
    func initWithTitle() {
        let cat = DittoCategory(title: "Business")
        #expect(cat.title == "Business")
        #expect(cat.dittos.isEmpty)
        #expect(cat.dittoOrder.isEmpty)
    }

    @Test("Ordered dittos returns empty for new category")
    func orderedDittosEmpty() {
        let cat = DittoCategory(title: "Test")
        #expect(cat.orderedDittos.isEmpty)
    }
}

@Suite("Profile Model Tests")
struct ProfileTests {

    @Test("Initialize with empty categories")
    func initEmpty() {
        let profile = Profile()
        #expect(profile.categories.isEmpty)
        #expect(profile.categoryOrder.isEmpty)
    }

    @Test("Ordered categories returns empty for new profile")
    func orderedCategoriesEmpty() {
        let profile = Profile()
        #expect(profile.orderedCategories.isEmpty)
    }
}
