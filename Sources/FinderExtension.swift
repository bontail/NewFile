import Cocoa
import FinderSync

@objc(NewFileFinderExtension)
final class NewFileFinderExtension: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/", isDirectory: true)]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard let target = FIFinderSyncController.default().targetedURL(), target.isFileURL else { return nil }
        let menu = NSMenu()
        let item = NSMenuItem(title: FinderMenuSettings.currentTitle(), action: #selector(createFile(_:)), keyEquivalent: "")
        item.target = self
        // Finder transports menu items between processes; use the supported tag
        // and resolve the current target again inside the action callback.
        item.tag = Int(menuKind.rawValue)
        menu.addItem(item)
        return menu
    }

    @objc private func createFile(_ sender: NSMenuItem) {
        guard let target = FIFinderSyncController.default().targetedURL(), target.isFileURL else { return }
        let isContainer = sender.tag == Int(FIMenuKind.contextualMenuForContainer.rawValue)
        let isDirectory = (try? target.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        let directory = (isContainer || isDirectory || target.hasDirectoryPath) ? target : target.deletingLastPathComponent()
        var request = URLComponents()
        request.scheme = "local-newfile"
        request.host = "create"
        request.queryItems = [URLQueryItem(name: "directory", value: directory.path)]
        guard let url = request.url else { return }
        // The sandboxed extension does not write files or launch a shell.
        let host = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.arguments = ["--finder-request"]
        NSWorkspace.shared.open([url], withApplicationAt: host, configuration: configuration)
    }
}
