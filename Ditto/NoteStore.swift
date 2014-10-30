import Foundation

class NoteStore: NSObject {
    
    let defaults = NSUserDefaults(suiteName: "io.kern.ditto")!
    
    func add(note: String) {
        var notes = getAll()
        notes.append(note)
        defaults.setObject(notes, forKey: "notes")
        defaults.synchronize()
    }
    
    func getAll() -> [String] {
        if let notes = defaults.arrayForKey("notes") as? [String] {
            return notes
        } else {
            return []
        }
    }
    
    func get(index: Int) -> String {
        var notes = getAll()
        return notes[index]
    }
    
    func set(index: Int, text: String) {
        var notes = getAll()
        notes[index] = text
        defaults.setObject(notes, forKey: "notes")
        defaults.synchronize()
    }
    
    func move(from: Int, to: Int) {
        var notes = getAll()
        let text = notes[from]
        notes.removeAtIndex(from)
        notes.insert(text, atIndex: to)
        defaults.setObject(notes, forKey: "notes")
        defaults.synchronize()
    }
    
    func remove(index: Int) {
        var notes = getAll()
        notes.removeAtIndex(index)
        defaults.setObject(notes, forKey: "notes")
        defaults.synchronize()
    }
    
}