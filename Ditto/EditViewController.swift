import UIKit

class EditViewController: UIViewController {
    
    let dittoStore: DittoStore
    let objectType: DittoObjectType

    let dittoIndex: Int
    let categoryIndex: Int
    
    let categoryPicker: CategoryPicker?
    let keyboardAccessory: KeyboardAccessory?
    
    @IBOutlet var textView: UITextView!
    
    init(categoryIndex: Int) {
        
        self.dittoStore = DittoStore()
        self.objectType = .Category
        self.categoryIndex = categoryIndex
        self.dittoIndex = 0
        self.categoryPicker = nil
        self.keyboardAccessory = nil
        
        super.init(nibName: "EditViewController", bundle: nil)
        initNavigationItem()
        
    }

    init(categoryIndex: Int, dittoIndex: Int) {
        
        self.dittoStore = DittoStore()
        self.objectType = .Ditto
        self.categoryIndex = categoryIndex
        self.dittoIndex = dittoIndex
        self.categoryPicker = CategoryPicker(categories: dittoStore.getCategories(), selected: categoryIndex)
        self.keyboardAccessory = KeyboardAccessory(categoryPicker: categoryPicker!)
        
        super.init(nibName: "EditViewController", bundle: nil)
        initNavigationItem()
        
    }
    
    func initNavigationItem() {
        
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "cancelButtonClicked")
        navigationItem.leftBarButtonItem = cancelButton
        
        let saveButton = UIBarButtonItem(barButtonSystemItem: .Save, target: self, action: "saveButtonClicked")
        saveButton.style = .Done
        navigationItem.rightBarButtonItem = saveButton
        
        switch objectType {
        case .Category:
            navigationItem.title = "Edit Category"
            
        case .Ditto:
            navigationItem.title = "Edit Ditto"
        }

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textView.textContainerInset = UIEdgeInsetsMake(10, 6, 10, 6)
        textView.inputAccessoryView = keyboardAccessory

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
    }
    
    func keyboardWillShow(n: NSNotification) {
        let v = n.userInfo?[UIKeyboardFrameEndUserInfoKey] as! NSValue
        let height = v.CGRectValue().size.height
        var insets = textView.contentInset
        insets.bottom = height
        textView.contentInset = insets
        textView.scrollIndicatorInsets = insets
    }
    
    func keyboardWillHide(n: NSNotification) {
        var insets = textView.contentInset
        insets.bottom = 0
        textView.contentInset = insets
        textView.scrollIndicatorInsets = insets
    }
    
    override func viewWillAppear(animated: Bool) {
        switch objectType {
        case .Category:
            textView.text = dittoStore.getCategory(categoryIndex)
            
        case .Ditto:
            textView.text = dittoStore.getDittoInCategory(categoryIndex, index: dittoIndex)
        }
        
        navigationItem.rightBarButtonItem?.enabled = true
        textView.becomeFirstResponder()
    }
    
    func saveButtonClicked() {
        
        switch objectType {
        case .Category:
            dittoStore.editCategoryAtIndex(categoryIndex, name: textView.text)

        case .Ditto:
            dittoStore.editDittoInCategory(categoryIndex, index: dittoIndex, text: textView.text)
            
            if categoryIndex != categoryPicker!.index {
                dittoStore.moveDittoFromCategory(categoryIndex, index: dittoIndex, toCategory: categoryPicker!.index)
            }
        }
        
        textView.resignFirstResponder()
        navigationController?.dismissViewControllerAnimated(true, completion: nil)
        
    }
    
    func cancelButtonClicked() {
        textView.resignFirstResponder()
        navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func textViewDidChange(textView: UITextView) {
        navigationItem.rightBarButtonItem?.enabled = textView.text.characters.count > 0
    }

}