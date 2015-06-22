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
    
    var currentTabDittos: [String] = []
    var currentTabCells: [UITableViewCell] = []
    var selectedCellRowIndex: Int = -1
    
    override func loadView() {
        let xib = NSBundle.mainBundle().loadNibNamed("KeyboardViewController", owner: self, options: nil);
        bottomBar.backgroundColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        tableView.registerClass(UITableViewCell.classForCoder(), forCellReuseIdentifier: "DittoCell")
        currentTabDittos = dittoStore.getDittosByCategory(0)
        loadTabButtons()
        categoryPicker.delegate = addDittoViewController
        categoryPicker.dataSource = addDittoViewController
    }
    
    func loadTabButtons() {
        var numCategories = dittoStore.numCategories()
        let width = UIScreen.mainScreen().bounds.width / CGFloat(numCategories)
        for index in 0..<numCategories {
            let button = UIButton(frame: CGRectMake(CGFloat(index) * width, 0, width, tabBar.bounds.height))
            button.backgroundColor = dittoStore.getColorForIndex(index)
            button.tag = index
            button.addTarget(self, action: "tabButtonPressed:", forControlEvents: .TouchUpInside)
            tabBar.addSubview(button)
        }
    }
    
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        dittoStore.reload()
        tableView.reloadData()
        currentTabCells = []
//        setKeyboardHeight(max(250, UIScreen.mainScreen().bounds.height/2))
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
        currentTabDittos = dittoStore.getDittosByCategory(sender.tag)
        currentTabCells = []
        selectedCellRowIndex = -1
        tableView.reloadData()
        numericKeys.hidden = true
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
        
        var text = currentTabDittos[indexPath.row]
        text = text.stringByReplacingOccurrencesOfString("\n", withString: " ")
        text = text.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " "))
        cell.textLabel?.text = text
        cell.textLabel?.numberOfLines = 2
        
        currentTabCells.append(cell)
        
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if selectedCellRowIndex == indexPath.row {
            let cell = currentTabCells[indexPath.row]
            cell.textLabel?.numberOfLines = 0
            cell.textLabel!.sizeToFit()
            return cell.textLabel!.frame.height + 20
        }
        let x = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: CGFloat.max))
        x.text = currentTabDittos[indexPath.row]
        x.numberOfLines = 2
        x.sizeToFit()
    
        return x.frame.height + 20
        
//        if selectedCellRowIndex == indexPath.row {
//            let cell = currentTabCells[indexPath.row]
//            cell.textLabel?.numberOfLines = 0
//            cell.textLabel!.sizeToFit()
//            return cell.textLabel!.frame.height + 20
//        }
//        return 60
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
                
                var cell: UITableViewCell = currentTabCells[indexPath.row]
                tableView.beginUpdates()
                tableView.endUpdates()
                
            }
        }
    }
    
    @IBAction func nextKeyboardButtonClicked() {
        self.advanceToNextInputMode()
    }
    
    @IBAction func dittoButtonClicked() {
        numericKeys.hidden = !numericKeys.hidden
//        addDittoView.hidden = !addDittoView.hidden
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
            dittoStore.add(categoryIndex, ditto: pasteboardString)
        }
    }
    
}
