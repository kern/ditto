import UIKit

class ListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet var tableView: UITableView!
    
    let dittoStore = DittoStore()
    
    var editButton: UIBarButtonItem!
    var newButton: UIBarButtonItem!
    var doneButton: UIBarButtonItem!
    
    var batchEditing = false
    
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
    
    //==============================
    // MARK: - Table View Callbacks
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return dittoStore.numCategories()
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dittoStore.count(section)
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
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        dittoStore.moveFromCategoryIndex(sourceIndexPath.section,
            fromDittoIndex: sourceIndexPath.row,
            toCategoryIndex: destinationIndexPath.section,
            toDittoIndex: destinationIndexPath.row)
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == .Delete) {
            dittoStore.remove(indexPath.section, dittoIndex: indexPath.row)
            let trimmedCategories = batchEditing ? NSIndexSet() : dittoStore.trimEmptyCategories()

            if trimmedCategories.count == 0 {
                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Left)
            } else {
                tableView.deleteSections(trimmedCategories, withRowAnimation: .Left)
            }
        }
    }
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 28
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let headerLabel = UILabel(frame: CGRectZero)
        headerLabel.backgroundColor = UIColor(red: 242/255, green: 242/255, blue: 242/255, alpha: 1)
        headerLabel.text = "  " + dittoStore.getCategory(section)
        headerLabel.textColor = UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1)
        return headerLabel
        
    }
    
    //==========================
    // MARK: - Button Callbacks
    
    func newButtonClicked() {
        let newViewController = NewViewController()
        let subnavController = NavigationController(rootViewController: newViewController)
        presentViewController(subnavController, animated: true, completion: nil)
    }
    
    func editButtonClicked() {
        
        batchEditing = true
        tableView.setEditing(true, animated: true)
        navigationItem.setLeftBarButtonItem(doneButton, animated: true)
        navigationItem.setRightBarButtonItem(nil, animated: true)
        
    }
    
    func doneButtonClicked() {
        
        let trimmedCategories = dittoStore.trimEmptyCategories()
        tableView.deleteSections(trimmedCategories, withRowAnimation: .Left)
        
        batchEditing = false
        tableView.setEditing(false, animated: true)
        navigationItem.setLeftBarButtonItem(editButton, animated: true)
        navigationItem.setRightBarButtonItem(newButton, animated: true)
        
    }
    
}