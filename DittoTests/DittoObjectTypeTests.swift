import Foundation
import Testing
@testable import Ditto

@Suite("DittoObjectType Tests")
struct DittoObjectTypeTests {

    @Test("Ditto case has correct raw value")
    func dittoRawValue() {
        #expect(DittoObjectType.ditto.rawValue == "Dittos")
    }

    @Test("Category case has correct raw value")
    func categoryRawValue() {
        #expect(DittoObjectType.category.rawValue == "Categories")
    }

    @Test("CaseIterable returns both cases")
    func allCases() {
        #expect(DittoObjectType.allCases.count == 2)
        #expect(DittoObjectType.allCases.contains(.ditto))
        #expect(DittoObjectType.allCases.contains(.category))
    }

    @Test("Can initialize from raw value")
    func initFromRawValue() {
        #expect(DittoObjectType(rawValue: "Dittos") == .ditto)
        #expect(DittoObjectType(rawValue: "Categories") == .category)
        #expect(DittoObjectType(rawValue: "Invalid") == nil)
    }
}
