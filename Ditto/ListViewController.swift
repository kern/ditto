import UIKit

class ListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet var tableView: UITableView!
    
    let noteStore = NoteStore()
    var notes: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool) {
        notes = noteStore.getAll()
        tableView.reloadData()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        let editViewController = segue.destinationViewController as UINavigationController
        
        if segue.identifier == "New" {
            editViewController.visibleViewController.navigationItem.title = "New Note"
        } else {
            editViewController.visibleViewController.navigationItem.title = "Editing Note"
        }
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
        let editViewController = EditViewController(index: indexPath.row)
        let subnavController = UINavigationController(rootViewController: editViewController)
        subnavController.navigationBar.tintColor = UIColor.purpleColor()
        presentViewController(subnavController, animated: true, completion: nil)
    }
    
    @IBAction func newButtonClicked() {
        let newViewController = NewViewController()
        let subnavController = UINavigationController(rootViewController: newViewController)
        subnavController.navigationBar.tintColor = UIColor.purpleColor()
        presentViewController(subnavController, animated: true, completion: nil)
    }
    
}