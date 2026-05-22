import CoreData
import Foundation
import OSLog
import SwiftData

/// Migrates data from the legacy Core Data store (Ditto 2.x) into the new SwiftData store.
///
/// The 2.0.1 source (`git show 60f395d:Ditto/DittoStore.swift`) persists user content as
/// Core Data under the shared App Group container:
///
/// ```
/// let directory = NSFileManager.defaultManager()
///     .containerURLForSecurityApplicationGroupIdentifier("group.io.kern.ditto")
/// let storeURL = directory?.URLByAppendingPathComponent("Ditto.sqlite")
/// ```
///
/// The schema is `Profile` (singleton root) → ordered `categories` → `Category` → ordered
/// `dittos` → `Ditto`, with `Ditto.text: String` and `Ditto.use_count: Int32`. The same
/// `.xcdatamodeld` is checked into this repo at `Ditto/Ditto.xcdatamodeld/Ditto.xcdatamodel/contents`;
/// this migrator loads it from `Bundle.main` at runtime and opens the legacy store **read-only**.
///
/// IMPORTANT — we never delete the on-disk SQLite. The 3.0.0 migrator deleted
/// `Ditto.sqlite` (and its `-shm`/`-wal` siblings) on the "no data found" branch because
/// the model wasn't bundled in the main app, so model-loading silently returned `[]`,
/// and the migrator interpreted that as "nothing to migrate, safe to clean up" — destroying
/// the user's data. We will never call `removeItem` on the legacy store, even on success.
@available(iOS, deprecated: 18.0, message: "Remove once all users have migrated from the v2 Core Data store (target: v4.0)")
enum LegacyDataMigrator {

    private static let appGroupIdentifier = "group.io.kern.ditto"
    /// Bumped from `legacyUserDefaultsMigrationComplete` (the 3.0.1 NSUserDefaults migrator)
    /// and `legacyCoreDataMigrationComplete` (the 3.0.0 migrator) so any device that hit
    /// either of those builds re-runs the corrected Core Data migration in 3.0.2.
    private static let migrationCompleteKey = "legacyCoreDataMigrationComplete_v302"
    private static let legacyStoreFilename = "Ditto.sqlite"

    private static let log = Logger(subsystem: "io.kern.ditto", category: "LegacyDataMigrator")

