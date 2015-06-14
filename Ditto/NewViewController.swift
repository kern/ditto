import UIKit

class NewViewController: UIViewController, UITextViewDelegate {
    
    let dittoStore = DittoStore()
    let keyboardAccessory = KeyboardAccessory()
    
    @IBOutlet var textView: UITextView!
    
    init() {
        super.init(nibName: "NewViewController", bundle: nil)
        
        navigationItem.title = "New Ditto"
        
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
        navigationItem.rightBarButtonItem?.enabled = false
        textView.becomeFirstResponder()
    }
    
    func saveButtonClicked() {
        dittoStore.add(textView.text)
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