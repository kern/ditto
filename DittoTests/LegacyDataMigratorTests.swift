import CoreData
import Foundation
import SwiftData
import Testing
@testable import Ditto

@Suite("LegacyDataMigrator Tests", .serialized)
struct LegacyDataMigratorTests {

    private let appGroupSuite = "group.io.kern.ditto"
    private let completeKey = "legacyCoreDataMigrationComplete_v302"

    // MARK: - Helpers

    private func appGroupDefaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupSuite)
    }

    private func clearFlag() {
        appGroupDefaults()?.removeObject(forKey: completeKey)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Profile.self, DittoCategory.self, DittoItem.self])
        let config = ModelConfiguration(
            "Migration-\(UUID())",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// Builds a real on-disk Core Data store with the v2 schema, populated with the given
    /// categories. Returns the URL of the SQLite file. The caller is responsible for
    /// cleaning up the temp directory when done.
    private func makeLegacyStore(
        categories: [(title: String, dittos: [(text: String, useCount: Int)])]
    ) throws -> (url: URL, tempDir: URL) {
        // Load the v2 model from the test bundle. The test target inherits the same
        // Ditto.xcdatamodeld from the project as the app target.
        guard let modelURL = Bundle.main.url(forResource: "Ditto", withExtension: "momd")
            ?? Bundle.main.url(forResource: "Ditto", withExtension: "mom"),
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            throw NSError(domain: "LegacyDataMigratorTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Ditto.xcdatamodeld not in test bundle"
            ])
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storeURL = tempDir.appendingPathComponent("Ditto.sqlite")

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )

        let moc = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        moc.persistentStoreCoordinator = coordinator

        let profile = NSEntityDescription.insertNewObject(forEntityName: "Profile", into: moc)
        let orderedCategories = NSMutableOrderedSet()
        for legacyCat in categories {
            let cat = NSEntityDescription.insertNewObject(forEntityName: "Category", into: moc)
            cat.setValue(legacyCat.title, forKey: "title")
            cat.setValue(profile, forKey: "profile")
            let orderedDittos = NSMutableOrderedSet()
            for legacyDitto in legacyCat.dittos {
                let ditto = NSEntityDescription.insertNewObject(forEntityName: "Ditto", into: moc)
                ditto.setValue(legacyDitto.text, forKey: "text")
                ditto.setValue(legacyDitto.useCount, forKey: "use_count")
                ditto.setValue(cat, forKey: "category")
                orderedDittos.add(ditto)
            }
            cat.setValue(orderedDittos, forKey: "dittos")
            orderedCategories.add(cat)
        }
        profile.setValue(orderedCategories, forKey: "categories")
        try moc.save()
        // Drop the store reference so the migrator can re-open it cleanly.
        if let store = coordinator.persistentStores.first {
            try coordinator.remove(store)
        }

        return (storeURL, tempDir)
    }

    // MARK: - Tests

    @Test("Reads ordered Profile→Category→Ditto entities from a v2 SQLite store")
    func readsV2Store() throws {
        clearFlag()
        defer { clearFlag() }

        let (storeURL, tempDir) = try makeLegacyStore(categories: [
            (title: "Work", dittos: [
                (text: "meeting at ___", useCount: 5),
                (text: "OOO today", useCount: 0)
            ]),
            (title: "Personal", dittos: [
                (text: "on my way", useCount: 12)
            ])
        ])
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // The migrator's discovery logic looks in the App Group container — but for the
        // unit test we can drive runMigration directly via the read helper, which is
        // exercised through previewRecoverableData / recoverNow with a known URL by
        // shimming through a temp-dir App Group is impractical. So this test verifies the
        // read path end-to-end via the public previewing function in a way that the next
        // test (using recoverNow) extends.
        // We rely on FileManager finding our test store at one of the probe paths is not
        // possible in the unit test sandbox, so we exercise the read path by invoking the
        // private NSPersistentStoreCoordinator load that the migrator uses, via a
        // matching read implemented in the test itself. This guards the v2 schema
        // assumptions — title/dittos/text/use_count keys — that the real migrator depends on.

        guard let modelURL = Bundle.main.url(forResource: "Ditto", withExtension: "momd")
            ?? Bundle.main.url(forResource: "Ditto", withExtension: "mom"),
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            throw NSError(domain: "test", code: 0)
        }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: [NSReadOnlyPersistentStoreOption: true]
        )
        let moc = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        moc.persistentStoreCoordinator = coordinator

        let profiles = try moc.fetch(NSFetchRequest<NSManagedObject>(entityName: "Profile"))
        let profile = try #require(profiles.first)
        let categoriesSet = try #require(profile.value(forKey: "categories") as? NSOrderedSet)
        let cats = categoriesSet.compactMap { $0 as? NSManagedObject }
        #expect(cats.count == 2)
        #expect(cats[0].value(forKey: "title") as? String == "Work")
        #expect(cats[1].value(forKey: "title") as? String == "Personal")

        let workDittos = try #require(cats[0].value(forKey: "dittos") as? NSOrderedSet)
        let workTexts = workDittos.compactMap { ($0 as? NSManagedObject)?.value(forKey: "text") as? String }
        #expect(workTexts == ["meeting at ___", "OOO today"])
        let firstUseCount = (workDittos.firstObject as? NSManagedObject)?.value(forKey: "use_count") as? Int
        #expect(firstUseCount == 5)
    }

    @Test("Completion flag short-circuits needsMigration")
    func completionFlagShortCircuits() {
        clearFlag()
        defer { clearFlag() }

        appGroupDefaults()?.set(true, forKey: completeKey)
        #expect(!LegacyDataMigrator.needsMigration)
    }

    @Test("Auto-migration marks the completion flag even when no store is on disk")
    func autoMigrationMarksCompleteWhenNoStore() throws {
        clearFlag()
        defer { clearFlag() }

        let context = try makeContext()
        let result = LegacyDataMigrator.migrateIfNeeded(into: context)
        #expect(!result)
        #expect(appGroupDefaults()?.bool(forKey: completeKey) == true)
    }

    // MARK: - WAL sidecar recovery

    @Test("extractPhrases pulls TEXT records out of synthetic WAL frames")
    func walParserExtractsTextRecords() throws {
        let wal = makeSyntheticWAL(phrases: [
            "meeting at ___",
            "OOO today",
            "on my way"
        ])
        let walURL = try writeTempFile(wal, suffix: ".sqlite-wal")
        defer { try? FileManager.default.removeItem(at: walURL) }

        let phrases = WALSidecarRecovery.extractPhrases(from: walURL)
        #expect(phrases.contains("meeting at ___"))
        #expect(phrases.contains("OOO today"))
        #expect(phrases.contains("on my way"))
    }

    @Test("extractPhrases drops too-short strings and Core Data internals")
    func walParserFiltersNoise() throws {
        // "a" → too short (dropped), "Z_PRIMARYKEY" / "Z_METADATA blob" → Core Data
        // internals (dropped), "real ditto phrase" → kept.
        let wal = makeSyntheticWAL(phrases: [
            "a",
            "Z_PRIMARYKEY",
            "Z_METADATA blob",
            "real ditto phrase"
        ])
        let walURL = try writeTempFile(wal, suffix: ".sqlite-wal")
        defer { try? FileManager.default.removeItem(at: walURL) }

        let phrases = WALSidecarRecovery.extractPhrases(from: walURL)
        #expect(phrases.contains("real ditto phrase"))
        #expect(!phrases.contains("a"))
        #expect(!phrases.contains("Z_PRIMARYKEY"))
        #expect(!phrases.contains("Z_METADATA blob"))
    }

    @Test("extractPhrases returns empty for a file without WAL magic")
    func walParserRejectsGarbage() throws {
        let walURL = try writeTempFile(Data(repeating: 0xFF, count: 200), suffix: ".sqlite-wal")
        defer { try? FileManager.default.removeItem(at: walURL) }

        #expect(WALSidecarRecovery.extractPhrases(from: walURL).isEmpty)
    }

    @Test("extractPhrases deduplicates repeated phrases across frames")
    func walParserDeduplicates() throws {
        let wal = makeSyntheticWAL(phrases: ["duplicate phrase", "duplicate phrase", "unique phrase"])
        let walURL = try writeTempFile(wal, suffix: ".sqlite-wal")
        defer { try? FileManager.default.removeItem(at: walURL) }

        let phrases = WALSidecarRecovery.extractPhrases(from: walURL)
        #expect(phrases.filter { $0 == "duplicate phrase" }.count == 1)
        #expect(phrases.contains("unique phrase"))
    }

    // MARK: - Synthetic WAL builder

    /// Writes `data` to a uniquely-named temp file with the given suffix and returns its URL.
    private func writeTempFile(_ data: Data, suffix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + suffix)
        try data.write(to: url)
        return url
    }

    /// Builds a minimal valid SQLite WAL file containing a single frame whose page is a
    /// table B-tree leaf with one cell per input string. Each cell is a record with one
    /// TEXT column. Page size is 4096; the page is page #2 so the parser doesn't apply
    /// the 100-byte SQLite-DB-header offset.
    ///
    /// Strings must be ≤127 bytes after UTF-8 encoding (so all varints fit in 1 byte);
    /// that's plenty for ditto-sized phrases and keeps this helper readable.
    private func makeSyntheticWAL(phrases: [String]) -> Data {
        let pageSize = 4096
        var wal = Data()

        // WAL header (32 bytes, big-endian on disk):
        // magic, file format version, page size, checkpoint sequence, salt-1, salt-2,
        // checksum-1, checksum-2.
        wal.append(contentsOf: [0x37, 0x7F, 0x06, 0x82])
        wal.appendUInt32BE(3_007_000)
        wal.appendUInt32BE(UInt32(pageSize))
        wal.appendUInt32BE(0)
        wal.appendUInt32BE(0)
        wal.appendUInt32BE(0)
        wal.appendUInt32BE(0)
        wal.appendUInt32BE(0)

        // Frame header (24 bytes):
        // page number (>1 so the parser doesn't apply page-1's 100-byte DB-header offset),
        // commit size, salt-1, salt-2, checksum-1, checksum-2.
        wal.appendUInt32BE(2)
        wal.appendUInt32BE(UInt32(phrases.count))
        wal.appendUInt32BE(0)
        wal.appendUInt32BE(0)
        wal.appendUInt32BE(0)
        wal.appendUInt32BE(0)

        // Build cells, placing them at the tail of the page (SQLite cell content area).
        var page = [UInt8](repeating: 0, count: pageSize)
        var cellOffsets: [Int] = []
        var contentCursor = pageSize
        for (i, phrase) in phrases.enumerated() {
            let textBytes = Array(phrase.utf8)
            precondition(textBytes.count <= 127, "Synthetic builder only supports short strings")
            let serialType = UInt8(textBytes.count * 2 + 13)
            // header_length varint (1 byte) + serial_type varint (1 byte)
            let headerLength: UInt8 = 2
            let payloadLength = UInt8(Int(headerLength) + textBytes.count)
            let rowid = UInt8(i + 1)
            let cell: [UInt8] = [payloadLength, rowid, headerLength, serialType] + textBytes
            contentCursor -= cell.count
            for (j, byte) in cell.enumerated() {
                page[contentCursor + j] = byte
            }
            cellOffsets.append(contentCursor)
        }

        // Page header (8 bytes): type (0x0D = table leaf), first-freeblock offset (0 = none),
        // cell count, cell-content-area start, fragmented free byte count.
        page[0] = 0x0D
        page[1] = 0
        page[2] = 0
        page[3] = UInt8(phrases.count >> 8)
        page[4] = UInt8(phrases.count & 0xFF)
        let contentStart = UInt16(cellOffsets.last ?? pageSize)
        page[5] = UInt8(contentStart >> 8)
        page[6] = UInt8(contentStart & 0xFF)
        page[7] = 0

        // Cell pointer array (in rowid/insertion order)
        for (i, offset) in cellOffsets.enumerated() {
            let ptrPos = 8 + i * 2
            page[ptrPos] = UInt8(offset >> 8)
            page[ptrPos + 1] = UInt8(offset & 0xFF)
        }

        wal.append(contentsOf: page)
        return wal
    }
}

private extension Data {
    mutating func appendUInt32BE(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }
}
