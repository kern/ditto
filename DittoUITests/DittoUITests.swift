import XCTest

final class DittoUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        // Wait for app to fully load
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Navigation bar should appear")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Launch

    func testAppLaunches() throws {
        // Verify the app launched and shows some content
        XCTAssertTrue(app.navigationBars.count > 0, "Should have at least one navigation bar")
    }

    func testAppShowsSegmentedControl() throws {
        // Segmented control renders as buttons in SwiftUI
        let dittosSegment = app.buttons["Dittos"]
        let categoriesSegment = app.buttons["Categories"]

        let hasDittos = dittosSegment.waitForExistence(timeout: 5)
        let hasCategories = categoriesSegment.waitForExistence(timeout: 2)

        XCTAssertTrue(hasDittos || hasCategories,
                      "Should show segmented control with Dittos or Categories")
    }

    // MARK: - Navigation

    func testSwitchToCategoriesAndBack() throws {
        let categoriesButton = app.buttons["Categories"]
        guard categoriesButton.waitForExistence(timeout: 5) else {
            XCTFail("Categories button not found")
            return
        }
        categoriesButton.tap()

        // Wait for categories view to load
        sleep(1)

        let dittosButton = app.buttons["Dittos"]
        guard dittosButton.waitForExistence(timeout: 5) else {
            XCTFail("Dittos button not found after switching")
            return
        }
        dittosButton.tap()

        // Verify we can switch back
        XCTAssertTrue(dittosButton.exists, "Should be back on dittos view")
    }

    // MARK: - Content

    func testPresetContentVisible() throws {
        // The app should show some preset content on launch
        // Look for any text content in the list
        let listExists = app.collectionViews.firstMatch.waitForExistence(timeout: 5)
            || app.tables.firstMatch.waitForExistence(timeout: 2)

        XCTAssertTrue(listExists, "Should show a list of content")
    }

    func testCategoriesViewShowsContent() throws {
        let categoriesButton = app.buttons["Categories"]
        guard categoriesButton.waitForExistence(timeout: 5) else {
            XCTFail("Categories button not found")
            return
        }
        categoriesButton.tap()

        // Wait for view to render
        sleep(1)

        // Should show at least one button (category row) in the list
        let listExists = app.collectionViews.firstMatch.waitForExistence(timeout: 5)
            || app.tables.firstMatch.waitForExistence(timeout: 2)

        XCTAssertTrue(listExists, "Categories view should show a list")
    }

    // MARK: - Toolbar

    func testToolbarHasButtons() throws {
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))

        // Should have at least one toolbar button (menu or plus)
        let buttons = navBar.buttons
        XCTAssertTrue(buttons.count > 0, "Navigation bar should have toolbar buttons")
    }

    func testAddButtonExists() throws {
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))

        // Look for the plus/add button
        let addButton = navBar.buttons["Add"]
        let plusButton = navBar.buttons["plus"]

        let hasAdd = addButton.exists || plusButton.exists

        // If not found by label, check by index (plus is typically trailing)
        if !hasAdd {
            XCTAssertTrue(navBar.buttons.count >= 2,
                          "Should have at least 2 toolbar buttons (menu + add)")
        }
    }

    // MARK: - Add Sheet

    func testTapAddShowsSheet() throws {
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))

        // Tap the trailing (rightmost) button - should be the add button
        let buttons = navBar.buttons
        guard buttons.count >= 2 else {
            XCTFail("Not enough toolbar buttons")
            return
        }

        // The add button is the last one in the nav bar
        buttons.element(boundBy: buttons.count - 1).tap()

        // Should show a sheet with New Ditto or New Category
        let newDittoNav = app.navigationBars["New Ditto"]
        let newCatNav = app.navigationBars["New Category"]

        let sheetAppeared = newDittoNav.waitForExistence(timeout: 5)
            || newCatNav.waitForExistence(timeout: 2)

        XCTAssertTrue(sheetAppeared, "Tapping add should show New Ditto or New Category sheet")

        // Dismiss the sheet
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 2) {
            cancelButton.tap()
        }
    }
}
