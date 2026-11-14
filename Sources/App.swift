import Cocoa
import FinderSync
import SwiftUI
import CoreServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var settingsWindow: NSWindow?
    private var status: NSTextField?
    private var extensionButton: NSButton?
    private var setupInstructions: NSTextField?
    private var handlingRequest = false
    private var receivedRequest = ProcessInfo.processInfo.arguments.contains("--finder-request")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Permission settings resolve the current code signature by bundle ID.
        // Register this copy after moves or local rebuilds, before requesting access.
        LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
        buildMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshLanguage), name: .appLanguageChanged, object: nil)
        // URL events can arrive immediately after launch; avoid flashing setup.
        DispatchQueue.main.async { [self] in
            if !receivedRequest { showSetup() }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) { updateStatus() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag && !handlingRequest { showSetup() }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard !handlingRequest, let url = urls.first,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "local-newfile", parts.host == "create",
              let path = parts.queryItems?.first(where: { $0.name == "directory" })?.value,
              path.hasPrefix("/"), !path.contains("\0") else { return }
        receivedRequest = true
        createFile(in: URL(fileURLWithPath: path, isDirectory: true))
    }

    private func buildMenu() {
        let menu = NSMenu()
        let root = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L10n.text("menu.settings"), action: #selector(showPreferences), keyEquivalent: ",").target = self
        appMenu.addItem(withTitle: L10n.text("menu.start"), action: #selector(openSetup), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.text("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        root.submenu = appMenu
        menu.addItem(root)
        let edit = NSMenuItem()
        let editMenu = NSMenu(title: L10n.text("menu.edit"))
        for (title, action, key) in [("menu.cut", "cut:", "x"), ("menu.copy", "copy:", "c"), ("menu.paste", "paste:", "v"), ("menu.select_all", "selectAll:", "a")] {
            editMenu.addItem(withTitle: L10n.text(title), action: Selector(action), keyEquivalent: key)
        }
        edit.submenu = editMenu
        menu.addItem(edit)
        NSApp.mainMenu = menu
    }

    @objc private func openSetup() { showSetup() }

    private func showSetup() {
        if window == nil {
            let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 560),
                               styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            win.isReleasedWhenClosed = false
            win.center()
            buildSetupContent(in: win)
            window = win
        }
        updateStatus()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildSetupContent(in win: NSWindow) {
        win.contentView = NSView()
        win.title = L10n.text("app.title")
        let title = NSTextField(labelWithString: L10n.text("app.heading"))
        title.font = .systemFont(ofSize: 23, weight: .semibold)
        let body = NSTextField(wrappingLabelWithString: "")
        body.font = .systemFont(ofSize: 14)
        setupInstructions = body
        let state = NSTextField(labelWithString: "")
        self.status = state
        let enable = NSButton(title: L10n.text("button.enable"), target: self, action: #selector(enableExtension))
        enable.bezelStyle = .rounded
        extensionButton = enable
        let rename = NSButton(title: L10n.text("button.rename"), target: self, action: #selector(enableRenaming))
        rename.bezelStyle = .rounded
        let settings = NSButton(title: L10n.text("button.templates"), target: self, action: #selector(showPreferences))
        settings.bezelStyle = .rounded
        let stack = NSStackView(views: [title, body, state, enable, rename, settings])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        win.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: win.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: win.contentView!.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: win.contentView!.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: win.contentView!.bottomAnchor, constant: -28)
        ])
    }

    @objc private func refreshLanguage() {
        buildMenu()
        if let window { buildSetupContent(in: window) }
        settingsWindow?.title = L10n.text("settings.title")
        updateStatus()
    }

    @objc private func showPreferences() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: FileSettingsView()))
            w.title = L10n.text("settings.title"); w.isReleasedWhenClosed = false; w.center(); settingsWindow = w
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func updateStatus() {
        let enabled = FIFinderSyncController.isExtensionEnabled
        status?.stringValue = L10n.text(enabled ? "status.enabled" : "status.disabled")
        status?.textColor = enabled ? .systemGreen : .secondaryLabelColor
        extensionButton?.title = L10n.text(enabled ? "button.manage" : "button.enable")
        let actionTitle = FinderMenuSettings.title(from: FileSettings.shared.finderMenuTitle)
        setupInstructions?.stringValue = L10n.format("app.instructions", actionTitle)
    }

    @objc private func enableExtension() { FIFinderSyncController.showExtensionManagementInterface() }
    @objc private func enableRenaming() { FinderRenamer.requestPermission() }

    private func createFile(in directory: URL) {
        guard !handlingRequest else { return }
        handlingRequest = true
        do {
            let result = try FileSettings.shared.createFile(in: directory)
            FinderRenamer.revealAndRename(result) { [weak self] message in
                self?.handlingRequest = false
                if let message {
                    self?.status?.stringValue = message
                    NSLog("%@", message)
                    NSSound.beep()
                }
            }
        } catch {
            handlingRequest = false
            NSApp.activate(ignoringOtherApps: true)
            NSAlert(error: error).runModal()
        }
    }

}

@main
enum NewFileApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { application.run() }
    }
}
