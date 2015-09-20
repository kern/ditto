import UIKit
import CoreData

class PendingDittoStore : NSObject {
    
    let defaults = NSUserDefaults(suiteName: "group.io.kern.ditto")!
    let dittoStore = DittoStore()
    
    
    //===============
    // MARK: Getters
    
    func getCategories() -> [String] {
        return dittoStore.getCategories()
    }
    
    func getCategory(categoryIndex: Int) -> String {
        return dittoStore.getCategories()[categoryIndex]
    }
    
    func getDittosInCategory(categoryIndex: Int) -> [String] {
        var savedDittos = dittoStore.getDittosInCategory(categoryIndex)
        let category = dittoStore.getCategory(categoryIndex)
        if let pendingDittos = defaults.objectForKey("pendingDittos") as? [String: [String]]{
            if let pendingCategories = defaults.objectForKey("pendingCategories") as? [String] {
                if pendingCategories.contains(category) {
                    savedDittos = savedDittos + pendingDittos[category]!
                }
            }
        }
        return savedDittos
    }
    
    func getDittoInCategory(categoryIndex: Int, index dittoIndex: Int) -> String {
        return getDittosInCategory(categoryIndex)[dittoIndex]
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
        let category = getCategory(categoryIndex)
        var count = dittoStore.countInCategory(categoryIndex)
        if let pendingDittos = defaults.objectForKey("pendingDittos") as? [String: [String]]{
            if let pendingCategories = defaults.objectForKey("pendingCategories") as? [String] {
                if pendingCategories.contains(category) {
                    count += pendingDittos[category]!.count
                }
            }
        }
        return count
    }
    
    func countCategories() -> Int {
        return getCategories().count
    }
    
    //==========================
    // MARK: - Ditto Management
    
    func addDittoToCategory(categoryIndex: Int, text: String) {
        defaults.synchronize()
        
        let categories = dittoStore.getCategories()
        let category = categories[categoryIndex]
        
        if var pendingDittos = defaults.dictionaryForKey("pendingDittos") as? [String:[String]] {
            if var pendingCategories = defaults.arrayForKey("pendingCategories") as? [String] {
                if pendingCategories.contains(category){
                    var dittos = pendingDittos[category]
                    dittos!.append(text)
                    pendingDittos[category] = dittos!
                } else {
                    pendingCategories.append(category)
                    pendingDittos[category] = [text]
                }
                
                defaults.setObject(pendingCategories, forKey: "pendingCategories")
                defaults.setObject(pendingDittos, forKey: "pendingDittos")
                
            }
        } else {
            let pendingCategories = [category]
            let pendingDittos = [category: [text]]
            
            defaults.setObject(pendingCategories, forKey: "pendingCategories")
            defaults.setObject(pendingDittos, forKey: "pendingDittos")
        }
        
        defaults.synchronize()
    }
    
    //=================
    // MARK: - Helpers
    
    func preview(ditto: String) -> String {
        return ditto
            .stringByReplacingOccurrencesOfString("\n", withString: " ")
            .stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " "))
    }
    
}