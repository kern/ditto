import Foundation
import OSLog

/// Last-resort recovery from an orphaned SQLite `-wal` file whose main `.sqlite` was
/// deleted by the 3.0.0 cleanup.
///
/// The WAL contains pages that would have been merged back into the main DB on the next
/// checkpoint. We can't reopen them through SQLite (the WAL's salt values reference a
/// DB header we no longer have), so this parses the WAL frames directly and walks the
/// SQLite B-tree leaf pages within them to extract TEXT-typed record values.
///
/// Format references:
/// - WAL: https://www.sqlite.org/walformat.html
/// - DB pages / records: https://www.sqlite.org/fileformat.html
///
/// Recovery is best-effort by construction: WAL frame checksums are not verified, and
/// cells whose payload spills onto overflow pages are skipped (we don't have the main
/// DB's free-page list, so we can't follow overflow chains). For typical ditto-length
/// strings none of that matters.
enum WALSidecarRecovery {

    private static let log = Logger(subsystem: "io.kern.ditto", category: "WALSidecarRecovery")

    /// Extracts deduplicated TEXT-typed record values from table B-tree leaf pages
    /// within `walURL`. Returned strings are sorted, trimmed, and filtered to drop:
    /// - very short strings (`< 2` chars) — pure noise
    /// - very long strings (`> 5000` chars) — almost certainly mis-parsed bytes
    /// - obvious Core Data internal identifiers (`Z_PRIMARYKEY`, etc.)
    static func extractPhrases(from walURL: URL) -> [String] {
        guard let data = try? Data(contentsOf: walURL) else {
            log.error("extractPhrases: could not read \(walURL.path, privacy: .public)")
            return []
        }
        return parse([UInt8](data))
    }

    /// Same as `extractPhrases(from:)` but takes raw bytes. Internal entry point so
    /// tests can drive the parser against synthetic data without touching disk.
    static func parse(_ bytes: [UInt8]) -> [String] {
        guard bytes.count >= 32 else { return [] }
        // WAL magic: 0x377F0682 (host-endian write) or 0x377F0683 (byte-swapped).
        // The header is always stored big-endian on disk regardless.
        let magic = readUInt32BE(bytes, at: 0)
        guard magic == 0x377F_0682 || magic == 0x377F_0683 else { return [] }
        let pageSize = Int(readUInt32BE(bytes, at: 8))
        // SQLite page sizes are powers of two between 512 and 65536.
        guard pageSize >= 512, pageSize <= 65536, pageSize.nonzeroBitCount == 1 else { return [] }

        var results: Set<String> = []
        let frameSize = 24 + pageSize
        var offset = 32 // past WAL header
        while offset + frameSize <= bytes.count {
            let pageNumber = readUInt32BE(bytes, at: offset)
            let pageBase = offset + 24
            // Page 1 has the 100-byte SQLite DB header before its B-tree header.
            let btreeStart = pageNumber == 1 ? 100 : 0
            extractFromPage(bytes, pageBase: pageBase, pageSize: pageSize, btreeStart: btreeStart, into: &results)
            offset += frameSize
        }
        return results.sorted()
    }

    // MARK: - B-tree page walker

    private static func extractFromPage(
        _ bytes: [UInt8],
        pageBase: Int,
        pageSize: Int,
        btreeStart: Int,
        into results: inout Set<String>
    ) {
        let pageEnd = pageBase + pageSize
        let header = pageBase + btreeStart
        guard header < bytes.count, header < pageEnd else { return }
        // Only table B-tree leaf pages (0x0D) carry the row payloads we want. Index
        // pages, interior pages, and freelist pages don't contain user TEXT.
        guard bytes[header] == 0x0D else { return }

        let cellCount = Int(readUInt16BE(bytes, at: header + 3))
        // Table-leaf page header is 8 bytes; cell pointer array follows.
        let cellPtrStart = header + 8
        for i in 0..<cellCount {
            let ptr = cellPtrStart + i * 2
            guard ptr + 1 < bytes.count, ptr + 1 < pageEnd else { break }
            let cellOffsetInPage = Int(readUInt16BE(bytes, at: ptr))
            let cellAbs = pageBase + cellOffsetInPage
            guard cellAbs >= pageBase, cellAbs < pageEnd else { continue }
            parseTableLeafCell(bytes, at: cellAbs, pageEnd: pageEnd, into: &results)
        }
    }

