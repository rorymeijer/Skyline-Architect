#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The system's Reduce Motion setting (Phase 20): renderers skip flashing and other
/// non-essential motion when it is on.
enum Motion {
    static var reduced: Bool {
        #if os(macOS)
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        UIAccessibility.isReduceMotionEnabled
        #endif
    }
}
