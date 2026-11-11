//
//  ExpandCollapseAction.swift
//  Hidden Bar
//
//  Copyright © 2026 Dwarves Foundation. All rights reserved.
//

import AppKit

// What a press on the expand/collapse button should do. Kept as a pure mapping
// so the decision is unit-testable without a live status item or a real NSEvent.
enum ExpandCollapseAction {
    case toggle
    case contextMenu
    case toggleSeparators
}

enum ExpandCollapseActionResolver {
    // A nil event type means there is no real NSEvent behind the press, which is
    // what assistive synthesis (VoiceOver AXPress) produces: treat it as a plain
    // left click so VoiceOver users can toggle the bar at all.
    static func action(eventType: NSEvent.EventType?, optionPressed: Bool) -> ExpandCollapseAction {
        guard let eventType = eventType else { return .toggle }
        if optionPressed { return .toggleSeparators }
        switch eventType {
        case .leftMouseUp: return .toggle
        case .rightMouseUp: return .contextMenu
        default: return .toggleSeparators
        }
    }
}

// Tells a double press of the global shortcut, or a double click on the arrow,
// from two single ones. The first press still acts at once, so a single press
// is never delayed; the second counts as a double press only within `interval`
// of the first, and does not start another pair.
struct DoublePressDetector {
    let interval: TimeInterval
    private var pendingPress: Date?

    init(interval: TimeInterval) {
        self.interval = interval
    }

    mutating func isDoublePress(at date: Date) -> Bool {
        if let pending = pendingPress, date.timeIntervalSince(pending) <= interval {
            pendingPress = nil
            return true
        }
        pendingPress = date
        return false
    }
}

// Why the hidden section should stay open for now. Each is checked where a
// collapse is about to happen; nothing here watches for them going away.
struct CollapseBlockers: OptionSet {
    let rawValue: Int

    // The user is in the middle of something a collapse would cut short:
    // hovering, clicking or dragging icons in the bar, or editing preferences
    // in a window the collapse can dismiss (#170).
    static let pointerInMenuBar = CollapseBlockers(rawValue: 1 << 0)
    static let preferencesWindowVisible = CollapseBlockers(rawValue: 1 << 1)
    // A menu or panel is open from an icon the collapse would hide. The pointer
    // is down in the menu then, below the menu bar.
    static let hiddenAppMenuOpen = CollapseBlockers(rawValue: 1 << 3)

    // The engine cannot hide anything right now and shows the whole bar
    // (MenuBarEngine.isHeldOpen).
    static let heldOpen = CollapseBlockers(rawValue: 1 << 2)
}

enum CollapseTrigger {
    // Asked for outright: the arrow, the shortcut, the collapse at launch.
    case request
    // The auto-collapse timer ran out.
    case autoHide
}

enum CollapseVerdict {
    case proceed
    // Not now; ask again after another auto-collapse interval.
    case deferred
    // Not until the blocker is gone, and whoever lifts it follows up.
    case refused
}

// Whether a collapse goes ahead. Kept as a pure mapping, like the resolver
// above, so the rules are unit-testable without a live menu bar.
enum CollapsePolicy {
    static func verdict(for trigger: CollapseTrigger, blockers: CollapseBlockers) -> CollapseVerdict {
        // Nothing can be hidden, whoever asks. Checked first, so the timer
        // does not keep re-arming through a hold of unknown length.
        if blockers.contains(.heldOpen) {
            return .refused
        }
        // Only the timer waits: a collapse the user asked for is the user's call.
        if trigger == .autoHide && !blockers.isEmpty {
            return .deferred
        }
        return .proceed
    }
}
