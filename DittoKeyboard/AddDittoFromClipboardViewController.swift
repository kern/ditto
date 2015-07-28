import UIKit

class AddDittoFromClipboardViewController: UIViewController,UIPickerViewDataSource,UIPickerViewDelegate {
    
    let dittoStore = DittoStore()
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if dittoStore.isEmpty() {
            return 1
        } else {
            return dittoStore.countCategories()
        }
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
        if dittoStore.isEmpty() {
            return "General"
        } else {
            return dittoStore.getCategory(row)
        }
    }
}