import UIKit

class DelayedRepeatTimer: NSObject {
    
    var initialTimer: NSTimer!
    var repeatTimer: NSTimer!
    
    let ti: NSTimeInterval
    let target: AnyObject
    let selector: Selector
    
    init(delay: NSTimeInterval, ti: NSTimeInterval, target: AnyObject, selector: Selector) {
        self.ti = ti
        self.target = target
        self.selector = selector
        super.init()
        
        initialTimer = NSTimer.scheduledTimerWithTimeInterval(delay, target: self, selector: Selector("beginRepeating"), userInfo: nil, repeats: false)
    }
    
    func beginRepeating() {
        NSTimer.scheduledTimerWithTimeInterval(0, target: target, selector: selector, userInfo: nil, repeats: false)
        repeatTimer = NSTimer.scheduledTimerWithTimeInterval(ti, target: target, selector: selector, userInfo: nil, repeats: true)
    }
    
    func invalidate() {
        initialTimer.invalidate()
        initialTimer = nil
        
        if (repeatTimer != nil) {
            repeatTimer.invalidate()
            repeatTimer = nil
        }
    }
   
}
