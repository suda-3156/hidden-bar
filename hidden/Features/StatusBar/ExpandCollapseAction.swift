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

// Tells a double press of the global shortcut from two single ones. The first
// press still acts at once, so a single press is never delayed; the second
// counts as a double press only within `interval` of the first, and does not
// start another pair.
struct ShortcutDoublePressDetector {
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
