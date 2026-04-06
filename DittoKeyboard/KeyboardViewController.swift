import UIKit

final class KeyboardViewController: UIInputViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet private var keyboardView: UIView!
    @IBOutlet private var tableView: UITableView!
    @IBOutlet private var numericKeys: UIView!
    @IBOutlet private var bottomBar: UIView!
    @IBOutlet private var tabBar: UIView!
    @IBOutlet private var noDittosLabel: UILabel!
    @IBOutlet private var tabTitleLabel: UILabel!

    @IBOutlet private var backspaceButton: UIButton!
    @IBOutlet private var nextKeyboardButton: UIButton!
    @IBOutlet private var returnButton: UIButton!
    @IBOutlet private var spaceButton: UIButton!
    @IBOutlet private var decimalButton: UIButton!
    @IBOutlet private var dittoButton: UIButton!

    @IBOutlet private var addDittoTextInput: UITextView!
    @IBOutlet private var addDittoView: UIView!
    @IBOutlet private var categoryPicker: UIPickerView!
    @IBOutlet private var addDittoTextView: UITextView!
    @IBOutlet private var selectedCategory: UILabel!
    @IBOutlet private var addDittoButtons: UIView!
    @IBOutlet private var addDittoButton: UIButton!

    private var keyboardHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var tabBarHeightConstraint: NSLayoutConstraint!

    let dittoStore: PendingDittoStore
    let addDittoViewController: AddDittoFromClipboardViewController
    var backspaceTimer: DelayedRepeatTimer?

    // swiftlint:disable:next line_length
    let addDittoTextInputPlaceholder = "Select and copy desired text... if it doesn't appear, you may need to turn on \"Allow Full Access\" in your device's keyboard settings."

    var tabViews: [UIView] = []
    var selectedTab: Int = -1
    var selectedRow: Int = -1
    var selectedTabArrow = CAShapeLayer()

    init() {
        let store = PendingDittoStore()
        dittoStore = store
        addDittoViewController = AddDittoFromClipboardViewController(dittoStore: store)
        super.init(nibName: "KeyboardViewController", bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Signal to the main app that the keyboard has been loaded (full access granted)
        UserDefaults(suiteName: "group.io.kern.ditto")?.set(true, forKey: "keyboardHasLoaded")

        keyboardHeightConstraint = keyboardView.heightAnchor.constraint(equalToConstant: keyboardHeight)

        setupAppearance()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DittoCell")

        categoryPicker.delegate = addDittoViewController
        categoryPicker.dataSource = addDittoViewController

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tabDragged(_:)))
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(tabDragged(_:)))
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(tabDragged(_:)))
        tabBar.addGestureRecognizer(tapGesture)
        tabBar.addGestureRecognizer(longPressGesture)
        tabBar.addGestureRecognizer(panGesture)

        loadTab(0)
        selectedTabArrow = drawSelectedTabArrow(0)

        addDittoView.isHidden = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        keyboardView.addConstraint(keyboardHeightConstraint)

        if dittoStore.isEmpty {
            noDittosLabel.isHidden = false
            tableView.isHidden = true
        } else {
            noDittosLabel.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        keyboardHeightConstraint.constant = keyboardHeight
        tabBarHeightConstraint.constant = tabBarHeight
        refreshTabButtons()
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    func loadAddDittoView() {
        categoryPicker.isHidden = true
        addDittoTextView.isHidden = false
        addDittoTextView.isSelectable = false
        selectedCategory.text = selectedCategoryFromPicker()
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.pollPasteboard()
        }
        pollPasteboard()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        let proxy = textDocumentProxy

        switch proxy.keyboardType {
        case .numberPad:
            numericKeys.isHidden = false
            spaceButton.isHidden = true
            returnButton.isHidden = true
            decimalButton.isHidden = true
            dittoButton.isHidden = true

        case .decimalPad:
            numericKeys.isHidden = false
            spaceButton.isHidden = true
            returnButton.isHidden = true
            decimalButton.isHidden = false
            dittoButton.isHidden = true

        default:
            numericKeys.isHidden = true
            spaceButton.isHidden = false
            returnButton.isHidden = false
            decimalButton.isHidden = false
            dittoButton.isHidden = false
        }
    }

    // MARK: - Tabs

    @objc func tabDragged(_ recognizer: UIGestureRecognizer) {
        let tab = Int(floor(recognizer.location(in: tabBar).x / tabWidth))

        if addDittoView.isHidden {
            loadTab(tab)
            selectedTabArrow.isHidden = false
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            loadTab(tab)
            selectedTabArrow.isHidden = false
            CATransaction.commit()
        }

        addDittoView.isHidden = true
        numericKeys.isHidden = true
        tableView.isHidden = false

        tabTitleLabel.isHidden = dittoStore.hasOneCategory || recognizer.state == .ended
        view.setNeedsLayout()
    }

    func loadTab(_ tab: Int) {
        tableView.setContentOffset(.zero, animated: false)
        guard selectedTab != tab, !dittoStore.isEmpty else { return }
        selectedTab = tab
        moveSelectedTabArrow(tab)
        selectedRow = -1
        tabTitleLabel.text = dittoStore.categoryTitle(at: selectedTab)
        tabTitleLabel.backgroundColor = colorForTab(selectedTab)
        tableView.reloadData()
    }

    func selectedTabArrowPath() -> CGPath {
        let h = tabBar.bounds.height
        let path = UIBezierPath()
        path.move(to: CGPoint(x: -7, y: h))
        path.addLine(to: CGPoint(x: 7, y: h))
        path.addLine(to: CGPoint(x: 0, y: h - 7))
        path.close()
        return path.cgPath
    }

    func moveSelectedTabArrow(_ tab: Int) {
        selectedTabArrow.position = CGPoint(x: (CGFloat(tab) + 0.5) * tabWidth, y: 0)
    }

    func drawSelectedTabArrow(_ tab: Int) -> CAShapeLayer {
        guard !dittoStore.isEmpty, !dittoStore.hasOneCategory else {
            return CAShapeLayer()
        }

        let arrowColor = Self.keyboardBg.resolvedColor(with: traitCollection).cgColor
        let shape = CAShapeLayer()
        tabBar.layer.addSublayer(shape)
        shape.opacity = 1
        shape.lineWidth = 0
        shape.lineJoin = .miter
        shape.strokeColor = arrowColor
        shape.fillColor = arrowColor
        shape.path = selectedTabArrowPath()
        shape.zPosition = 1
        return shape
    }

