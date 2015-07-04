import UIKit

class EditViewController: UIViewController {
    
    let categoryPicker: CategoryPicker
    let dittoStore: DittoStore
    let dittoIndex: Int
    let categoryIndex: Int
    let keyboardAccessory: KeyboardAccessory
    
    @IBOutlet var textView: UITextView!

    init(categoryIndex : Int, dittoIndex: Int) {
        
        self.dittoIndex = dittoIndex
        self.categoryIndex = categoryIndex
        self.dittoStore = DittoStore()
        self.categoryPicker = CategoryPicker(categories: dittoStore.cachedCategories, selected: categoryIndex)
        self.keyboardAccessory = KeyboardAccessory(categoryPicker: categoryPicker)
        super.init(nibName: "EditViewController", bundle: nil)
        
        navigationItem.title = "Edit Ditto"
        
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "cancelButtonClicked")
        navigationItem.leftBarButtonItem = cancelButton
        
        let saveButton = UIBarButtonItem(barButtonSystemItem: .Save, target: self, action: "saveButtonClicked")
        saveButton.style = .Done
        navigationItem.rightBarButtonItem = saveButton
        
    }

    required init(coder aDecoder: NSCoder) {
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
        navigationItem.rightBarButtonItem?.enabled = true
        textView.text = dittoStore.get(categoryIndex, dittoIndex: dittoIndex)
        textView.becomeFirstResponder()
    }
    
    func saveButtonClicked() {
        
        dittoStore.set(categoryIndex, dittoIndex: dittoIndex, ditto: textView.text)
        dittoStore.moveFromCategory(categoryIndex, dittoIndex: dittoIndex, toCategory: categoryPicker.index)
        
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