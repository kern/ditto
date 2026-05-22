// swiftlint:disable file_length type_body_length
//
// This type concentrates discovery / read / write / telemetry for the v2 Core Data
// migration AND the orphan-WAL fallback in one place because they share state
// (App Group resolution, completion flag, logging category, outcome telemetry).
// Splitting them would force that state to be passed around or duplicated.

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

    /// Snapshot for the confirmation alert.
    struct RecoveryPreview {
        let categoryCount: Int
        let dittoCount: Int
        /// True when the only thing on disk is an orphaned WAL sidecar (no main
        /// `.sqlite`). Category structure is unrecoverable in this mode — items
        /// land in a single "Recovered" bucket — so the UI surfaces a different
        /// confirmation message.
        let isWALRecovery: Bool
    }

    /// Reads the legacy store (without mutating it) and returns how many categories /
    /// dittos would be imported. When the main `.sqlite` is missing but a `-wal`
    /// sidecar exists, falls back to a WAL-frame extraction preview. Returns nil if
    /// nothing is recoverable from either path.
    static func previewRecoverableData() -> RecoveryPreview? {
        if let url = legacyStoreURL,
           let legacy = try? readLegacyStore(at: url),
           !legacy.isEmpty {
            return RecoveryPreview(
                categoryCount: legacy.count,
                dittoCount: legacy.reduce(0) { $0 + $1.dittos.count },
                isWALRecovery: false
            )
        }
        if let walURL = findOrphanWAL() {
            let phrases = WALSidecarRecovery.extractPhrases(from: walURL)
            if !phrases.isEmpty {
                return RecoveryPreview(categoryCount: 1, dittoCount: phrases.count, isWALRecovery: true)
            }
        }
        return nil
    }

    /// Outcome of a manual recovery attempt. Surfaced in the UI so users see *why* nothing
    /// was recovered, rather than a silent "0 dittos imported".
    enum RecoveryResult {
        /// No SQLite candidate file exists anywhere we know to look.
        case nothingOnDisk
        /// A file exists but Core Data couldn't open or read it (corruption, file
        /// protection, schema mismatch). The `localizedDescription` is human-readable.
        case foundButUnreadable(String)
        /// The store opened cleanly but contained no Profile/Category data.
        case emptyStore
        /// Successful import. `inserted` is the number of *new* dittos added; duplicates
        /// already present in the SwiftData store were skipped.
        case inserted(Int)
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
            logOutcome(source: "auto", outcome: "nothing_on_disk")
            return false
        }

        return runMigration(at: storeURL, into: context, source: "auto", markCompleteOnEmpty: true)
    }

    /// Manually re-runs the migration from a user-tapped menu item. Ignores the completion
    /// flag. Never deletes the legacy store. Returns a structured result so the UI can
    /// distinguish "nothing on disk" from "file present but unreadable" from "successfully
    /// imported N dittos".
    ///
    /// If the main `.sqlite` is gone but a `-wal` sidecar survives, falls through to a raw
    /// WAL-frame extraction that pulls candidate phrases out of the journal directly.
    /// Category structure is lost in that mode — phrases land in a "Recovered" bucket.
    static func recoverNow(into context: ModelContext) -> RecoveryResult {
        guard let storeURL = legacyStoreURL else {
            if let walURL = findOrphanWAL() {
                return runWALSidecarRecovery(at: walURL, into: context)
            }
            log.info("recoverNow: no legacy store on disk")
            logOutcome(source: "manual", outcome: "nothing_on_disk")
            return .nothingOnDisk
        }

        let legacy: [LegacyCategory]
        do {
            legacy = try readLegacyStore(at: storeURL)
        } catch {
            log.error("recoverNow: read failed: \(error.localizedDescription, privacy: .public)")
            logOutcome(source: "manual", outcome: "found_unreadable")
            return .foundButUnreadable(error.localizedDescription)
        }

        guard !legacy.isEmpty else {
            log.info("recoverNow: legacy store opened but empty")
            logOutcome(source: "manual", outcome: "empty_store")
            return .emptyStore
        }

        let totalDittos = legacy.reduce(0) { $0 + $1.dittos.count }
        let beforeCount = (try? context.fetch(FetchDescriptor<DittoItem>()).count) ?? 0
        writeMigratedData(legacy, into: context)

        do {
            try context.save()
        } catch {
            log.error("recoverNow: save failed: \(error.localizedDescription, privacy: .public)")
            logOutcome(source: "manual", outcome: "found_unreadable")
            return .foundButUnreadable(error.localizedDescription)
        }

        markComplete()
        let afterCount = (try? context.fetch(FetchDescriptor<DittoItem>()).count) ?? 0
        let inserted = max(0, afterCount - beforeCount)
        log.info("recoverNow: inserted \(inserted, privacy: .public) new dittos")
        logOutcome(
            source: "manual",
            outcome: inserted > 0 ? "success" : "no_new_data",
            categoriesFound: legacy.count,
            dittosFound: totalDittos,
            inserted: inserted
        )
        return .inserted(inserted)
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
            logOutcome(source: source, outcome: "found_unreadable")
            return false
        }

        guard !legacy.isEmpty else {
            log.info("runMigration(\(source, privacy: .public)): legacy store opened but empty")
            if markCompleteOnEmpty { markComplete() }
            logOutcome(source: source, outcome: "empty_store")
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
            logOutcome(source: source, outcome: "found_unreadable")
            return false
        }

        markComplete()
        log.info("runMigration(\(source, privacy: .public)): inserted \(inserted, privacy: .public) new dittos")
        logOutcome(
            source: source,
            outcome: inserted > 0 ? "success" : "no_new_data",
            categoriesFound: legacy.count,
            dittosFound: totalDittos,
            inserted: inserted
        )
        return inserted > 0
    }

    /// Single-line, grep-friendly telemetry tag. Emitted at every terminal exit of an
    /// auto- or manual-migration attempt so a TestFlight sysdiagnose collection can be
    /// aggregated with a one-liner:
    ///
    ///     log show ... | grep migration_outcome
    ///
    /// All fields are `.public` (no user content — just counts and outcome codes).
    private static func logOutcome(
        source: String,
        outcome: String,
        categoriesFound: Int = 0,
        dittosFound: Int = 0,
        inserted: Int = 0
    ) {
        log.info(
            // swiftlint:disable:next line_length
            "migration_outcome source=\(source, privacy: .public) outcome=\(outcome, privacy: .public) categories=\(categoriesFound, privacy: .public) dittos=\(dittosFound, privacy: .public) inserted=\(inserted, privacy: .public)"
        )
    }

    // MARK: - Store discovery

    /// Returns the URL of the legacy 2.x Core Data store if one exists on disk.
    /// The 2.0.1 source put it at `<App Group container>/Ditto.sqlite`; we also probe
    /// other common pre-`NSPersistentContainer` locations and case variants as a safety net.
    private static var legacyStoreURL: URL? {
        let fm = FileManager.default

        // Walk the App Group container and the main app sandbox listing every file we
        // can see (with size and name), so support sysdiagnoses contain enough info to
        // tell whether the 3.0.0 cleanup actually deleted anything for this user — even
        // when it silently `try?`'d the error.
        logContainerInventory()

        let nameVariants = ["Ditto.sqlite", "ditto.sqlite", "Ditto.SQLite"]
        var candidates: [URL] = []

        if let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            for name in nameVariants {
                candidates.append(groupURL.appendingPathComponent(name))
                candidates.append(groupURL.appendingPathComponent("Library/Application Support/" + name))
                candidates.append(groupURL.appendingPathComponent("Library/Application Support/Ditto/" + name))
                candidates.append(groupURL.appendingPathComponent("Documents/" + name))
            }
        }
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            for name in nameVariants {
                candidates.append(appSupport.appendingPathComponent(name))
                candidates.append(appSupport.appendingPathComponent("Ditto/" + name))
            }
        }
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            for name in nameVariants {
                candidates.append(docs.appendingPathComponent(name))
            }
        }

        // Pick the largest matching file. The 3.0.0 cleanup may have left a zero-byte
        // truncated copy at one path while the real data lives at another; prefer the
        // one with content.
        let existing = candidates.filter { fm.fileExists(atPath: $0.path) }
        let chosen = existing.max { lhs, rhs in
            fileSize(at: lhs) < fileSize(at: rhs)
        }
        if let chosen {
            log.info("legacyStoreURL: matched \(chosen.path, privacy: .public) (\(fileSize(at: chosen), privacy: .public) bytes)")
        } else {
            log.info("legacyStoreURL: no legacy SQLite found at any candidate path")
            // Look for an orphan WAL/SHM — main .sqlite gone, but the sidecar survived.
            // We can't open it with the SQLite library alone (the WAL header's salt
            // values must match a main DB we don't have), but if this bucket is
            // non-empty in the TestFlight cohort it justifies writing a custom
            // WAL-frame extractor as a last-resort recovery path.
            if let walURL = findOrphanWALOrSHM() {
                // swiftlint:disable:next line_length
                log.info("legacyStoreURL: orphan WAL/SHM detected at \(walURL.path, privacy: .public) (\(fileSize(at: walURL), privacy: .public) bytes) — no main .sqlite alongside it")
                logOutcome(source: "discovery", outcome: "wal_orphan")
            }
        }
        return chosen
    }

    /// Returns the URL of a `.sqlite-wal` or `.sqlite-shm` file in the App Group
    /// container that has *no* matching main `.sqlite` alongside it — the situation
    /// where 3.0.0's cleanup removed the main DB but left a sidecar behind.
    private static func findOrphanWALOrSHM() -> URL? {
        let fm = FileManager.default
        guard let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return nil
        }
        let suffixes = ["-wal", "-shm"]
        let names = ["Ditto.sqlite", "ditto.sqlite", "Ditto.SQLite"]
        for base in names {
            for suffix in suffixes {
                let sidecar = groupURL.appendingPathComponent(base + suffix)
                guard fm.fileExists(atPath: sidecar.path) else { continue }
                let main = groupURL.appendingPathComponent(base)
                if !fm.fileExists(atPath: main.path) {
                    return sidecar
                }
            }
        }
        return nil
    }

    /// Returns the URL of a `.sqlite-wal` file that has no main `.sqlite` alongside it.
    /// Distinct from `findOrphanWALOrSHM` — that one's for diagnostic logging and accepts
    /// either sidecar; this one only returns `-wal`, the only file that actually carries
    /// page data we can extract from. SHM files contain just the WAL index and are useless
    /// without the WAL.
    private static func findOrphanWAL() -> URL? {
        let fm = FileManager.default
        guard let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return nil
        }
        let names = ["Ditto.sqlite", "ditto.sqlite", "Ditto.SQLite"]
        for base in names {
            let walURL = groupURL.appendingPathComponent(base + "-wal")
            guard fm.fileExists(atPath: walURL.path) else { continue }
            let main = groupURL.appendingPathComponent(base)
            if !fm.fileExists(atPath: main.path) {
                return walURL
            }
        }
        return nil
    }

    private static func fileSize(at url: URL) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }

    /// Walks the App Group container and every reachable corner of the main app's
    /// sandbox, logging every file and directory we can stat. Designed to answer the
    /// support question "do I have anything anywhere?" with a single sysdiagnose, even
    /// when the user has uninstalled / reinstalled / migrated between accounts and the
    /// expected paths come back empty.
    ///
    /// Includes hidden files (we don't skip them), empty directories (so you can tell
    /// whether iOS even gave us a writable Application Support), every search-path
    /// domain we can think of, and the keys (but never the values) stored in both
    /// `.standard` and the shared-suite UserDefaults.
    private static func logContainerInventory() {
        let fm = FileManager.default

        // 1) Resolve every search root we know how to ask iOS for, and log whether we
        //    actually got a URL back. If `appgroup` here logs "<unavailable>", the
        //    App Group entitlement isn't being honored on this build — most likely a
        //    signing-team mismatch — and there's no point looking further.
        struct Root {
            let label: String
            let url: URL?
        }
        var roots: [Root] = []
        roots.append(Root(label: "appgroup", url: fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)))
        let domains: [(String, FileManager.SearchPathDirectory)] = [
            ("documents", .documentDirectory),
            ("library", .libraryDirectory),
            ("appsupport", .applicationSupportDirectory),
            ("caches", .cachesDirectory)
        ]
        for (label, dir) in domains {
            roots.append(Root(label: label, url: fm.urls(for: dir, in: .userDomainMask).first))
        }
        // Sandbox root and tmp/ aren't in SearchPathDirectory; derive them from home.
        let sandboxRoot = URL(fileURLWithPath: NSHomeDirectory())
        roots.append(Root(label: "sandbox", url: sandboxRoot))
        roots.append(Root(label: "tmp", url: URL(fileURLWithPath: NSTemporaryDirectory())))

        for root in roots {
            if let url = root.url {
                log.info("inventory_root[\(root.label, privacy: .public)] \(url.path, privacy: .public)")
            } else {
                log.info("inventory_root[\(root.label, privacy: .public)] <unavailable>")
            }
        }

        // 2) Walk each root recursively. Log every file (with size) and every directory
        //    (with [dir] tag, so empty directories appear in the dump too).
        for root in roots {
            guard let rootURL = root.url else { continue }
            // Note the root itself first so the dump self-anchors.
            log.info("inventory[\(root.label, privacy: .public)] [root] \(rootURL.path, privacy: .public)")
            guard let enumerator = fm.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                // Don't skip hidden files; legacy stores or stray plists can be dotfiles.
                options: []
            ) else { continue }
            for case let url as URL in enumerator {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let relative = url.path.replacingOccurrences(of: rootURL.path, with: "")
                if isDir {
                    log.info("inventory[\(root.label, privacy: .public)] [dir] \(relative, privacy: .public)/")
                } else {
                    let size = fileSize(at: url)
                    log.info("inventory[\(root.label, privacy: .public)] \(size, privacy: .public)B \(relative, privacy: .public)")
                }
            }
        }

        // 3) Dump the keys (only — never the values) of both UserDefaults suites we
        //    know to look at. Tells us whether ANY legacy NSUserDefaults state
        //    survived, what type each value has, and how big each entry is.
        logDefaultsKeys(label: "appgroup_defaults", defaults: UserDefaults(suiteName: appGroupIdentifier))
        logDefaultsKeys(label: "standard_defaults", defaults: .standard)
    }

    private static func logDefaultsKeys(label: String, defaults: UserDefaults?) {
        guard let defaults else {
            log.info("\(label, privacy: .public): <unavailable>")
            return
        }
        let snapshot = defaults.dictionaryRepresentation()
        if snapshot.isEmpty {
            log.info("\(label, privacy: .public): <empty>")
            return
        }
        for key in snapshot.keys.sorted() {
            let value = snapshot[key]
            let typeName = value.map { String(describing: type(of: $0)) } ?? "nil"
            let count: Int
            switch value {
            case let s as String: count = s.count
            case let a as [Any]: count = a.count
            case let d as [AnyHashable: Any]: count = d.count
            case let d as Data: count = d.count
            default: count = 0
            }
            log.info("\(label, privacy: .public) key=\(key, privacy: .public) type=\(typeName, privacy: .public) size=\(count, privacy: .public)")
        }
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

    // MARK: - WAL sidecar recovery

    /// Title of the bucket category created when WAL-frame recovery succeeds. Surfaced
    /// to the user in the confirmation alert so they know where to look.
    static let walRecoveryCategoryTitle = "Recovered"

    /// Manual recovery from an orphaned `-wal` file. Pulls text out of WAL frame
    /// payloads directly via `WALSidecarRecovery`, then writes the phrases into a
    /// single `walRecoveryCategoryTitle` bucket since category structure is unrecoverable.
    private static func runWALSidecarRecovery(at walURL: URL, into context: ModelContext) -> RecoveryResult {
        log.info("runWALSidecarRecovery: parsing \(walURL.path, privacy: .public) (\(fileSize(at: walURL), privacy: .public) bytes)")
        let phrases = WALSidecarRecovery.extractPhrases(from: walURL)
        guard !phrases.isEmpty else {
            log.info("runWALSidecarRecovery: WAL parsed but yielded no recoverable phrases")
            logOutcome(source: "manual_wal", outcome: "empty_store")
            return .emptyStore
        }

        let beforeCount = (try? context.fetch(FetchDescriptor<DittoItem>()).count) ?? 0
        writeWALPhrases(phrases, into: context)

        do {
            try context.save()
        } catch {
            log.error("runWALSidecarRecovery: save failed: \(error.localizedDescription, privacy: .public)")
            logOutcome(source: "manual_wal", outcome: "found_unreadable")
            return .foundButUnreadable(error.localizedDescription)
        }

        markComplete()
        let afterCount = (try? context.fetch(FetchDescriptor<DittoItem>()).count) ?? 0
        let inserted = max(0, afterCount - beforeCount)
        log.info("runWALSidecarRecovery: inserted \(inserted, privacy: .public) phrases from WAL")
        logOutcome(
            source: "manual_wal",
            outcome: inserted > 0 ? "success" : "no_new_data",
            categoriesFound: 1,
            dittosFound: phrases.count,
            inserted: inserted
        )
        return .inserted(inserted)
    }

    /// Inserts WAL-extracted phrases into a single "Recovered" category, deduplicating
    /// against anything already in that category.
    @discardableResult
    private static func writeWALPhrases(_ phrases: [String], into context: ModelContext) -> Int {
        let profile: Profile
        if let existing = (try? context.fetch(FetchDescriptor<Profile>()))?.first {
            profile = existing
        } else {
            profile = Profile()
            context.insert(profile)
        }

        let existingByTitle = Dictionary(
            profile.orderedCategories.map { ($0.title, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let category: DittoCategory
        if let existing = existingByTitle[walRecoveryCategoryTitle] {
            category = existing
        } else {
            category = DittoCategory(title: walRecoveryCategoryTitle, profile: profile)
            category.sortOrder = profile.orderedCategories.count
            context.insert(category)
            profile.categories?.append(category)
        }

        let existingTexts = Set((category.dittos ?? []).map { $0.text })
        var nextSort = (category.dittos ?? []).count
        var inserted = 0
        for phrase in phrases {
            guard !existingTexts.contains(phrase) else { continue }
            let item = DittoItem(text: phrase, category: category)
            item.sortOrder = nextSort
            nextSort += 1
            context.insert(item)
            category.dittos?.append(item)
            inserted += 1
        }
        log.info("writeWALPhrases: inserted \(inserted, privacy: .public) phrases into '\(walRecoveryCategoryTitle, privacy: .public)'")
        return inserted
    }
}
