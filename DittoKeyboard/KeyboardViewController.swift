import UIKit

class KeyboardViewController: UIInputViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet var keyboardView: UIView!
    @IBOutlet var tableView: UITableView!
    
    @IBOutlet var backspaceButton: UIButton!
    @IBOutlet var nextKeyboardButton: UIButton!
    @IBOutlet var returnButton: UIButton!
    @IBOutlet var spaceButton: UIButton!
    
    let dittoStore = DittoStore()

    override func loadView() {
        let xib = NSBundle.mainBundle().loadNibNamed("KeyboardViewController", owner: self, options: nil);
        tableView.registerClass(UITableViewCell.classForCoder(), forCellReuseIdentifier: "DittoCell")
        
        var borderColor = UIColor(red: 0, green: 0, blue:0, alpha: 0.25)
        nextKeyboardButton.layer.borderWidth = 0.25
        returnButton.layer.borderWidth = 0.25
        spaceButton.layer.borderWidth = 0.25
        
        nextKeyboardButton.layer.borderColor = borderColor.CGColor
        returnButton.layer.borderColor = borderColor.CGColor
        spaceButton.layer.borderColor = borderColor.CGColor
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
        text = text.stringByReplacingOccurrencesOfString("\n", withString: "↩")
        text = text.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " "))
        cell.textLabel.text = text
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let proxy = self.textDocumentProxy as UITextDocumentProxy
        proxy.insertText(dittoStore.get(indexPath.row))
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    @IBAction func nextKeyboardButtonClicked() {
        self.advanceToNextInputMode()
    }
    
    @IBAction func returnButtonClicked() {
        let proxy = self.textDocumentProxy as UITextDocumentProxy
        proxy.insertText("\n")
    }
    
    @IBAction func backspaceButtonClicked() {
        let proxy = self.textDocumentProxy as UITextDocumentProxy
        proxy.deleteBackward()
    }
    
    @IBAction func spaceButtonClicked() {
        let proxy = self.textDocumentProxy as UITextDocumentProxy
        proxy.insertText(" ")
    }
    
}
