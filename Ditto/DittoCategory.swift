import Foundation
import SwiftData

@Model
final class DittoCategory {
    var title: String = ""
    var sortOrder: Int = 0

    var profile: Profile?

    @Relationship(deleteRule: .cascade, inverse: \DittoItem.category)
    var dittos: [DittoItem] = []

    init(title: String, profile: Profile? = nil) {
        self.title = title
        self.profile = profile
    }

    var orderedDittos: [DittoItem] {
        dittos.sorted { $0.sortOrder < $1.sortOrder }
    }
}
