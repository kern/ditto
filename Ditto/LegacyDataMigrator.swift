import Foundation
import OSLog
import SwiftData

/// Migrates data from the legacy NSUserDefaults-backed store (v2) to the new SwiftData store.
///
/// The pre-3.0 (v2) app stored user content in NSUserDefaults under these keys:
/// - "dittos" — the dittos themselves, in one of three shapes:
///     - `[String]` — flat ordered list of dittos with no categories
///       (this is the only shape committed to git — see the v1 tag's `Ditto/DittoStore.swift`)
///     - `[String: [String]]` — category title → ordered ditto texts (when "categories" is also present)
///     - `[[String]]` — array of ditto lists parallel to "categories"
/// - "categories" — `[String]` ordered list of category titles, present only in
///   the categorized variants above.
///
/// Some installs wrote to the shared App Group suite (once the keyboard extension shipped),
/// while earlier installs wrote to `UserDefaults.standard`. We check both and merge by title.
///
/// IMPORTANT: We deliberately do NOT delete the legacy keys from NSUserDefaults after a
/// successful migration. Keeping the source data intact lets users roll back to an older
/// build (or re-run the migration) without data loss, and powers the manual
/// "Recover Old Dittos" menu item for users who upgraded before the migrator handled
/// their on-disk format.
@available(iOS, deprecated: 18.0, message: "Remove once all users have migrated from NSUserDefaults (target: v4.0)")
enum LegacyDataMigrator {

    /// Default category title used when migrating the flat `[String]` shape (v1/2.0),
    /// which had no concept of categories.
    static let flatRecoveryCategoryTitle = "Imported"

    private static let appGroupIdentifier = "group.io.kern.ditto"
    private static let migrationCompleteKey = "legacyUserDefaultsMigrationComplete"

    private static let legacyCategoriesKey = "categories"
    private static let legacyDittosKey = "dittos"

    private static let log = Logger(subsystem: "io.kern.ditto", category: "LegacyDataMigrator")

