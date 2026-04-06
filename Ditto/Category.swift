import Foundation
import SwiftData

@Model
final class DittoCategory {
    var title: String = ""

    var profile: Profile?

    @Relationship(deleteRule: .cascade, inverse: \DittoItem.category)
    var dittos: [DittoItem] = []

    /// Maintains the user-defined ordering of dittos
    var dittoOrder: [PersistentIdentifier] = []

    init(title: String, profile: Profile? = nil) {
        self.title = title
        self.profile = profile
    }

    var orderedDittos: [DittoItem] {
        let orderMap = Dictionary(uniqueKeysWithValues: dittoOrder.enumerated().map { ($1, $0) })
        return dittos.sorted { a, b in
            let indexA = orderMap[a.persistentModelID] ?? Int.max
            let indexB = orderMap[b.persistentModelID] ?? Int.max
            return indexA < indexB
        }
    }

    func appendDittoToOrder(_ ditto: DittoItem) {
        if !dittoOrder.contains(ditto.persistentModelID) {
            dittoOrder.append(ditto.persistentModelID)
        }
    }

    func removeDittoFromOrder(_ ditto: DittoItem) {
        dittoOrder.removeAll { $0 == ditto.persistentModelID }
    }

    func moveDittoOrder(fromIndex: Int, toIndex: Int) {
        guard fromIndex != toIndex,
              fromIndex >= 0, fromIndex < dittoOrder.count,
              toIndex >= 0, toIndex < dittoOrder.count else { return }
        let id = dittoOrder.remove(at: fromIndex)
        dittoOrder.insert(id, at: toIndex)
    }
}
