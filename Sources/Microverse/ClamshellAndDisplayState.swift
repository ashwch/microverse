import AppKit
import CoreGraphics
import Foundation
import IOKit

/// Helpers for “clamshell mode” and display topology.
///
/// Microverse uses this to implement the optional rule:
/// “Auto-enable the Desktop Widget when the lid is closed and an external display is connected.”
///
/// Keeping IOKit + display-topology code isolated prevents the core UI/view model from accumulating platform plumbing.
enum MicroverseClamshellState: Sendable {
    case open
    case closed
    case unknown
}

enum MicroverseClamshellStateProvider {
    static func current() -> MicroverseClamshellState {
        // Read the IOPMrootDomain property `AppleClamshellState`.
        // This is best-effort: if the key is unavailable, we fall back to `.unknown`.
        let entry: io_object_t
        if #available(macOS 12.0, *) {
            entry = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        } else {
            entry = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPMrootDomain"))
        }

        guard entry != IO_OBJECT_NULL else { return .unknown }
        defer { IOObjectRelease(entry) }

        guard let clamshellRef = IORegistryEntryCreateCFProperty(
            entry,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        ) else {
            return .unknown
        }

        let value = clamshellRef.takeRetainedValue()
        if let bool = value as? Bool {
            return bool ? .closed : .open
        }
        if let number = value as? NSNumber {
            return number.boolValue ? .closed : .open
        }

        return .unknown
    }
}

struct MicroverseDisplayTopology: Sendable, Equatable {
    var hasExternalDisplay: Bool
    var hasBuiltInDisplay: Bool

    static func current() -> MicroverseDisplayTopology {
        let screens = NSScreen.screens

        let hasBuiltIn = screens.contains(where: { $0.microverseIsBuiltIn })
        let hasExternal = screens.contains(where: { !$0.microverseIsBuiltIn })

        return MicroverseDisplayTopology(hasExternalDisplay: hasExternal, hasBuiltInDisplay: hasBuiltIn)
    }
}

private extension NSScreen {
    var microverseDisplayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    var microverseIsBuiltIn: Bool {
        guard let id = microverseDisplayID else { return false }
        return CGDisplayIsBuiltin(id) != 0
    }
}
