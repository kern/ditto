import Foundation

class DittoStore : NSObject {
    
    let defaults = NSUserDefaults(suiteName: "group.io.kern.ditto")!
    
    let presetDittos = [
        "Hello there!\n\nI'm a student at UC Berkeley.",
        "Please don't hesitate to reach out if you have any questions.",
        "Cheers!",
        "Never gonna give you up\nNever gonna let you down\nNever gonna run around and desert you\nNever gonna make you cry\nNever gonna say goodbye\nNever gonna tell a lie and hurt you",
        "💙💙💙💙💙❤❤❤❤❤❤❤\n💙💙💙💙💙❤❤❤❤❤❤❤\n💙💙💙💙💙❤❤❤❤❤❤❤\n💙💙💙💙💙❤❤❤❤❤❤❤\n💙💙💙💙💙❤❤❤❤❤❤❤\n❤❤❤❤❤❤❤❤❤❤❤❤\n❤❤❤❤❤❤❤❤❤❤❤❤\n❤❤❤❤❤❤❤❤❤❤❤❤\n❤❤❤❤❤❤❤❤❤❤❤❤"
    ]
    
    var cached : [String] = []
    
    override init() {
        super.init()
        reload()
    }
    
    func reload() {
        defaults.synchronize()
        if let dittos = defaults.arrayForKey("dittos") as? [String] {
            cached = dittos
        } else {
            cached = presetDittos
        }
    }
    
    func save() {
        defaults.setObject(cached, forKey: "dittos")
        defaults.synchronize()
    }
    
    func get(index : Int) -> String {
        return cached[index]
    }
    
    func count() -> Int {
        return cached.count
    }
    
    func add(ditto : String) {
        cached.append(ditto)
        save()
    }
    
    func set(index : Int, ditto : String) {
        cached[index] = ditto
        save()
    }
    
    func move(from : Int, to : Int) {
        let ditto = cached[from]
        cached.removeAtIndex(from)
        cached.insert(ditto, atIndex: to)
        save()
    }
    
    func remove(index : Int) {
        cached.removeAtIndex(index)
        save()
    }
    
}