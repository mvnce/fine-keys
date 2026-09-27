import AppKit
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let hasShownOnboardingKey = "hasShownOnboarding"

    private var item: NSStatusItem!
    private let menu = NSMenu()
    private let interceptor = MediaKeyInterceptor()
    private let defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["volume": true, "brightness": true])
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "FineKeys")
        menu.delegate = self
        item.menu = menu
        interceptor.onStateChange = { [weak self] state in self?.updateStatus(state) }
        configure()
        rebuildMenu()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(becameActive), name: NSApplication.didBecomeActiveNotification, object: nil)
        showOnboardingIfNeeded()
    }

    private func showOnboardingIfNeeded() {
        guard !defaults.bool(forKey: Self.hasShownOnboardingKey) else { return }
        defaults.set(true, forKey: Self.hasShownOnboardingKey)
        showHelp()
    }

    private func configure() {
        interceptor.configure(volume: defaults.bool(forKey: "volume"), brightness: defaults.bool(forKey: "brightness"))
    }
    @objc private func wake() { interceptor.refresh(retry: true) }
    @objc private func becameActive() { interceptor.refresh() }
    private func updateStatus(_ state: InterceptorState) {
        item.button?.appearsDisabled = state != .active
        item.button?.toolTip = "FineKeys: \(state.title)"
        menu.items.first?.title = "FineKeys · \(state.title)"
    }
    func menuWillOpen(_ menu: NSMenu) { interceptor.refresh(); rebuildMenu() }
    private func rebuildMenu() {
        menu.removeAllItems()
        menu.addItem(NSMenuItem(title: "FineKeys · \(interceptor.state.title)", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        add("Fine volume keys", #selector(toggle(_:)), key: "volume")
        add("Fine brightness keys", #selector(toggle(_:)), key: "brightness")
        if interceptor.state == .permissionRequired { add("Grant Accessibility Permission…", #selector(showHelp)) }
        if case .failed = interceptor.state { add("Retry Key Interception", #selector(retry)) }
        menu.addItem(.separator())
        switch SMAppService.mainApp.status {
        case .enabled:
            add("Launch at Login", #selector(toggleLogin)).state = .on
        case .requiresApproval:
            add("Launch at Login — Approval Required…", #selector(openLoginSettings)).state = .mixed
            add("Cancel Launch at Login", #selector(cancelLogin))
        case .notRegistered:
            add("Launch at Login", #selector(toggleLogin))
        case .notFound:
            add("Launch at Login — App Not Found…", #selector(loginUnavailable))
        @unknown default:
            add("Launch at Login — Check Settings…", #selector(openLoginSettings))
        }
        add("Setup & Help…", #selector(showHelp))
        menu.addItem(.separator())
        add("Quit FineKeys", #selector(quit))
        updateStatus(interceptor.state)
    }

    @discardableResult private func add(_ title: String, _ action: Selector, key: String? = nil) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        if let key { entry.representedObject = key; entry.state = defaults.bool(forKey: key) ? .on : .off }
        menu.addItem(entry)
        return entry
    }
    @objc private func toggle(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        defaults.set(!defaults.bool(forKey: key), forKey: key)
        configure(); rebuildMenu()
    }
    @objc private func retry() { interceptor.refresh(retry: true); rebuildMenu() }
    @objc private func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
    @objc private func cancelLogin() {
        do { try SMAppService.mainApp.unregister() }
        catch { showError(error.localizedDescription) }
        rebuildMenu()
    }
    @objc private func loginUnavailable() {
        showError("Move FineKeys to Applications, open that copy, and try again. macOS could not locate the login service.")
    }
    @objc private func toggleLogin() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled: try SMAppService.mainApp.unregister()
            case .notRegistered:
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .requiresApproval { openLoginSettings() }
            case .requiresApproval: openLoginSettings()
            case .notFound: loginUnavailable()
            @unknown default: openLoginSettings()
            }
        } catch { showError(error.localizedDescription) }
        rebuildMenu()
    }
    private func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "FineKeys needs attention"
        alert.informativeText = message
        alert.runModal()
    }
    @objc private func showHelp() {
        interceptor.requestAccessibilityPermission()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Make small adjustments with FineKeys"
        var message = "Enable FineKeys in System Settings → Privacy & Security → Accessibility. FineKeys connects automatically once allowed.\n\nPress your usual volume or display brightness keys for native fine steps. Turn off either option for normal steps on those keys. Explicit modifier shortcuts, mute, and playback stay unchanged.\n\nIf your top row uses F1–F12, keep holding Fn as usual. External displays and audio outputs must support native adjustments. Other media-key utilities may conflict.\n\nFineKeys processes media-key events locally. It does not record keystrokes or send data over the network."
        if case .failed(let reason) = interceptor.state { message += "\n\nCurrent issue: " + reason }
        alert.informativeText = message
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Done")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        interceptor.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
