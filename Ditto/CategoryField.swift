import UIKit

class CategoryField: UILabel {
    
    let doneButton: UIButton
    let categoryPicker: CategoryPicker
    override var inputView: UIView? { return categoryPicker.view }
    
    init(frame: CGRect, categoryPicker: CategoryPicker) {
        
        self.doneButton = UIButton()
        self.categoryPicker = categoryPicker
        super.init(frame: frame)
        
        userInteractionEnabled = true
        text = categoryPicker.name
        font = UIFont.boldSystemFontOfSize(16)
        textColor = UIColor.purpleColor()
        textAlignment = .Right
        
        doneButton.hidden = true
        doneButton.titleLabel?.font = UIFont.boldSystemFontOfSize(16)
        doneButton.setTitle("Done", forState: .Normal)
        doneButton.setTitleColor(UIColor.purpleColor(), forState: .Normal)
        doneButton.addTarget(self, action: Selector("resignFirstResponder"), forControlEvents: .TouchUpInside)
        addSubview(doneButton)
        
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        
        text = ""
        doneButton.hidden = false
        return super.becomeFirstResponder()
        
    }
    
    override func resignFirstResponder() -> Bool {
        
        text = categoryPicker.name
        doneButton.hidden = true
        return super.resignFirstResponder()
        
    }
    
    override func layoutSubviews() {
        
        super.layoutSubviews()
        
        doneButton.sizeToFit()
        var buttonFrame = doneButton.frame
        buttonFrame.origin.x = frame.size.width - buttonFrame.size.width
        buttonFrame.size.height = frame.height
        doneButton.frame = buttonFrame

    }

}