import Foundation
import CoreData

@objc(Ditto)
class Ditto: NSManagedObject {

    @NSManaged var text: String
    @NSManaged var use_count: NSNumber
    @NSManaged var category: Category

}