    /// Returns true if legacy NSUserDefaults content exists and hasn't been migrated yet.
    /// Used by automatic on-launch migration in DittoApp.
    static var needsMigration: Bool {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            log.debug("needsMigration: App Group defaults unavailable, assuming no migration needed")
            return false
        }
        if defaults.bool(forKey: migrationCompleteKey) {
            log.debug("needsMigration: completion flag is set, skipping")
            return false
        }
        let legacy = readLegacyCategories()
        log.debug("needsMigration: found \(legacy.count, privacy: .public) legacy categories")
        return !legacy.isEmpty
    }

    /// Returns true if legacy NSUserDefaults content is still present, *regardless* of the
    /// completion flag. Powers the manual "Recover Old Dittos" menu item so users who
    /// upgraded before the migrator handled their on-disk format can still recover.
    static var hasRecoverableLegacyData: Bool {
        !readLegacyCategories().isEmpty
    }

    /// Snapshot of what is available to recover, for confirmation UI.
    struct RecoveryPreview {
        let categoryCount: Int
        let dittoCount: Int
    }

    /// Returns a summary of legacy data that would be imported on recovery, or nil if nothing.
    static func previewRecoverableData() -> RecoveryPreview? {
        let legacy = readLegacyCategories()
        guard !legacy.isEmpty else { return nil }
        return RecoveryPreview(
            categoryCount: legacy.count,
            dittoCount: legacy.reduce(0) { $0 + $1.dittos.count }
        )
    }

    // MARK: - Migration

    /// Migrates legacy NSUserDefaults content into the given SwiftData model context.
    /// Returns `true` if data was migrated, `false` if no legacy data was found.
    ///
    /// The legacy NSUserDefaults entries are preserved (not deleted) so the source data
    /// remains available for rollback or repeated migration runs.
    @discardableResult
    static func migrateIfNeeded(into context: ModelContext) -> Bool {
        let legacyCategories = readLegacyCategories()
        guard !legacyCategories.isEmpty else {
            log.info("migrateIfNeeded: no legacy data found, marking complete")
            markComplete()
            return false
        }

        let totalDittos = legacyCategories.reduce(0) { $0 + $1.dittos.count }
        log.info(
            "migrateIfNeeded: starting migration of \(legacyCategories.count, privacy: .public) categories, \(totalDittos, privacy: .public) dittos"
        )

        let inserted = writeMigratedData(legacyCategories, into: context)

        do {
            try context.save()
        } catch {
            log.error("migrateIfNeeded: save failed: \(error.localizedDescription, privacy: .public)")
            return false
        }

        log.info("migrateIfNeeded: migration succeeded, marking complete")
        markComplete()
        return inserted > 0
    }

    /// Manually re-run the migration, ignoring the completion flag. Used by the
    /// "Recover Old Dittos" menu item. Returns the number of dittos newly inserted
    /// (duplicates already in the SwiftData store are skipped).
    @discardableResult
    static func recoverNow(into context: ModelContext) -> Int {
        let legacyCategories = readLegacyCategories()
        guard !legacyCategories.isEmpty else {
            log.info("recoverNow: no legacy data to recover")
            return 0
        }

        log.info("recoverNow: attempting manual recovery of \(legacyCategories.count, privacy: .public) categories")
        let inserted = writeMigratedData(legacyCategories, into: context)

        do {
            try context.save()
        } catch {
            log.error("recoverNow: save failed: \(error.localizedDescription, privacy: .public)")
            return 0
        }

        markComplete()
        log.info("recoverNow: recovered \(inserted, privacy: .public) new dittos")
        return inserted
    }

    // MARK: - Read Legacy Store

    private struct LegacyCategory {
        let title: String
        let dittos: [String]
    }

    /// Reads ordered legacy categories from both the App Group suite and standard defaults,
    /// merging duplicates by title (App Group takes precedence; standard contributes any
    /// categories or trailing dittos missing from the group store).
    private static func readLegacyCategories() -> [LegacyCategory] {
        let groupCategories = readLegacyCategories(from: UserDefaults(suiteName: appGroupIdentifier))
        let standardCategories = readLegacyCategories(from: .standard)

        log.debug(
            "readLegacyCategories: app-group=\(groupCategories.count, privacy: .public), standard=\(standardCategories.count, privacy: .public)"
        )

        if standardCategories.isEmpty { return groupCategories }
        if groupCategories.isEmpty { return standardCategories }

        // Merge: keep order from group, then append any group-missing categories from standard.
        // For shared categories, union the ditto lists while preserving group order.
        var titleToIndex: [String: Int] = [:]
        var merged: [LegacyCategory] = []
        for cat in groupCategories {
            titleToIndex[cat.title] = merged.count
            merged.append(cat)
        }
        for cat in standardCategories {
            if let idx = titleToIndex[cat.title] {
                var combined = merged[idx].dittos
                for text in cat.dittos where !combined.contains(text) {
                    combined.append(text)
                }
                merged[idx] = LegacyCategory(title: merged[idx].title, dittos: combined)
            } else {
                titleToIndex[cat.title] = merged.count
                merged.append(cat)
            }
        }
        log.debug("readLegacyCategories: merged to \(merged.count, privacy: .public) unique categories")
        return merged
    }

    private static func readLegacyCategories(from defaults: UserDefaults?) -> [LegacyCategory] {
        guard let defaults else { return [] }

        let titlesAny = defaults.object(forKey: legacyCategoriesKey)
        let dittosAny = defaults.object(forKey: legacyDittosKey)

        // v2 categorized format: "categories" = [String], "dittos" = [String: [String]].
        if let titles = titlesAny as? [String], !titles.isEmpty,
           let dittosByTitle = dittosAny as? [String: [String]] {
            log.debug("readLegacyCategories: matched v2 dict-by-title format")
            return titles.map { LegacyCategory(title: $0, dittos: dittosByTitle[$0] ?? []) }
        }

        // v2 parallel-array variant: "categories" = [String], "dittos" = [[String]].
        if let titles = titlesAny as? [String], !titles.isEmpty,
           let dittosArrays = dittosAny as? [[String]] {
            log.debug("readLegacyCategories: matched v2 parallel-array format")
            return zip(titles, dittosArrays).map { LegacyCategory(title: $0, dittos: $1) }
        }

        // Flat format (v1 and 2.0 builds before categories existed):
        // "dittos" = [String], no "categories" key.
        if let flat = dittosAny as? [String], !flat.isEmpty {
            log.debug("readLegacyCategories: matched flat-array format (\(flat.count, privacy: .public) items)")
            return [LegacyCategory(title: flatRecoveryCategoryTitle, dittos: flat)]
        }

        if titlesAny != nil || dittosAny != nil {
            log.error(
                // swiftlint:disable:next line_length
                "readLegacyCategories: legacy keys present but format not recognized — categoriesType=\(String(describing: type(of: titlesAny)), privacy: .public), dittosType=\(String(describing: type(of: dittosAny)), privacy: .public)"
            )
        }

        return []
    }

    // MARK: - Write Migrated Data

    /// Inserts legacy categories/dittos into the context, merging into any existing profile.
    /// Returns the number of new dittos inserted (duplicates skipped).
    @discardableResult
    private static func writeMigratedData(_ categories: [LegacyCategory], into context: ModelContext) -> Int {
        // Reuse an existing Profile if one was already created (e.g. by a previous
        // partial run); otherwise create a new one.
        let profile: Profile
        let descriptor = FetchDescriptor<Profile>()
        if let existing = (try? context.fetch(descriptor))?.first {
            log.debug("writeMigratedData: merging into existing profile")
            profile = existing
        } else {
            log.debug("writeMigratedData: creating new profile")
            profile = Profile()
            context.insert(profile)
        }

        // Track titles already in the profile so we don't duplicate preset categories.
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

            for text in legacyCat.dittos {
                guard !existingTexts.contains(text) else {
                    skippedDittoCount += 1
                    continue
                }
                let item = DittoItem(text: text, category: category)
                item.sortOrder = nextDittoSortOrder
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

    // MARK: - Cleanup

    /// Records that migration finished. The legacy NSUserDefaults entries are intentionally
    /// left in place so the source data is preserved.
    private static func markComplete() {
        UserDefaults(suiteName: appGroupIdentifier)?.set(true, forKey: migrationCompleteKey)
    }
}
