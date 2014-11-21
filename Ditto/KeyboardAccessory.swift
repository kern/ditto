import UIKit

class KeyboardAccessory: UIToolbar {
    
    var label: UILabel!

    override init() {
        super.init(frame: CGRectMake(0, 0, 0, 44))
        
        label = UILabel(frame: CGRectMake(11, 11, 0, 22))
        label.textColor = UIColor.purpleColor()
        label.text = "Use _ _ _ to place cursor."
        label.textAlignment = .Center
        
        self.addSubview(label)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        var labelFrame = label.frame
        labelFrame.size.width = frame.width - 22
        label.frame = labelFrame
    }
    
}