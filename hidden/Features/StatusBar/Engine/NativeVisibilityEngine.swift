//
//  NativeVisibilityEngine.swift
//  Hidden Bar
//
//  Copyright © 2026 Dwarves Foundation. All rights reserved.
//

import AppKit

// macOS 27 hiding for the direct (non-App Store) build. Instead of inflating the
// separator, which macOS 27 ejects from the layout once it is too wide (#360),
// this reads which apps the user placed in each section and asks macOS to show
// only the allowed ones through the menu-bar visibility restriction behind
// assessment mode. macOS then hides the rest and reflows the bar itself, so the
// result does not depend on display width, the notch or the frontmost app's menus.
//
// The arrow is the boundary: apps left of it (LTR) are hidden, apps right of it
// stay visible. The regular separator is not needed and is taken out of the
// bar; even at zero width macOS keeps a gap for it. The always-hidden
// separator, when enabled, marks the third section; it shows while expanded so
// it can be ⌘-dragged, and drops to zero width while collapsed, where macOS
// has already removed everything it would separate. It keeps its slot because
// its position is what defines that section.
//
// The arrow itself can go with the hidden section while collapsed: leaving this
// app out of the allow-list makes macOS hide it too and close the gap. Its slot
// is untouched, so it comes back in place on expand. Hiding is per app, so the
// always-hidden separator goes with it, which changes nothing since it is at
// zero width while collapsed anyway.
//
// Limits, all from what macOS 27 exposes:
// - Hiding is per app: an app with several icons hides or shows them together
//   (the most visible section wins).
// - The restriction is assessment (exam) mode's, and macOS applies the rest of
//   that mode while it is held (#437): Now Playing, Live Activities and the
//   capsule naming the app that uses the microphone or camera are hidden
//   whatever the allow-list says (the dot in the screen corner stays), and
//   clicking the clock does not open Notification Center (the trackpad swipe
//   still does). MenuBarAgent accepts two other origins for the same request,
//   and neither helps: userSessionTransition ignores the allow-list and hides
//   nothing, and campoDrag is rejected (measured on 27.0, 26A428). To keep that
//   capsule visible, no restriction is held while a microphone or camera is in
//   use: the engine expands, reports isHeldOpen and refuses to collapse until
//   capture stops.
// - macOS's own items that the allow-list can name (see systemItemsToKeep) are
//   always kept visible: Accessibility cannot tell them apart, so they cannot be
//   mapped to sections.
//   SystemUIServer's legacy Menu Extras (Time Machine...) are the exception:
//   none was observed with a system item identifier, so they are sectioned
//   per bundle instead.
// - Sections are read only while nothing is hidden, because hidden items report
//   stale positions. They are re-read on the next collapse from an unrestricted
//   bar, so an app launched while collapsed stays hidden until then, the same
//   as a new icon landing in the hidden section under the old mechanism.
//   The collapse that follows a hold is the exception: it reuses the sections
//   of the collapse the hold interrupted, although the bar was unrestricted in
//   between, because the read takes about a second and would delay hiding
//   right when capture stops. Icons moved or apps launched during the hold are
//   picked up by the collapse after the next expand.
final class NativeVisibilityEngine: MenuBarEngine {
    // System item identifiers to keep visible. Unknown identifiers are ignored,
    // so the range covers items a given Mac does not have. On 27.0, 0-63 resolves
    // to battery, bluetooth, clock, displays, keyboard, volume, wifi,
    // screenMirroring and primaryBentoBox (Control Center).
    static let systemItemsToKeep = Array(0..<64)

    private weak var items: MenuBarItemProvider?
    private let inventory: MenuBarInventoryProviding
    private let visibility: NativeVisibilityProviding
    private let captureActivity: CaptureActivityMonitoring
    private let systemOverflow: SystemOverflowRevealing
    private let ownBundleIdentifier: String?
    private let itemFrame: (NSStatusItem) -> CGRect?
    private let isLTR: () -> Bool

