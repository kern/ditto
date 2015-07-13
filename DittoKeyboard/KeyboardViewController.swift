import UIKit

class KeyboardViewController: UIInputViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet var keyboardView: UIView!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var infoView: UIView!
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
    
    @IBOutlet var addDittoTextInput: UITextView!
    @IBOutlet var addDittoView: UIView!
    @IBOutlet var categoryPicker: UIPickerView!
    @IBOutlet var addDittoTextView: UIScrollView!
    @IBOutlet var selectedCategory: UILabel!
    @IBOutlet var addDittoButtons: UIView!
    
    var keyboardHeightConstraint: NSLayoutConstraint!
    @IBOutlet var tabBarHeightConstraint: NSLayoutConstraint!
    
    let dittoStore: DittoStore
    let addDittoViewController = AddDittoFromClipboardViewController()
    var backspaceTimer: DelayedRepeatTimer!
    
    let ADD_DITTO_TEXT_INPUT_PLACEHOLDERS = [
        "PASTE_TEXT": "Copy desired text and click paste...",
        "DITTO_ADDED": "New ditto has been added."
    ]
    
    var tabViews: [UIView]
    var selectedTab: Int
    var selectedRow: Int
    
    init() {
        dittoStore = DittoStore()
        tabViews = []
        selectedTab = -1
        selectedRow = -1
        super.init(nibName: "KeyboardViewController", bundle: nil)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        keyboardHeightConstraint = NSLayoutConstraint(item: keyboardView,
            attribute: .Height,
            relatedBy: .Equal,
            toItem: nil,
            attribute: .NotAnAttribute,
            multiplier: 0,
            constant: getHeightForKeyboard())
        
        bottomBar.backgroundColor = UIColor(white: 0.85, alpha: 1)
        tableView.registerClass(ObjectTableViewCell.classForCoder(), forCellReuseIdentifier: "ObjectTableViewCell")
        
        categoryPicker.delegate = addDittoViewController
        categoryPicker.dataSource = addDittoViewController
        
        let tapGesture = UITapGestureRecognizer(target: self, action: Selector("tabDragged:"))
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: Selector("tabDragged:"))
        let panGesture = UIPanGestureRecognizer(target: self, action: Selector("tabDragged:"))
        tabBar.addGestureRecognizer(tapGesture)
        tabBar.addGestureRecognizer(longPressGesture)
        tabBar.addGestureRecognizer(panGesture)
        
        loadTab(0)
        
    }
    
    override func viewWillAppear(animated: Bool) {
        
        super.viewWillAppear(animated)
        
        // Keyboard height constraint must be added here rather than ViewDidLoad
        keyboardView.addConstraint(keyboardHeightConstraint)
        
        if dittoStore.isEmpty() {
            noDittosLabel.hidden = false
            tableView.hidden = true
        } else {
            noDittosLabel.hidden = true
            tableView.hidden = false
            dittoStore.reload()
            tableView.reloadData()
        }
    
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        keyboardHeightConstraint.constant = getHeightForKeyboard()
        tabBarHeightConstraint.constant = getHeightForTabBar()
        refreshTabButtons()
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    
    func loadAddDittoView() {
        categoryPicker.hidden = true
        selectedCategory.text = selectedCategoryFromPicker()
        addDittoTextInput.text = ADD_DITTO_TEXT_INPUT_PLACEHOLDERS["PASTE_TEXT"]
    }
    
    override func textDidChange(textInput: UITextInput) {
        let proxy = textDocumentProxy as! UITextDocumentProxy
        
        switch proxy.keyboardType! {
        case .NumberPad:
            numericKeys.hidden = false
            spaceButton.hidden = true
            returnButton.hidden = true
            decimalButton.hidden = true
            addDittoView.hidden = true

        case .DecimalPad:
            numericKeys.hidden = false
            spaceButton.hidden = true
            returnButton.hidden = true
            decimalButton.hidden = false
            addDittoView.hidden = true
            
        default:
            numericKeys.hidden = true
            spaceButton.hidden = false
            returnButton.hidden = false
            decimalButton.hidden = false
            addDittoView.hidden = true
            
        }
    }
    
    //==============
    // MARK: - Tabs
    
    func tabDragged(recognizer: UIGestureRecognizer) {
        
        let tab = Int(floor(recognizer.locationInView(tabBar).x / tabWidth()))
        
        addDittoView.hidden = true
        numericKeys.hidden = true
        tableView.hidden = false
        
        loadTab(tab)
        tabTitleLabel.hidden = dittoStore.oneCategory() || recognizer.state == .Ended
        view.setNeedsLayout()
    
    }
    
    func loadTab(tab: Int) {
        if selectedTab == tab { return }
        selectedTab = tab
        selectedRow = -1
        tabTitleLabel.text = dittoStore.getCategory(selectedTab)
        tabTitleLabel.backgroundColor = colorForTab(selectedTab)
        tableView.reloadData()
    }
    
    func refreshTabButtons() {
        
        if dittoStore.oneCategory() {
            return
        }
        
        for tv in tabViews {
            tv.removeFromSuperview()
        }
        
        let w = tabWidth()
        let h = tabBar.bounds.height
        
        tabViews = (0..<countTabs()).map({ i in
            
            let button = UIView(frame: CGRectMake(CGFloat(i) * w, 0, w, h))
            button.backgroundColor = self.colorForTab(i)
            self.tabBar.addSubview(button)
            return button
            
        })
        
        tabBar.bringSubviewToFront(tabTitleLabel)
        
    }
    
    func countTabs() -> Int {
        return dittoStore.countCategories()
    }
    
    func tabWidth() -> CGFloat {
        return UIScreen.mainScreen().bounds.width / CGFloat(countTabs())
    }
    
    func colorForTab(index: Int) -> UIColor {
        let whiteMix = 0.4 * (CGFloat(index) / CGFloat(dittoStore.countCategories()))
        let rbComponent = min(1, 0.6 + whiteMix)
        return UIColor(red: rbComponent, green: whiteMix, blue: rbComponent, alpha: 1)
    }
    
    //=======================
    // MARK: - Row Selection
    
    var selectedIndexPath: NSIndexPath {
        return NSIndexPath(forRow: selectedRow, inSection: 0)
    }
    
    func selectRow(row: Int) {
        
        if selectedRow == row { return }
        
        if selectedRow >= 0 {
            let cell = tableView.cellForRowAtIndexPath(selectedIndexPath) as? ObjectTableViewCell
            cell?.truncated = true
        }
        
        selectedRow = row
        let cell = tableView.cellForRowAtIndexPath(selectedIndexPath) as! ObjectTableViewCell
        cell.truncated = false
        
        tableView.beginUpdates()
        tableView.endUpdates()

    }
    
    //==============================
    // MARK: - Table View Callbacks
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if dittoStore.isEmpty() {
            return 0
        } else {
            return dittoStore.countInCategory(selectedTab)
        }
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        var text = dittoStore.getDittoPreviewInCategory(selectedTab, index: indexPath.row)
        return ObjectTableViewCell.heightForText(text, truncated: selectedRow != indexPath.row, disclosure: false)
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("ObjectTableViewCell", forIndexPath: indexPath) as! ObjectTableViewCell
        let text = dittoStore.getDittoPreviewInCategory(selectedTab, index: indexPath.row)
        cell.setText(text, disclosure: false)
        cell.truncated = selectedRow != indexPath.row
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        let proxy = textDocumentProxy as! UITextDocumentProxy
        let ditto = dittoStore.getDittoInCategory(selectedTab, index: indexPath.row)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        let (newDitto, cursorRewind) = findCursorRange(ditto)
        proxy.insertText(newDitto)
        dispatch_async(dispatch_get_main_queue(), {
            proxy.adjustTextPositionByCharacterOffset(-cursorRewind)
        })
        
    }
    
    @IBAction func dittoLongPressed(sender: UILongPressGestureRecognizer) {
        if sender.state != .Began { return }
        let p = sender.locationInView(tableView)
        if let indexPath = tableView.indexPathForRowAtPoint(p) {
            selectRow(indexPath.row)
        }
    }
    
    //==========================
    // MARK: - Button Callbacks
    
    @IBAction func nextKeyboardButtonClicked() {
        advanceToNextInputMode()
    }
    
    @IBAction func dittoButtonClicked() {
        if dittoStore.isEmpty() {
            return
        } else if addDittoView.hidden && numericKeys.hidden {
            loadAddDittoView()
            addDittoView.hidden = false
        } else if !addDittoView.hidden {
            addDittoView.hidden = true
            numericKeys.hidden = false
        } else if !numericKeys.hidden {
            numericKeys.hidden = true
            tableView.hidden = false
        }
    }
    
    @IBAction func returnButtonClicked() {
        let proxy = textDocumentProxy as! UITextDocumentProxy
        proxy.insertText("\n")
    }
    
    @IBAction func backspaceButtonDown() {
        backspaceFire()
        backspaceTimer = DelayedRepeatTimer(delay: 0.5, ti: 0.1, target: self, selector: Selector("backspaceFire"))
    }
    
    @IBAction func backspaceButtonUp() {
        backspaceTimer.invalidate()
        backspaceTimer = nil
    }
    
    @IBAction func spaceButtonClicked() {
        let proxy = textDocumentProxy as! UITextDocumentProxy
        proxy.insertText(" ")
    }
    
    @IBAction func numberClicked(button: UIButton) {
        let proxy = textDocumentProxy as! UITextDocumentProxy
        let char = button.titleLabel?.text
        proxy.insertText(char!)
    }
    
    @IBAction func pasteButtonClicked(sender: UIButton) {
        if let pasteBoardString = UIPasteboard.generalPasteboard().string {
            addDittoTextInput.text = pasteBoardString
        }
    }
    
    @IBAction func addDittoButtonClicked(sender: UIButton) {
        if !contains(ADD_DITTO_TEXT_INPUT_PLACEHOLDERS.values.array, addDittoTextInput.text) {
            let categoryIndex = categoryPicker.selectedRowInComponent(0)
            dittoStore.addDittoToCategory(categoryIndex, text: addDittoTextInput.text!)
            addDittoTextInput.text = ADD_DITTO_TEXT_INPUT_PLACEHOLDERS["DITTO_ADDED"]
        }
    }
    
    @IBAction func categoryBarTapped(sender: UITapGestureRecognizer) {
        if categoryPicker.hidden {
            selectedCategory.text = "Done"
            categoryPicker.hidden = false
            addDittoButtons.hidden = true
            addDittoTextView.hidden = true
        } else {
            selectedCategory.text = selectedCategoryFromPicker()
            categoryPicker.hidden = true
            addDittoButtons.hidden = false
            addDittoTextView.hidden = false
        }
    }
    //=================
    // MARK: - Helpers
    
    func backspaceFire() {
        let proxy = textDocumentProxy as! UITextDocumentProxy
        proxy.deleteBackward()
    }
    
    func findCursorRange(s: String) -> (String, Int) {
        let length = count(s)
        let regex = NSRegularExpression(pattern: "___+", options: nil, error: nil)!
        let match = regex.rangeOfFirstMatchInString(s, options: nil, range: NSMakeRange(0, length))
        
        if (match.location == NSNotFound) {
            return (s, 0)
        } else {
            let start = advance(s.startIndex, match.location)
            let end = advance(start, match.length)
            let range = Range(start: start, end: end)
            let newS = s.stringByReplacingCharactersInRange(range, withString: "")
            return (newS, length - match.location - match.length)
        }
    }
    
    func selectedCategoryFromPicker() -> String {
        let categoryIndex = categoryPicker.selectedRowInComponent(0)
        return dittoStore.getCategory(categoryIndex)
    }
    
    func getHeightForKeyboard() -> CGFloat {
        
        let screenHeight = UIScreen.mainScreen().bounds.height
        let screenWidth = UIScreen.mainScreen().bounds.width
        
        if screenWidth > screenHeight {
            return screenHeight * 0.6
        } else {
            return min(260, screenHeight * 0.7)
        }
        
    }
    
    func getHeightForTabBar() -> CGFloat {
        if dittoStore.oneCategory() {
            return 0
        } else {
            return 35
        }
    }
}
