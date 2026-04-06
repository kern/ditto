import UIKit

final class KeyboardViewController: UIInputViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet var keyboardView: UIView!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var numericKeys: UIView!
    @IBOutlet var bottomBar: UIView!
    @IBOutlet var tabBar: UIView!
    @IBOutlet var noDittosLabel: UILabel!
    @IBOutlet var tabTitleLabel: UILabel!

    @IBOutlet var backspaceButton: UIButton!
    @IBOutlet var nextKeyboardButton: UIButton!
    @IBOutlet var returnButton: UIButton!
    @IBOutlet var spaceButton: UIButton!
    @IBOutlet var decimalButton: UIButton!
    @IBOutlet var dittoButton: UIButton!

    @IBOutlet var addDittoTextInput: UITextView!
    @IBOutlet var addDittoView: UIView!
    @IBOutlet var categoryPicker: UIPickerView!
    @IBOutlet var addDittoTextView: UITextView!
    @IBOutlet var selectedCategory: UILabel!
    @IBOutlet var addDittoButtons: UIView!
    @IBOutlet var addDittoButton: UIButton!

    var keyboardHeightConstraint: NSLayoutConstraint!
    @IBOutlet var tabBarHeightConstraint: NSLayoutConstraint!

    let dittoStore: PendingDittoStore
    let addDittoViewController = AddDittoFromClipboardViewController()
    var backspaceTimer: DelayedRepeatTimer?
    let defaults = UserDefaults(suiteName: "group.io.kern.ditto")!

    let addDittoTextInputPlaceholder = "Select and copy desired text... if it doesn't appear, you may need to turn on \"Allow Full Access\" in your device's keyboard settings."

    var tabViews: [UIView] = []
    var selectedTab: Int = -1
    var selectedRow: Int = -1
    var selectedTabArrow = CAShapeLayer()

    init() {
        dittoStore = PendingDittoStore()
        super.init(nibName: "KeyboardViewController", bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        keyboardHeightConstraint = NSLayoutConstraint(
            item: keyboardView!,
            attribute: .height,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 0,
            constant: keyboardHeight
        )

        bottomBar.backgroundColor = UIColor(white: 0.85, alpha: 1)
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

        let shape = CAShapeLayer()
        tabBar.layer.addSublayer(shape)
        shape.opacity = 1
        shape.lineWidth = 0
        shape.lineJoin = .miter
        shape.strokeColor = UIColor.white.cgColor
        shape.fillColor = UIColor.white.cgColor
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

    var tabWidth: CGFloat {
        UIScreen.main.bounds.width / CGFloat(tabCount)
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

        if selectedRow >= 0, let cell = tableView.cellForRow(at: selectedIndexPath) {
            cell.textLabel?.numberOfLines = 2
        }

        selectedRow = row
        if let cell = tableView.cellForRow(at: selectedIndexPath) {
            cell.textLabel?.numberOfLines = 0
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
        cell.textLabel?.text = text
        cell.textLabel?.font = .systemFont(ofSize: UIFont.labelFontSize)
        cell.textLabel?.numberOfLines = selectedRow == indexPath.row ? 0 : 2
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

    @IBAction func dittoLongPressed(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        let p = sender.location(in: tableView)
        if let indexPath = tableView.indexPathForRow(at: p) {
            selectRow(indexPath.row)
        }
    }

    // MARK: - Button Actions

    @IBAction func nextKeyboardButtonClicked() {
        advanceToNextInputMode()
    }

    @IBAction func dittoButtonClicked() {
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

    @IBAction func returnButtonClicked() {
        textDocumentProxy.insertText("\n")
    }

    @IBAction func backspaceButtonDown() {
        backspaceFire()
        backspaceTimer = DelayedRepeatTimer(delay: 0.5, interval: 0.1) { [weak self] in
            self?.backspaceFire()
        }
    }

    @IBAction func backspaceButtonUp() {
        backspaceTimer?.invalidate()
        backspaceTimer = nil
    }

    @IBAction func spaceButtonClicked() {
        textDocumentProxy.insertText(" ")
    }

    @IBAction func numberClicked(_ button: UIButton) {
        if let char = button.titleLabel?.text {
            textDocumentProxy.insertText(char)
        }
    }

    @IBAction func pasteButtonClicked(_ sender: UIButton) {
        if let text = UIPasteboard.general.string {
            addDittoTextInput.text = text
        }
    }

    @IBAction func addDittoButtonClicked(_ sender: UIButton) {
        guard addDittoTextInput.text != addDittoTextInputPlaceholder else { return }
        let categoryIndex = categoryPicker.selectedRow(inComponent: 0)
        dittoStore.addDitto(text: addDittoTextInput.text, toCategoryAt: categoryIndex)
        tableView.reloadData()
        addDittoButton.setTitle("Your ditto has been saved!", for: .normal)
        addDittoButton.isEnabled = false
    }

    @IBAction func categoryBarTapped(_ sender: UITapGestureRecognizer) {
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
        let screenHeight = UIScreen.main.bounds.height
        let screenWidth = UIScreen.main.bounds.width

        if screenWidth > screenHeight {
            return screenHeight * 0.6
        } else {
            return min(260, screenHeight * 0.7)
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
