import UIKit

/// Light-styled keyboard button used for letter and standard keys.
final class LightKeyboardButton: UIButton {

    private let normalColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
    private let highlightedColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)

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
