import UIKit

class ObjectTableViewCell: UITableViewCell {

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        textLabel!.text = ""
        textLabel!.font = UIFont.systemFontOfSize(UIFont.labelFontSize())
        textLabel!.numberOfLines = 2
        setTextLabelConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
//    override func layoutSubviews() {
//        
//        super.layoutSubviews()
//        
//        let disclosure = accessoryType == .DisclosureIndicator
//        let width = ObjectTableViewCell.widthWithDisclosure(disclosure)
//        let height = ObjectTableViewCell.heightForText(textLabel!.text!, truncated: truncated, disclosure: disclosure)
//        textLabel!.frame = CGRectMake(15, 0, width, height)
//        
//    }
    
    var truncated: Bool {
        get {
            return textLabel!.numberOfLines != 0
        }
        
        set {
            textLabel!.numberOfLines = newValue ? 2 : 0
            setNeedsLayout()
        }
    }

    func setText(text: String, disclosure: Bool) {
        textLabel!.text = text
        accessoryType = disclosure ? .DisclosureIndicator : .None
        setNeedsLayout()
    }
    
    static func widthWithDisclosure(disclosure: Bool) -> CGFloat {
        return UIScreen.mainScreen().bounds.width - (disclosure ? 45 : 30)
    }
    
    static func heightForText(text: String, truncated: Bool, disclosure: Bool) -> CGFloat {
        
        let w = widthWithDisclosure(disclosure)
        var height = text.boundingRectWithSize(CGSizeMake(w, CGFloat.max),
            options: [.UsesLineFragmentOrigin, .UsesFontLeading],
            attributes: [NSFontAttributeName: UIFont.systemFontOfSize(UIFont.labelFontSize())],
            context: nil).size.height
        
        if truncated {
            let twoLineHeight = " \n ".boundingRectWithSize(CGSizeMake(w, CGFloat.max),
                options: [.UsesLineFragmentOrigin, .UsesFontLeading],
                attributes: [NSFontAttributeName: UIFont.systemFontOfSize(UIFont.labelFontSize())],
                context: nil).size.height
            
            height = min(height, twoLineHeight)
        }
        
        return height + 22
    }

    func setTextLabelConstraints() {
        
        let leadingConstraint = NSLayoutConstraint(item: textLabel!,
            attribute: .Leading,
            relatedBy: .Equal,
            toItem: self,
            attribute: .Leading,
            multiplier: 1,
            constant: 15)
        
        self.addConstraint(leadingConstraint)
        
        let trailingConstraint = NSLayoutConstraint(item: textLabel!,
            attribute: .Trailing,
            relatedBy: .Equal,
            toItem: self,
            attribute: .Trailing,
            multiplier: 1,
            constant: 10)
        
        self.addConstraint(trailingConstraint)
        
        let disclosure = accessoryType == .DisclosureIndicator
        let width = ObjectTableViewCell.widthWithDisclosure(disclosure)
        let height = ObjectTableViewCell.heightForText(textLabel!.text!, truncated: truncated, disclosure: disclosure)
        
        let heightConstraint = NSLayoutConstraint(item: textLabel!,
            attribute: .Height,
            relatedBy: .Equal,
            toItem: nil,
            attribute: .NotAnAttribute,
            multiplier: 0,
            constant: height)
        
        self.addConstraint(heightConstraint)

    }
}
