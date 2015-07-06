import UIKit

class KeyboardViewController: UIInputViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet var keyboardView: UIView!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var infoView: UIView!
    @IBOutlet var numericKeys: UIView!
    @IBOutlet var bottomBar: UIView!
    @IBOutlet var tabBar: UIView!
    @IBOutlet var addDittoView: UIView!
    
    @IBOutlet var backspaceButton: UIButton!
    @IBOutlet var nextKeyboardButton: UIButton!
    @IBOutlet var returnButton: UIButton!
    @IBOutlet var spaceButton: UIButton!
    @IBOutlet var decimalButton: UIButton!
    @IBOutlet var addDittoButton: UIButton!
    @IBOutlet var categoryPicker: UIPickerView!
    
    let dittoStore = DittoStore()
    let addDittoViewController = AddDittoFromClipboardViewController()
    var backspaceTimer: DelayedRepeatTimer!
    
    // Cache for current tab dittos
    var currentTabDittos: [String] = []
    
    // Cache for trimmed dittos, used to display text in cell and calculate cell height
    var currentTabDittosTrimmed: [String] = []
    
    var selectedCellRowIndex: Int = -1
    
    override func loadView() {
        let xib = NSBundle.mainBundle().loadNibNamed("KeyboardViewController", owner: self, options: nil);
        bottomBar.backgroundColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        tableView.registerClass(UITableViewCell.classForCoder(), forCellReuseIdentifier: "DittoCell")
        loadTabDittosByCategoryIndex(0)
        loadTabButtons()
        categoryPicker.delegate = addDittoViewController
        categoryPicker.dataSource = addDittoViewController
    }
    
    func loadTabDittosByCategoryIndex(categoryIndex: Int) {
        self.currentTabDittosTrimmed = dittoStore.getDittosInCategory(categoryIndex).map({ $0.stringByReplacingOccurrencesOfString("\n", withString: " ").stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " "))})
        self.currentTabDittos = dittoStore.getDittosInCategory(categoryIndex)
    }
    
    func loadTabButtons() {
        var numCategories = dittoStore.countCategories()
        let width = UIScreen.mainScreen().bounds.width / CGFloat(numCategories)
        for index in 0..<numCategories {
            let button = UIButton(frame: CGRectMake(CGFloat(index) * width, 0, width, tabBar.bounds.height))
            button.backgroundColor = getColorForIndex(index)
            button.tag = index
            button.addTarget(self, action: "tabButtonPressed:", forControlEvents: .TouchUpInside)
            tabBar.addSubview(button)
        }
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        tabBar.subviews.map({ $0.removeFromSuperview() })
        loadTabButtons()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        dittoStore.reload()
        tableView.reloadData()
        setKeyboardHeight(250)
    }
    
    func setKeyboardHeight(height: CGFloat) {
        let expandedHeight:CGFloat = height
        let heightConstraint = NSLayoutConstraint(item:keyboardView,
            attribute: .Height,
            relatedBy: .Equal,
            toItem: nil,
            attribute: .NotAnAttribute,
            multiplier: 0.0,
            constant: expandedHeight)
        keyboardView.addConstraint(heightConstraint)
    }
    
    func tabButtonPressed(sender: UIButton!) {
        loadTabDittosByCategoryIndex(sender.tag)
        selectedCellRowIndex = -1
        tableView.reloadData()
        numericKeys.hidden = true
        addDittoView.hidden = true
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
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentTabDittos.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("DittoCell", forIndexPath: indexPath) as! UITableViewCell
        
        var text = currentTabDittosTrimmed[indexPath.row]
        cell.textLabel?.text = text
        cell.textLabel?.numberOfLines = 0
        
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let size = (currentTabDittosTrimmed[indexPath.row] as NSString).boundingRectWithSize(CGSizeMake(tableView.frame.width, CGFloat.max), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName: UIFont(name: "HelveticaNeue-Light", size: 20)!], context: nil)
        
        if selectedCellRowIndex == indexPath.row {
            return size.size.height + 14
        } else {
            // TODO How do i guarantee the font type size is always right / what's currently the font type size of 
            // the cell labels (otherwise both size and width can be slightly off for variable lengths of text)
            
            // Height for two rows of text
            let sizeTwo = ("\n" as NSString).boundingRectWithSize(CGSizeMake(tableView.frame.width, CGFloat.max), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName: UIFont(name: "HelveticaNeue-Light", size: 20)!], context: nil)
            
            return min(size.size.height, sizeTwo.size.height) + 14
        }
    }
    
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let proxy = textDocumentProxy as! UITextDocumentProxy
        let ditto = currentTabDittos[indexPath.row]
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        let (newDitto, cursorRewind) = findCursorRange(ditto)
        proxy.insertText(newDitto)
        dispatch_async(dispatch_get_main_queue(), {
            proxy.adjustTextPositionByCharacterOffset(-cursorRewind)
        })
    }
    @IBAction func longPressCell(sender: UILongPressGestureRecognizer) {
        let p: CGPoint = sender.locationInView(tableView)
        if let indexPath = tableView.indexPathForRowAtPoint(p) {
            if sender.state == UIGestureRecognizerState.Began {
                if selectedCellRowIndex == indexPath.row {
                    selectedCellRowIndex = -1
                } else {
                    selectedCellRowIndex = indexPath.row
                }
                
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        }
    }
    
    @IBAction func nextKeyboardButtonClicked() {
        self.advanceToNextInputMode()
    }
    
    @IBAction func dittoButtonClicked() {
        // TODO nicer way to toggle?
        if addDittoView.hidden && numericKeys.hidden {
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
    
    @IBAction func addDittoFromClipboard(sender: UIButton) {
        let row = categoryPicker.selectedRowInComponent(0)
        addDittoFromClipboardByCategory(row)
    }
    
    func addDittoFromClipboardByCategory(categoryIndex: Int) {
        if let pasteboardString = UIPasteboard.generalPasteboard().string {
            dittoStore.addDittoToCategory(categoryIndex, text: pasteboardString)
        }
    }

    func getColorForIndex(index: Int) -> UIColor {
        return UIColor(red: 153/255,
            green: 0,
            blue: 153/255,
            alpha: 1 - ((4 / (4 * CGFloat(dittoStore.countCategories()))) * CGFloat(index)))
    }
    
}
