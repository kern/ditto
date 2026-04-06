import XCTest

final class DittoUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Basic Launch

    func testAppLaunches() throws {
        // Simply verify the app process is running
        XCTAssertTrue(app.state == .runningForeground, "App should be running in foreground, state: \(app.state.rawValue)")
    }

    func testAppShowsNavigationBar() throws {
        let exists = app.navigationBars.firstMatch.waitForExistence(timeout: 15)
        if !exists {
            // Debug: dump top-level elements
            let windows = app.windows.count
            let buttons = app.buttons.count
            let texts = app.staticTexts.count
            XCTFail("No navigation bar found. Windows: \(windows), Buttons: \(buttons), Texts: \(texts)")
            return
        }
        XCTAssertTrue(exists)
    }

    func testAppShowsSegmentedControl() throws {
        // Wait for app to load
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 15)

        let dittosExists = app.buttons["Dittos"].waitForExistence(timeout: 5)
        let categoriesExists = app.buttons["Categories"].waitForExistence(timeout: 2)

        XCTAssertTrue(dittosExists || categoriesExists,
                      "Should show Dittos or Categories segment. Total buttons: \(app.buttons.count)")
    }

    func testToolbarHasButtons() throws {
        let navBar = app.navigationBars.firstMatch
        guard navBar.waitForExistence(timeout: 15) else {
            XCTFail("No navigation bar")
            return
        }
        XCTAssertTrue(navBar.buttons.count > 0,
                      "Navigation bar should have buttons, found: \(navBar.buttons.count)")
    }

    func testSwitchToCategoriesView() throws {
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 15)

        let categoriesButton = app.buttons["Categories"]
        guard categoriesButton.waitForExistence(timeout: 5) else {
            XCTFail("Categories button not found")
            return
        }
        categoriesButton.tap()

        // After switching, the segmented control should still exist
        XCTAssertTrue(app.buttons["Dittos"].waitForExistence(timeout: 5),
                      "Should still see Dittos segment after switching")
    }

    func testListContentExists() throws {
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 15)

        // SwiftUI List renders as collection view or table
        let hasContent = app.collectionViews.firstMatch.waitForExistence(timeout: 5)
            || app.tables.firstMatch.waitForExistence(timeout: 2)

        XCTAssertTrue(hasContent, "Should show list content")
    }
}