func refreshTabButtons() {
        guard !dittoStore.isEmpty, !dittoStore.hasOneCategory else { return }

        tabViews.forEach { $0.removeFromSuperview() }

        let w = tabWidth
        let h = tabBar.bounds.height

        tabViews = (0..<tabCount).map { i in
            let tab = UIView(frame: CGRect(x: CGFloat(i) * w, y: 0, width: w, height: h))
            tab.backgroundColor = self.colorForTab(i)

            let tabLabel = UILabel(frame: CGRect(x: 8, y: 0, width: w - 16, height: h))
            tabLabel.textColor = .white
            tabLabel.text = self.dittoStore.categoryTitle(at: i)
            tabLabel.font = tabLabel.font.withSize(14)
            tabLabel.textAlignment = .center
            tabLabel.lineBreakMode = .byClipping
            self.truncateToLastFullLetter(tabLabel, width: w - 16)

            tab.addSubview(tabLabel)
            self.tabBar.addSubview(tab)
            return tab
        }

        tabBar.bringSubviewToFront(tabTitleLabel)
        moveSelectedTabArrow(selectedTab)
    }

    var tabCount: Int { dittoStore.categoryCount }

    private var screenBounds: CGRect {
        view.window?.windowScene?.screen.bounds ?? UIScreen.main.bounds
    }

    var tabWidth: CGFloat {
        screenBounds.width / CGFloat(tabCount)
    }

    func colorForTab(_ index: Int) -> UIColor {
        let whiteMix = 0.4 * (CGFloat(index) / CGFloat(dittoStore.categoryCount))
        let rbComponent = min(1, 0.6 + whiteMix)
        return UIColor(red: rbComponent, green: whiteMix * 1.7, blue: rbComponent, alpha: 1)
    }

    // MARK: - Row Selection

    var selectedIndexPath: IndexPath {
        IndexPath(row: selectedRow, section: 0)
    }

    func selectRow(_ row: Int) {
        guard selectedRow != row else { return }

        if selectedRow >= 0, let cell = tableView.cellForRow(at: selectedIndexPath),
           var config = cell.contentConfiguration as? UIListContentConfiguration {
            config.textProperties.numberOfLines = 2
            cell.contentConfiguration = config
        }

        selectedRow = row
        if let cell = tableView.cellForRow(at: selectedIndexPath),
           var config = cell.contentConfiguration as? UIListContentConfiguration {
            config.textProperties.numberOfLines = 0
            cell.contentConfiguration = config
        }

        tableView.beginUpdates()
        tableView.endUpdates()
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        dittoStore.isEmpty ? 0 : dittoStore.dittoCount(inCategoryAt: selectedTab)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DittoCell", for: indexPath)
        let text = dittoStore.dittoPreview(inCategoryAt: selectedTab, at: indexPath.row)
        var config = cell.defaultContentConfiguration()
        config.text = text
        config.textProperties.font = .systemFont(ofSize: UIFont.labelFontSize)
        config.textProperties.numberOfLines = selectedRow == indexPath.row ? 0 : 2
        cell.contentConfiguration = config
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let proxy = textDocumentProxy
        let item = dittoStore.ditto(inCategoryAt: selectedTab, at: indexPath.row)
        tableView.deselectRow(at: indexPath, animated: true)

        let (cleanText, cursorRewind) = item.processedTextForInsertion()
        proxy.insertText(cleanText)
        DispatchQueue.main.async {
            proxy.adjustTextPosition(byCharacterOffset: -cursorRewind)
        }
    }

    @IBAction private func dittoLongPressed(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        let p = sender.location(in: tableView)
        if let indexPath = tableView.indexPathForRow(at: p) {
            selectRow(indexPath.row)
        }
    }

    // MARK: - Button Actions

    @IBAction private func nextKeyboardButtonClicked() {
        advanceToNextInputMode()
    }

    @IBAction private func dittoButtonClicked() {
        guard !dittoStore.isEmpty else { return }

        if addDittoView.isHidden {
            loadAddDittoView()
            addDittoView.isHidden = false
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            selectedTabArrow.isHidden = true
            CATransaction.commit()
        } else {
            addDittoView.isHidden = true
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            selectedTabArrow.isHidden = false
            CATransaction.commit()
        }
    }

    @IBAction private func returnButtonClicked() { textDocumentProxy.insertText("\n") }

    @IBAction private func backspaceButtonDown() {
        backspaceFire()
        backspaceTimer = DelayedRepeatTimer(delay: 0.5, interval: 0.1) { [weak self] in self?.backspaceFire() }
    }

    @IBAction private func backspaceButtonUp() { backspaceTimer?.invalidate(); backspaceTimer = nil }
    @IBAction private func spaceButtonClicked() { textDocumentProxy.insertText(" ") }

    @IBAction private func numberClicked(_ button: UIButton) {
        if let char = button.titleLabel?.text { textDocumentProxy.insertText(char) }
    }

    @IBAction private func pasteButtonClicked(_ sender: UIButton) {
        if let text = UIPasteboard.general.string { addDittoTextInput.text = text }
    }

    @IBAction private func addDittoButtonClicked(_ sender: UIButton) {
        guard addDittoTextInput.text != addDittoTextInputPlaceholder else { return }
        let categoryIndex = categoryPicker.selectedRow(inComponent: 0)
        dittoStore.addDitto(text: addDittoTextInput.text, toCategoryAt: categoryIndex)
        tableView.reloadData()
        addDittoButton.setTitle("Your ditto has been saved!", for: .normal)
        addDittoButton.isEnabled = false
    }

    @IBAction private func categoryBarTapped(_ sender: UITapGestureRecognizer) {
        guard UIPasteboard.general.string != nil else { return }

        if categoryPicker.isHidden {
            selectedCategory.text = "Done"
            categoryPicker.isHidden = false
            addDittoButtons.isHidden = true
            addDittoTextView.isHidden = true
        } else {
            selectedCategory.text = selectedCategoryFromPicker()
            categoryPicker.isHidden = true
            addDittoButtons.isHidden = false
            addDittoTextView.isHidden = false
        }
    }

    // MARK: - Helpers

    func truncateToLastFullLetter(_ label: UILabel, width: CGFloat) {
        guard var text = label.text else { return }
        while label.intrinsicContentSize.width > width, !text.isEmpty {
            text = String(text.dropLast())
            label.text = text
        }
    }

    @objc func backspaceFire() {
        textDocumentProxy.deleteBackward()
    }

    func selectedCategoryFromPicker() -> String {
        let index = categoryPicker.selectedRow(inComponent: 0)
        return dittoStore.categoryTitle(at: index)
    }

    var keyboardHeight: CGFloat {
        let bounds = screenBounds
        if bounds.width > bounds.height {
            return bounds.height * 0.6
        } else {
            return min(260, bounds.height * 0.7)
        }
    }

    var tabBarHeight: CGFloat {
        dittoStore.hasOneCategory ? 0 : 35
    }

    func resetAddDittoButton() {
        addDittoButton.setTitle("Add Ditto", for: .normal)
        addDittoButton.isEnabled = true
    }

    @objc func pollPasteboard() {
        if let text = UIPasteboard.general.string {
            if text != addDittoTextInput.text {
                addDittoTextInput.text = text
                resetAddDittoButton()
            }
        } else {
            addDittoTextInput.text = addDittoTextInputPlaceholder
        }
    }
}

