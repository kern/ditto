import UIKit

class KeyboardViewController: UIInputViewController, UITableViewDelegate, UITableViewDataSource {

    let defaults = NSUserDefaults(suiteName: "io.kern.ditto")!
    
    @IBOutlet var keyboardView: UIView!
    @IBOutlet var notesTableView: UITableView!
    
    @IBOutlet var backspaceButton: UIButton!
    @IBOutlet var nextKeyboardButton: UIButton!
    @IBOutlet var returnButton: UIButton!
    @IBOutlet var spaceButton: UIButton!
    
    var notes: [String] = []

    override func loadView() {
        let xib = NSBundle.mainBundle().loadNibNamed("KeyboardViewController", owner: self, options: nil);
        notesTableView.registerClass(UITableViewCell.classForCoder(), forCellReuseIdentifier: "NoteCell")
        
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
        notes = getNotes();
        notesTableView.reloadData()
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notes.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("NoteCell", forIndexPath: indexPath) as UITableViewCell
        
        var text = notes[indexPath.row]
        text = text.stringByReplacingOccurrencesOfString("\n", withString: "↩")
        text = text.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " "))
        cell.textLabel.text = text
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let proxy = self.textDocumentProxy as UITextDocumentProxy
        proxy.insertText(notes[indexPath.row])
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
    
    func getNotes() -> [String] {
        if let notes = defaults.arrayForKey("notes") as? [String] {
            return notes
        } else {
            return []
        }
    }
    
}
