import AppKit
import ApplicationServices

enum InterceptorState: Equatable {
    case disabled, permissionRequired, active, failed(String)
    var title: String {
        switch self {
        case .disabled: return "Normal adjustments"
        case .permissionRequired: return "Accessibility permission needed"
        case .active: return "Fine adjustments active"
        case .failed: return "Key interception unavailable — Retry"
        }
    }
}

final class MediaKeyInterceptor {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var permissionTimer: Timer?
    private var healthTimer: Timer?
    private var volume = false
    private var brightness = false
    private var enabled: Bool { volume || brightness }
    var onStateChange: ((InterceptorState) -> Void)?
    private(set) var state: InterceptorState = .disabled {
        didSet { if state != oldValue { onStateChange?(state) } }
    }

    func configure(volume: Bool, brightness: Bool) {
        self.volume = volume
        self.brightness = brightness
        refresh(retry: true)
    }

    func requestAccessibilityPermission() {
        guard !AXIsProcessTrusted() else { return }
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func refresh(retry: Bool = false) {
        precondition(Thread.isMainThread)
        guard enabled else { stop(); state = .disabled; return }
        guard AXIsProcessTrusted() else {
            tearDownTap()
            state = .permissionRequired
            if permissionTimer == nil {
                permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                    self?.refresh()
                }
                permissionTimer?.tolerance = 0.5
            }
            return
        }
        permissionTimer?.invalidate(); permissionTimer = nil
        if let tap, CFMachPortIsValid(tap) {
            if !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
            if CGEvent.tapIsEnabled(tap: tap) { state = .active; return }
        }
        if case .failed = state, !retry { return }
        tearDownTap()
        start()
    }

    private func start() {
        let mask = CGEventMask(1) << NSEvent.EventType.systemDefined.rawValue
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<MediaKeyInterceptor>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    DispatchQueue.main.async { [weak owner] in owner?.refresh(retry: true) }
                } else {
                    MediaKeyInterceptor.transform(event, volume: owner.volume, brightness: owner.brightness)
                }
                return Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
                state = .failed("macOS did not create the event tap despite Accessibility permission. Try Retry Key Interception, or quit and reopen FineKeys.")
                return
            }
        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            state = .failed("Could not attach key interception to the run loop.")
            return
        }
        tap = newTap; source = newSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        guard CGEvent.tapIsEnabled(tap: newTap) else {
            tearDownTap()
            state = .failed("macOS created the event tap but did not enable it.")
            return
        }
        state = .active
        healthTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.refresh() }
        healthTimer?.tolerance = 5
    }

    static func transform(_ event: CGEvent, volume: Bool, brightness: Bool) {
        guard let cocoa = NSEvent(cgEvent: event), cocoa.type == .systemDefined,
              cocoa.subtype.rawValue == 8 else { return }
        let key = (cocoa.data1 >> 16) & 0xffff
        event.flags = KeyPolicy.flags(key: key, flags: event.flags, volume: volume, brightness: brightness)
    }

    private func tearDownTap() {
        healthTimer?.invalidate(); healthTimer = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil; tap = nil
    }

    func stop() {
        permissionTimer?.invalidate(); permissionTimer = nil
        tearDownTap()
        state = .disabled
    }
    deinit { stop() }
}
