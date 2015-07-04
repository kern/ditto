import UIKit

class ListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet var tableView: UITableView!
    
    let dittoStore = DittoStore()
    
    var editButton: UIBarButtonItem!
    var newButton: UIBarButtonItem!
    var doneButton: UIBarButtonItem!
    
    let segmentedControl: UISegmentedControl
    var objectType: DittoObjectType
    
    init() {
        
        self.segmentedControl = UISegmentedControl(items: ["Categories", "Dittos"])
        self.objectType = .Ditto
        super.init(nibName: "ListViewController", bundle: nil)
        
        navigationItem.titleView = segmentedControl
        segmentedControl.selectedSegmentIndex = 1
        segmentedControl.addTarget(self, action: Selector("segmentedControlChanged:"), forControlEvents: .ValueChanged)
        
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
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        var segmentedFrame = segmentedControl.frame
        segmentedFrame.size.width = UIScreen.mainScreen().bounds.width * 0.5
        segmentedControl.frame = segmentedFrame
    }
    
    func segmentedControlChanged(sender: AnyObject) {
        switch (segmentedControl.selectedSegmentIndex) {
        case 0:
            objectType = .Category
            
        case 1:
            objectType = .Ditto
            
        default:
            fatalError("Unknown index")
            
        }
        
        tableView.reloadData()
    }
    
    func textForCellAtIndexPath(indexPath: NSIndexPath) -> String {
        switch (objectType) {
        case .Category:
            return dittoStore.getCategory(indexPath.row)
            
        case .Ditto:
            return dittoStore.getDittoInCategory(indexPath.section, index: indexPath.row)
        }
    }
    
    //==============================
    // MARK: - Table View Callbacks
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        switch (objectType) {
        case .Category:
            return 1
            
        case .Ditto:
            return dittoStore.countCategories()
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (objectType) {
        case .Category:
            return dittoStore.countCategories()

        case .Ditto:
            return dittoStore.countInCategory(section)
        }
    }
    
    func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier("DittoCell", forIndexPath: indexPath) as! UITableViewCell
        cell.accessoryType = .DisclosureIndicator
        
        var text = textForCellAtIndexPath(indexPath)
        text = text.stringByReplacingOccurrencesOfString("\n", withString: " ")
        text = text.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " "))
        cell.textLabel?.text = text
        cell.textLabel?.numberOfLines = 2
        
        return cell
        
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        var text = textForCellAtIndexPath(indexPath)
        let size = text.boundingRectWithSize(CGSizeMake(tableView.frame.width, CGFloat.max), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName: UIFont(name: "HelveticaNeue-Light", size: 20)!], context: nil)
        
        let sizeTwo = ("\n" as NSString).boundingRectWithSize(CGSizeMake(tableView.frame.width, CGFloat.max), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName: UIFont(name: "HelveticaNeue-Light", size: 20)!], context: nil)
        
        return min(size.size.height, sizeTwo.size.height) + 14
    }
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch (objectType) {
        case .Category:
            return 0
            
        case .Ditto:
            return 28
        }
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch (objectType) {
        case .Category:
            return nil
            
        case .Ditto:
            let headerLabel = UILabel(frame: CGRectZero)
            headerLabel.backgroundColor = UIColor(red: 242/255, green: 242/255, blue: 242/255, alpha: 1)
            headerLabel.text = "  " + dittoStore.getCategory(section)
            headerLabel.textColor = UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1)
            return headerLabel
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var editViewController: EditViewController
        switch (objectType) {
        case .Category:
            editViewController = EditViewController(categoryIndex: indexPath.row)
        case .Ditto:
            editViewController = EditViewController(categoryIndex: indexPath.section, dittoIndex: indexPath.row)
        }
        
        let subnavController = NavigationController(rootViewController: editViewController)
        presentViewController(subnavController, animated: true, completion: nil)
    }
    
    func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        switch (objectType) {
        case .Category:
            dittoStore.moveCategoryFromIndex(sourceIndexPath.row, toIndex: destinationIndexPath.row)
            
        case .Ditto:
            dittoStore.moveDittoFromCategory(sourceIndexPath.section,
                index: sourceIndexPath.row,
                toCategory: destinationIndexPath.section,
                index: destinationIndexPath.row)
        }
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == .Delete) {
            switch (objectType) {
            case .Category:
                let alert = UIAlertController(title: "Warning", message: "Deleting a category removes all of its Dittos. Are you sure you wish to continue?", preferredStyle: .Alert)
                
                alert.addAction(UIAlertAction(title: "Delete", style: .Destructive, handler: { action in
                    self.dittoStore.removeCategoryAtIndex(indexPath.row)
                    tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Left)
                }))
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
                
                presentViewController(alert, animated: true, completion: nil)

            case .Ditto:
                dittoStore.removeDittoFromCategory(indexPath.section, index: indexPath.row)
                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Left)
            }
        }
    }
    
    //==========================
    // MARK: - Button Callbacks
    
    func newButtonClicked() {
        
        if (objectType == .Category && !dittoStore.canCreateNewCategory()) {
            let alert = UIAlertController(title: "Warning", message: "You can only create up to 8 categories. Please delete a category before creating a new one.", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Okay", style: .Cancel, handler: nil))
            presentViewController(alert, animated: true, completion: nil)
        } else {
            let newViewController = NewViewController(objectType: objectType)
            let subnavController = NavigationController(rootViewController: newViewController)
            presentViewController(subnavController, animated: true, completion: nil)
        }
        
    }
    
    func editButtonClicked() {
        
        segmentedControl.enabled = false
        segmentedControl.userInteractionEnabled = false
        tableView.setEditing(true, animated: true)
        navigationItem.setLeftBarButtonItem(doneButton, animated: true)
        navigationItem.setRightBarButtonItem(nil, animated: true)
        
    }
    
    func doneButtonClicked() {
        
        segmentedControl.enabled = true
        segmentedControl.userInteractionEnabled = true
        tableView.setEditing(false, animated: true)
        navigationItem.setLeftBarButtonItem(editButton, animated: true)
        navigationItem.setRightBarButtonItem(newButton, animated: true)
        
    }
    
}