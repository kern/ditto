import Foundation
import SwiftData

@Model
final class Profile {
    @Relationship(deleteRule: .cascade, inverse: \DittoCategory.profile)
    var categories: [DittoCategory]?

    init() {
        self.categories = []
    }

    var orderedCategories: [DittoCategory] {
        (categories ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }
}
