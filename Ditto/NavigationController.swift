import UIKit

class NavigationController: UINavigationController {

    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        navigationBar.barTintColor = UIColor.purpleColor()
        navigationBar.tintColor = UIColor.whiteColor()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}