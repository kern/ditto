import Foundation
import Testing
@testable import Ditto

@Suite("DittoItem Model Tests")
struct DittoItemTests {

    @Test("Initialize with text and default values")
    func initWithText() {
        let item = DittoItem(text: "Hello world")
        #expect(item.text == "Hello world")
        #expect(item.useCount == 0)
        #expect(item.category == nil)
    }

    @Test("Preview strips newlines and trims whitespace")
    func preview() {
        let item = DittoItem(text: "  Hello\nWorld  ")
        #expect(item.preview == "Hello World")
    }

    @Test("Preview with single line text")
    func previewSingleLine() {
        let item = DittoItem(text: "Simple text")
        #expect(item.preview == "Simple text")
    }

    @Test("Preview with multiple newlines")
    func previewMultipleNewlines() {
        let item = DittoItem(text: "Line 1\nLine 2\nLine 3")
        #expect(item.preview == "Line 1 Line 2 Line 3")
    }

    @Test("Process text with no cursor marker returns original")
    func processNoCursorMarker() {
        let item = DittoItem(text: "Hello world")
        let (text, rewind) = item.processedTextForInsertion()
        #expect(text == "Hello world")
        #expect(rewind == 0)
    }

    @Test("Process text with triple underscore cursor marker")
    func processWithCursorMarker() {
        let item = DittoItem(text: "Hello ___ world")
        let (text, rewind) = item.processedTextForInsertion()
        #expect(text == "Hello  world")
        #expect(rewind == 6) // " world" = 6 chars after the marker
    }

    @Test("Process text with cursor marker at end")
    func processWithCursorMarkerAtEnd() {
        let item = DittoItem(text: "Hello ___")
        let (text, rewind) = item.processedTextForInsertion()
        #expect(text == "Hello ")
        #expect(rewind == 0)
    }

    @Test("Process text with longer underscore marker")
    func processWithLongerMarker() {
        let item = DittoItem(text: "Hi _____ there")
        let (text, rewind) = item.processedTextForInsertion()
        #expect(text == "Hi  there")
        #expect(rewind == 6) // " there" = 6 chars
    }

    @Test("Process text with double underscore (not a marker)")
    func processDoubleUnderscore() {
        let item = DittoItem(text: "Hello __ world")
        let (text, rewind) = item.processedTextForInsertion()
        // __ is only 2 underscores, not 3+, so no match
        #expect(text == "Hello __ world")
        #expect(rewind == 0)
    }

    @Test("Process text with cursor marker in middle of sentence")
    func processMiddleMarker() {
        let item = DittoItem(text: "I'll be there in ___ minutes!")
        let (text, rewind) = item.processedTextForInsertion()
        #expect(text == "I'll be there in  minutes!")
        #expect(rewind == 9) // " minutes!" = 9 chars
    }
}