    private let expandedLength: CGFloat = 20

    // .calibrating stands for "an activation is in flight".
    private(set) var state: MenuBarEngineState = .expanded
    private(set) var layout: MenuBarLayout?

    private var assertion: NativeVisibilityAssertion?
    // Bumped whenever a pending activation must no longer win (an expand, a newer
    // activation); a late success is then invalidated straight away.
    private var generation = 0
    private var lastUnavailableReason: String?
    // The capture state last acted on, so only a change moves the restriction.
    // Everything else reads this rather than the monitor, so the engine never
    // acts on a change it has not reported through onHoldChange yet.
    private var isCaptureActive: Bool

    var isHeldOpen: Bool {
        return isCaptureActive
    }

    var onHoldChange: (() -> Void)?

    // True from a hold that began while collapsed until the next collapse has
    // taken the cached sections, see the limits above.
    private var reusesLayoutAfterHold = false

    private var alwaysHiddenEnabled = false
    private var alwaysHiddenSeparatorHidden = false
    private var arrowHiddenWhenCollapsed = false

    init(items: MenuBarItemProvider,
         inventory: MenuBarInventoryProviding = AccessibilityMenuBarInventory(),
         visibility: NativeVisibilityProviding = NativeVisibilityBridge(),
         captureActivity: CaptureActivityMonitoring = CaptureActivityMonitor(),
         systemOverflow: SystemOverflowRevealing = SystemOverflowButton(),
         ownBundleIdentifier: String? = Bundle.main.bundleIdentifier,
         itemFrame: @escaping (NSStatusItem) -> CGRect? = { $0.button?.window?.frame },
         isLTR: @escaping () -> Bool = { Constant.isUsingLTRLanguage }) {
        self.items = items
        self.inventory = inventory
        self.visibility = visibility
        self.captureActivity = captureActivity
        self.systemOverflow = systemOverflow
        self.ownBundleIdentifier = ownBundleIdentifier
        self.itemFrame = itemFrame
        self.isLTR = isLTR
        isCaptureActive = captureActivity.isActive
        items.separatorItem.isVisible = false
        captureActivity.onChange = { [weak self] in
            self?.captureActivityDidChange()
        }
    }

    func collapse(completion: @escaping (CollapseResult) -> Void) {
        guard !isHeldOpen else {
            return completion(.unavailable)
        }
        switch state {
        case .collapsed:
            return completion(.collapsed)
        case .calibrating:
            // The activation in flight answers the request that started it.
            return
        case .expanded, .unavailable:
            break
        }
        setSeparatorsVisible(true)

        guard visibility.isAvailable else {
            logUnavailableOnce("the native menu-bar visibility API is not available in this build or on this macOS")
            state = .unavailable
            return completion(.unavailable)
        }
        guard inventory.isAuthorized else {
            // Without Accessibility the sections cannot be read, and guessing would
            // hide icons the user kept visible. Not latched: it works as soon as
            // the permission is granted.
            inventory.requestAuthorization()
            logUnavailableOnce("Accessibility permission is needed to read the menu-bar sections")
            return completion(.unavailable)
        }
        state = .calibrating
        withLayout { [weak self] layout in
            guard let self = self else { return }
            guard let layout = layout else {
                self.logUnavailableOnce("the arrow's position cannot be read yet")
                self.state = .expanded
                return completion(.unavailable)
            }
            // Only this once: a retry after a failure reads the bar afresh.
            self.reusesLayoutAfterHold = false
            let arrowHidden = self.arrowHiddenWhenCollapsed
            self.activate(allowing: layout.bundles(in: [.visible]), keepingArrow: !arrowHidden) { [weak self] succeeded in
                guard let self = self else { return }
                self.state = succeeded ? .collapsed : .expanded
                if succeeded {
                    self.setSeparatorsVisible(false)
                    // Changed while this was in flight.
                    if arrowHidden != self.arrowHiddenWhenCollapsed {
                        self.restorePresentation()
                    }
                }
                completion(succeeded ? .collapsed : .unavailable)
            }
        }
    }

