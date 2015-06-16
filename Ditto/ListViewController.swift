import UIKit

class ListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet var tableView: UITableView!
    
    let dittoStore = DittoStore()
    
    let categories = ["family askdlfj alsdf kla sdfj kasjdfljalskdfj lasdj flkajs dlfk a","cabin","aepi","calhacks"]
    let dittoLists = [ ["almog","asaf","ora","erez","ofek","efrat"],
        ["jaso","ori","jason","sam"],
        ["henry","adam"],
        ["kern","rick","eve"]]
    
    var numCategories: Int  {
        return categories.count
    }
    
    var editButton: UIBarButtonItem!
    var newButton: UIBarButtonItem!
    var doneButton: UIBarButtonItem!
    
    init() {
        super.init(nibName: "ListViewController", bundle: nil)
        
        let logo = UIImage(named: "logo")
        navigationItem.titleView = UIImageView(image: logo)
        
        editButton = UIBarButtonItem(barButtonSystemItem: .Edit, target: self, action: "editButtonClicked")
        newButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "newButtonClicked")
        doneButton = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "doneButtonClicked")
    
        navigationItem.leftBarButtonItem = editButton
        navigationItem.rightBarButtonItem = newButton
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.registerClass(UITableViewCell.classForCoder(), forCellReuseIdentifier: "DittoCell")
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(animated: Bool) {
        dittoStore.reload()
        tableView.reloadData()
    }
    
    // Table View Callbacks
    // --------------------
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        return dittoStore.count()
        return dittoLists[section].count
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return numCategories
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("DittoCell", forIndexPath: indexPath) as! UITableViewCell
        cell.accessoryType = .DisclosureIndicator
        
//        var text = dittoStore.get(indexPath.row)
        var text = dittoLists[indexPath.section][indexPath.row]
        text = text.stringByReplacingOccurrencesOfString("\n", withString: " ")
        text = text.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " "))
        cell.textLabel?.text = text
        cell.textLabel?.numberOfLines = 2
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let editViewController = EditViewController(index: indexPath.row)
        let subnavController = NavigationController(rootViewController: editViewController)
        presentViewController(subnavController, animated: true, completion: nil)
    }
    
    func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        dittoStore.move(sourceIndexPath.row, to: destinationIndexPath.row)
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == .Delete) {
            dittoStore.remove(indexPath.row)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Left)
        }
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerLabel = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 20))
        headerLabel.backgroundColor = UIColor(red: 153/255, green: 0, blue: 153/255, alpha: 1 - ((4 / (4 * CGFloat(numCategories))) * CGFloat(section)))
        headerLabel.text = categories[section]
        headerLabel.textColor = UIColor.whiteColor()
        return headerLabel
    }
    
   
    
    // Button Callbacks
    // ----------------
    
    func newButtonClicked() {
        let newViewController = NewViewController()
        let subnavController = NavigationController(rootViewController: newViewController)
        presentViewController(subnavController, animated: true, completion: nil)
    }
    
    func editButtonClicked() {
        tableView.setEditing(true, animated: true)
        navigationItem.setLeftBarButtonItem(doneButton, animated: true)
        navigationItem.setRightBarButtonItem(nil, animated: true)
    }
    
    func doneButtonClicked() {
        tableView.setEditing(false, animated: true)
        navigationItem.setLeftBarButtonItem(editButton, animated: true)
        navigationItem.setRightBarButtonItem(newButton, animated: true)
    }
    
}