//
//  SystemOverflowButton.swift
//  Hidden Bar
//
//  Copyright © 2026 Dwarves Foundation. All rights reserved.
//

import AppKit
import ApplicationServices

// Opens the overflow button ("<<") that macOS 27 adds to the menu bar when the
// status items no longer fit beside the notch.
protocol SystemOverflowRevealing: AnyObject {
    // Waits for the button to appear, then presses it if `shouldPress` still
    // holds. Does nothing when everything fits and no button appears.
    func reveal(if shouldPress: @escaping () -> Bool)
}

// The button belongs to MenuBarAgent: it is the one AXButton among the
// AXHostingView groups under its AXExtrasMenuBar. Its description is localized
// and flips between "Show Hidden Menu Bar Items" and "Hide Menu Bar Items", so
// only the role identifies it. It exposes no Accessibility action (AXPress
// returns kAXErrorActionUnsupported, measured on 27.0, 26A428), so it is pressed
// with a synthesized click and the pointer is put back afterwards. Both costs
// are accepted and shown next to the preference: the click closes any open menu,
// and the warp back occasionally does not take. MenuBarAgent rebuilds the
// button closed whenever the hidden section is shown again, so a press right
// after expanding always opens it.
final class SystemOverflowButton: SystemOverflowRevealing {
    private static let bundleIdentifier = "com.apple.MenuBarAgent"
    private static let messagingTimeout: Float = 0.1
    // The button appears about 0.1s after the restriction is dropped.
    private static let pollInterval: TimeInterval = 0.05
    private static let waitLimit: TimeInterval = 2

    private let queue = DispatchQueue(label: "com.dwarvesv.minimalbar.system-overflow", qos: .userInitiated)
    // Bumped per request on the main queue, so only the latest one presses.
    private var generation = 0

    func reveal(if shouldPress: @escaping () -> Bool) {
        // Posting events needs the same permission as reading the bar.
        guard AXIsProcessTrusted(),
              let agent = NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier).first else { return }
        generation += 1
        let generation = self.generation
        let element = AXUIElementCreateApplication(agent.processIdentifier)
        AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
        queue.async { [weak self] in
            let deadline = Date().addingTimeInterval(Self.waitLimit)
            // Pressed once two reads agree, so a button still moving while the
            // bar reflows is not clicked where it no longer is.
            var lastFrame: CGRect?
            while Date() < deadline {
                let frame = Self.buttonFrame(in: element)
                if let frame = frame, frame == lastFrame {
                    DispatchQueue.main.async {
                        guard let self = self, generation == self.generation, shouldPress() else { return }
                        Self.click(at: CGPoint(x: frame.midX, y: frame.midY))
                    }
                    return
                }
                lastFrame = frame
                Thread.sleep(forTimeInterval: Self.pollInterval)
            }
            NSLog("SystemOverflow: no overflow button appeared; the menu bar fits")
        }
    }

    private static func buttonFrame(in agent: AXUIElement) -> CGRect? {
        var barValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(agent, "AXExtrasMenuBar" as CFString, &barValue) == .success,
              let bar = barValue else { return nil }
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(bar as! AXUIElement, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else { return nil }
        for child in children {
            var roleValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue) == .success,
                  roleValue as? String == kAXButtonRole as String else { continue }
            return frame(of: child)
        }
        return nil
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }

    // Accessibility and CGEvent share the top-left global coordinate space. Each
    // event carries its own location, so warping the pointer back straight away
    // does not move where the click lands.
    private static func click(at point: CGPoint) {
        let pointer = CGEvent(source: nil)?.location
        let source = CGEventSource(stateID: .hidSystemState)
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?
                .post(tap: .cghidEventTap)
        }
        if let pointer = pointer {
            CGWarpMouseCursorPosition(pointer)
        }
    }
}
