import UIKit

final class KeyboardViewController: UIInputViewController,
    UITableViewDelegate, UITableViewDataSource,
    UIPickerViewDelegate, UIPickerViewDataSource {

    // MARK: - Subviews

    let keyboardView = UIView()
    let tabBar = UIView()
    let tabTitleLabel = UILabel()
    let tableView = UITableView(frame: .zero, style: .plain)
    let noDittosLabel = UILabel()
    let addDittoView = UIView()
    let categoryButton = UIButton(type: .system)
    let addDittoTextView = UITextView()
    let addDittoActionsRow = UIView()
    let addDittoButton = UIButton(type: .system)
    let pasteButton = UIButton(type: .system)
    let categoryPicker = UIPickerView()
    let numericKeys = UIView()
    let bottomBar = UIView()
    let nextKeyboardButton = UIButton(type: .system)
    let dittoButton = UIButton(type: .system)
    let spaceButton = UIButton(type: .system)
    let returnButton = UIButton(type: .system)
    let backspaceButton = UIButton(type: .system)
    var decimalButton = UIButton(type: .system)
    let actionsRowDivider = UIView()

    var keyboardHeightConstraint: NSLayoutConstraint!
    var tabBarHeightConstraint: NSLayoutConstraint!

    // MARK: - State

    let dittoStore = PendingDittoStore()
    var backspaceTimer: DelayedRepeatTimer?
    var tabViews: [UIView] = []
    var selectedTab: Int = -1
    var selectedRow: Int = -1
    var selectedTabArrow = CAShapeLayer()
    var pasteboardPollTimer: Timer?

    // MARK: - Colors

    static let bgColor = UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.14, alpha: 1) : UIColor(white: 0.86, alpha: 1)
    })
    static let actionColor = UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.26, alpha: 1) : UIColor(white: 0.65, alpha: 1)
    })
    static let inputColor = UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.22, alpha: 1) : UIColor(white: 1.0, alpha: 1)
    })
    static let iconTint = UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.95, alpha: 1) : UIColor(white: 0.1, alpha: 1)
    })

    // MARK: - Init

    init() { super.init(nibName: nil, bundle: nil) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        UserDefaults(suiteName: "group.io.kern.ditto")?.set(true, forKey: "keyboardHasLoaded")
        buildLayout()
        applyColors()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DittoCell")
        categoryPicker.delegate = self
        categoryPicker.dataSource = self
        setupGestures()
        loadTab(0)
        selectedTabArrow = drawSelectedTabArrow(0)
        addDittoView.isHidden = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if dittoStore.isEmpty {
            noDittosLabel.isHidden = false; tableView.isHidden = true
        } else {
            noDittosLabel.isHidden = true; tableView.isHidden = false
            tableView.reloadData()
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        keyboardHeightConstraint.constant = keyboardHeight
        tabBarHeightConstraint.constant = tabBarHeight
        refreshTabButtons()
        tableView.beginUpdates(); tableView.endUpdates()
    }

    override func traitCollectionDidChange(_ prev: UITraitCollection?) {
        super.traitCollectionDidChange(prev)
        guard prev?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        applyColors(); refreshTabButtons()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        switch textDocumentProxy.keyboardType {
        case .numberPad:
            numericKeys.isHidden = false; spaceButton.isHidden = true
            returnButton.isHidden = true; decimalButton.isHidden = true; dittoButton.isHidden = true
        case .decimalPad:
            numericKeys.isHidden = false; spaceButton.isHidden = true
            returnButton.isHidden = true; decimalButton.isHidden = false; dittoButton.isHidden = true
        default:
            numericKeys.isHidden = true; spaceButton.isHidden = false
            returnButton.isHidden = false; decimalButton.isHidden = true; dittoButton.isHidden = false
        }
    }

    // MARK: - Gestures

    func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(tabDragged(_:)))
        let long = UILongPressGestureRecognizer(target: self, action: #selector(tabDragged(_:)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(tabDragged(_:)))
        tabBar.addGestureRecognizer(tap)
        tabBar.addGestureRecognizer(long)
        tabBar.addGestureRecognizer(pan)

        let tableLong = UILongPressGestureRecognizer(target: self, action: #selector(tableLongPressed(_:)))
        tableView.addGestureRecognizer(tableLong)

        let catTap = UITapGestureRecognizer(target: self, action: #selector(categoryBarTapped))
        categoryButton.addGestureRecognizer(catTap)
    }

    // MARK: - Tabs

    @objc func tabDragged(_ recognizer: UIGestureRecognizer) {
        let tab = Int(floor(recognizer.location(in: tabBar).x / tabWidth))
        if addDittoView.isHidden {
            loadTab(tab)
            selectedTabArrow.isHidden = false
        } else {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            loadTab(tab); selectedTabArrow.isHidden = false
            CATransaction.commit()
        }
        addDittoView.isHidden = true; numericKeys.isHidden = true; tableView.isHidden = false
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

    func refreshTabButtons() {
        guard !dittoStore.isEmpty, !dittoStore.hasOneCategory else { return }
        tabViews.forEach { $0.removeFromSuperview() }
        let w = tabWidth; let h = tabBar.bounds.height
        tabViews = (0..<tabCount).map { i in
            let tab = UIView(frame: CGRect(x: CGFloat(i) * w, y: 0, width: w, height: h))
            tab.backgroundColor = colorForTab(i)
            let lbl = UILabel(frame: CGRect(x: 8, y: 0, width: w - 16, height: h))
            lbl.textColor = .white; lbl.text = dittoStore.categoryTitle(at: i)
            lbl.font = lbl.font.withSize(14); lbl.textAlignment = .center
            lbl.lineBreakMode = .byClipping; truncateToLastFullLetter(lbl, width: w - 16)
            tab.addSubview(lbl); tabBar.addSubview(tab); return tab
        }
        tabBar.bringSubviewToFront(tabTitleLabel)
        moveSelectedTabArrow(selectedTab)
    }

    func selectedTabArrowPath() -> CGPath {
        let h = tabBar.bounds.height
        let path = UIBezierPath()
        path.move(to: CGPoint(x: -7, y: h))
        path.addLine(to: CGPoint(x: 7, y: h))
        path.addLine(to: CGPoint(x: 0, y: h - 7))
        path.close(); return path.cgPath
    }

    func moveSelectedTabArrow(_ tab: Int) {
        selectedTabArrow.position = CGPoint(x: (CGFloat(tab) + 0.5) * tabWidth, y: 0)
    }

    func drawSelectedTabArrow(_ tab: Int) -> CAShapeLayer {
        guard !dittoStore.isEmpty, !dittoStore.hasOneCategory else { return CAShapeLayer() }
        let arrowColor = Self.bgColor.resolvedColor(with: traitCollection).cgColor
        let shape = CAShapeLayer()
        tabBar.layer.addSublayer(shape)
        shape.opacity = 1; shape.lineWidth = 0; shape.lineJoin = .miter
        shape.strokeColor = arrowColor; shape.fillColor = arrowColor
        shape.path = selectedTabArrowPath(); shape.zPosition = 1
        return shape
    }

    var tabCount: Int { dittoStore.categoryCount }

    private var screenBounds: CGRect {
        view.window?.windowScene?.screen.bounds ?? UIScreen.main.bounds
    }

    var tabWidth: CGFloat { screenBounds.width / CGFloat(tabCount) }

    func colorForTab(_ index: Int) -> UIColor {
        let mix = 0.4 * (CGFloat(index) / CGFloat(dittoStore.categoryCount))
        let rb = min(1, 0.6 + mix)
        return UIColor(red: rb, green: mix * 1.7, blue: rb, alpha: 1)
    }

    // MARK: - Row Selection

    var selectedIndexPath: IndexPath { IndexPath(row: selectedRow, section: 0) }

    func selectRow(_ row: Int) {
        guard selectedRow != row else { return }
        if selectedRow >= 0, let cell = tableView.cellForRow(at: selectedIndexPath),
           var cfg = cell.contentConfiguration as? UIListContentConfiguration {
            cfg.textProperties.numberOfLines = 2; cell.contentConfiguration = cfg
        }
        selectedRow = row
        if let cell = tableView.cellForRow(at: selectedIndexPath),
           var cfg = cell.contentConfiguration as? UIListContentConfiguration {
            cfg.textProperties.numberOfLines = 0; cell.contentConfiguration = cfg
        }
        tableView.beginUpdates(); tableView.endUpdates()
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        dittoStore.isEmpty ? 0 : dittoStore.dittoCount(inCategoryAt: selectedTab)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DittoCell", for: indexPath)
        let text = dittoStore.dittoPreview(inCategoryAt: selectedTab, at: indexPath.row)
        var cfg = cell.defaultContentConfiguration()
        cfg.text = text
        cfg.textProperties.font = .systemFont(ofSize: UIFont.labelFontSize)
        cfg.textProperties.numberOfLines = selectedRow == indexPath.row ? 0 : 2
        cell.contentConfiguration = cfg
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let proxy = textDocumentProxy
        let item = dittoStore.ditto(inCategoryAt: selectedTab, at: indexPath.row)
        tableView.deselectRow(at: indexPath, animated: true)
        let (cleanText, cursorRewind) = item.processedTextForInsertion()
        proxy.insertText(cleanText)
        DispatchQueue.main.async { proxy.adjustTextPosition(byCharacterOffset: -cursorRewind) }
    }

    @objc private func tableLongPressed(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        if let ip = tableView.indexPathForRow(at: sender.location(in: tableView)) { selectRow(ip.row) }
    }

    // MARK: - Button Actions

    @objc func nextKeyboardButtonClicked() { advanceToNextInputMode() }

    @objc func dittoButtonClicked() {
        guard !dittoStore.isEmpty else { return }
        if addDittoView.isHidden {
            loadAddDittoView(); addDittoView.isHidden = false
            CATransaction.begin(); CATransaction.setDisableActions(true)
            selectedTabArrow.isHidden = true; CATransaction.commit()
        } else {
            addDittoView.isHidden = true
            CATransaction.begin(); CATransaction.setDisableActions(true)
            selectedTabArrow.isHidden = false; CATransaction.commit()
        }
    }

    @objc func returnButtonClicked() { textDocumentProxy.insertText("\n") }

    @objc func backspaceButtonDown() {
        backspaceFire()
        backspaceTimer = DelayedRepeatTimer(delay: 0.5, interval: 0.1) { [weak self] in self?.backspaceFire() }
    }

    @objc func backspaceButtonUp() { backspaceTimer?.invalidate(); backspaceTimer = nil }
    @objc func spaceButtonClicked() { textDocumentProxy.insertText(" ") }

    @objc func numberClicked(_ button: UIButton) {
        if let char = button.titleLabel?.text { textDocumentProxy.insertText(char) }
    }

    @objc func pasteButtonClicked() {
        if let text = UIPasteboard.general.string { addDittoTextView.text = text }
    }

    @objc func addDittoButtonClicked() {
        guard !addDittoTextView.text.isEmpty else { return }
        let index = categoryPicker.selectedRow(inComponent: 0)
        dittoStore.addDitto(text: addDittoTextView.text, toCategoryAt: index)
        tableView.reloadData()
        addDittoButton.setTitle("Saved!", for: .normal)
        addDittoButton.isEnabled = false
    }

    @objc func categoryBarTapped() {
        guard UIPasteboard.general.string != nil else { return }
        if categoryPicker.isHidden {
            setCategoryButtonTitle("Done")
            categoryPicker.isHidden = false
            addDittoActionsRow.isHidden = true
            addDittoTextView.isHidden = true
        } else {
            setCategoryButtonTitle(selectedCategoryFromPicker())
            categoryPicker.isHidden = true
            addDittoActionsRow.isHidden = false
            addDittoTextView.isHidden = false
        }
    }

    // MARK: - UIPickerViewDataSource

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        dittoStore.isEmpty ? 1 : dittoStore.categoryCount
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        dittoStore.isEmpty ? "General" : dittoStore.categoryTitle(at: row)
    }

    // MARK: - Helpers

    func loadAddDittoView() {
        categoryPicker.isHidden = true
        addDittoTextView.isHidden = false
        addDittoActionsRow.isHidden = false
        setCategoryButtonTitle(selectedCategoryFromPicker())
        addDittoButton.setTitle("Add Ditto", for: .normal)
        addDittoButton.isEnabled = true
        pasteboardPollTimer?.invalidate()
        pasteboardPollTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.pollPasteboard()
        }
        pollPasteboard()
    }

    @objc func pollPasteboard() {
        let text = UIPasteboard.general.string ?? ""
        if text != addDittoTextView.text { addDittoTextView.text = text }
    }

    func selectedCategoryFromPicker() -> String {
        dittoStore.categoryTitle(at: categoryPicker.selectedRow(inComponent: 0))
    }

    func setCategoryButtonTitle(_ title: String) {
        let img = UIImage(systemName: "chevron.up.chevron.down",
                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        var cfg = UIButton.Configuration.plain()
        cfg.title = title
        cfg.image = img
        cfg.imagePlacement = .trailing
        cfg.imagePadding = 6
        cfg.baseForegroundColor = Self.iconTint
        categoryButton.configuration = cfg
    }

    func truncateToLastFullLetter(_ label: UILabel, width: CGFloat) {
        guard var text = label.text else { return }
        while label.intrinsicContentSize.width > width, !text.isEmpty {
            text = String(text.dropLast()); label.text = text
        }
    }

    @objc func backspaceFire() { textDocumentProxy.deleteBackward() }

    var keyboardHeight: CGFloat {
        let b = screenBounds
        return b.width > b.height ? b.height * 0.6 : min(260, b.height * 0.7)
    }

    var tabBarHeight: CGFloat { dittoStore.hasOneCategory ? 0 : 35 }
}
