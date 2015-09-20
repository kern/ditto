import UIKit

class CategoryHeaderView: UILabel {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.95, alpha: 1)
        textColor = UIColor(white: 0.35, alpha: 1)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawTextInRect(rect: CGRect) {
        let insets = UIEdgeInsetsMake(0, 15, 0, 15)
        super.drawTextInRect(UIEdgeInsetsInsetRect(rect, insets))
    }

}
