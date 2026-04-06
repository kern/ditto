import Foundation
import Testing
@testable import Ditto

@Suite("DittoCategory Extended Tests")
struct DittoCategoryExtendedTests {

    @Test("Default sortOrder is 0")
    func defaultSortOrder() {
        let cat = DittoCategory(title: "Test")
        #expect(cat.sortOrder == 0)
    }

    @Test("Default profile is nil")
    func defaultProfile() {
        let cat = DittoCategory(title: "Test")
        #expect(cat.profile == nil)
    }

    @Test("Default dittos is empty")
    func defaultDittos() {
        let cat = DittoCategory(title: "Test")
        #expect(cat.dittos.isEmpty)
    }

    @Test("title can be updated")
    func updateTitle() {
        let cat = DittoCategory(title: "Original")
        cat.title = "Updated"
        #expect(cat.title == "Updated")
    }

    @Test("sortOrder can be set")
    func setSortOrder() {
        let cat = DittoCategory(title: "Test")
        cat.sortOrder = 5
        #expect(cat.sortOrder == 5)
    }

    @Test("Initialize with profile")
    func initWithProfile() {
        let profile = Profile()
        let cat = DittoCategory(title: "WithProfile", profile: profile)
        #expect(cat.profile === profile)
        #expect(cat.title == "WithProfile")
    }
}

@Suite("Profile Extended Tests")
struct ProfileExtendedTests {

    @Test("Default categories is empty")
    func defaultCategories() {
        let profile = Profile()
        #expect(profile.categories.isEmpty)
    }

    @Test("orderedCategories on empty is empty")
    func orderedEmpty() {
        let profile = Profile()
        #expect(profile.orderedCategories.isEmpty)
    }
}