    func expand() {
        setSeparatorsVisible(true)
        state = .expanded
        reusesLayoutAfterHold = false
        applyExpandedPresentation()
    }

    func updateAlwaysHiddenSection(enabled: Bool, separatorHidden: Bool) {
        alwaysHiddenEnabled = enabled
        alwaysHiddenSeparatorHidden = separatorHidden
        if state != .collapsed {
            setSeparatorsVisible(true)
        }
        if state == .expanded {
            applyExpandedPresentation()
        }
    }

    // Applied straight away while collapsed, so losing the last way to expand
    // without the arrow (the controller then passes false) brings it back.
    func updateArrowHidden(whenCollapsed hidden: Bool) {
        guard hidden != arrowHiddenWhenCollapsed else { return }
        arrowHiddenWhenCollapsed = hidden
        if state == .collapsed {
            restorePresentation()
        }
    }

    // The overflow button only exists once macOS has reflowed the expanded bar,
    // which it does on its own time; the press is dropped if the bar was
    // collapsed again in the meantime. Nor is anything pressed while held open,
    // including a press still pending when the hold starts: the bar is
    // expanded then, but not because the user asked, and the synthesized click
    // would move the pointer and close menus in the middle of a call.
    func revealSystemOverflow() {
        guard canRevealSystemOverflow else { return }
        systemOverflow.reveal { [weak self] in
            self?.canRevealSystemOverflow ?? false
        }
    }

    private var canRevealSystemOverflow: Bool {
        return state == .expanded && !isHeldOpen
    }

    // Native hiding does not depend on display geometry, so only drop the cached
    // sections; the next read from an unrestricted bar replaces them.
    func invalidateLayout() {
        if assertion == nil {
            layout = nil
            reusesLayoutAfterHold = false
        }
    }

    // Expanded shows the hidden section; the always-hidden section stays hidden
    // while "hide separators" is on, otherwise everything is revealed by dropping
    // the restriction altogether.
    private func applyExpandedPresentation() {
        guard !isHeldOpen, alwaysHiddenEnabled && alwaysHiddenSeparatorHidden, visibility.isAvailable, inventory.isAuthorized else {
            return releaseAssertion()
        }
        withLayout { [weak self] layout in
            guard let self = self else { return }
            guard let layout = layout else {
                return self.releaseAssertion()
            }
            self.activate(allowing: layout.bundles(in: [.visible, .hidden])) { _ in }
        }
    }

    // The sections as the user arranged them. Read fresh only from an
    // unrestricted bar; while a restriction is active the cached ones stand in,
    // as they do once after a hold.
    // Superseded by any later expand or activation, like an activation is.
    private func withLayout(_ body: @escaping (MenuBarLayout?) -> Void) {
        if assertion != nil || reusesLayoutAfterHold {
            return body(layout)
        }
        guard let arrow = items?.toggleItem,
              let boundary = itemFrame(arrow) else { return body(nil) }
        let alwaysHiddenFrame = alwaysHiddenEnabled ? items?.alwaysHiddenItem.flatMap(itemFrame) : nil
        let isLTR = self.isLTR()
        generation += 1
        let generation = self.generation
        inventory.snapshot { [weak self] inventory in
            guard let self = self, generation == self.generation else { return }
            let layout = MenuBarLayoutResolver.resolve(inventory: inventory,
                                                       separatorFrame: boundary,
                                                       alwaysHiddenSeparatorFrame: alwaysHiddenFrame,
                                                       isLTR: isLTR,
                                                       excludingBundle: self.ownBundleIdentifier)
            NSLog("NativeVisibility: arrow at x=\(boundary.midX); visible \(layout.bundles(in: [.visible])), hidden \(layout.bundles(in: [.hidden])), always hidden \(layout.bundles(in: [.alwaysHidden]))")
            self.layout = layout
            body(layout)
        }
    }

