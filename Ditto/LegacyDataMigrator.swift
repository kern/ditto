import Foundation
import SwiftData

/// Migrates data from the legacy NSUserDefaults-backed store (v1/v2) to the new SwiftData store.
///
/// The pre-3.0 app persisted user content directly in NSUserDefaults under two keys:
/// - "categories": `[String]` — ordered list of category titles
/// - "dittos": `[String: [String]]` — category title → ordered list of ditto texts
///
/// Some installs wrote to the shared App Group suite (once the keyboard extension shipped),
/// while earlier installs wrote to `UserDefaults.standard`. We check both, prefer whichever
/// has data, and merge if both are populated.
///
/// IMPORTANT: We deliberately do NOT delete the legacy keys from NSUserDefaults after a
/// successful migration. Keeping the source data intact lets users roll back to an older
/// build (or re-run the migration) without data loss.
@available(iOS, deprecated: 18.0, message: "Remove once all users have migrated from NSUserDefaults (target: v4.0)")
enum LegacyDataMigrator {

    private static let appGroupIdentifier = "group.io.kern.ditto"
    private static let migrationCompleteKey = "legacyUserDefaultsMigrationComplete"

    private static let legacyCategoriesKey = "categories"
    private static let legacyDittosKey = "dittos"

    /// Returns true if legacy NSUserDefaults content exists and hasn't been migrated yet.
    static var needsMigration: Bool {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return false }
        if defaults.bool(forKey: migrationCompleteKey) { return false }
        return !readLegacyCategories().isEmpty
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
            markComplete()
            return false
        }

        writeMigratedData(legacyCategories, into: context)

        do {
            try context.save()
        } catch {
            print("Legacy data migration save failed: \(error)")
            return false
        }

        markComplete()
        return true
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
        return merged
    }

    private static func readLegacyCategories(from defaults: UserDefaults?) -> [LegacyCategory] {
        guard let defaults else { return [] }
        guard let titles = defaults.array(forKey: legacyCategoriesKey) as? [String],
              !titles.isEmpty else { return [] }
        let dittosByTitle = defaults.dictionary(forKey: legacyDittosKey) as? [String: [String]] ?? [:]

        return titles.map { title in
            LegacyCategory(title: title, dittos: dittosByTitle[title] ?? [])
        }
    }

    // MARK: - Write Migrated Data

    private static func writeMigratedData(_ categories: [LegacyCategory], into context: ModelContext) {
        // Reuse an existing Profile if one was already created (e.g. by a previous
        // partial run); otherwise create a new one.
        let profile: Profile
        let descriptor = FetchDescriptor<Profile>()
        if let existing = (try? context.fetch(descriptor))?.first {
            profile = existing
        } else {
            profile = Profile()
            context.insert(profile)
        }

        // Track titles already in the profile so we don't duplicate preset categories.
        let existingByTitle = Dictionary(
            profile.orderedCategories.map { ($0.title, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var nextCategorySortOrder = profile.orderedCategories.count

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
            }

            let existingTexts = Set((category.dittos ?? []).map { $0.text })
            var nextDittoSortOrder = (category.dittos ?? []).count

            for text in legacyCat.dittos where !existingTexts.contains(text) {
                let item = DittoItem(text: text, category: category)
                item.sortOrder = nextDittoSortOrder
                nextDittoSortOrder += 1
                context.insert(item)
                category.dittos?.append(item)
            }
        }
    }

    // MARK: - Cleanup

    /// Records that migration finished. The legacy NSUserDefaults entries are intentionally
    /// left in place so the source data is preserved.
    private static func markComplete() {
        UserDefaults(suiteName: appGroupIdentifier)?.set(true, forKey: migrationCompleteKey)
    }
}
