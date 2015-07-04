import UIKit

class AddDittoFromClipboardViewController: UIViewController,UIPickerViewDataSource,UIPickerViewDelegate {
    
    let dittoStore = DittoStore()
    let dataSource = DittoStore().cachedCategories
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return dataSource.count
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
        return dataSource[row]
    }
    
}