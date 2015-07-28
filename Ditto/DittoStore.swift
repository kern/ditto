import Foundation
import UIKit

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
            "Can't text, I'm driving.",
            "Can you send me the address?",
            "I'll be there in ___ minutes!",
            "I'm on my way!",
            "I'm driving, can you call me?"
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
    
    override init() {
        super.init()
        // TODO
    }
    
    //===============
    // MARK: Getters
    
    func getCategories() -> [String] {
        fatalError("Not yet implemented")
    }
    
    func getCategory(categoryIndex: Int) -> String {
        fatalError("Not yet implemented")
    }
    
    func getDittosInCategory(categoryIndex: Int) -> [String] {
        fatalError("Not yet implemented")
    }
    
    func getDittoInCategory(categoryIndex: Int, index dittoIndex: Int) -> String {
        fatalError("Not yet implemented")
    }
    
    func getDittoPreviewInCategory(categoryIndex: Int, index dittoIndex: Int) -> String {
        return preview(getDittoInCategory(categoryIndex, index: dittoIndex))
    }
    
    //==================
    // MARK: - Counting
    
    func isEmpty() -> Bool {
        fatalError("Not yet implemented")
    }
    
    func oneCategory() -> Bool {
        fatalError("Not yet implemented")
    }
    
    func countInCategory(categoryIndex: Int) -> Int {
        fatalError("Not yet implemented")
    }
    
    func countCategories() -> Int {
        fatalError("Not yet implemented")
    }
    
    //=============================
    // MARK: - Category Management
    
    func canCreateNewCategory() -> Bool {
        return countCategories() < MAX_CATEGORIES
    }
    
    func addCategoryWithName(name: String) {
            fatalError("Not yet implemented")
    }
    
    func removeCategoryAtIndex(categoryIndex: Int) {
        fatalError("Not yet implemented")
    }
    
    func moveCategoryFromIndex(fromIndex: Int, toIndex: Int) {
        fatalError("Not yet implemented")
    }
    
    func editCategoryAtIndex(index: Int, name: String) {
        fatalError("Not yet implemented")
    }
    
    //==========================
    // MARK: - Ditto Management
    
    func addDittoToCategory(categoryIndex: Int, text: String) {
        fatalError("Not yet implemented")
    }
    
    func removeDittoFromCategory(categoryIndex: Int, index dittoIndex: Int) {
        fatalError("Not yet implemented")
    }
    
    func moveDittoFromCategory(fromCategoryIndex: Int, index fromDittoIndex: Int, toCategory toCategoryIndex: Int, index toDittoIndex: Int) {
        fatalError("Not yet implemented")
    }
    
    func moveDittoFromCategory(fromCategoryIndex: Int, index dittoIndex: Int, toCategory toCategoryIndex: Int) {
        moveDittoFromCategory(fromCategoryIndex,
            index: dittoIndex,
            toCategory: toCategoryIndex,
            index: countInCategory(toCategoryIndex))
    }
    
    func editDittoInCategory(categoryIndex: Int, index dittoIndex: Int, text: String) {
        fatalError("Not yet implemented")
    }
    
    //=================
    // MARK: - Helpers
    
    func preview(ditto: String) -> String {
        return ditto
            .stringByReplacingOccurrencesOfString("\n", withString: " ")
            .stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " "))
    }
    
}