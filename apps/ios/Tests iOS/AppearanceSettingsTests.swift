//
//  AppearanceSettingsTests.swift
//  Tests iOS
//
//  Test for theme system after simplification to Light + Dark
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import XCTest
@testable import POPOPXSwitch

class AppearanceSettingsTests: XCTestCase {

    func testDefaultThemeEnumValues() {
        XCTAssertEqual(DefaultTheme.LIGHT.themeName, "LIGHT")
        XCTAssertEqual(DefaultTheme.DARK.themeName, "DARK")
    }

    func testOnlyTwoThemesExist() {
        let allThemes: [DefaultTheme] = [.LIGHT, .DARK]
        XCTAssertEqual(allThemes.count, 2, "Should only have LIGHT and DARK themes")
    }

    func testThemeDecoderMapsUnknownToDark() throws {
        let json = "\"QUANTUM\""
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(DefaultTheme.self, from: data)
        XCTAssertEqual(decoded, .DARK, "Unknown theme names should decode to DARK")
    }

    func testThemeDecoderLightRoundtrip() throws {
        let json = "\"LIGHT\""
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(DefaultTheme.self, from: data)
        XCTAssertEqual(decoded, .LIGHT)
    }
}