    private static func parseTableLeafCell(
        _ bytes: [UInt8],
        at offset: Int,
        pageEnd: Int,
        into results: inout Set<String>
    ) {
        var cursor = offset
        guard let (payloadLength, n1) = readVarint(bytes, at: cursor) else { return }
        cursor += n1
        guard let (_, n2) = readVarint(bytes, at: cursor) else { return }
        cursor += n2

        let payloadEnd = cursor + Int(payloadLength)
        // If the payload extends past the page, this cell uses overflow pages.
        // Skip — extracting from overflow without the main DB's free-page map is
        // not worth the complexity for typical ditto-sized text.
        guard payloadEnd <= pageEnd, payloadEnd <= bytes.count else { return }

        let recordStart = cursor
        guard let (headerLength, hLen) = readVarint(bytes, at: cursor) else { return }
        var headerCursor = cursor + hLen
        let headerEnd = recordStart + Int(headerLength)
        guard headerEnd <= payloadEnd else { return }

        var serials: [UInt64] = []
        while headerCursor < headerEnd {
            guard let (st, sz) = readVarint(bytes, at: headerCursor) else { return }
            serials.append(st)
            headerCursor += sz
        }

        var body = headerEnd
        for st in serials {
            let info = serialTypeInfo(st)
            guard body + info.size <= payloadEnd else { return }
            if info.isText && info.size > 0 {
                let slice = Array(bytes[body..<(body + info.size)])
                if let raw = String(bytes: slice, encoding: .utf8) {
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.count >= 2, trimmed.count <= 5000, !isInternalString(trimmed) {
                        results.insert(trimmed)
                    }
                }
            }
            body += info.size
        }
    }

    private static func serialTypeInfo(_ st: UInt64) -> (size: Int, isText: Bool) {
        switch st {
        case 0, 8, 9, 10, 11: return (0, false)
        case 1: return (1, false)
        case 2: return (2, false)
        case 3: return (3, false)
        case 4: return (4, false)
        case 5: return (6, false)
        case 6, 7: return (8, false)
        default:
            guard st >= 12 else { return (0, false) }
            return (Int((st - 12) / 2), st % 2 == 1)
        }
    }

    private static func isInternalString(_ s: String) -> Bool {
        // Core Data's Z_PRIMARYKEY / Z_METADATA / Z_MODELCACHE tables store entity
        // names and serialized schema state as TEXT — we don't want to surface those
        // alongside the user's actual ditto phrases.
        let internalPrefixes = ["Z_PRIMARYKEY", "Z_METADATA", "Z_MODELCACHE", "NSStoreType"]
        return internalPrefixes.contains { s.hasPrefix($0) }
    }

    // MARK: - Byte readers

    private static func readUInt16BE(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        guard offset + 1 < bytes.count else { return 0 }
        return UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    private static func readUInt32BE(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        guard offset + 3 < bytes.count else { return 0 }
        return UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])
    }

    private static func readVarint(_ bytes: [UInt8], at offset: Int) -> (value: UInt64, bytesRead: Int)? {
        var result: UInt64 = 0
        for i in 0..<9 {
            guard offset + i < bytes.count else { return nil }
            let byte = bytes[offset + i]
            if i == 8 {
                result = (result << 8) | UInt64(byte)
                return (result, 9)
            }
            result = (result << 7) | UInt64(byte & 0x7F)
            if byte & 0x80 == 0 {
                return (result, i + 1)
            }
        }
        return nil
    }
}
