import Foundation
import CoreData

@objc(Profile)
class Profile: NSManagedObject {
    
    @NSManaged var categories: NSOrderedSet
    
}