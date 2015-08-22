import UIKit
import CoreData

class DittoStore : NSObject {
    
    let MAX_CATEGORIES = 8
    let PRESET_CATEGORIES = ["Instructions", "Driving", "Business", "Tinder"]
    let PRESET_DITTOS = [
        "Instructions": [
            "Welcome to Ditto! 👋",
            "Add Ditto in Settings > General > Keyboard > Keyboards.",
            "You must allow full access for Ditto to work properly. After you've added the Ditto keyboard, select it, and turn on Allow Full Access.",
            "We DO NOT access ANYTHING that you type on the keyboard.",
            "Everything is saved privately on your device.",
            "Use the Ditto app to customize your dittos.",
            "Add a triple underscore ___ to your ditto to control where your cursor lands.",
            "You can expand long dittos within the keyboard by holding them down. Go ahead and give this one a try! You can expand long dittos within the keyboard by holding them down. Go ahead and give this one a try! You can expand long dittos within the keyboard by holding them down. Go ahead and give this one a try! You can expand long dittos within the keyboard by holding them down. Go ahead and give this one a try!",
            "Hold down a keyboard tab to uncover the category, and swipe between tabs for quick access."
        ],
        
        "Driving": [
            "I'm driving, can you call me?",
            "I'll be there in ___ minutes!",
            "What's the address?",
            "Can't text, I'm driving."
        ],
        
        "Business": [
            "Hi ___,\n\nIt was great meeting you today. I'd love to chat in more detail about possible business opportunities. Please let me know your availability.\n\nBest,\nAsaf Avidan Antonir",
            "My name is Asaf, and I work at Shmoogle on the search team. We are always looking for talented candidates to join our team, and with your impressive background, we think you could be a great fit. Please let me know if you are interested, and if so, your availability to chat this week."
        ],
        
        "Tinder": [
            "I'm not a photographer, but I can picture us together.",
            "Was your dad a thief? Because someone stole the stars from the sky and put them in your eyes.",
            "Do you have a Band-Aid? Because I just scraped my knee falling for you."
        ]
    ]
    
    static var managedObjectModel: NSManagedObjectModel = {
        let modelURL = NSBundle.mainBundle().URLForResource("Ditto", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()
    
    static var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        
        let directory = NSFileManager.defaultManager().containerURLForSecurityApplicationGroupIdentifier("group.io.asaf.ditto")
        let storeURL = directory?.URLByAppendingPathComponent("Ditto.sqlite")
        
        let options = [
            NSMigratePersistentStoresAutomaticallyOption: NSNumber(bool: true),
            NSInferMappingModelAutomaticallyOption: NSNumber(bool: true)
        ]
        
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        
        var err: NSError? = nil
        if persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: options, error: &err) == nil {
            fatalError(err!.localizedDescription)
        }
        
        return persistentStoreCoordinator
        
    }()
    
    static var managedObjectContext: NSManagedObjectContext = {
        var managedObjectContext = NSManagedObjectContext()
        managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        return managedObjectContext
    }()
    
    //===================
    // MARK: Persistence
    
    func dumpStore() {
        
        println("========")
        println()
        
        let entities = DittoStore.managedObjectModel.entities as! [NSEntityDescription]
        
        println("Entities")
        println(entities)
        
        for entity in entities {
            
            let request = NSFetchRequest()
            request.entity = entity
            let results = context.executeFetchRequest(request, error: nil)!
//
//            println(entity.name! + " (" + String(results.count) + "):")
//            println()
//            for x in results {
//                println(x)
//            }
//            println()

        }
        
        println("========")

    }
    
    lazy var context: NSManagedObjectContext = {
        return DittoStore.managedObjectContext
    }()
    
    func save() {
        var err: NSError? = nil
        if !DittoStore.managedObjectContext.save(&err) {
            fatalError(err!.localizedDescription)
        }
    }
    
//    func loadPresets(profile: Profile) {
//            }
    
    func createProfile() -> Profile {
        let profile = NSEntityDescription.insertNewObjectForEntityForName("Profile", inManagedObjectContext: DittoStore.managedObjectContext) as! Profile
        for categoryName in PRESET_CATEGORIES {
            var category = NSEntityDescription.insertNewObjectForEntityForName("Category", inManagedObjectContext: DittoStore.managedObjectContext) as! Category
            category.profile = profile
            category.title = categoryName
            
            for dittoText in PRESET_DITTOS[categoryName]! {
                var ditto = NSEntityDescription.insertNewObjectForEntityForName("Ditto", inManagedObjectContext: DittoStore.managedObjectContext) as! Ditto
                ditto.category = category
                ditto.text = dittoText
            }
        }
        save()
        
        return profile
    }
    
    lazy var profile: Profile = {
        let fetchRequest = NSFetchRequest(entityName: "Profile")
        var error: NSError?
        if let profiles = DittoStore.managedObjectContext.executeFetchRequest(fetchRequest, error: &error) {
            if profiles.count > 0 {
                return profiles[0] as! Profile
            } else {
                return self.createProfile()
            }
        } else {
            fatalError(error!.localizedDescription)
        }
        
    }()
    

    
    //===============
    // MARK: Getters
    
    func getCategories() -> [String] {
        return Array(profile.categories).map({ (category) in
            let c = category as! Category
            return c.title
        })
        
    }
    
