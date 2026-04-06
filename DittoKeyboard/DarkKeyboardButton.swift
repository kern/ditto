import UIKit

/// Dark-styled keyboard button (action keys: backspace, space, return, globe).
final class DarkKeyboardButton: UIButton {

    private static let normalColor = UIColor(dynamicProvider: { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.24, alpha: 1)
            : UIColor(white: 0.68, alpha: 1)
    })

    private static let highlightedColor = UIColor(dynamicProvider: { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.32, alpha: 1)
            : UIColor(white: 0.58, alpha: 1)
    })

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = Self.normalColor
    }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? Self.highlightedColor : Self.normalColor
        }
    }
}
