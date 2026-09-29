//
//  MenuBarEngineFactory.swift
//  Hidden Bar
//
//  Copyright © 2026 Dwarves Foundation. All rights reserved.
//

import Foundation

// The single place that picks a hiding mechanism for the running OS.
enum MenuBarEngineFactory {
    static func make(items: MenuBarItemProvider) -> MenuBarEngine {
        if usesNativeVisibility {
            return NativeVisibilityEngine(items: items)
        }
        return LegacyLengthEngine(items: items)
    }

    // Only native hiding can take the arrow away with the hidden section.
    static var canHideArrow: Bool {
        return usesNativeVisibility
    }

    // macOS 27 ejects an inflated separator from the menu bar (#360). The
    // direct build hides natively there instead. The App Store build cannot:
    // the sandbox blocks the Accessibility reads that locate the sections.
    private static var usesNativeVisibility: Bool {
        #if HIDDENBAR_NATIVE_VISIBILITY
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
        #else
        return false
        #endif
    }
}
