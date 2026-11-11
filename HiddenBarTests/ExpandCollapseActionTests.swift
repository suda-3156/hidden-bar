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

final class DoublePressDetectorTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    func testFirstPressIsSingle() {
        var detector = DoublePressDetector(interval: 0.4)
        XCTAssertFalse(detector.isDoublePress(at: start))
    }

    func testSecondPressWithinIntervalIsDouble() {
        var detector = DoublePressDetector(interval: 0.4)
        _ = detector.isDoublePress(at: start)
        XCTAssertTrue(detector.isDoublePress(at: start.addingTimeInterval(0.3)))
    }

    func testSecondPressAfterIntervalStartsOver() {
        var detector = DoublePressDetector(interval: 0.4)
        _ = detector.isDoublePress(at: start)
        XCTAssertFalse(detector.isDoublePress(at: start.addingTimeInterval(0.5)))
        XCTAssertTrue(detector.isDoublePress(at: start.addingTimeInterval(0.8)))
    }

    // A triple press is a double press followed by a new single one, not two
    // overlapping doubles.
    func testThirdPressIsSingleAgain() {
        var detector = DoublePressDetector(interval: 0.4)
        _ = detector.isDoublePress(at: start)
        XCTAssertTrue(detector.isDoublePress(at: start.addingTimeInterval(0.2)))
        XCTAssertFalse(detector.isDoublePress(at: start.addingTimeInterval(0.3)))
    }
}

final class CollapsePolicyTests: XCTestCase {

    func testNothingBlocksByDefault() {
        XCTAssertEqual(CollapsePolicy.verdict(for: .autoHide, blockers: []), .proceed)
        XCTAssertEqual(CollapsePolicy.verdict(for: .request, blockers: []), .proceed)
    }

    func testAutoHideWaitsWhileTheUserIsBusy() {
        XCTAssertEqual(CollapsePolicy.verdict(for: .autoHide, blockers: .pointerInMenuBar), .deferred)
        XCTAssertEqual(CollapsePolicy.verdict(for: .autoHide, blockers: .preferencesWindowVisible), .deferred)
        XCTAssertEqual(CollapsePolicy.verdict(for: .autoHide, blockers: .hiddenAppMenuOpen), .deferred)
    }

    // The arrow and the shortcut are pressed with the pointer wherever it is.
    func testARequestIsNotDeferred() {
        XCTAssertEqual(CollapsePolicy.verdict(for: .request, blockers: [.pointerInMenuBar, .preferencesWindowVisible, .hiddenAppMenuOpen]), .proceed)
    }

    func testAHoldRefusesEveryCollapse() {
        XCTAssertEqual(CollapsePolicy.verdict(for: .request, blockers: .heldOpen), .refused)
        XCTAssertEqual(CollapsePolicy.verdict(for: .autoHide, blockers: .heldOpen), .refused)
    }

    // Deferring would re-arm the timer for as long as the hold lasts.
    func testAHoldWinsOverDeferring() {
        XCTAssertEqual(CollapsePolicy.verdict(for: .autoHide, blockers: [.heldOpen, .pointerInMenuBar]), .refused)
    }
}

// Rows from windows measured on macOS 27.2 with one display and a 1710x38 menu
// bar, while menus were opened and closed.
final class OpenMenuDetectorTests: XCTestCase {
    private let bar = CGRect(x: 0, y: 0, width: 1710, height: 38)

    private func window(pid: pid_t = 1, layer: Int, y: CGFloat, height: CGFloat,
                        x: CGFloat = 800, width: CGFloat = 300, alpha: CGFloat = 1) -> OnScreenWindow {
        return OnScreenWindow(ownerPID: pid, layer: layer,
                              frame: CGRect(x: x, y: y, width: width, height: height), alpha: alpha)
    }

    private func isOpen(_ window: OnScreenWindow, bars: [CGRect]? = nil) -> Bool {
        return !OpenMenuDetector.ownersOfOpenMenus(in: [window], menuBars: bars ?? [bar]).isEmpty
    }

    func testMenusAndPanelsUnderTheBarAreOpenMenus() {
        XCTAssertTrue(isOpen(window(layer: 24, y: 40, height: 253)), "Itsycal")
        XCTAssertTrue(isOpen(window(layer: 25, y: 30, height: 521)), "Vorssaint panel")
        XCTAssertTrue(isOpen(window(layer: 101, y: -36, height: 542)), "Little Snitch Mini Helper")
        XCTAssertTrue(isOpen(window(layer: 101, y: 40, height: 475)), "RunCat Neo")
        XCTAssertTrue(isOpen(window(layer: 101, y: 38, height: 1045)), "Control Center")
    }

    func testOtherWindowsAreNot() {
        XCTAssertFalse(isOpen(window(layer: 24, y: 0, height: 38, x: 0, width: 1710)), "the menu bar itself")
        XCTAssertFalse(isOpen(window(layer: 3, y: 45, height: 331)), "a desktop widget")
        XCTAssertFalse(isOpen(window(layer: 18, y: 0, height: 1112, x: 0, width: 1710)), "WindowManager")
        XCTAssertFalse(isOpen(window(layer: 1000, y: 1111, height: 1, x: 0, width: 1)), "an invisible helper")
        XCTAssertFalse(isOpen(window(layer: 102, y: -60, height: 100)), "a status item being dragged")
    }

    func testAMenuFarBelowTheBarOrInvisibleIsNot() {
        XCTAssertFalse(isOpen(window(layer: 101, y: 300, height: 200)), "a context menu inside a window")
        XCTAssertFalse(isOpen(window(layer: 101, y: 40, height: 475, alpha: 0)))
    }

    // A second display to the right of the primary, its top 200pt higher.
    func testEachDisplayHasItsOwnBar() {
        let second = CGRect(x: 1710, y: -200, width: 1920, height: 24)
        XCTAssertTrue(isOpen(window(layer: 101, y: -176, height: 300, x: 2000), bars: [bar, second]))
        XCTAssertFalse(isOpen(window(layer: 101, y: 30, height: 300, x: 2000), bars: [bar, second]),
                       "level with the primary bar, but far below the second one")
    }

    func testReportsEachOwnerOnce() {
        let windows = [window(pid: 7, layer: 101, y: 40, height: 475),
                       window(pid: 7, layer: 24, y: 40, height: 100),
                       window(pid: 9, layer: 3, y: 45, height: 331)]
        XCTAssertEqual(OpenMenuDetector.ownersOfOpenMenus(in: windows, menuBars: [bar]), [7])
    }
}