    func getCategory(categoryIndex: Int) -> String {
        let category = profile.categories[categoryIndex] as! Category
        return category.title
    }
    
    func getDittosInCategory(categoryIndex: Int) -> [String] {
        let category = profile.categories[categoryIndex] as! Category
        let dittos = Array(category.dittos)
        return dittos.map({ (ditto) in
            let d = ditto as! Ditto
            return d.text
        })
    }
    
    func getDittoInCategory(categoryIndex: Int, index dittoIndex: Int) -> String {
        let category = profile.categories[categoryIndex] as! Category
        let ditto = category.dittos[dittoIndex] as! Ditto
        return ditto.text
    }
    
    func getDittoPreviewInCategory(categoryIndex: Int, index dittoIndex: Int) -> String {
        return preview(getDittoInCategory(categoryIndex, index: dittoIndex))
    }
    
    //==================
    // MARK: - Counting
    
    func isEmpty() -> Bool {
        return countCategories() == 0
    }
    
    func oneCategory() -> Bool {
        return countCategories() == 1
    }
    
    func countInCategory(categoryIndex: Int) -> Int {
        let category = profile.categories[categoryIndex] as! Category
        return category.dittos.count
    }
    
    func countCategories() -> Int {
        return profile.categories.count
    }
    
    //=============================
    // MARK: - Category Management
    
    func canCreateNewCategory() -> Bool {
        return countCategories() < MAX_CATEGORIES
    }
    
    func addCategoryWithName(name: String) {
        var category = NSEntityDescription.insertNewObjectForEntityForName("Category", inManagedObjectContext: context) as! Category
        category.profile = profile
        category.title = name
        save()
    }
    
    func removeCategoryAtIndex(categoryIndex: Int) {
        let category = profile.categories[categoryIndex] as! Category
        context.deleteObject(category)
        save()
    }
    
    func moveCategoryFromIndex(fromIndex: Int, toIndex: Int) {
        let categories = profile.categories.mutableCopy() as! NSMutableOrderedSet
        let category = categories[fromIndex] as! Category
        categories.removeObjectAtIndex(fromIndex)
        categories.insertObject(category, atIndex: toIndex)
        profile.categories = categories as NSOrderedSet
        save()
    }
    
    func editCategoryAtIndex(index: Int, name: String) {
        let category = profile.categories[index] as! Category
        category.title = name
        save()
    }
    
    //==========================
    // MARK: - Ditto Management
    
    func addDittoToCategory(categoryIndex: Int, text: String) {
        var ditto = NSEntityDescription.insertNewObjectForEntityForName("Ditto", inManagedObjectContext: context) as! Ditto
        ditto.category = profile.categories[categoryIndex] as! Category
        ditto.text = text
        save()
    }
    
    func removeDittoFromCategory(categoryIndex: Int, index dittoIndex: Int) {
        let category = profile.categories[categoryIndex] as! Category
        let ditto = category.dittos[dittoIndex] as! Ditto
        context.deleteObject(ditto)
        save()
    }
    
    func moveDittoFromCategory(fromCategoryIndex: Int, index fromDittoIndex: Int, toCategory toCategoryIndex: Int, index toDittoIndex: Int) {
        
        if fromCategoryIndex == toCategoryIndex {
            let category = profile.categories[fromCategoryIndex] as! Category
            let dittos = category.dittos.mutableCopy() as! NSMutableOrderedSet
            let ditto = dittos[fromDittoIndex] as! Ditto
            dittos.removeObjectAtIndex(fromDittoIndex)
            dittos.insertObject(ditto, atIndex: toDittoIndex)
            category.dittos = dittos as NSOrderedSet
        
        
        } else {
            
            let fromCategory = profile.categories[fromCategoryIndex] as! Category
            let toCategory = profile.categories[toCategoryIndex] as! Category
            
            let fromDittos = fromCategory.dittos.mutableCopy() as! NSMutableOrderedSet
            let toDittos = toCategory.dittos.mutableCopy() as! NSMutableOrderedSet
            
            let ditto = fromDittos[fromDittoIndex] as! Ditto
            
            fromDittos.removeObjectAtIndex(fromDittoIndex)
            toDittos.insertObject(ditto, atIndex: toDittoIndex)

            fromCategory.dittos = fromDittos as NSOrderedSet
            toCategory.dittos = toDittos as NSOrderedSet
        }
        
        save()
    }
    
    func moveDittoFromCategory(fromCategoryIndex: Int, index dittoIndex: Int, toCategory toCategoryIndex: Int) {
        moveDittoFromCategory(fromCategoryIndex,
            index: dittoIndex,
            toCategory: toCategoryIndex,
            index: countInCategory(toCategoryIndex))
    }
    
    func editDittoInCategory(categoryIndex: Int, index dittoIndex: Int, text: String) {
        let category = profile.categories[categoryIndex] as! Category
        let ditto = category.dittos[dittoIndex] as! Ditto
        ditto.text = text
        save()
    }
    
    //=================
    // MARK: - Helpers
    
    func preview(ditto: String) -> String {
        return ditto
            .stringByReplacingOccurrencesOfString("\n", withString: " ")
            .stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " "))
    }
    
}