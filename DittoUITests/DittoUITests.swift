import XCTest

final class DittoUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Launch

    func testAppLaunchShowsNavigationTitle() throws {
        let navBar = app.navigationBars["Ditto"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Navigation bar with title 'Ditto' should exist")
    }

    func testAppLaunchShowsSegmentedControl() throws {
        let dittosButton = app.buttons["Dittos"]
        let categoriesButton = app.buttons["Categories"]
        XCTAssertTrue(dittosButton.waitForExistence(timeout: 5), "Dittos segment should exist")
        XCTAssertTrue(categoriesButton.exists, "Categories segment should exist")
    }

    // MARK: - Segmented Control

    func testSwitchToCategoriesView() throws {
        let categoriesButton = app.buttons["Categories"]
        XCTAssertTrue(categoriesButton.waitForExistence(timeout: 5))
        categoriesButton.tap()

        // Should show category list with preset categories
        let instructionsCell = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Instructions'")).firstMatch
        XCTAssertTrue(instructionsCell.waitForExistence(timeout: 3), "Instructions category should be visible")
    }

    func testSwitchBackToDittosView() throws {
        let categoriesButton = app.buttons["Categories"]
        XCTAssertTrue(categoriesButton.waitForExistence(timeout: 5))
        categoriesButton.tap()

        let dittosButton = app.buttons["Dittos"]
        dittosButton.tap()

        // Should show ditto list with section headers
        let exists = app.staticTexts["Instructions"].waitForExistence(timeout: 3)
            || app.staticTexts["Driving"].waitForExistence(timeout: 3)
        XCTAssertTrue(exists, "Should show category section headers in dittos view")
    }

    // MARK: - Add New Category

    func testAddNewCategory() throws {
        // Switch to Categories view
        let categoriesButton = app.buttons["Categories"]
        XCTAssertTrue(categoriesButton.waitForExistence(timeout: 5))
        categoriesButton.tap()

        // Tap plus button
        let plusButton = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS 'Add'")).firstMatch
        if !plusButton.waitForExistence(timeout: 3) {
            // Try by image name
            let addButton = app.buttons["plus"]
            if addButton.waitForExistence(timeout: 2) {
                addButton.tap()
            } else {
                // Try the toolbar plus button
                app.navigationBars["Ditto"].buttons.element(boundBy: 1).tap()
            }
        } else {
            plusButton.tap()
        }

        // Should show New Category sheet
        let newCatTitle = app.navigationBars["New Category"]
        if newCatTitle.waitForExistence(timeout: 3) {
            // Type a category name
            let textEditor = app.textViews.firstMatch
            if textEditor.waitForExistence(timeout: 2) {
                textEditor.tap()
                textEditor.typeText("Test Category")

                // Save
                let saveButton = app.buttons["Save"]
                XCTAssertTrue(saveButton.isEnabled, "Save should be enabled after typing text")
                saveButton.tap()
            }
        }
    }

    // MARK: - Add New Ditto

    func testAddNewDitto() throws {
        // Should be in Dittos view by default
        let dittosButton = app.buttons["Dittos"]
        XCTAssertTrue(dittosButton.waitForExistence(timeout: 5))

        // Tap plus button
        let addButton = app.navigationBars["Ditto"].buttons.element(boundBy: 1)
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
        }

        // Should show New Ditto sheet
        let newDittoTitle = app.navigationBars["New Ditto"]
        if newDittoTitle.waitForExistence(timeout: 3) {
            let textEditor = app.textViews.firstMatch
            if textEditor.waitForExistence(timeout: 2) {
                textEditor.tap()
                textEditor.typeText("Test ditto text")

                let saveButton = app.buttons["Save"]
                XCTAssertTrue(saveButton.isEnabled)
                saveButton.tap()
            }
        }
    }

    // MARK: - Edit Category

    func testTapCategoryOpensEditSheet() throws {
        let categoriesButton = app.buttons["Categories"]
        XCTAssertTrue(categoriesButton.waitForExistence(timeout: 5))
        categoriesButton.tap()

        // Tap first category
        let firstCategory = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Instructions'")).firstMatch
        if firstCategory.waitForExistence(timeout: 3) {
            firstCategory.tap()

            let editTitle = app.navigationBars["Edit Category"]
            XCTAssertTrue(editTitle.waitForExistence(timeout: 3), "Edit Category sheet should appear")

            // Cancel
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tap()
            }
        }
    }

    // MARK: - Menu Button

    func testMenuButtonExists() throws {
        let menuButton = app.navigationBars["Ditto"].buttons.firstMatch
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Menu button should exist in toolbar")
    }

    // MARK: - Preset Data

    func testPresetCategoriesExist() throws {
        // Default view should show dittos grouped by category
        let instructions = app.staticTexts["Instructions"]
        XCTAssertTrue(instructions.waitForExistence(timeout: 5), "Instructions section should exist")
    }

    func testPresetDittosExist() throws {
        let welcomeDitto = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Welcome to Ditto'")).firstMatch
        XCTAssertTrue(welcomeDitto.waitForExistence(timeout: 5), "Welcome to Ditto ditto should exist")
    }
}
