import XCTest
@testable import Hidden_Bar

/// A double press of the shortcut opens macOS's overflow only when the user
/// opted in, because doing so takes a synthesized click.
final class DoublePressOverflowPreferencesTests: XCTestCase {

    private let key = UserDefaults.Key.doublePressRevealsSystemOverflow
    private var priorValue: Any?

    override func setUp() {
        super.setUp()
        priorValue = UserDefaults.standard.object(forKey: key)
    }

    override func tearDown() {
        UserDefaults.standard.set(priorValue, forKey: key)
        super.tearDown()
    }

    func test_offUntilTheUserOptsIn() {
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertNil(AppDelegate.defaultPreferenceValues[key])
        XCTAssertFalse(Preferences.doublePressRevealsSystemOverflow)
    }

    func test_settingPreference_persistsAndPostsPrefsChanged() {
        expectation(forNotification: .prefsChanged, object: nil)

        Preferences.doublePressRevealsSystemOverflow = true

        waitForExpectations(timeout: 0)
        XCTAssertTrue(Preferences.doublePressRevealsSystemOverflow)
    }
}
