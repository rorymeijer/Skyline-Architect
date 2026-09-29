#if os(iOS)
import UIKit
#endif

/// The kind of device the app runs on (F5). Read from the device, not the size class, so
/// automated captures (which render outside the window) lay out like the window does.
enum Device {
    /// An iPhone: the chrome takes its compact layout — the cash readout in the top-left
    /// corner, the narrow view controls.
    @MainActor static var isPhone: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }
}
