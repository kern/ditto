import Foundation
import CoreData

@objc(Category)
class Category: NSManagedObject {

    @NSManaged var title: String
    @NSManaged var dittos: NSOrderedSet
    @NSManaged var profile: Profile

}