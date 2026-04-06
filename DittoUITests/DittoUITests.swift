import XCTest

final class DittoUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        if let app {
            app.terminate()
        }
        app = nil
    }

    func testAppLaunches() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30),
                      "App should launch to foreground")
    }

    func testAppShowsNavigationBar() throws {
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10),
                      "Navigation bar should exist")
    }

    func testSegmentedControl() throws {
        guard app.navigationBars.firstMatch.waitForExistence(timeout: 10) else {
            XCTFail("No navigation bar")
            return
        }
        XCTAssertTrue(app.buttons["Dittos"].exists || app.buttons["Categories"].exists,
                      "Segmented control should exist")
    }

    func testSwitchViews() throws {
        guard app.navigationBars.firstMatch.waitForExistence(timeout: 10) else {
            XCTFail("No navigation bar")
            return
        }
        let categories = app.buttons["Categories"]
        guard categories.waitForExistence(timeout: 5) else {
            XCTFail("Categories not found")
            return
        }
        categories.tap()
        XCTAssertTrue(app.buttons["Dittos"].exists, "Dittos segment should still exist")
    }

    func testListExists() throws {
        guard app.navigationBars.firstMatch.waitForExistence(timeout: 10) else {
            XCTFail("No navigation bar")
            return
        }
        let hasContent = app.collectionViews.firstMatch.waitForExistence(timeout: 5)
            || app.tables.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(hasContent, "List content should exist")
    }
}
