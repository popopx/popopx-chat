//
//  PXTests_iOS.swift
//  Tests iOS
//
//  POPOPX test suite entry point.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import XCTest

class PXTests_iOS: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {}

    func testPOPOPXAppLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--px-test-mode"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    func testPOPOPXLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    func testPOPOPXMainScreenExists() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--px-test-mode"]
        app.launch()
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "POPOPX main window should be present after launch")
    }
}
