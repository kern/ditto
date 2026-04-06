import SwiftUI
import Testing
@testable import Ditto

@Suite("Theme Tests")
struct ThemeTests {

    @Test("DittoTheme max category count is 8")
    func maxCategoryCount() {
        #expect(DittoTheme.maxCategoryCount == 8)
    }

    @Test("DittoTheme accent color is purple")
    func accentColor() {
        #expect(DittoTheme.accentColor == Color.purple)
    }

    @Test("Color.dittoAccent is purple")
    func dittoAccent() {
        #expect(Color.dittoAccent == Color.purple)
    }
}
