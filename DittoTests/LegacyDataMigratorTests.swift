import Foundation
import SwiftData
import Testing
@testable import Ditto

@Suite("LegacyDataMigrator Tests", .serialized)
struct LegacyDataMigratorTests {

    private let appGroupSuite = "group.io.kern.ditto"
    private let completeKey = "legacyUserDefaultsMigrationComplete"
    private let categoriesKey = "categories"
    private let dittosKey = "dittos"

    private struct DefaultsSnapshot {
        let complete: Bool
        let categories: Any?
        let dittos: Any?
        let stdCategories: Any?
        let stdDittos: Any?
    }

    private func appGroupDefaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupSuite)
    }

    private func snapshot() -> DefaultsSnapshot {
        let group = appGroupDefaults()
        return DefaultsSnapshot(
            complete: group?.bool(forKey: completeKey) ?? false,
            categories: group?.object(forKey: categoriesKey),
            dittos: group?.object(forKey: dittosKey),
            stdCategories: UserDefaults.standard.object(forKey: categoriesKey),
            stdDittos: UserDefaults.standard.object(forKey: dittosKey)
        )
    }

    private func restore(_ snap: DefaultsSnapshot) {
        let group = appGroupDefaults()
        group?.set(snap.complete, forKey: completeKey)
        group?.set(snap.categories, forKey: categoriesKey)
        group?.set(snap.dittos, forKey: dittosKey)
        UserDefaults.standard.set(snap.stdCategories, forKey: categoriesKey)
        UserDefaults.standard.set(snap.stdDittos, forKey: dittosKey)
    }

    private func clearAll() {
        let group = appGroupDefaults()
        group?.removeObject(forKey: completeKey)
        group?.removeObject(forKey: categoriesKey)
        group?.removeObject(forKey: dittosKey)
        UserDefaults.standard.removeObject(forKey: categoriesKey)
        UserDefaults.standard.removeObject(forKey: dittosKey)
    }

    private func makeContext() throws -> ModelContext {
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

        let context = try makeContext()
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

        let context = try makeContext()
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

        let context = try makeContext()
        let result = LegacyDataMigrator.migrateIfNeeded(into: context)
        #expect(result)

        let profile = try #require(try context.fetch(FetchDescriptor<Profile>()).first)
        #expect(profile.orderedCategories.map { $0.title } == ["Old"])
        #expect(profile.orderedCategories.first?.orderedDittos.map { $0.text } == ["legacy ditto"])
    }

    @Test("Flat dittos=[String] (v1/2.0 shape) is migrated into a single category")
    func migratesFlatArrayFormat() throws {
        let snap = snapshot()
        defer { restore(snap) }

        clearAll()
        let flat = ["hello", "running late", "on my way"]
        appGroupDefaults()?.set(flat, forKey: dittosKey)

        #expect(LegacyDataMigrator.needsMigration)

        let context = try makeContext()
        let result = LegacyDataMigrator.migrateIfNeeded(into: context)
        #expect(result)

        let profile = try #require(try context.fetch(FetchDescriptor<Profile>()).first)
        let categories = profile.orderedCategories
        #expect(categories.count == 1)
        #expect(categories.first?.title == LegacyDataMigrator.flatRecoveryCategoryTitle)
        #expect(categories.first?.orderedDittos.map { $0.text } == flat)
    }

    @Test("recoverNow ignores the completion flag and imports legacy data")
    func recoverNowIgnoresFlag() throws {
        let snap = snapshot()
        defer { restore(snap) }

        clearAll()
        appGroupDefaults()?.set(["hi", "bye"], forKey: dittosKey)
        // Simulate a previous launch that marked migration complete (e.g. the
        // 3.0.0 Core Data migrator that never touched this NSUserDefaults blob,
        // or any future build that prematurely sets the flag).
        appGroupDefaults()?.set(true, forKey: completeKey)
        #expect(!LegacyDataMigrator.needsMigration)

        // hasRecoverableLegacyData and previewRecoverableData ignore the flag.
        #expect(LegacyDataMigrator.hasRecoverableLegacyData)
        let preview = try #require(LegacyDataMigrator.previewRecoverableData())
        #expect(preview.dittoCount == 2)
        #expect(preview.categoryCount == 1)

        let context = try makeContext()
        let inserted = LegacyDataMigrator.recoverNow(into: context)
        #expect(inserted == 2)

        let profile = try #require(try context.fetch(FetchDescriptor<Profile>()).first)
        #expect(profile.orderedCategories.first?.orderedDittos.map { $0.text } == ["hi", "bye"])
    }

    @Test("recoverNow skips dittos that already exist in the SwiftData store")
    func recoverNowDedupes() throws {
        let snap = snapshot()
        defer { restore(snap) }

        clearAll()
        appGroupDefaults()?.set(["hello", "world"], forKey: dittosKey)

        let context = try makeContext()
        // Seed the context with one of the dittos already present in the legacy data,
        // in a category with the same title the flat-format migrator will use.
        let profile = Profile()
        context.insert(profile)
        let category = DittoCategory(title: LegacyDataMigrator.flatRecoveryCategoryTitle, profile: profile)
        category.sortOrder = 0
        context.insert(category)
        profile.categories?.append(category)
        let existing = DittoItem(text: "hello", category: category)
        existing.sortOrder = 0
        context.insert(existing)
        category.dittos?.append(existing)
        try context.save()

        let inserted = LegacyDataMigrator.recoverNow(into: context)
        #expect(inserted == 1) // only "world" is new

        let refreshed = try #require(try context.fetch(FetchDescriptor<Profile>()).first)
        #expect(refreshed.orderedCategories.first?.orderedDittos.map { $0.text } == ["hello", "world"])
    }
}
