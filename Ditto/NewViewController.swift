import UIKit

class NewViewController: UIViewController, UITextViewDelegate {
    
    let noteStore = NoteStore()
    
    @IBOutlet var textView: UITextView!
    
    override init() {
        super.init(nibName: "NewViewController", bundle: nil)
        
        navigationItem.title = "New Snippet"
        
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "cancelButtonClicked")
        navigationItem.leftBarButtonItem = cancelButton
        
        let saveButton = UIBarButtonItem(barButtonSystemItem: .Save, target: self, action: "saveButtonClicked")
        saveButton.style = .Done
        navigationItem.rightBarButtonItem = saveButton
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textView.textContainerInset = UIEdgeInsetsMake(0, -4, 0, -4)
    }
    
    override func viewWillAppear(animated: Bool) {
        navigationItem.rightBarButtonItem?.enabled = false
        textView.becomeFirstResponder()
    }
    
    func saveButtonClicked() {
        noteStore.add(textView.text)
        textView.resignFirstResponder()
        navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func cancelButtonClicked() {
        textView.resignFirstResponder()
        navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func textViewDidChange(textView: UITextView) {
        navigationItem.rightBarButtonItem?.enabled = countElements(textView.text) > 0
    }
    
}