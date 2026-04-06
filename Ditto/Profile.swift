import Foundation
import SwiftData

@Model
final class Profile {
    @Relationship(deleteRule: .cascade, inverse: \DittoCategory.profile)
    var categories: [DittoCategory] = []

    /// Maintains the user-defined ordering of categories
    var categoryOrder: [PersistentIdentifier] = []

    init() {}

    var orderedCategories: [DittoCategory] {
        let orderMap = Dictionary(uniqueKeysWithValues: categoryOrder.enumerated().map { ($1, $0) })
        return categories.sorted { a, b in
            let indexA = orderMap[a.persistentModelID] ?? Int.max
            let indexB = orderMap[b.persistentModelID] ?? Int.max
            return indexA < indexB
        }
    }

    func appendCategoryToOrder(_ category: DittoCategory) {
        if !categoryOrder.contains(category.persistentModelID) {
            categoryOrder.append(category.persistentModelID)
        }
    }

    func removeCategoryFromOrder(_ category: DittoCategory) {
        categoryOrder.removeAll { $0 == category.persistentModelID }
    }

    func moveCategoryOrder(fromIndex: Int, toIndex: Int) {
        guard fromIndex != toIndex,
              fromIndex >= 0, fromIndex < categoryOrder.count,
              toIndex >= 0, toIndex < categoryOrder.count else { return }
        let id = categoryOrder.remove(at: fromIndex)
        categoryOrder.insert(id, at: toIndex)
    }
}
