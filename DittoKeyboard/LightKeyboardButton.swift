import UIKit

class LightKeyboardButton: UIButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
    }
    
    override var highlighted: Bool {
        get {
            return super.highlighted
        }
        
        set {
            if newValue {
                backgroundColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
            } else {
                backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
            }
            
            super.highlighted = newValue
        }
    }
    
}
