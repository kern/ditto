import Foundation
import SwiftData

/// Central data store managing all Ditto persistence via SwiftData.
/// Uses a shared App Group container so the keyboard extension can access the same data.
@Observable
final class DittoStore {

    static let maxCategories = 8
    static let appGroupIdentifier = "group.io.kern.ditto"

    let modelContainer: ModelContainer
    let modelContext: ModelContext

    static let presetCategories = ["Instructions", "Driving", "Business", "Dating"]
    static let presetDittos: [String: [String]] = [
        "Instructions": [
            "Welcome to Ditto!",
            "Use the Ditto app to customize your dittos.",
            "Add a triple underscore ___ to your ditto to control where your cursor lands.",
            "You can expand long dittos within the keyboard by holding them down.",
            "Hold down a keyboard tab to expand the category title, and swipe on the tab bar for quick access."
        ],
        "Driving": [
            "I'm driving, can you call me?",
            "I'll be there in ___ minutes!",
            "What's the address?",
            "Can't text, I'm driving"
        ],
        "Business": [
            // swiftlint:disable:next line_length
            "Hi ___,\n\nIt was great meeting you today. I'd love to chat in more detail about possible business opportunities. Please let me know your availability.\n\nBest",
            // swiftlint:disable:next line_length
            "My name is ___, and I work at ___. We are always looking for talented candidates to join our team. Please let me know if you are interested."
        ],
        "Dating": [
            "I'm not a photographer, but I can picture us together.",
            "Do you have a Band-Aid? Because I just scraped my knee falling for you."
        ]
    ]

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        ensureProfileExists()
    }

    /// Convenience initializer for production use with the shared App Group container.
    convenience init() {
        let schema = Schema([Profile.self, DittoCategory.self, DittoItem.self])
        let config: ModelConfiguration
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: DittoStore.appGroupIdentifier) {
            let storeURL = groupURL.appendingPathComponent("Ditto.store")
            config = ModelConfiguration("Ditto", schema: schema, url: storeURL)
        } else {
            config = ModelConfiguration("Ditto", schema: schema)
        }

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            self.init(modelContainer: container)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    // MARK: - Profile

    func getProfile() -> Profile {
        let descriptor = FetchDescriptor<Profile>()
        let profiles = (try? modelContext.fetch(descriptor)) ?? []
        if let profile = profiles.first {
            return profile
        }
        return createProfile()
    }

    private func ensureProfileExists() {
        let descriptor = FetchDescriptor<Profile>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        if count == 0 {
            _ = createProfile()
        }
    }

    @discardableResult
    private func createProfile() -> Profile {
        let profile = Profile()
        modelContext.insert(profile)

        for (categoryIndex, categoryName) in Self.presetCategories.enumerated() {
            let category = DittoCategory(title: categoryName, profile: profile)
            category.sortOrder = categoryIndex
            modelContext.insert(category)
            profile.categories.append(category)

            for (dittoIndex, dittoText) in (Self.presetDittos[categoryName] ?? []).enumerated() {
                let ditto = DittoItem(text: dittoText, category: category)
                ditto.sortOrder = dittoIndex
                modelContext.insert(ditto)
                category.dittos.append(ditto)
            }
        }

        // Migrate pending dittos from UserDefaults (V1 compatibility)
        migratePendingDittos(profile: profile)

        save()
        return profile
    }

    // MARK: - Categories

    var categories: [DittoCategory] {
        getProfile().orderedCategories
    }

    var categoryCount: Int {
        getProfile().orderedCategories.count
    }

    var canCreateNewCategory: Bool {
        categoryCount < Self.maxCategories
    }

    var isEmpty: Bool {
        categoryCount == 0
    }

    func category(at index: Int) -> DittoCategory {
        getProfile().orderedCategories[index]
    }

    func addCategory(title: String) {
        let profile = getProfile()
        let category = DittoCategory(title: title, profile: profile)
        category.sortOrder = profile.categories.count
        modelContext.insert(category)
        profile.categories.append(category)
        save()
    }

    func removeCategory(at index: Int) {
        let profile = getProfile()
        let ordered = profile.orderedCategories
        let category = ordered[index]
        modelContext.delete(category)
        save()
        // Reindex remaining categories
        reindexCategories()
    }

    func moveCategory(fromIndex: Int, toIndex: Int) {
        let profile = getProfile()
        var ordered = profile.orderedCategories
        guard fromIndex != toIndex,
              fromIndex >= 0, fromIndex < ordered.count,
              toIndex >= 0, toIndex < ordered.count else { return }
        let moved = ordered.remove(at: fromIndex)
        ordered.insert(moved, at: toIndex)
        for (i, cat) in ordered.enumerated() {
            cat.sortOrder = i
        }
        save()
    }

    func updateCategory(at index: Int, title: String) {
        let category = category(at: index)
        category.title = title
        save()
    }

    // MARK: - Dittos

    func dittos(inCategoryAt index: Int) -> [DittoItem] {
        category(at: index).orderedDittos
    }

    func ditto(inCategoryAt categoryIndex: Int, at dittoIndex: Int) -> DittoItem {
        category(at: categoryIndex).orderedDittos[dittoIndex]
    }

    func dittoCount(inCategoryAt index: Int) -> Int {
        category(at: index).orderedDittos.count
    }

    func addDitto(text: String, toCategoryAt index: Int) {
        let cat = category(at: index)
        let ditto = DittoItem(text: text, category: cat)
        ditto.sortOrder = cat.dittos.count
        modelContext.insert(ditto)
        cat.dittos.append(ditto)
        save()
    }

    func removeDitto(inCategoryAt categoryIndex: Int, at dittoIndex: Int) {
        let cat = category(at: categoryIndex)
        let item = cat.orderedDittos[dittoIndex]
        modelContext.delete(item)
        save()
        // Reindex remaining dittos
        reindexDittos(in: cat)
    }

    func updateDitto(inCategoryAt categoryIndex: Int, at dittoIndex: Int, text: String) {
        let item = ditto(inCategoryAt: categoryIndex, at: dittoIndex)
        item.text = text
        save()
    }

    func moveDitto(fromCategory: Int, fromIndex: Int, toCategory: Int, toIndex: Int) {
        let srcCat = category(at: fromCategory)
        let item = srcCat.orderedDittos[fromIndex]

        if fromCategory == toCategory {
            var ordered = srcCat.orderedDittos
            ordered.remove(at: fromIndex)
            ordered.insert(item, at: toIndex)
            for (i, d) in ordered.enumerated() {
                d.sortOrder = i
            }
        } else {
            let dstCat = category(at: toCategory)
            item.category = dstCat
            dstCat.dittos.append(item)

            // Reindex source
            reindexDittos(in: srcCat)

            // Insert at position in destination
            var dstOrdered = dstCat.orderedDittos
            // Remove then insert to get correct position
            dstOrdered.removeAll { $0 === item }
            if toIndex < dstOrdered.count {
                dstOrdered.insert(item, at: toIndex)
            } else {
                dstOrdered.append(item)
            }
            for (i, d) in dstOrdered.enumerated() {
                d.sortOrder = i
            }
        }
        save()
    }

    func moveDitto(fromCategory: Int, fromIndex: Int, toCategory: Int) {
        let count = dittoCount(inCategoryAt: toCategory)
        moveDitto(fromCategory: fromCategory, fromIndex: fromIndex, toCategory: toCategory, toIndex: count)
    }

    // MARK: - Reindexing

    private func reindexCategories() {
        let profile = getProfile()
        for (i, cat) in profile.orderedCategories.enumerated() {
            cat.sortOrder = i
        }
    }

    private func reindexDittos(in category: DittoCategory) {
        for (i, ditto) in category.orderedDittos.enumerated() {
            ditto.sortOrder = i
        }
    }

    // MARK: - Persistence

    func save() {
        do {
            try modelContext.save()
        } catch {
            print("DittoStore save error: \(error)")
        }
    }

    // MARK: - Pending Dittos Migration

    private func migratePendingDittos(profile: Profile) {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) else { return }
        defaults.synchronize()

        guard let pendingDittos = defaults.dictionary(forKey: "pendingDittos") as? [String: [String]],
              let pendingCategories = defaults.array(forKey: "pendingCategories") as? [String] else { return }

        let orderedCats = profile.orderedCategories
        for cat in orderedCats {
            if pendingCategories.contains(cat.title),
               let texts = pendingDittos[cat.title] {
                for text in texts {
                    let ditto = DittoItem(text: text, category: cat)
                    ditto.sortOrder = cat.dittos.count
                    modelContext.insert(ditto)
                    cat.dittos.append(ditto)
                }
            }
        }

        defaults.removeObject(forKey: "pendingDittos")
        defaults.removeObject(forKey: "pendingCategories")
        defaults.synchronize()
    }

    func loadPendingDittos() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) else { return }
        defaults.synchronize()

        guard let pendingDittos = defaults.dictionary(forKey: "pendingDittos") as? [String: [String]],
              defaults.array(forKey: "pendingCategories") is [String] else { return }

        let cats = categories
        for cat in cats {
            if let texts = pendingDittos[cat.title] {
                for text in texts {
                    let ditto = DittoItem(text: text, category: cat)
                    ditto.sortOrder = cat.dittos.count
                    modelContext.insert(ditto)
                    cat.dittos.append(ditto)
                }
            }
        }

        defaults.removeObject(forKey: "pendingDittos")
        defaults.removeObject(forKey: "pendingCategories")
        defaults.synchronize()
        save()
    }
}
