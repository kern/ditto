import Foundation
import UIKit

class DittoStore : NSObject {
    
    let MAX_CATEGORIES = 8
    let PRESET_CATEGORIES = ["Instructions", "Driving", "Business", "Tinder"]
    let PRESET_DITTOS = [
        "Instructions": [
            "Welcome to Ditto. 👋",
            "Add Ditto in Settings > General > Keyboard > Keyboards.",
            "You must Allow Full Access for Ditto to work properly.",
            "We DO NOT access ANYTHING that you type on the keyboard.",
            "Everything is saved privately on your device.",
            "Use the Ditto app to customize your Dittos.",
            "You can expand this long ditto by holding it down within the keyboard. You can expand this long ditto by holding it down within the keyboard. You can expand this long ditto by holding it down within the keyboard. You can expand this long ditto by holding it down within the keyboard. You can expand this long ditto by holding it down within the keyboard. "
        ],
        
        "Driving": [
            "Can't talk, I'm driving.",
            "Can you send me the address?",
            "I'll be there in ___ minutes!"
        ],
        
        "Business": [
            "Hi ___,\n\nIt was great meeting you today. I'd love to chat in more detail about possible business opportinities. Please let me know your avilability.\n\nBest,\nAsaf",
            "My name is Asaf. I'm a recruiter at Shmoogle on the search team. We are always looking for talented candidates to join our team, and with your impressive background, we think you could be a great fit. Please let me know if you are interested, and if so, your availability to chat this week."
        ],
        
        "Tinder": [
            "I'm not a photographer, but I can picture us together.",
            "Was your dad a thief? Because someone stole the stars from the sky and put them in your eyes.",
            "Do you have a Band-Aid? Because I just scraped my knee falling for you."
        ]
    ]
    
    
    let defaults = NSUserDefaults(suiteName: "group.io.kern.ditto")!
    var cachedDittos: [String: [String]] = [String: [String]]()
    var cachedCategories: [String] = []
    
    override init() {
        super.init()
        reload()
    }
    
    //=====================
    // MARK: - Persistence
    
    func reload() {
        
        defaults.synchronize()
        
        if let dittos = defaults.dictionaryForKey("dittos") as? [String:[String]] {
            if let categories = defaults.arrayForKey("categories") as? [String] {
                cachedCategories = categories
                cachedDittos = dittos
            }
        } else {
            cachedCategories = PRESET_CATEGORIES
            cachedDittos = PRESET_DITTOS
        }
        
    }
    
    func save() {
        defaults.setObject(cachedCategories, forKey: "categories")
        defaults.setObject(cachedDittos, forKey: "dittos")
        defaults.synchronize()
    }
    
    //===============
    // MARK: Getters
    
    func getCategory(categoryIndex: Int) -> String {
        return cachedCategories[categoryIndex]
    }
    
    func getDittosInCategory(categoryIndex: Int) -> [String] {
        let category = cachedCategories[categoryIndex]
        return cachedDittos[category]!
    }
    
    func getDittoInCategory(categoryIndex: Int, index dittoIndex: Int) -> String {
        let category = cachedCategories[categoryIndex]
        let dittos = cachedDittos[category]!
        return dittos[dittoIndex]
    }
    
    func getDittoPreviewInCategory(categoryIndex: Int, index dittoIndex: Int) -> String {
        return getDittoInCategory(categoryIndex, index: dittoIndex)
            .stringByReplacingOccurrencesOfString("\n", withString: " ")
            .stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " "))
    }
    
    //==================
    // MARK: - Counting
    
    func isEmpty() -> Bool {
        return cachedCategories.isEmpty
    }
    
    func oneCategory() -> Bool {
        return cachedCategories.count == 1
    }
    
    func countInCategory(categoryIndex: Int) -> Int {
        let category = cachedCategories[categoryIndex]
        let dittos = cachedDittos[category]!
        return dittos.count
    }
    
    func countCategories() -> Int {
        return cachedCategories.count
    }
    
    //=============================
    // MARK: - Category Management
    
    func canCreateNewCategory() -> Bool {
        return countCategories() < MAX_CATEGORIES
    }
    
    func addCategoryWithName(name: String) {
        cachedCategories.append(name)
        cachedDittos[name] = []
        save()
    }
    
    func removeCategoryAtIndex(categoryIndex: Int) {
        let category = cachedCategories[categoryIndex]
        cachedDittos.removeValueForKey(category)
        cachedCategories.removeAtIndex(categoryIndex)
        save()
    }
    
    func moveCategoryFromIndex(fromIndex: Int, toIndex: Int) {
        let category = cachedCategories[fromIndex]
        cachedCategories.removeAtIndex(fromIndex)
        cachedCategories.insert(category, atIndex: toIndex)
        save()
    }
    
    func editCategoryAtIndex(index: Int, name: String) {
        let oldName = cachedCategories[index]
        let dittos = cachedDittos[oldName]
        cachedCategories[index] = name
        cachedDittos.removeValueForKey(oldName)
        cachedDittos[name] = dittos
        save()
    }
    
    //==========================
    // MARK: - Ditto Management
    
    func addDittoToCategory(categoryIndex: Int, text: String) {
        let category = cachedCategories[categoryIndex]
        var dittos = cachedDittos[category]!
        dittos.append(text)
        cachedDittos[category] = dittos
        save()
    }
    
    func removeDittoFromCategory(categoryIndex: Int, index dittoIndex: Int) {
        let category = cachedCategories[categoryIndex]
        var dittos = cachedDittos[category]!
        dittos.removeAtIndex(dittoIndex)
        cachedDittos[category] = dittos
        save()
    }
    
    func moveDittoFromCategory(fromCategoryIndex: Int, index fromDittoIndex: Int, toCategory toCategoryIndex: Int, index toDittoIndex: Int) {
        let fromCategory = cachedCategories[fromCategoryIndex]
        let toCategory = cachedCategories[toCategoryIndex]
        let ditto = cachedDittos[fromCategory]![fromDittoIndex]
        cachedDittos[fromCategory]!.removeAtIndex(fromDittoIndex)
        cachedDittos[toCategory]!.insert(ditto, atIndex: toDittoIndex)
        save()
    }
    
    func moveDittoFromCategory(fromCategoryIndex: Int, index dittoIndex: Int, toCategory toCategoryIndex: Int) {
        moveDittoFromCategory(fromCategoryIndex,
            index: dittoIndex,
            toCategory: toCategoryIndex,
            index: countInCategory(toCategoryIndex))
    }
    
    func editDittoInCategory(categoryIndex: Int, index dittoIndex: Int, text: String) {
        let category = cachedCategories[categoryIndex]
        var dittos = cachedDittos[category]!
        dittos[dittoIndex] = text
        cachedDittos[category] = dittos
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