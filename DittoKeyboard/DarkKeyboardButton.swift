import UIKit

/// Dark-styled keyboard button used for numeric and special keys.
final class DarkKeyboardButton: UIButton {

    private let normalColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
    private let highlightedColor = UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1)

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = normalColor
    }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? highlightedColor : normalColor
        }
    }
}