    /// Auto-launch gate. True if a legacy Core Data store exists and we haven't already
    /// migrated it in this corrected build.
    static var needsMigration: Bool {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            log.debug("needsMigration: App Group defaults unavailable")
            return false
        }
        if defaults.bool(forKey: migrationCompleteKey) {
            log.debug("needsMigration: completion flag is set, skipping auto-migration")
            return false
        }
        let exists = legacyStoreURL != nil
        log.debug("needsMigration: legacy store present=\(exists, privacy: .public)")
        return exists
    }

    /// True if a legacy store is on disk *regardless* of the completion flag. Powers the
    /// manual "Recover Old Dittos" menu item so users who already silently no-op'd on a
    /// previous 3.0.x build can still recover after updating.
    static var hasRecoverableLegacyData: Bool {
        legacyStoreURL != nil
    }

    /// Snapshot for the confirmation alert.
    struct RecoveryPreview {
        let categoryCount: Int
        let dittoCount: Int
    }

    /// Reads the legacy store (without mutating it) and returns how many categories /
    /// dittos would be imported. Returns nil if there's no recoverable store on disk.
    static func previewRecoverableData() -> RecoveryPreview? {
        guard let url = legacyStoreURL else { return nil }
        guard let legacy = try? readLegacyStore(at: url), !legacy.isEmpty else { return nil }
        return RecoveryPreview(
            categoryCount: legacy.count,
            dittoCount: legacy.reduce(0) { $0 + $1.dittos.count }
        )
    }

    // MARK: - Auto migration

    /// Runs from `DittoApp.init` on launch. Migrates if a legacy store is present and the
    /// completion flag isn't set yet. Returns true iff anything was inserted into `context`.
    @discardableResult
    static func migrateIfNeeded(into context: ModelContext) -> Bool {
        guard let storeURL = legacyStoreURL else {
            // No store on disk. Mark complete so we don't re-scan every cold launch.
            log.info("migrateIfNeeded: no legacy store on disk, marking complete")
            markComplete()
            return false
        }

        return runMigration(at: storeURL, into: context, source: "auto", markCompleteOnEmpty: true)
    }

    /// Manually re-runs the migration from a user-tapped menu item. Ignores the completion
    /// flag. Never marks the legacy store as deletable. Returns the number of *new* dittos
    /// inserted (duplicates already in the SwiftData store are skipped).
    @discardableResult
    static func recoverNow(into context: ModelContext) -> Int {
        guard let storeURL = legacyStoreURL else {
            log.info("recoverNow: no legacy store on disk")
            return 0
        }

        let beforeCount = (try? context.fetch(FetchDescriptor<DittoItem>()).count) ?? 0
        _ = runMigration(at: storeURL, into: context, source: "manual", markCompleteOnEmpty: false)
        let afterCount = (try? context.fetch(FetchDescriptor<DittoItem>()).count) ?? 0

        return max(0, afterCount - beforeCount)
    }

    // MARK: - Migration core

    /// Shared read+write+save path used by both the auto and manual entry points.
    @discardableResult
    private static func runMigration(
        at storeURL: URL,
        into context: ModelContext,
        source: String,
        markCompleteOnEmpty: Bool
    ) -> Bool {
        let legacy: [LegacyCategory]
        do {
            legacy = try readLegacyStore(at: storeURL)
        } catch {
            // Read failed — could not load the model, could not open the store, could not
            // fetch. Do NOT mark complete, do NOT touch the SQLite file. The user can try
            // again on the next launch or via the menu item.
            log.error("runMigration(\(source, privacy: .public)): read failed: \(error.localizedDescription, privacy: .public)")
            return false
        }

        guard !legacy.isEmpty else {
            log.info("runMigration(\(source, privacy: .public)): legacy store opened but empty")
            if markCompleteOnEmpty { markComplete() }
            return false
        }

        let totalDittos = legacy.reduce(0) { $0 + $1.dittos.count }
        log.info(
            // swiftlint:disable:next line_length
            "runMigration(\(source, privacy: .public)): importing \(legacy.count, privacy: .public) categories / \(totalDittos, privacy: .public) dittos"
        )

        let inserted = writeMigratedData(legacy, into: context)

        do {
            try context.save()
        } catch {
            log.error("runMigration(\(source, privacy: .public)): save failed: \(error.localizedDescription, privacy: .public)")
            return false
        }

        markComplete()
        log.info("runMigration(\(source, privacy: .public)): inserted \(inserted, privacy: .public) new dittos")
        return inserted > 0
    }

    // MARK: - Store discovery

    /// Returns the URL of the legacy 2.x Core Data store if one exists on disk.
    /// The 2.0.1 source put it at `<App Group container>/Ditto.sqlite`; we also probe
    /// a couple of other common pre-`NSPersistentContainer` locations as a safety net.
    private static var legacyStoreURL: URL? {
        let fm = FileManager.default
        var candidates: [URL] = []

        if let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            candidates.append(groupURL.appendingPathComponent(legacyStoreFilename))
            candidates.append(groupURL.appendingPathComponent("Library/Application Support/" + legacyStoreFilename))
            candidates.append(groupURL.appendingPathComponent("Library/Application Support/Ditto/" + legacyStoreFilename))
        }
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            candidates.append(appSupport.appendingPathComponent(legacyStoreFilename))
            candidates.append(appSupport.appendingPathComponent("Ditto/" + legacyStoreFilename))
        }
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            candidates.append(docs.appendingPathComponent(legacyStoreFilename))
        }

        return candidates.first { fm.fileExists(atPath: $0.path) }
    }

    // MARK: - Read legacy store

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
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            throw MigrationError.modelNotInBundle
        }

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let options: [AnyHashable: Any] = [
            // Open read-only — defense in depth so we can never accidentally rewrite the
            // legacy file, even if Core Data lightweight-migrates the schema in memory.
            NSReadOnlyPersistentStoreOption: true,
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
        try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)

        let moc = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        moc.persistentStoreCoordinator = coordinator

        // Fetch the singleton Profile and walk its ordered relationships. Falls back to
        // fetching categories directly if the profile is missing for any reason (a
        // partially-initialized 2.x store from before any user content existed).
        let profileRequest = NSFetchRequest<NSManagedObject>(entityName: "Profile")
        let profiles = try moc.fetch(profileRequest)
        if let profile = profiles.first,
           let categoriesSet = profile.value(forKey: "categories") as? NSOrderedSet {
            return categoriesSet.compactMap { ($0 as? NSManagedObject).map(readCategory) }
        }

        let categoryRequest = NSFetchRequest<NSManagedObject>(entityName: "Category")
        let categories = try moc.fetch(categoryRequest)
        return categories.map(readCategory)
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

    enum MigrationError: Error {
        case modelNotInBundle
    }

    // MARK: - Write migrated data

    /// Inserts legacy categories/dittos into the context, merging into any existing profile.
    /// Returns the number of new dittos inserted (duplicates by `(category title, ditto text)`
    /// are skipped).
    @discardableResult
    private static func writeMigratedData(_ categories: [LegacyCategory], into context: ModelContext) -> Int {
        let profile: Profile
        let descriptor = FetchDescriptor<Profile>()
        if let existing = (try? context.fetch(descriptor))?.first {
            profile = existing
        } else {
            profile = Profile()
            context.insert(profile)
        }

        let existingByTitle = Dictionary(
            profile.orderedCategories.map { ($0.title, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var nextCategorySortOrder = profile.orderedCategories.count
        var newCategoryCount = 0
        var newDittoCount = 0
        var skippedDittoCount = 0

        for legacyCat in categories {
            let category: DittoCategory
            if let existing = existingByTitle[legacyCat.title] {
                category = existing
            } else {
                category = DittoCategory(title: legacyCat.title, profile: profile)
                category.sortOrder = nextCategorySortOrder
                nextCategorySortOrder += 1
                context.insert(category)
                profile.categories?.append(category)
                newCategoryCount += 1
            }

            let existingTexts = Set((category.dittos ?? []).map { $0.text })
            var nextDittoSortOrder = (category.dittos ?? []).count

            for legacyDitto in legacyCat.dittos {
                guard !existingTexts.contains(legacyDitto.text) else {
                    skippedDittoCount += 1
                    continue
                }
                let item = DittoItem(text: legacyDitto.text, category: category)
                item.sortOrder = nextDittoSortOrder
                item.useCount = legacyDitto.useCount
                nextDittoSortOrder += 1
                context.insert(item)
                category.dittos?.append(item)
                newDittoCount += 1
            }
        }

        log.info(
            // swiftlint:disable:next line_length
            "writeMigratedData: inserted \(newCategoryCount, privacy: .public) new categories, \(newDittoCount, privacy: .public) new dittos (skipped \(skippedDittoCount, privacy: .public) duplicates)"
        )
        return newDittoCount
    }

    private static func markComplete() {
        UserDefaults(suiteName: appGroupIdentifier)?.set(true, forKey: migrationCompleteKey)
    }
}
