import UIKit

class KeyboardViewController: UIInputViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet var keyboardView: UIView!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var infoView: UIView!
    @IBOutlet var numericKeys: UIView!
    @IBOutlet var bottomBar: UIView!
    @IBOutlet var tabBar: UIView!
    
    @IBOutlet var backspaceButton: UIButton!
    @IBOutlet var nextKeyboardButton: UIButton!
    @IBOutlet var returnButton: UIButton!
    @IBOutlet var spaceButton: UIButton!
    @IBOutlet var decimalButton: UIButton!
    
    @IBOutlet var addDittoView: UIView!
    @IBOutlet var categoryPicker: UIPickerView!
    @IBOutlet var addDittoTextInput: UILabel!
    @IBOutlet var addDittoTextView: UIScrollView!
    @IBOutlet var selectedCategory: UILabel!
    @IBOutlet var addDittoButtons: UIView!
    
    let dittoStore: DittoStore
    let addDittoViewController = AddDittoFromClipboardViewController()
    var backspaceTimer: DelayedRepeatTimer!
    let ADD_DITTO_TEXT_INPUT_PLACEHOLDER = "Copy desired text and click paste..."
    var heightConstraint: NSLayoutConstraint = NSLayoutConstraint()
    
    var tabViews: [UIView]
    var selectedTab: Int
    var selectedRow: Int
    
    init() {
        
        dittoStore = DittoStore()
        tabViews = []
        selectedTab = 0
        selectedRow = -1
        
        super.init(nibName: "KeyboardViewController", bundle: nil)
        
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
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
        
        refreshTabButtons()
        
    }
    
    override func viewWillAppear(animated: Bool) {
        
        super.viewWillAppear(animated)
        dittoStore.reload()
        tableView.reloadData()
        setKeyboardHeight()
        
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        resetKeyboardHeight()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        refreshTabButtons()
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    
    func loadAddDittoView() {
        categoryPicker.hidden = true
        selectedCategory.text = selectedCategoryFromPicker()
        addDittoTextInput.text = ADD_DITTO_TEXT_INPUT_PLACEHOLDER
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
        
        if selectedTab != tab {
            selectedTab = tab
            selectedRow = -1
            tableView.reloadData()
        }
    }
    
    func refreshTabButtons() {
        
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
        
    }
    
    func countTabs() -> Int {
        return dittoStore.countCategories()
    }
    
    func tabWidth() -> CGFloat {
        return UIScreen.mainScreen().bounds.width / CGFloat(countTabs())
    }
    
    func colorForTab(index: Int) -> UIColor {
        return UIColor(
            red: 0.6,
            green: 0,
            blue: 0.6,
            alpha: 1 - (CGFloat(index) / CGFloat(dittoStore.countCategories())))
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
        return dittoStore.countInCategory(selectedTab)
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
        if addDittoView.hidden && numericKeys.hidden {
            loadAddDittoView()
            addDittoView.hidden = false
        }
        else if !addDittoView.hidden {
            addDittoView.hidden = true
            numericKeys.hidden = false
        }
        else if !numericKeys.hidden {
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
        if addDittoTextInput.text != ADD_DITTO_TEXT_INPUT_PLACEHOLDER {
            let categoryIndex = categoryPicker.selectedRowInComponent(0)
            dittoStore.addDittoToCategory(categoryIndex, text: addDittoTextInput.text!)
          
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
    
    func setKeyboardHeight() {
        
        heightConstraint = NSLayoutConstraint(
            item: keyboardView,
            attribute: .Height,
            relatedBy: .Equal,
            toItem: nil,
            attribute: .NotAnAttribute,
            multiplier: 0.0,
            constant: getHeightForKeyboard())
        keyboardView.addConstraint(heightConstraint)
    }
    
    func resetKeyboardHeight() {
        heightConstraint.constant = getHeightForKeyboard()
    }
    
    func getHeightForKeyboard() -> CGFloat {
        
        let screenHeight = UIScreen.mainScreen().bounds.height
        let screenWidth = UIScreen.mainScreen().bounds.width
        var height: CGFloat
        
        if screenWidth > screenHeight {
            height = screenHeight * 0.6
        } else {
            height = min(260, screenHeight * 0.7)
        }
        
        return height
    }
}
