import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// CSV-based export and JSON/CSV import for Ditto collections.
enum DittoImportExport {

    // MARK: - CSV Export

    /// Exports all dittos as CSV: Category,Ditto
    static func exportCSV(from store: DittoStore) -> Data {
        var lines = ["Category,Ditto"]
        for cat in store.categories {
            for ditto in cat.orderedDittos {
                lines.append("\(csvEscape(cat.title)),\(csvEscape(ditto.text))")
            }
        }
        return lines.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    private static func csvEscape(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n")
        if needsQuoting {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    // MARK: - CSV Import

    static func importCSV(_ data: Data, into store: DittoStore) throws -> Int {
        guard let content = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }

        let rows = parseCSV(content)
        guard rows.count > 1 else { return 0 }

        // Skip header row if it looks like one
        let startIndex = (rows.first?.count == 2
            && rows.first?[0].lowercased() == "category"
            && rows.first?[1].lowercased() == "ditto") ? 1 : 0

        var imported = 0
        for row in rows[startIndex...] {
            guard row.count >= 2 else { continue }
            let categoryTitle = row[0].trimmingCharacters(in: .whitespaces)
            let dittoText = row[1].trimmingCharacters(in: .whitespaces)
            guard !categoryTitle.isEmpty, !dittoText.isEmpty else { continue }

            if let catIndex = store.categories.firstIndex(where: { $0.title == categoryTitle }) {
                let existingTexts = Set(store.category(at: catIndex).orderedDittos.map(\.text))
                if !existingTexts.contains(dittoText) {
                    store.addDitto(text: dittoText, toCategoryAt: catIndex)
                    imported += 1
                }
            } else if store.canCreateNewCategory {
                store.addCategory(title: categoryTitle)
                let catIndex = store.categoryCount - 1
                store.addDitto(text: dittoText, toCategoryAt: catIndex)
                imported += 1
            }
        }

        return imported
    }

    /// Simple CSV parser that handles quoted fields with newlines and escaped quotes.
    private static func parseCSV(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var current: [String] = []
        var field = ""
        var inQuotes = false
        var i = content.startIndex

        while i < content.endIndex {
            let c = content[i]
            if inQuotes {
                if c == "\"" {
                    let next = content.index(after: i)
                    if next < content.endIndex && content[next] == "\"" {
                        field.append("\"")
                        i = content.index(after: next)
                    } else {
                        inQuotes = false
                        i = content.index(after: i)
                    }
                } else {
                    field.append(c)
                    i = content.index(after: i)
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                    i = content.index(after: i)
                } else if c == "," {
                    current.append(field)
                    field = ""
                    i = content.index(after: i)
                } else if c == "\n" || c == "\r" {
                    current.append(field)
                    field = ""
                    if !current.allSatisfy({ $0.isEmpty }) {
                        rows.append(current)
                    }
                    current = []
                    // Skip \r\n
                    let next = content.index(after: i)
                    if c == "\r" && next < content.endIndex && content[next] == "\n" {
                        i = content.index(after: next)
                    } else {
                        i = content.index(after: i)
                    }
                } else {
                    field.append(c)
                    i = content.index(after: i)
                }
            }
        }
        // Last field
        current.append(field)
        if !current.allSatisfy({ $0.isEmpty }) {
            rows.append(current)
        }
        return rows
    }
}

// MARK: - Export Document

struct DittoExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let data: Data

    init(store: DittoStore) {
        data = DittoImportExport.exportCSV(from: store)
    }

    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = fileData
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
