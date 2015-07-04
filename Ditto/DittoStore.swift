import Foundation
import UIKit

class DittoStore : NSObject {
    
    let defaults = NSUserDefaults(suiteName: "group.io.kern.ditto")!
    
    let presetDittos = [
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
    
    let presetCategories = ["Instructions", "Driving", "Business", "Tinder"]
    
    var cachedDittos: [String: [String]] = [String:[String]]()
    var cachedCategories: [String] = []
    
    override init() {
        super.init()
        reload()
    }
    
    func reload() {
        
        defaults.synchronize()
        
        if let dittos = defaults.dictionaryForKey("dittos") as? [String:[String]] {
            if let categories = defaults.arrayForKey("categories") as? [String] {
                cachedDittos = dittos
                cachedCategories = categories
            }
        } else {
            cachedDittos = presetDittos
            cachedCategories = presetCategories
        }
        
    }
    
    func save() {
        defaults.setObject(cachedDittos, forKey: "dittos")
        defaults.setObject(cachedCategories, forKey: "categories")
        defaults.synchronize()
    }
    
    func get(categoryIndex: Int, dittoIndex : Int) -> String {
        let category: String = cachedCategories[categoryIndex]
        let dittos: [String] = cachedDittos[category]!
        return dittos[dittoIndex]
    }
    
    func getDittosByCategory(categoryIndex: Int) -> [String] {
        let category: String = cachedCategories[categoryIndex]
        return cachedDittos[category]!
    }
    
    func getCategory(categoryIndex: Int) -> String {
        return cachedCategories[categoryIndex]
    }
    
    func count(categoryIndex: Int) -> Int {
        let category = cachedCategories[categoryIndex]
        let dittos = cachedDittos[category]!
        return dittos.count
    }
    
    func numCategories() -> Int {
        return cachedCategories.count
    }
    
    func add(categoryIndex: Int, ditto: String) {
        let category = cachedCategories[categoryIndex]
        var dittos = cachedDittos[category]!
        dittos.append(ditto)
        cachedDittos[category] = dittos
        save()
    }
    
    func set(categoryIndex: Int, dittoIndex : Int, ditto : String) {
        let category = cachedCategories[categoryIndex]
        var dittos = cachedDittos[category]!
        dittos[dittoIndex] = ditto
        cachedDittos[category] = dittos
        save()
    }
    
    func moveFromCategoryIndex(fromCategoryIndex: Int, fromDittoIndex: Int, toCategoryIndex: Int, toDittoIndex: Int) {
        let fromCategory = cachedCategories[fromCategoryIndex]
        let toCategory = cachedCategories[toCategoryIndex]
        let ditto = cachedDittos[fromCategory]![fromDittoIndex]
        cachedDittos[fromCategory]!.removeAtIndex(fromDittoIndex)
        cachedDittos[toCategory]!.insert(ditto, atIndex: toDittoIndex)
        save()
    }
    
    func moveFromCategory(fromCategory: Int, dittoIndex: Int, toCategory: Int) {
        moveFromCategoryIndex(fromCategory, fromDittoIndex: dittoIndex, toCategoryIndex: toCategory, toDittoIndex: count(toCategory))
    }
    
    func remove(categoryIndex: Int, dittoIndex: Int) {
        let category = cachedCategories[categoryIndex]
        var dittos = cachedDittos[category]!
        dittos.removeAtIndex(dittoIndex)
        cachedDittos[category] = dittos
        save()
    }
    
    func trimEmptyCategories() -> NSIndexSet {
        
        var categories: [String] = []
        var trimmedCategories = NSMutableIndexSet()
        
        for (index, category) in enumerate(cachedCategories) {
            var dittos = cachedDittos[category]!
            
            if (dittos.count == 0) {
                trimmedCategories.addIndex(index)
                cachedDittos.removeValueForKey(category)
            } else {
                categories.append(category)
            }
        }
        
        cachedCategories = categories
        save()
        
        return trimmedCategories
        
    }
    
    func getColorForIndex(index: Int) -> UIColor {
        return UIColor(red: 153/255, green: 0, blue: 153/255, alpha: 1 - ((4 / (4 * CGFloat(self.numCategories()))) * CGFloat(index)))
    }
    
    func isEmpty() -> Bool {
        return cachedCategories.isEmpty
    }
    
    func addCategory(name: String) {
        cachedCategories.append(name)
        cachedDittos[name] = []
        save()
    }
    
}