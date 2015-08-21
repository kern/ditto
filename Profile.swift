import Foundation
import CoreData

@objc(Profile)
class Profile: NSManagedObject {
    
    @NSManaged var categories: NSOrderedSet
    
//    init(context: NSManagedObjectContext) {
//        let entity = NSEntityDescription.entityForName("Profile", inManagedObjectContext: context)!
//        super.init(entity: entity, insertIntoManagedObjectContext: context)
//    }
    
}

