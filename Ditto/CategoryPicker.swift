import UIKit

class CategoryPicker: NSObject, UIPickerViewDelegate, UIPickerViewDataSource {
    
    let categories: [String]
    let view = UIPickerView(frame: CGRectZero)
    
    var index: Int { return view.selectedRowInComponent(0) }
    var name: String { return categories[index] }
    
    init(categories: [String]) {
        
        self.categories = categories
        super.init()
        
        view.showsSelectionIndicator = true
        view.backgroundColor = UIColor(white: 0.97, alpha: 1)
        view.delegate = self
        view.dataSource = self
        
    }
    
    convenience init(categories: [String], selected: Int) {
        self.init(categories: categories)
        view.selectRow(selected, inComponent: 0, animated: false)
    }
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return categories.count
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
        return categories[row]
    }
    
}