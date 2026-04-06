import CoreData
import Foundation
import SwiftData

/// Migrates data from the legacy Core Data store (v1/v2) to the new SwiftData store.
///
/// The old Core Data model used entities: Profile, Category, Ditto
/// with ordered relationships and snake_case attributes (use_count).
/// This migrator reads the old store, creates equivalent SwiftData objects,
/// and removes the old store files after successful migration.
@available(iOS, deprecated: 18.0, message: "Remove once all users have migrated from Core Data (target: v4.0)")
enum LegacyDataMigrator {

    private static let appGroupIdentifier = "group.io.kern.ditto"
    private static let migrationCompleteKey = "legacyCoreDataMigrationComplete"

    /// Returns true if legacy Core Data files exist and haven't been migrated yet.
    static var needsMigration: Bool {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return false }
        if defaults.bool(forKey: migrationCompleteKey) { return false }
        return legacyStoreURL != nil
    }

    /// The URL of the legacy Core Data SQLite store, if it exists.
    private static var legacyStoreURL: URL? {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return nil }

        // Check common Core Data store filenames from the old app
        let candidates = [
            groupURL.appendingPathComponent("Ditto.sqlite"),
            groupURL.appendingPathComponent("ditto.sqlite")
        ]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        // Also check the default application support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let url = appSupport?.appendingPathComponent("Ditto.sqlite"),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        return nil
    }

    // MARK: - Migration

    /// Migrates legacy Core Data content into the given SwiftData model context.
    /// Returns `true` if data was migrated, `false` if no legacy data was found.
    @discardableResult
    static func migrateIfNeeded(into context: ModelContext) -> Bool {
        guard let storeURL = legacyStoreURL else {
            markComplete()
            return false
        }

        do {
            let legacyData = try readLegacyStore(at: storeURL)
            if legacyData.isEmpty {
                markComplete()
                cleanupLegacyFiles(at: storeURL)
                return false
            }

            writeMigratedData(legacyData, into: context)
            try context.save()

            markComplete()
            cleanupLegacyFiles(at: storeURL)
            return true
        } catch {
            print("Legacy data migration failed: \(error)")
            return false
        }
    }

    // MARK: - Read Legacy Store

    private struct LegacyCategory {
        let title: String
        let dittos: [LegacyDitto]
    }

    private struct LegacyDitto {
        let text: String
        let useCount: Int
    }

    private static func readLegacyStore(at url: URL) throws -> [LegacyCategory] {
        guard let modelURL = Bundle.main.url(forResource: "Ditto", withExtension: "momd")
                ?? Bundle.main.url(forResource: "Ditto", withExtension: "mom"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            print("Legacy Core Data model not found in bundle")
            return []
        }

        let container = NSPersistentContainer(name: "Ditto", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: url)
        description.isReadOnly = true
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let error = loadError { throw error }

        let moc = container.viewContext

        // Fetch the profile to get ordered categories
        let profileRequest = NSFetchRequest<NSManagedObject>(entityName: "Profile")
        let profiles = try moc.fetch(profileRequest)

        guard let profile = profiles.first else {
            // No profile means no data to migrate - try fetching categories directly
            return try readCategoriesWithoutProfile(moc: moc)
        }

        // Core Data ordered relationship returns NSOrderedSet
        guard let categoriesSet = profile.value(forKey: "categories") as? NSOrderedSet else {
            return []
        }

        var result: [LegacyCategory] = []
        for case let categoryObj as NSManagedObject in categoriesSet {
            let category = readCategory(categoryObj)
            result.append(category)
        }
        return result
    }

    private static func readCategoriesWithoutProfile(moc: NSManagedObjectContext) throws -> [LegacyCategory] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Category")
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        let categories = try moc.fetch(request)
        return categories.map { readCategory($0) }
    }

    private static func readCategory(_ obj: NSManagedObject) -> LegacyCategory {
        let title = obj.value(forKey: "title") as? String ?? ""

        var dittos: [LegacyDitto] = []
        if let dittosSet = obj.value(forKey: "dittos") as? NSOrderedSet {
            for case let dittoObj as NSManagedObject in dittosSet {
                let text = dittoObj.value(forKey: "text") as? String ?? ""
                let useCount = (dittoObj.value(forKey: "use_count") as? Int) ?? 0
                dittos.append(LegacyDitto(text: text, useCount: useCount))
            }
        }

        return LegacyCategory(title: title, dittos: dittos)
    }

    // MARK: - Write Migrated Data

    private static func writeMigratedData(_ categories: [LegacyCategory], into context: ModelContext) {
        let profile = Profile()
        context.insert(profile)

        for (catIndex, legacyCat) in categories.enumerated() {
            let category = DittoCategory(title: legacyCat.title, profile: profile)
            category.sortOrder = catIndex
            context.insert(category)
            profile.categories?.append(category)

            for (dittoIndex, legacyDitto) in legacyCat.dittos.enumerated() {
                let item = DittoItem(text: legacyDitto.text, category: category)
                item.useCount = legacyDitto.useCount
                item.sortOrder = dittoIndex
                context.insert(item)
                category.dittos?.append(item)
            }
        }
    }

    // MARK: - Cleanup

    private static func markComplete() {
        UserDefaults(suiteName: appGroupIdentifier)?.set(true, forKey: migrationCompleteKey)
    }

    private static func cleanupLegacyFiles(at storeURL: URL) {
        let fm = FileManager.default
        let suffixes = ["", "-shm", "-wal", "-journal"]
        for suffix in suffixes {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            try? fm.removeItem(at: url)
        }
    }
}
