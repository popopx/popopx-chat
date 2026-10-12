//
//  PXTests_iOSLaunchTests.swift
//  Tests iOS
//
//  POPOPX launch verification tests.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import XCTest

class PXTests_iOSLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--px-test-mode"]
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "POPOPX Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLaunchWithDarkMode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--px-test-mode", "-AppleInterfaceStyle", "Dark"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
