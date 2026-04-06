import XCTest

final class DittoUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        // Disable Core Animations to prevent idle detection hangs
        app.launchEnvironment["UIAnimationsEnabled"] = "NO"
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Basic Launch

    func testAppLaunches() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10),
                      "App should be running")
    }

    func testAppShowsNavigationBar() throws {
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10),
                      "Navigation bar should exist")
    }

    func testAppShowsSegmentedControl() throws {
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 10)

        let hasDittos = app.buttons["Dittos"].waitForExistence(timeout: 5)
        let hasCategories = app.buttons["Categories"].exists

        XCTAssertTrue(hasDittos || hasCategories,
                      "Should show segmented control")
    }

    func testSwitchToCategoriesView() throws {
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 10)

        let categoriesButton = app.buttons["Categories"]
        guard categoriesButton.waitForExistence(timeout: 5) else {
            XCTFail("Categories button not found")
            return
        }
        categoriesButton.tap()
        XCTAssertTrue(app.buttons["Dittos"].waitForExistence(timeout: 5))
    }

    func testListContentExists() throws {
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 10)

        let hasContent = app.collectionViews.firstMatch.waitForExistence(timeout: 5)
            || app.tables.firstMatch.waitForExistence(timeout: 3)

        XCTAssertTrue(hasContent, "Should show list content")
    }
}
