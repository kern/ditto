import UIKit

class ListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet var tableView: UITableView!
    
    let dittoStore = DittoStore()
    
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
        return dittoStore.count(section)
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return dittoStore.numCategories()
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("DittoCell", forIndexPath: indexPath) as! UITableViewCell
        cell.accessoryType = .DisclosureIndicator
        
        var text = dittoStore.get(indexPath.section, dittoIndex: indexPath.row)
        text = text.stringByReplacingOccurrencesOfString("\n", withString: " ")
        text = text.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " "))
        cell.textLabel?.text = text
        cell.textLabel?.numberOfLines = 2
        
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let size = (dittoStore.get(indexPath.section, dittoIndex: indexPath.row) as NSString).boundingRectWithSize(CGSizeMake(tableView.frame.width, CGFloat.max), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName: UIFont(name: "HelveticaNeue-Light", size: 20)!], context: nil)
        
        let sizeTwo = ("\n" as NSString).boundingRectWithSize(CGSizeMake(tableView.frame.width, CGFloat.max), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName: UIFont(name: "HelveticaNeue-Light", size: 20)!], context: nil)
        
        return min(size.size.height, sizeTwo.size.height) + 14
        
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let editViewController = EditViewController(categoryIndex: indexPath.section, dittoIndex: indexPath.row)
        let subnavController = NavigationController(rootViewController: editViewController)
        presentViewController(subnavController, animated: true, completion: nil)
    }
    
    func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        dittoStore.move(sourceIndexPath.section, fromDittoIndex: sourceIndexPath.row, toCatogryIndex: destinationIndexPath.section, toDittoIndex: destinationIndexPath.row)
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == .Delete) {
            dittoStore.remove(indexPath.section, dittoIndex: indexPath.row)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Left)
        }
    }
    
    // TODO: clean this up with a custom header
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 25))
        
        let headerLabel = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width * 0.8, height: 25))
        headerLabel.backgroundColor = UIColor(red: 242/255, green: 242/255, blue: 242/255, alpha: 1)
        headerLabel.text = "  " + dittoStore.getCategory(section)
        headerLabel.textColor = UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1)
        
        let deleteCategoryButton = UIButton(frame: CGRect(x: tableView.bounds.width * 0.8, y: 0, width: tableView.bounds.width * 0.2, height: 25))
        deleteCategoryButton.setTitle("delete", forState: UIControlState.Normal)
        deleteCategoryButton.addTarget(self, action: "deleteCategoryButtonAction:", forControlEvents: UIControlEvents.TouchUpInside)
        deleteCategoryButton.tag = section
        deleteCategoryButton.backgroundColor = UIColor.blackColor()
        
        headerView.addSubview(headerLabel)
        headerView.addSubview(deleteCategoryButton)
        return headerView
    }
    
    func deleteCategoryButtonAction(sender: UIButton!) {
        var alert = UIAlertController(title: "Warning!", message: "Deleting a category removes all of its dittos. Are you sure you want to continue?", preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "Delete", style: .Default, handler: { action in
            self.dittoStore.removeCategory(sender.tag)
            self.tableView.deleteSections(NSIndexSet(index: sender.tag), withRowAnimation: UITableViewRowAnimation(rawValue: 1)!)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
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