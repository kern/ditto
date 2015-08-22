import UIKit

class ListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var objectType: DittoObjectType
    let dittoStore: DittoStore
    
    let segmentedControl: UISegmentedControl
    var tableView: UITableView!
    var editButton: UIBarButtonItem!
    var newButton: UIBarButtonItem!
    var doneButton: UIBarButtonItem!
    
    init() {
        
        objectType = .Ditto
        dittoStore = DittoStore()
        segmentedControl = UISegmentedControl(items: ["Categories", "Dittos"])
        super.init(nibName: nil, bundle: nil)
        
        navigationItem.titleView = segmentedControl
        segmentedControl.selectedSegmentIndex = 1
        segmentedControl.addTarget(self, action: Selector("segmentedControlChanged:"), forControlEvents: .ValueChanged)
        
        editButton = UIBarButtonItem(barButtonSystemItem: .Edit, target: self, action: "editButtonClicked")
        newButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "newButtonClicked")
        doneButton = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "doneButtonClicked")
    
        navigationItem.leftBarButtonItem = editButton
        navigationItem.rightBarButtonItem = newButton

    }
    
    override func loadView() {
        tableView = UITableView(frame: CGRectZero, style: .Plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerClass(ObjectTableViewCell.classForCoder(), forCellReuseIdentifier: "ObjectTableViewCell")
        view = tableView
        
        NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("pollTableData"), userInfo: nil, repeats: true)
    }
    
    func pollTableData() {
        if !tableView.editing {
            tableView.reloadData()
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(animated: Bool) {
        tableView.reloadData()
    }
    
    override func viewWillLayoutSubviews() {
        
        super.viewWillLayoutSubviews()
        
        var segmentedFrame = segmentedControl.frame
        segmentedFrame.size.width = UIScreen.mainScreen().bounds.width * 0.5
        segmentedControl.frame = segmentedFrame
        
    }
    
    func segmentedControlChanged(sender: AnyObject) {
        switch segmentedControl.selectedSegmentIndex {
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
        switch objectType {
        case .Category:
            return "\(dittoStore.getCategory(indexPath.row)) (\(dittoStore.countInCategory(indexPath.row)))"
            
        case .Ditto:
            return dittoStore.getDittoPreviewInCategory(indexPath.section, index: indexPath.row)
            
        }
    }
    
    //==============================
    // MARK: - Table View Callbacks
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        switch objectType {
        case .Category: return 1
        case .Ditto:    return dittoStore.countCategories()
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch objectType {
        case .Category: return dittoStore.countCategories()
        case .Ditto:    return dittoStore.countInCategory(section)
        }
    }
    
    func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch objectType {
        case .Category: return 0
        case .Ditto:    return 33
        }
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch objectType {
        case .Category:
            return nil
            
        case .Ditto:
            let v = CategoryHeaderView(frame: CGRectZero)
            v.text = dittoStore.getCategory(section)
            return v
        }
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let text = textForCellAtIndexPath(indexPath)
        return ObjectTableViewCell.heightForText(text, truncated: true, disclosure: true)
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("ObjectTableViewCell", forIndexPath: indexPath) as! ObjectTableViewCell
        let text = textForCellAtIndexPath(indexPath)
        cell.setText(text, disclosure: true)
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        presentEditViewController(indexPath)
    }
    
    func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        switch objectType {
        case .Category: dittoStore.moveCategoryFromIndex(sourceIndexPath.row, toIndex: destinationIndexPath.row)
        case .Ditto: dittoStore.moveDittoFromCategory(sourceIndexPath.section, index: sourceIndexPath.row, toCategory: destinationIndexPath.section, index: destinationIndexPath.row)
        }
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            switch objectType {
            case .Category:
                
                presentRemoveCategoryWarning({ action in
                    self.dittoStore.removeCategoryAtIndex(indexPath.row)
                    tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Left)
                })
                
            case .Ditto:
                
                dittoStore.removeDittoFromCategory(indexPath.section, index: indexPath.row)
                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Left)
                
            }
        }
    }
    
    //==========================
    // MARK: - Button Callbacks
    
    func newButtonClicked() {
        
        if objectType == .Category && !dittoStore.canCreateNewCategory() {
            presentMaxCategoryWarning()
        } else {
            presentNewViewController()
        }
        
    }
    
    func editButtonClicked() {
        
        segmentedControl.enabled = false
        segmentedControl.userInteractionEnabled = false
        navigationItem.setLeftBarButtonItem(doneButton, animated: true)
        navigationItem.setRightBarButtonItem(nil, animated: true)
        tableView.setEditing(true, animated: true)
        
    }
    
    func doneButtonClicked() {
        
        segmentedControl.enabled = true
        segmentedControl.userInteractionEnabled = true
        navigationItem.setLeftBarButtonItem(editButton, animated: true)
        navigationItem.setRightBarButtonItem(newButton, animated: true)
        tableView.setEditing(false, animated: true)
        
    }
    
    //=====================================
    // MARK: - Presenting View Controllers
    
    func presentNewViewController() {
        let newViewController = NewViewController(objectType: objectType)
        let subnavController = NavigationController(rootViewController: newViewController)
        presentViewController(subnavController, animated: true, completion: nil)
    }
    
    func presentEditViewController(indexPath: NSIndexPath) {
        
        var editViewController: EditViewController
        switch objectType {
        case .Category:
            editViewController = EditViewController(categoryIndex: indexPath.row)
        case .Ditto:
            editViewController = EditViewController(categoryIndex: indexPath.section, dittoIndex: indexPath.row)
        }
        
        let subnavController = NavigationController(rootViewController: editViewController)
        presentViewController(subnavController, animated: true, completion: nil)
        
    }
    
    func presentMaxCategoryWarning() {

        let alert = UIAlertController(title: "Warning",
            message: "You can only create up to 8 categories. Delete a category before creating a new one.",
            preferredStyle: .Alert)
        
        alert.addAction(UIAlertAction(title: "Okay", style: .Cancel, handler: nil))
        presentViewController(alert, animated: true, completion: nil)

    }
    
    func presentRemoveCategoryWarning(handler: ((UIAlertAction!) -> Void)) {
        
        let alert = UIAlertController(title: "Warning",
            message: "Deleting a category removes all of its Dittos. Are you sure you wish to continue?",
            preferredStyle: .Alert)
        
        alert.addAction(UIAlertAction(title: "Delete", style: .Destructive, handler: handler))
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        presentViewController(alert, animated: true, completion: nil)
        
    }
    
}