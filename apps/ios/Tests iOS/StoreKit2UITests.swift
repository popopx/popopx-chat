//
//  StoreKit2UITests.swift
//  Tests iOS
//
//  UI tests for StoreKit 2 subscription flow
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import XCTest

final class StoreKit2UITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSubscriptionViewOpens() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait for trial banner to appear
        let subscribeButton = app.buttons["Subscribe"]
        XCTAssertTrue(subscribeButton.waitForExistence(timeout: 5), "Subscribe button should appear in trial banner")

        // Tap Subscribe to open subscription view
        subscribeButton.tap()

        // Verify subscription view appears
        let subscriptionView = app.staticTexts["Membership"]
        XCTAssertTrue(subscriptionView.waitForExistence(timeout: 3), "Membership view should open")

        // Take screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "SubscriptionView_Opened"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testBillingToggleExists() throws {
        let app = XCUIApplication()
        app.launch()

        // Open subscription view
        app.buttons["Subscribe"].tap()
        sleep(1)

        // Verify billing period toggle exists
        let monthlyToggle = app.buttons["Monthly"]
        let yearlyToggle = app.buttons["Yearly"]

        XCTAssertTrue(monthlyToggle.exists || yearlyToggle.exists, "Billing toggle should exist")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "BillingToggle"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSubscriptionProductsDisplay() throws {
        let app = XCUIApplication()
        app.launch()

        // Open subscription view
        app.buttons["Subscribe"].tap()
        sleep(1)

        // Verify product cards are displayed
        let basicPlan = app.staticTexts["Basic"]
        let premiumPlan = app.staticTexts["Premium"]

        // At least one should be visible
        XCTAssertTrue(basicPlan.exists || premiumPlan.exists, "Subscription plans should be displayed")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "SubscriptionProducts"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
