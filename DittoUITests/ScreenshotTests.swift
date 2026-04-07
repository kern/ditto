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
        // Dittos list (populated with demo snippets)
        let dittos = app.buttons["Dittos"]
        if dittos.waitForExistence(timeout: 5) { dittos.tap() }
        sleep(1)
        snapshot("01_dittos_list")
    }
}
