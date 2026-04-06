import UIKit

final class AddDittoFromClipboardViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    let dittoStore: PendingDittoStore

    init(dittoStore: PendingDittoStore) {
        self.dittoStore = dittoStore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        dittoStore.isEmpty ? 1 : dittoStore.categoryCount
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        dittoStore.isEmpty ? "General" : dittoStore.categoryTitle(at: row)
    }
}
