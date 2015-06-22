//
//  AddDittoFromClipboardViewController.swift
//  Ditto
//
//  Created by Asaf Avidan Antonir on 6/21/15.
//
//

import UIKit

class AddDittoFromClipboardViewController: UIViewController,UIPickerViewDataSource,UIPickerViewDelegate {
    
    let dittoStore = DittoStore()
    let dataSource = DittoStore().cachedCategories

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
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
