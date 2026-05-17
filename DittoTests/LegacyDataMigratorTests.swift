import Foundation
import SwiftData
import Testing
@testable import Ditto

@Suite("LegacyDataMigrator Tests", .serialized)
struct LegacyDataMigratorTests {

    private static let appGroupSuite = "group.io.kern.ditto"
    private static let completeKey = "legacyUserDefaultsMigrationComplete"
    private static let categoriesKey = "categories"
    private static let dittosKey = "dittos"

    private struct DefaultsSnapshot {
        let complete: Bool
        let categories: Any?
        let dittos: Any?
        let stdCategories: Any?
        let stdDittos: Any?
    }

    private static func appGroupDefaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupSuite)
    }

    private static func snapshot() -> DefaultsSnapshot {
        let group = appGroupDefaults()
        return DefaultsSnapshot(
            complete: group?.bool(forKey: completeKey) ?? false,
            categories: group?.object(forKey: categoriesKey),
            dittos: group?.object(forKey: dittosKey),
            stdCategories: UserDefaults.standard.object(forKey: categoriesKey),
            stdDittos: UserDefaults.standard.object(forKey: dittosKey)
        )
    }

    private static func restore(_ snap: DefaultsSnapshot) {
        let group = appGroupDefaults()
        group?.set(snap.complete, forKey: completeKey)
        group?.set(snap.categories, forKey: categoriesKey)
        group?.set(snap.dittos, forKey: dittosKey)
        UserDefaults.standard.set(snap.stdCategories, forKey: categoriesKey)
        UserDefaults.standard.set(snap.stdDittos, forKey: dittosKey)
    }

    private static func clearAll() {
        let group = appGroupDefaults()
        group?.removeObject(forKey: completeKey)
        group?.removeObject(forKey: categoriesKey)
        group?.removeObject(forKey: dittosKey)
        UserDefaults.standard.removeObject(forKey: categoriesKey)
        UserDefaults.standard.removeObject(forKey: dittosKey)
    }

    private static func makeContext() throws -> ModelContext {
        let schema = Schema([Profile.self, DittoCategory.self, DittoItem.self])
        let config = ModelConfiguration("Migration-\(UUID())", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test("Migration flag prevents repeated migration")
    func migrationFlag() {
        let snap = snapshot()
        defer { restore(snap) }

        clearAll()
        appGroupDefaults()?.set(["Personal"], forKey: categoriesKey)
        appGroupDefaults()?.set(["Personal": ["hello"]], forKey: dittosKey)
        appGroupDefaults()?.set(true, forKey: completeKey)

        #expect(!LegacyDataMigrator.needsMigration)
    }

    @Test("needsMigration is false when no legacy data exists")
    func noLegacyData() {
        let snap = snapshot()
        defer { restore(snap) }

        clearAll()
        #expect(!LegacyDataMigrator.needsMigration)
    }

    @Test("needsMigration is true when legacy data is present")
    func detectsLegacyData() {
        let snap = snapshot()
        defer { restore(snap) }

        clearAll()
        appGroupDefaults()?.set(["Greetings"], forKey: categoriesKey)
        appGroupDefaults()?.set(["Greetings": ["hi"]], forKey: dittosKey)

        #expect(LegacyDataMigrator.needsMigration)
    }

    @Test("Migration imports categories and dittos preserving order")
    func migratesData() throws {
        let snap = snapshot()
        defer { restore(snap) }

        clearAll()
        let titles = ["Work", "Personal"]
        let dittos: [String: [String]] = [
            "Work": ["meeting at ___", "OOO today"],
            "Personal": ["on my way", "running late"]
        ]
        appGroupDefaults()?.set(titles, forKey: categoriesKey)
        appGroupDefaults()?.set(dittos, forKey: dittosKey)

        let context = try Self.makeContext()
        let result = LegacyDataMigrator.migrateIfNeeded(into: context)
        #expect(result)

        let profiles = try context.fetch(FetchDescriptor<Profile>())
        let profile = try #require(profiles.first)
        let ordered = profile.orderedCategories
        #expect(ordered.map { $0.title } == titles)
        #expect(ordered[0].orderedDittos.map { $0.text } == ["meeting at ___", "OOO today"])
        #expect(ordered[1].orderedDittos.map { $0.text } == ["on my way", "running late"])
    }

    @Test("Migration does not delete legacy NSUserDefaults entries")
    func preservesLegacyDefaults() throws {
        let snap = snapshot()
        defer { restore(snap) }

        clearAll()
        let titles = ["Notes"]
        let dittos: [String: [String]] = ["Notes": ["remember the milk"]]
        appGroupDefaults()?.set(titles, forKey: categoriesKey)
        appGroupDefaults()?.set(dittos, forKey: dittosKey)

        let context = try Self.makeContext()
        _ = LegacyDataMigrator.migrateIfNeeded(into: context)

        // Legacy entries must remain in NSUserDefaults after migration
        #expect(appGroupDefaults()?.array(forKey: categoriesKey) as? [String] == titles)
        #expect((appGroupDefaults()?.dictionary(forKey: dittosKey) as? [String: [String]]) == dittos)
    }

    @Test("Migration reads from UserDefaults.standard when App Group is empty")
    func readsFromStandardDefaults() throws {
        let snap = snapshot()
        defer { restore(snap) }

        clearAll()
        UserDefaults.standard.set(["Old"], forKey: categoriesKey)
        UserDefaults.standard.set(["Old": ["legacy ditto"]], forKey: dittosKey)

        let context = try Self.makeContext()
        let result = LegacyDataMigrator.migrateIfNeeded(into: context)
        #expect(result)

        let profile = try #require(try context.fetch(FetchDescriptor<Profile>()).first)
        #expect(profile.orderedCategories.map { $0.title } == ["Old"])
        #expect(profile.orderedCategories.first?.orderedDittos.map { $0.text } == ["legacy ditto"])
    }
}
