import XCTest
@testable import Hidden_Bar

/// StatusBarController installs and removes the hover monitor on
/// `.prefsChanged`, so toggling the Preferences checkbox takes effect without
/// a relaunch only as long as the setter posts that notification.
final class HoverToExpandPreferencesTests: XCTestCase {

    private var priorValue: Any?

    override func setUp() {
        super.setUp()
        priorValue = UserDefaults.standard.object(forKey: UserDefaults.Key.hoverToExpand)
    }

    override func tearDown() {
        UserDefaults.standard.set(priorValue, forKey: UserDefaults.Key.hoverToExpand)
        super.tearDown()
    }

    func test_settingPreference_persistsValue() {
        Preferences.hoverToExpand = true
        XCTAssertTrue(Preferences.hoverToExpand)

        Preferences.hoverToExpand = false
        XCTAssertFalse(Preferences.hoverToExpand)
    }

    func test_settingPreference_postsPrefsChanged() {
        expectation(forNotification: .prefsChanged, object: nil)

        Preferences.hoverToExpand = !Preferences.hoverToExpand

        waitForExpectations(timeout: 0)
    }
}
