import Foundation
import SwiftData

@Model
final class DittoItem {
    var text: String = ""
    var useCount: Int = 0
    var sortOrder: Int = 0
    var modifiedAt: Date = Date()
    var category: DittoCategory?

    init(text: String, category: DittoCategory? = nil) {
        self.text = text
        self.modifiedAt = Date()
        self.category = category
    }

    /// Returns preview text with newlines replaced by spaces
    var preview: String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Processes `___` cursor placeholder markers.
    /// Returns the cleaned text and the number of characters to rewind the cursor.
    func processedTextForInsertion() -> (text: String, cursorRewind: Int) {
        guard let match = text.firstMatch(of: /___+/) else {
            return (text, 0)
        }
        let cleaned = String(text[text.startIndex..<match.range.lowerBound])
            + String(text[match.range.upperBound...])
        let cursorRewind = text[match.range.upperBound...].count
        return (cleaned, cursorRewind)
    }
}
