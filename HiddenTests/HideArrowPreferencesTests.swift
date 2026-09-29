import XCTest
@testable import Hidden_Bar

/// The arrow is hidden only while something else can expand a collapsed bar,
/// and StatusBarController re-applies that on `.prefsChanged`.
final class HideArrowPreferencesTests: XCTestCase {

    private let keys = [UserDefaults.Key.hideArrowWhenCollapsed,
                        UserDefaults.Key.globalKey,
                        UserDefaults.Key.hoverToExpand]
    private var priorValues: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        for key in keys {
            priorValues[key] = UserDefaults.standard.object(forKey: key)
        }
        Preferences.globalKey = nil
        Preferences.hoverToExpand = false
    }

    override func tearDown() {
        for key in keys {
            UserDefaults.standard.set(priorValues[key], forKey: key)
        }
        super.tearDown()
    }

    func test_arrowStaysWithoutAnotherWayToExpand() {
        Preferences.hideArrowWhenCollapsed = true
        XCTAssertFalse(Preferences.isArrowHiddenWhenCollapsed)
    }

    func test_shortcutAllowsHidingTheArrow() {
        Preferences.hideArrowWhenCollapsed = true
        Preferences.globalKey = GlobalKeybindPreferences(function: false, control: false, command: true,
                                                         shift: false, option: true, capsLock: false,
                                                         carbonFlags: 0, characters: "h", keyCode: 4)
        XCTAssertTrue(Preferences.isArrowHiddenWhenCollapsed)

        Preferences.globalKey = nil
        XCTAssertFalse(Preferences.isArrowHiddenWhenCollapsed)
    }

    func test_hoverAllowsHidingTheArrow() {
        Preferences.hideArrowWhenCollapsed = true
        Preferences.hoverToExpand = true
        XCTAssertTrue(Preferences.isArrowHiddenWhenCollapsed)

        Preferences.hideArrowWhenCollapsed = false
        XCTAssertFalse(Preferences.isArrowHiddenWhenCollapsed)
    }

    func test_settingPreference_postsPrefsChanged() {
        expectation(forNotification: .prefsChanged, object: nil)

        Preferences.hideArrowWhenCollapsed = !Preferences.hideArrowWhenCollapsed

        waitForExpectations(timeout: 0)
    }
}
