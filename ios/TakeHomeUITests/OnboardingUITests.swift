import XCTest

final class OnboardingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingFlow_CompletesSuccessfully() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-onboarding"]
        app.launch()

        // Welcome screen
        XCTAssertTrue(app.staticTexts["Welcome to TakeHome"].waitForExistence(timeout: 5))
        app.buttons["Next"].tap()

        // Income screen
        XCTAssertTrue(app.staticTexts["What's your annual salary?"].waitForExistence(timeout: 5))
        let salaryField = app.textFields["$100,000"]
        salaryField.tap()
        salaryField.typeText("100000")
        app.buttons["Next"].tap()

        // Location screen
        XCTAssertTrue(app.staticTexts["Where do you live?"].waitForExistence(timeout: 5))
        app.buttons["Next"].tap()

        // Deductions screen
        XCTAssertTrue(app.staticTexts["Pre-tax deductions"].waitForExistence(timeout: 5))
        app.buttons["Next"].tap()

        // Reveal screen
        XCTAssertTrue(app.staticTexts["Your Take-Home Pay"].waitForExistence(timeout: 10))
        app.buttons["Continue"].tap()

        // Expenses screen
        XCTAssertTrue(app.staticTexts["Track Your Expenses"].waitForExistence(timeout: 5))
        app.buttons["Skip"].tap()

        // Complete screen
        XCTAssertTrue(app.staticTexts["You're All Set!"].waitForExistence(timeout: 5))
        app.buttons["Go to Dashboard"].tap()

        // Verify we're on the dashboard
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 5))
    }

    func testOnboardingFlow_CanGoBack() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-onboarding"]
        app.launch()

        // Go forward
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["What's your annual salary?"].waitForExistence(timeout: 5))

        // Go back
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["Welcome to TakeHome"].waitForExistence(timeout: 5))
    }

    func testOnboardingFlow_RequiresSalaryInput() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-onboarding"]
        app.launch()

        // Navigate to income screen
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["What's your annual salary?"].waitForExistence(timeout: 5))

        // Next button should be disabled without salary input
        let nextButton = app.buttons["Next"]
        XCTAssertFalse(nextButton.isEnabled)

        // Enter salary
        let salaryField = app.textFields.firstMatch
        salaryField.tap()
        salaryField.typeText("50000")

        // Next button should now be enabled
        XCTAssertTrue(nextButton.isEnabled)
    }
}