    // Activates the new restriction before dropping the old one, so switching
    // between collapsed and expanded never flashes the whole bar visible.
    private func activate(allowing bundles: [String], keepingArrow: Bool = true, completion: @escaping (Bool) -> Void) {
        // Callers do not get here while held open; any restriction at all would
        // hide the recording capsule, so this is checked once more.
        guard !isHeldOpen else {
            releaseAssertion()
            return completion(false)
        }
        generation += 1
        let generation = self.generation
        let own = keepingArrow ? ownBundleIdentifier.map { [$0] } ?? [] : []
        let allowed = own + bundles
        visibility.activate(allowedSystemItems: Self.systemItemsToKeep,
                            allowedBundleIdentifiers: allowed) { [weak self] result in
            guard let self = self, generation == self.generation else {
                if case .success(let stale) = result { stale.invalidate() }
                return
            }
            switch result {
            case .success(let newAssertion):
                let old = self.assertion
                self.assertion = newAssertion
                old?.invalidate()
                completion(true)
            case .failure(let error):
                // Fail open: never leave icons hidden after an error.
                NSLog("NativeVisibility: activation failed: \(error.localizedDescription)")
                self.releaseAssertion()
                completion(false)
            }
        }
    }

    // The always-hidden separator goes to zero width rather than isVisible =
    // false, which would make macOS forget where the user placed it.
    private func setSeparatorsVisible(_ visible: Bool) {
        items?.separatorItem.isVisible = false
        items?.alwaysHiddenItem?.length = visible && alwaysHiddenEnabled ? expandedLength : 0
    }

    // Any arrangement works: whatever sits left of the arrow is the hidden section.
    var isArrangementValid: Bool {
        return true
    }

    var isAlwaysHiddenSeparatorPlaced: Bool {
        return MenuBarOrder.isItem(items?.alwaysHiddenItem, onHiddenSideOf: items?.toggleItem)
    }

    private func releaseAssertion() {
        generation += 1
        assertion?.invalidate()
        assertion = nil
    }

    private func captureActivityDidChange() {
        let isActive = captureActivity.isActive
        guard isActive != isCaptureActive else { return }
        isCaptureActive = isActive
        if isActive {
            NSLog("NativeVisibility: a microphone or camera is in use; holding the whole menu bar open until it stops")
            // Supersedes a collapse in flight too: its completion never runs,
            // as when an expand overtakes it, and its late result is released.
            setSeparatorsVisible(true)
            reusesLayoutAfterHold = state == .collapsed && layout != nil
            if state == .collapsed || state == .calibrating {
                state = .expanded
            }
            releaseAssertion()
        } else {
            NSLog("NativeVisibility: capture stopped; hiding is possible again")
            restorePresentation()
        }
        onHoldChange?()
    }

    // Re-applies the current state, from a fresh read of the bar when nothing
    // restricts it (a hold just ended), else from the cached sections. A
    // failure leaves the bar whole (fail open).
    private func restorePresentation() {
        switch state {
        case .collapsed:
            withLayout { [weak self] layout in
                guard let self = self, let layout = layout else { return }
                self.activate(allowing: layout.bundles(in: [.visible]), keepingArrow: !self.arrowHiddenWhenCollapsed) { _ in }
            }
        case .expanded:
            applyExpandedPresentation()
        case .calibrating, .unavailable:
            // An activation in flight applies what is current when it lands;
            // unavailable holds nothing.
            break
        }
    }

    // Logged when the reason changes, so a retried collapse does not spam.
    private func logUnavailableOnce(_ reason: String) {
        guard reason != lastUnavailableReason else { return }
        lastUnavailableReason = reason
        NSLog("NativeVisibility: hiding unavailable: \(reason)")
    }
}
