import UIKit

class KeyboardViewController: UIInputViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet var keyboardView: UIView!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var infoView: UIView!
    
    @IBOutlet var backspaceButton: UIButton!
    @IBOutlet var nextKeyboardButton: UIButton!
    @IBOutlet var returnButton: UIButton!
    @IBOutlet var spaceButton: UIButton!
    
    let dittoStore = DittoStore()
    var backspaceTimer: DelayedRepeatTimer!

    override func loadView() {
        let xib = NSBundle.mainBundle().loadNibNamed("KeyboardViewController", owner: self, options: nil);
        tableView.registerClass(UITableViewCell.classForCoder(), forCellReuseIdentifier: "DittoCell")
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        dittoStore.reload()
        tableView.reloadData()
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dittoStore.count()
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("DittoCell", forIndexPath: indexPath) as UITableViewCell
        
        var text = dittoStore.get(indexPath.row)
        text = text.stringByReplacingOccurrencesOfString("\n", withString: " ")
        text = text.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " "))
        cell.textLabel.text = text
        cell.textLabel.numberOfLines = 2
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let proxy = textDocumentProxy as UITextDocumentProxy
        let ditto = dittoStore.get(indexPath.row)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        let (newDitto, cursorRewind) = findCursorRange(ditto)
        proxy.insertText(newDitto)
        dispatch_async(dispatch_get_main_queue(), {
            proxy.adjustTextPositionByCharacterOffset(-cursorRewind)
        })
    }
    
    @IBAction func nextKeyboardButtonClicked() {
        self.advanceToNextInputMode()
    }
    
    @IBAction func dittoButtonClicked() {
        infoView.hidden = !infoView.hidden
    }
    
    @IBAction func returnButtonClicked() {
        let proxy = textDocumentProxy as UITextDocumentProxy
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
        let proxy = textDocumentProxy as UITextDocumentProxy
        proxy.insertText(" ")
    }
    
    func backspaceFire() {
        let proxy = textDocumentProxy as UITextDocumentProxy
        proxy.deleteBackward()
    }
    
    func findCursorRange(s: String) -> (String, Int) {
        let length = countElements(s)
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
    
}
