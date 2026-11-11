//
//  OpenMenuDetector.swift
//  Hidden Bar
//
//  Copyright © 2026 Dwarves Foundation. All rights reserved.
//

import AppKit

// One on-screen window as the window server describes it. The frame is in
// global display coordinates: origin at the top-left of the primary display, y
// growing downward.
struct OnScreenWindow: Equatable {
    let ownerPID: pid_t
    let layer: Int
    let frame: CGRect
    let alpha: CGFloat
}

// Which apps have a menu open below the menu bar. No API reports another app's
// menu state, but a menu or status-item panel is an on-screen window while it is
// open and is gone once it closes, so the window list can be read for one when
// a collapse is about to happen.
//
// Only layer, frame, alpha and PID are used. They are readable for other
// processes without Screen Recording; window and owner names are not.
enum OpenMenuDetector {
    // Menus and panels measured on macOS 27 sat at layers 24 (pop-up menu), 25
    // (status) and 101, depending on the app. Below are desktop widgets (3) and
    // WindowManager (18); above, drag images (102) and invisible helpers (1000).
    static let menuLayers = 24...101

    // How far below the menu bar a menu's top edge may sit. Measured tops ranged
    // from above the screen to 2pt below the bar.
    static let topMargin: CGFloat = 8

    // A window counts when it hangs from a menu bar: its top edge is no further
    // than topMargin below a bar, and it reaches below that bar. The second
    // condition excludes the menu bar itself.
    static func ownersOfOpenMenus(in windows: [OnScreenWindow], menuBars: [CGRect]) -> Set<pid_t> {
        var owners: Set<pid_t> = []
        for window in windows where menuLayers.contains(window.layer) && window.alpha > 0 {
            let hangsFromABar = menuBars.contains { bar in
                window.frame.minX < bar.maxX && window.frame.maxX > bar.minX
                    && window.frame.minY <= bar.maxY + topMargin
                    && window.frame.maxY > bar.maxY
            }
            if hangsFromABar {
                owners.insert(window.ownerPID)
            }
        }
        return owners
    }

    // The processes that have a menu open now.
    static func ownersOfOpenMenus() -> Set<pid_t> {
        return ownersOfOpenMenus(in: onScreenWindows(), menuBars: menuBars())
    }

    private static func onScreenWindows() -> [OnScreenWindow] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { info in
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds) else { return nil }
            let alpha = info[kCGWindowAlpha as String] as? CGFloat ?? 1
            return OnScreenWindow(ownerPID: pid, layer: layer, frame: frame, alpha: alpha)
        }
    }

    // Every display's menu bar, in window-server coordinates. The bar's height is
    // what visibleFrame leaves out at the top; where that is nothing (the bar
    // hides on full-screen Spaces or when set to hide automatically, and can be
    // revealed with a menu open), the notch's inset or the status bar's
    // thickness stands in.
    private static func menuBars() -> [CGRect] {
        guard let primary = NSScreen.screens.first else { return [] }
        return NSScreen.screens.map { screen in
            let height = max(screen.frame.maxY - screen.visibleFrame.maxY,
                             screen.safeAreaInsets.top,
                             NSStatusBar.system.thickness)
            return CGRect(x: screen.frame.minX,
                          y: primary.frame.maxY - screen.frame.maxY,
                          width: screen.frame.width,
                          height: height)
        }
    }
}
