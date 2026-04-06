import SwiftUI
import Testing
@testable import Ditto

@Suite("Theme Tests")
struct ThemeTests {

    @Test("Color.dittoAccent is purple")
    func dittoAccent() {
        #expect(Color.dittoAccent == Color.purple)
    }
}
