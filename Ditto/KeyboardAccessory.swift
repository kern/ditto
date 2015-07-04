import UIKit

class KeyboardAccessory: UIToolbar {
    
    let categoryLabel: UILabel
    let categoryField: CategoryField

    init(categoryPicker: CategoryPicker) {
        
        categoryLabel = UILabel(frame: CGRectZero)
        categoryField = CategoryField(frame: CGRectZero, categoryPicker: categoryPicker)
        super.init(frame: CGRectMake(0, 0, 0, 44))
        
        categoryLabel.textColor = UIColor.purpleColor()
        categoryLabel.text = "Category"
        categoryLabel.textAlignment = .Left
        self.addSubview(categoryLabel)
        self.addSubview(categoryField)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: Selector("accessoryClicked:"))
        self.addGestureRecognizer(tapGesture)
        self.userInteractionEnabled = true

    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        categoryLabel.sizeToFit()
        var labelFrame = categoryLabel.frame
        labelFrame.origin.x = 11
        labelFrame.size.height = frame.height
        categoryLabel.frame = labelFrame

        var fieldFrame = categoryField.frame
        fieldFrame.origin.x = CGRectGetMaxX(labelFrame) + 11
        fieldFrame.size.width = frame.width - fieldFrame.origin.x - 11
        fieldFrame.size.height = frame.height
        categoryField.frame = fieldFrame
    }
    
    func accessoryClicked(sender: UITapGestureRecognizer) {
        categoryField.becomeFirstResponder()
    }
    
}