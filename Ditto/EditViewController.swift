import UIKit

class EditViewController: UIViewController {
    
    let noteStore = NoteStore()
    let index: Int
    
    @IBOutlet var textView: UITextView!
    
    init(index: Int) {
        self.index = index
        super.init(nibName: "EditViewController", bundle: nil)
        
        navigationItem.title = "Edit Snippet"
        
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
        navigationItem.rightBarButtonItem?.enabled = true
        textView.text = noteStore.get(index)
        textView.becomeFirstResponder()
    }
    
    func saveButtonClicked() {
        noteStore.set(index, text: textView.text)
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