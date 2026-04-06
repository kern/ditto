import XCTest

final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--screenshots"]
        setupSnapshot(app)
        app.launch()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 15))
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testScreenshots() throws {
        // 1 — Dittos list (populated with demo snippets)
        let dittos = app.buttons["Dittos"]
        if dittos.waitForExistence(timeout: 5) { dittos.tap() }
        sleep(1)
        snapshot("01_dittos_list")

        // 2 — Categories list
        let categories = app.buttons["Categories"]
        XCTAssertTrue(categories.waitForExistence(timeout: 5))
        categories.tap()
        sleep(1)
        snapshot("02_categories")

        // 3 — New ditto sheet
        let plus = app.navigationBars.firstMatch.buttons.element(boundBy: 1)
        XCTAssertTrue(plus.waitForExistence(timeout: 5))
        plus.tap()
        sleep(1)
        snapshot("03_new_ditto")

        // Dismiss sheet
        let cancel = app.buttons["Cancel"]
        if cancel.waitForExistence(timeout: 3) { cancel.tap() }

        // 4 — Ditto detail / edit (tap first category then first ditto)
        let dittos2 = app.buttons["Dittos"]
        if dittos2.waitForExistence(timeout: 5) { dittos2.tap() }
        sleep(1)
        let firstDitto = app.tables.firstMatch.cells.firstMatch
        if firstDitto.waitForExistence(timeout: 5) {
            firstDitto.tap()
            sleep(1)
            snapshot("04_edit_ditto")
            let done = app.buttons["Done"]
            if done.waitForExistence(timeout: 3) { done.tap() }
        }
    }
}
