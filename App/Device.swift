#if os(iOS)
import UIKit
#endif

/// The kind of device the app runs on (F5). Read from the device, not the size class, so
/// automated captures (which render outside the window) lay out like the window does.
enum Device {
    /// An iPhone: the chrome takes its compact layout — the cash readout beside the view
    /// controls, the narrow view controls.
    ///
    /// Read on the main thread only (views and the capture script); callable from code the
    /// compiler does not know to be isolated.
    static var isPhone: Bool {
        #if os(iOS)
        MainActor.assumeIsolated { UIDevice.current.userInterfaceIdiom == .phone }
        #else
        false
        #endif
    }
}
