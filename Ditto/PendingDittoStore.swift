import Foundation

/// Lightweight store used by the keyboard extension to read dittos and queue pending additions.
/// Uses UserDefaults with the shared App Group since extensions have limited SwiftData access.
final class PendingDittoStore {

    static let appGroupIdentifier = "group.io.kern.ditto"

    private let dittoStore: DittoStore
    private let defaults: UserDefaults

    init(dittoStore: DittoStore? = nil) {
        self.dittoStore = dittoStore ?? DittoStore()
        self.defaults = UserDefaults(suiteName: Self.appGroupIdentifier) ?? .standard
    }

    // MARK: - Read Access (delegates to DittoStore)

    var categories: [DittoCategory] {
        dittoStore.categories
    }

    var categoryCount: Int {
        dittoStore.categoryCount
    }

    var isEmpty: Bool {
        dittoStore.isEmpty
    }

    var hasOneCategory: Bool {
        categoryCount == 1
    }

    func category(at index: Int) -> DittoCategory {
        dittoStore.category(at: index)
    }

    func categoryTitle(at index: Int) -> String {
        category(at: index).title
    }

    func dittos(inCategoryAt index: Int) -> [DittoItem] {
        var items = dittoStore.dittos(inCategoryAt: index)
        let categoryTitle = categoryTitle(at: index)

        // Append any pending dittos from UserDefaults
        if let pending = pendingDittos(for: categoryTitle) {
            let pendingItems = pending.map { DittoItem(text: $0) }
            items.append(contentsOf: pendingItems)
        }
        return items
    }

    func dittoCount(inCategoryAt index: Int) -> Int {
        var count = dittoStore.dittoCount(inCategoryAt: index)
        let categoryTitle = categoryTitle(at: index)

        if let pending = pendingDittos(for: categoryTitle) {
            count += pending.count
        }
        return count
    }

    func ditto(inCategoryAt categoryIndex: Int, at dittoIndex: Int) -> DittoItem {
        let allDittos = dittos(inCategoryAt: categoryIndex)
        return allDittos[dittoIndex]
    }

    func dittoPreview(inCategoryAt categoryIndex: Int, at dittoIndex: Int) -> String {
        ditto(inCategoryAt: categoryIndex, at: dittoIndex).preview
    }

    // MARK: - Write (queues to UserDefaults for main app to pick up)

    func addDitto(text: String, toCategoryAt index: Int) {
        defaults.synchronize()
        let categoryTitle = categoryTitle(at: index)

        var allPending = defaults.dictionary(forKey: "pendingDittos") as? [String: [String]] ?? [:]
        var pendingCats = defaults.array(forKey: "pendingCategories") as? [String] ?? []

        if var dittos = allPending[categoryTitle] {
            dittos.append(text)
            allPending[categoryTitle] = dittos
        } else {
            pendingCats.append(categoryTitle)
            allPending[categoryTitle] = [text]
        }

        defaults.set(pendingCats, forKey: "pendingCategories")
        defaults.set(allPending, forKey: "pendingDittos")
        defaults.synchronize()
    }

    // MARK: - Helpers

    private func pendingDittos(for categoryTitle: String) -> [String]? {
        defaults.synchronize()
        guard let allPending = defaults.dictionary(forKey: "pendingDittos") as? [String: [String]],
              let pendingCats = defaults.array(forKey: "pendingCategories") as? [String],
              pendingCats.contains(categoryTitle) else { return nil }
        return allPending[categoryTitle]
    }
}
