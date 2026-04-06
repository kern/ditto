import Foundation
import SwiftData

@Model
final class DittoItem {
    var text: String = ""
    var useCount: Int = 0
    var sortOrder: Int = 0
    var category: DittoCategory?

    init(text: String, category: DittoCategory? = nil) {
        self.text = text
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
        let length = text.count
        guard let regex = try? NSRegularExpression(pattern: "___+"),
              let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: length)) else {
            return (text, 0)
        }

        let matchRange = Range(match.range, in: text)!
        let cleaned = text.replacingCharacters(in: matchRange, with: "")
        let cursorRewind = length - match.range.location - match.range.length
        return (cleaned, cursorRewind)
    }
}
