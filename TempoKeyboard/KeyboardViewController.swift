import UIKit

class KeyboardViewController: UIInputViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet var keyboardView: UIView!
    @IBOutlet var notesTableView: UITableView!
    
    @IBOutlet var nextKeyboardButton: UIButton!
    @IBOutlet var returnButton: UIButton!
    @IBOutlet var spaceButton: UIButton!
    
    var notes: [String] = [
        "Hello!\n\nMy name is Alex Kern, and I'm a third year CS student at UC Berkeley.",
        "Please don't hesitate to reach out if you have any questions or concerns.",
        "Cheers,\nAlex Kern",
        "               🌟\n               🎄\n             🎄🎄\n           🎄🎄🎄\n         🎄🎄🎄🎄\n       🎄🎄🎄🎄🎄\n           🎁🎁🎁",
        "Never gonna give you up\nNever gonna let you down\nNever gonna run around and desert you\nNever gonna make you cry\nNever gonna say goodbye\nNever gonna tell a lie and hurt you"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let xib = NSBundle.mainBundle().loadNibNamed("Keyboard", owner: self, options: nil);
        self.notesTableView.registerClass(UITableViewCell.classForCoder(), forCellReuseIdentifier: "NoteCell")
        
        var borderColor = UIColor(red: 0, green: 0, blue:0, alpha: 0.25)
        nextKeyboardButton.layer.borderWidth = 0.25
        returnButton.layer.borderWidth = 0.25
        spaceButton.layer.borderWidth = 0.25
        
        nextKeyboardButton.layer.borderColor = borderColor.CGColor
        returnButton.layer.borderColor = borderColor.CGColor
        spaceButton.layer.borderColor = borderColor.CGColor
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notes.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("NoteCell", forIndexPath: indexPath) as UITableViewCell
        
        var text = notes[indexPath.row]
        text = text.stringByReplacingOccurrencesOfString("\n", withString: "↩")
        text = text.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " "))
        cell.textLabel?.text = text
        
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
    
    @IBAction func spaceButtonClicked() {
        let proxy = self.textDocumentProxy as UITextDocumentProxy
        proxy.insertText(" ")
    }
}
