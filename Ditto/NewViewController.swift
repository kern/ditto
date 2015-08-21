import UIKit

class NewViewController: UIViewController, UITextViewDelegate {
    
    let dittoStore: DittoStore
    let objectType: DittoObjectType
    
    let categoryPicker: CategoryPicker?
    let keyboardAccessory: KeyboardAccessory?

    @IBOutlet var textView: UITextView!
    
    init(objectType: DittoObjectType) {
        
        self.objectType = objectType
        self.dittoStore = DittoStore()
        
        switch (objectType) {
        case .Category:
            self.categoryPicker = nil
            self.keyboardAccessory = nil
            
        case .Ditto:
            if dittoStore.isEmpty() {
                self.categoryPicker = CategoryPicker(categories: ["General"])
            } else {
                self.categoryPicker = CategoryPicker(categories: dittoStore.getCategories())
            }
        
            self.keyboardAccessory = KeyboardAccessory(categoryPicker: categoryPicker!)
        }
        
        super.init(nibName: "NewViewController", bundle: nil)
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
            navigationItem.title = "New Category"
            
        case .Ditto:
            navigationItem.title = "New Ditto"
        }
        
    }

    required init(coder: NSCoder) {
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
        navigationItem.rightBarButtonItem?.enabled = false
        textView.becomeFirstResponder()
    }
    
    func saveButtonClicked() {
        
        switch objectType {
        case .Category:
            dittoStore.addCategoryWithName(textView.text)
            
        case .Ditto:
            if dittoStore.isEmpty() {
                dittoStore.addCategoryWithName("General")
            }
            
            dittoStore.addDittoToCategory(categoryPicker!.index, text: textView.text)
        }
        
        textView.resignFirstResponder()
        navigationController?.dismissViewControllerAnimated(true, completion: nil)
        
    }
    
    func cancelButtonClicked() {
        textView.resignFirstResponder()
        navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func textViewDidChange(textView: UITextView) {
        navigationItem.rightBarButtonItem?.enabled = count(textView.text) > 0
    }
    
}