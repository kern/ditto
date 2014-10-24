import UIKit

class ListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet var tableView: UITableView!
    
    let noteStore = NoteStore()
    var notes: [String] = []
    
    override init() {
        super.init(nibName: "ListViewController", bundle: nil)
        
        let logo = UIImage(named: "logo")
        navigationItem.titleView = UIImageView(image: logo)
        
        let editButton = UIBarButtonItem(barButtonSystemItem: .Edit, target: self, action: "editButtonClicked")
        navigationItem.leftBarButtonItem = editButton
        
        let newButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "newButtonClicked")
        navigationItem.rightBarButtonItem = newButton
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.registerClass(UITableViewCell.classForCoder(), forCellReuseIdentifier: "NoteCell")
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        let subnavController = NavigationController(rootViewController: editViewController)
        presentViewController(subnavController, animated: true, completion: nil)
    }
    
    func newButtonClicked() {
        let newViewController = NewViewController()
        let subnavController = NavigationController(rootViewController: newViewController)
        presentViewController(subnavController, animated: true, completion: nil)
    }
    
    func editButtonClicked() {
        
    }
    
}