// MARK: - Appearance

extension KeyboardViewController {

    static let keyboardBg = UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.14, alpha: 1) : UIColor(white: 0.86, alpha: 1)
    })

    func setupAppearance() {
        let bg = Self.keyboardBg
        let actionBg = UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark ? UIColor(white: 0.24, alpha: 1) : UIColor(white: 0.68, alpha: 1)
        })
        let inputBg = UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark ? UIColor(white: 0.40, alpha: 1) : UIColor(white: 0.98, alpha: 1)
        })
        let iconTint = UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark ? UIColor(white: 0.95, alpha: 1) : UIColor(white: 0.1, alpha: 1)
        })
        // Override every XIB-hardcoded white surface
        for v in [view, keyboardView, numericKeys, addDittoView, addDittoButtons] { v?.backgroundColor = bg }
        tableView.backgroundColor = .clear
        bottomBar.backgroundColor = UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark ? UIColor(white: 0.18, alpha: 1) : UIColor(white: 0.82, alpha: 1)
        })
        // Add-ditto panel
        for tv in [addDittoTextInput, addDittoTextView] { tv?.backgroundColor = inputBg; tv?.textColor = .label }
        selectedCategory.backgroundColor = actionBg
        selectedCategory.textColor = .white
        addDittoButton.backgroundColor = actionBg
        addDittoButton.setTitleColor(iconTint, for: .normal)
        addDittoButton.setTitleColor(iconTint.withAlphaComponent(0.4), for: .disabled)
        categoryPicker.backgroundColor = bg
        // SF Symbol bottom-bar buttons
        let sym = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        for (button, name) in [(nextKeyboardButton, "globe"), (backspaceButton, "delete.backward"),
                               (returnButton, "return"), (dittoButton, "plus")] {
            button?.setImage(UIImage(systemName: name, withConfiguration: sym), for: .normal)
            button?.tintColor = iconTint
            button?.backgroundColor = actionBg
        }
        spaceButton.setImage(nil, for: .normal)
        spaceButton.backgroundColor = inputBg
        spaceButton.setTitleColor(iconTint, for: .normal)
        // Arrow colour = keyboard bg, creating a notch effect regardless of mode
        let arrow = bg.resolvedColor(with: traitCollection).cgColor
        selectedTabArrow.fillColor = arrow
        selectedTabArrow.strokeColor = arrow
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        setupAppearance()
        refreshTabButtons()
    }
}
