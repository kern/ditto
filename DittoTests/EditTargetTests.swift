import Foundation
import Testing
@testable import Ditto

@Suite("EditTarget Tests")
struct EditTargetTests {

    @Test("Category target has correct id")
    func categoryId() {
        let target = EditTarget.category(index: 3)
        #expect(target.id == "cat-3")
    }

    @Test("Ditto target has correct id")
    func dittoId() {
        let target = EditTarget.ditto(categoryIndex: 1, dittoIndex: 5)
        #expect(target.id == "ditto-1-5")
    }

    @Test("Different targets have different ids")
    func uniqueIds() {
        let cat = EditTarget.category(index: 0)
        let ditto = EditTarget.ditto(categoryIndex: 0, dittoIndex: 0)
        #expect(cat.id != ditto.id)
    }

    @Test("Same category index produces same id")
    func categorySameId() {
        let a = EditTarget.category(index: 2)
        let b = EditTarget.category(index: 2)
        #expect(a.id == b.id)
    }

    @Test("Same ditto indices produce same id")
    func dittoSameId() {
        let a = EditTarget.ditto(categoryIndex: 1, dittoIndex: 3)
        let b = EditTarget.ditto(categoryIndex: 1, dittoIndex: 3)
        #expect(a.id == b.id)
    }
}
