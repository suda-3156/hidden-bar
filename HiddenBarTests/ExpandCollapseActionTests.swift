//
//  ExpandCollapseActionTests.swift
//  HiddenBarTests
//
//  Copyright © 2026 Dwarves Foundation. All rights reserved.
//

import AppKit
import XCTest

final class ExpandCollapseActionTests: XCTestCase {

    // Assistive synthesis (VoiceOver AXPress) produces no NSEvent; a nil event
    // must still toggle the bar, matching a plain left click.
    func testNilEventToggles() {
        XCTAssertEqual(ExpandCollapseActionResolver.action(eventType: nil, optionPressed: false), .toggle)
    }

    func testLeftClickToggles() {
        XCTAssertEqual(ExpandCollapseActionResolver.action(eventType: .leftMouseUp, optionPressed: false), .toggle)
    }

    func testRightClickShowsContextMenu() {
        XCTAssertEqual(ExpandCollapseActionResolver.action(eventType: .rightMouseUp, optionPressed: false), .contextMenu)
    }

    func testOptionLeftTogglesSeparators() {
        XCTAssertEqual(ExpandCollapseActionResolver.action(eventType: .leftMouseUp, optionPressed: true), .toggleSeparators)
    }

    func testOptionRightTogglesSeparators() {
        XCTAssertEqual(ExpandCollapseActionResolver.action(eventType: .rightMouseUp, optionPressed: true), .toggleSeparators)
    }

    func testOtherMouseEventTogglesSeparators() {
        // Preserves the old else-branch: any non-left/right click lands on the
        // separators toggle.
        XCTAssertEqual(ExpandCollapseActionResolver.action(eventType: .otherMouseUp, optionPressed: false), .toggleSeparators)
    }
}

final class ShortcutDoublePressDetectorTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    func testFirstPressIsSingle() {
        var detector = ShortcutDoublePressDetector(interval: 0.4)
        XCTAssertFalse(detector.isDoublePress(at: start))
    }

    func testSecondPressWithinIntervalIsDouble() {
        var detector = ShortcutDoublePressDetector(interval: 0.4)
        _ = detector.isDoublePress(at: start)
        XCTAssertTrue(detector.isDoublePress(at: start.addingTimeInterval(0.3)))
    }

    func testSecondPressAfterIntervalStartsOver() {
        var detector = ShortcutDoublePressDetector(interval: 0.4)
        _ = detector.isDoublePress(at: start)
        XCTAssertFalse(detector.isDoublePress(at: start.addingTimeInterval(0.5)))
        XCTAssertTrue(detector.isDoublePress(at: start.addingTimeInterval(0.8)))
    }

    // A triple press is a double press followed by a new single one, not two
    // overlapping doubles.
    func testThirdPressIsSingleAgain() {
        var detector = ShortcutDoublePressDetector(interval: 0.4)
        _ = detector.isDoublePress(at: start)
        XCTAssertTrue(detector.isDoublePress(at: start.addingTimeInterval(0.2)))
        XCTAssertFalse(detector.isDoublePress(at: start.addingTimeInterval(0.3)))
    }
}
