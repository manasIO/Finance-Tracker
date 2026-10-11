import XCTest
import UIKit
@testable import FinanceTracker

@MainActor
final class AppThemeTests: XCTestCase {
    private func window() throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        return UIWindow(windowScene: scene)
    }

    func testSwitchingDarkLightAndSystemResetsWindowOverride() throws {
        let window = try window()
        let view = WindowAppearanceView()
        window.addSubview(view)
        view.theme = .dark
        XCTAssertEqual(window.overrideUserInterfaceStyle, .dark)
        view.theme = .light
        XCTAssertEqual(window.overrideUserInterfaceStyle, .light)
        view.theme = .system
        XCTAssertEqual(window.overrideUserInterfaceStyle, .unspecified)
    }

    func testSavedThemeAppliesWhenViewAttachesAndDoesNotAffectOtherWindows() throws {
        let first = try window()
        let second = try window()
        let view = WindowAppearanceView()
        view.theme = .dark
        first.addSubview(view)
        XCTAssertEqual(first.overrideUserInterfaceStyle, .dark)
        XCTAssertEqual(second.overrideUserInterfaceStyle, .unspecified)
    }

    func testThemeValuesPreserveExistingSavedPreferences() {
        XCTAssertEqual(AppTheme(rawValue: "light")?.interfaceStyle, .light)
        XCTAssertEqual(AppTheme(rawValue: "dark")?.interfaceStyle, .dark)
        XCTAssertEqual(AppTheme(rawValue: "system")?.interfaceStyle, .unspecified)
    }
}
