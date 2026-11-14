import Cocoa
import ApplicationServices

enum FinderRenamer {
    static var isTrusted: Bool { AXIsProcessTrusted() && CGPreflightPostEventAccess() }

    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func revealAndRename(_ file: URL, completion: @escaping (String?) -> Void) {
        NSWorkspace.shared.activateFileViewerSelecting([file])
        guard isTrusted else {
            NSLog("NewFile rename permission: accessibility=%d, postEvents=%d, application=%@",
                  AXIsProcessTrusted() ? 1 : 0, CGPreflightPostEventAccess() ? 1 : 0, Bundle.main.bundlePath)
            completion(L10n.text("rename.permission"))
            return
        }
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else {
            completion(L10n.text("rename.unavailable"))
            return
        }
        let application = AXUIElementCreateApplication(finder.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.2)
        waitForSelection(file, finder: finder, application: application,
                         deadline: Date().addingTimeInterval(4), completion: completion)
    }

    private static func waitForSelection(_ file: URL, finder: NSRunningApplication, application: AXUIElement,
                                         deadline: Date, completion: @escaping (String?) -> Void) {
        let focused = element(attribute(application, kAXFocusedUIElementAttribute))
        let editing = focused.flatMap { attribute($0, kAXRoleAttribute) as? String } == kAXTextFieldRole as String
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == finder.processIdentifier,
           !editing, let window = element(attribute(application, kAXFocusedWindowAttribute)),
           selectionContains(file, in: window) {
            // Address Finder specifically, after verifying the newly created file
            // is selected. Never send Return globally or retry the key press.
            let down = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true)
            let up = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: false)
            down?.flags = []; up?.flags = []
            down?.postToPid(finder.processIdentifier)
            up?.postToPid(finder.processIdentifier)
            waitForEditor(file, application: application, deadline: Date().addingTimeInterval(2), completion: completion)
        } else if Date() < deadline {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                waitForSelection(file, finder: finder, application: application, deadline: deadline, completion: completion)
            }
        } else {
            completion(L10n.text("rename.not_ready"))
        }
    }

    private static func waitForEditor(_ file: URL, application: AXUIElement, deadline: Date,
                                      completion: @escaping (String?) -> Void) {
        if let focused = element(attribute(application, kAXFocusedUIElementAttribute)),
           attribute(focused, kAXRoleAttribute) as? String == kAXTextFieldRole as String,
           let value = attribute(focused, kAXValueAttribute) as? String,
           value == file.lastPathComponent || value == file.deletingPathExtension().lastPathComponent {
            completion(nil)
        } else if Date() < deadline {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                waitForEditor(file, application: application, deadline: deadline, completion: completion)
            }
        } else {
            completion(L10n.text("rename.not_confirmed"))
        }
    }

    private static func selectionContains(_ file: URL, in window: AXUIElement) -> Bool {
        var pending = [window]
        var remaining = 512
        while let node = pending.popLast(), remaining > 0 {
            remaining -= 1
            for key in [kAXSelectedRowsAttribute, kAXSelectedChildrenAttribute] {
                if let selected = attribute(node, key) as? [AXUIElement],
                   selected.contains(where: { containsURL(file, in: $0, depth: 6) }) { return true }
            }
            if let children = attribute(node, kAXChildrenAttribute) as? [AXUIElement] {
                pending.append(contentsOf: children.reversed())
            }
        }
        return false
    }

    private static func containsURL(_ file: URL, in node: AXUIElement, depth: Int) -> Bool {
        if let url = attribute(node, kAXURLAttribute) as? URL,
           url.standardizedFileURL.resolvingSymlinksInPath() == file.standardizedFileURL.resolvingSymlinksInPath() { return true }
        guard depth > 0, let children = attribute(node, kAXChildrenAttribute) as? [AXUIElement] else { return false }
        return children.contains { containsURL(file, in: $0, depth: depth - 1) }
    }

    private static func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return value
    }

    private static func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
}
