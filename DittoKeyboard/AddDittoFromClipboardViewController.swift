import UIKit

final class AddDittoFromClipboardViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    let dittoStore = DittoStore()

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        dittoStore.isEmpty ? 1 : dittoStore.categoryCount
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        dittoStore.isEmpty ? "General" : dittoStore.category(at: row).title
    }
}
