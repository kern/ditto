import Foundation
import Testing
@testable import Ditto

@Suite("DittoItem Extended Tests")
struct DittoItemExtendedTests {

    @Test("Default useCount is 0")
    func defaultUseCount() {
        let item = DittoItem(text: "test")
        #expect(item.useCount == 0)
    }

    @Test("Default sortOrder is 0")
    func defaultSortOrder() {
        let item = DittoItem(text: "test")
        #expect(item.sortOrder == 0)
    }

    @Test("Default category is nil")
    func defaultCategory() {
        let item = DittoItem(text: "test")
        #expect(item.category == nil)
    }

    @Test("Empty text has empty preview")
    func emptyTextPreview() {
        let item = DittoItem(text: "")
        #expect(item.preview == "")
    }

    @Test("Preview with only whitespace")
    func whitespaceOnlyPreview() {
        let item = DittoItem(text: "   ")
        #expect(item.preview == "")
    }

    @Test("Preview with only newlines")
    func newlineOnlyPreview() {
        let item = DittoItem(text: "\n\n\n")
        #expect(item.preview == "")
    }

    @Test("Process empty text returns empty")
    func processEmptyText() {
        let item = DittoItem(text: "")
        let (text, rewind) = item.processedTextForInsertion()
        #expect(text == "")
        #expect(rewind == 0)
    }

    @Test("Process text with single underscore (not a marker)")
    func processSingleUnderscore() {
        let item = DittoItem(text: "Hello _ world")
        let (text, rewind) = item.processedTextForInsertion()
        #expect(text == "Hello _ world")
        #expect(rewind == 0)
    }

    @Test("Process text with marker at start")
    func processMarkerAtStart() {
        let item = DittoItem(text: "___ rest of text")
        let (text, rewind) = item.processedTextForInsertion()
        #expect(text == " rest of text")
        #expect(rewind == 13)
    }

    @Test("useCount can be set")
    func setUseCount() {
        let item = DittoItem(text: "test")
        item.useCount = 5
        #expect(item.useCount == 5)
    }

    @Test("sortOrder can be set")
    func setSortOrder() {
        let item = DittoItem(text: "test")
        item.sortOrder = 3
        #expect(item.sortOrder == 3)
    }

    @Test("text can be updated")
    func updateText() {
        let item = DittoItem(text: "original")
        item.text = "updated"
        #expect(item.text == "updated")
        #expect(item.preview == "updated")
    }

    @Test("Preview with carriage return and newline")
    func previewCRLF() {
        let item = DittoItem(text: "Hello\nWorld")
        #expect(item.preview == "Hello World")
    }

    @Test("Process text with multiple underscore groups uses first")
    func processMultipleMarkers() {
        let item = DittoItem(text: "Hello ___ and ___ end")
        let (text, rewind) = item.processedTextForInsertion()
        // Only first match is processed
        #expect(text == "Hello  and ___ end")
        #expect(rewind == 15) // " and ___ end" = 12 chars after removing ___
    }
}
