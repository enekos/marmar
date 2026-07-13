import AppKit
import CoreGraphics

/// Global hold-to-talk hotkey via a CGEventTap on `.flagsChanged`.
///
/// We watch a *chord* of modifier keys, matched via CoreGraphics'
/// device-dependent flag bits so we can tell left from right. Default chord:
/// Right-Command + Right-Option. Using bare modifiers means the keys never emit
/// characters into the focused app, so the chord is safe to hold. Requires
/// Accessibility permission (same one we need to synthesize the paste).
final class HotKey {
    /// Device-dependent modifier flag bits (from IOKit's `NX_DEVICE*` masks).
    /// These distinguish left vs right, unlike the generic `.maskCommand` etc.
    enum Mod {
        static let leftControl: UInt64  = 0x00000001
        static let leftShift: UInt64    = 0x00000002
        static let rightShift: UInt64   = 0x00000004
        static let leftCommand: UInt64  = 0x00000008
        static let rightCommand: UInt64 = 0x00000010
        static let leftOption: UInt64   = 0x00000020
        static let rightOption: UInt64  = 0x00000040
        static let rightControl: UInt64 = 0x00002000
    }

    /// All of these bits must be present for the chord to be "held".
    /// Default: Right-Command + Right-Option.
    var requiredMask: UInt64 = Mod.rightCommand | Mod.rightOption

    var onDown: (() -> Void)?
    var onUp: (() -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isDown = false

    /// Returns false if the event tap couldn't be created (Accessibility not granted).
    @discardableResult
    func start() -> Bool {
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<HotKey>.fromOpaque(refcon).takeUnretainedValue()
            if type == .flagsChanged {
                me.handle(event)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    private func handle(_ event: CGEvent) {
        // The chord is "held" when every required device-flag bit is set. This
        // fires onDown the moment the last key of the chord goes down, and onUp
        // as soon as any key in the chord is released.
        let held = (event.flags.rawValue & requiredMask) == requiredMask
        if held && !isDown {
            isDown = true
            onDown?()
        } else if !held && isDown {
            isDown = false
            onUp?()
        }
    }
}
