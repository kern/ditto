import Foundation
import SwiftData
import Testing
@testable import Ditto

@Suite("LegacyDataMigrator Tests")
struct LegacyDataMigratorTests {

    @Test("Migration flag prevents repeated migration")
    func migrationFlag() {
        // Without a legacy store file present, needsMigration should be false
        // (or true only if there's actually an old .sqlite file)
        // This validates the guard logic works
        let defaults = UserDefaults(suiteName: "group.io.kern.ditto")
        let originalValue = defaults?.bool(forKey: "legacyCoreDataMigrationComplete")

        // Mark as complete
        defaults?.set(true, forKey: "legacyCoreDataMigrationComplete")
        #expect(!LegacyDataMigrator.needsMigration)

        // Restore original value
        if let original = originalValue, original {
            defaults?.set(true, forKey: "legacyCoreDataMigrationComplete")
        } else {
            defaults?.removeObject(forKey: "legacyCoreDataMigrationComplete")
        }
    }

    @Test("Migration returns false when no legacy store exists")
    func noLegacyStore() throws {
        let schema = Schema([Profile.self, DittoCategory.self, DittoItem.self])
        let config = ModelConfiguration("TestMigration", schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        // Clear migration flag to allow check
        let defaults = UserDefaults(suiteName: "group.io.kern.ditto")
        defaults?.removeObject(forKey: "legacyCoreDataMigrationComplete")

        let result = LegacyDataMigrator.migrateIfNeeded(into: context)
        #expect(!result)
    }
}
