import UIKit

class CategoryField: UILabel {
    
    let categoryPicker: CategoryPicker
    override var inputView: UIView? { return categoryPicker.view }
    
    init(frame: CGRect, categoryPicker: CategoryPicker) {
        
        self.categoryPicker = categoryPicker
        super.init(frame: frame)
        
        text = categoryPicker.name
        font = UIFont.boldSystemFontOfSize(16)
        textColor = UIColor.purpleColor()
        textAlignment = .Right
        
        let tapGesture = UITapGestureRecognizer(target: self, action: Selector("resignFirstResponder"))
        addGestureRecognizer(tapGesture)
        
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        userInteractionEnabled = true
        text = "Done"
        return super.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        userInteractionEnabled = false
        text = categoryPicker.name
        return super.resignFirstResponder()
    }

}