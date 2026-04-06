import Foundation
import SwiftData

@Model
final class DittoCategory {
    var title: String = ""
    var sortOrder: Int = 0
    var modifiedAt: Date = Date()

    var profile: Profile?

    @Relationship(deleteRule: .cascade, inverse: \DittoItem.category)
    var dittos: [DittoItem]?

    init(title: String, profile: Profile? = nil) {
        self.title = title
        self.profile = profile
        self.dittos = []
    }

    var orderedDittos: [DittoItem] {
        (dittos ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }
}
