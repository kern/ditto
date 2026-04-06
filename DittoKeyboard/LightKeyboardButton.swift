import UIKit

/// Light-styled keyboard button (letter and standard input keys).
final class LightKeyboardButton: UIButton {

    private static let normalColor = UIColor(dynamicProvider: { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.40, alpha: 1)
            : UIColor(white: 0.98, alpha: 1)
    })

    private static let highlightedColor = UIColor(dynamicProvider: { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.50, alpha: 1)
            : UIColor(white: 0.88, alpha: 1)
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
