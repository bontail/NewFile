import Foundation

enum FinderMenuSettings {
    static let defaultsDomain = "local.codex.newfile"
    static let titleKey = "finderMenuTitle"
    static var defaultTitle: String { L10n.text("menu.create") }

    static func title(from value: String?, language: AppLanguage? = nil) -> String {
        let singleLine = (value ?? "").components(separatedBy: .newlines).joined(separator: " ")
        let cleaned = String(singleLine.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }).trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? L10n.text("menu.create", language: language) : String(cleaned.prefix(80))
    }

    static func currentTitle() -> String {
        let defaults = UserDefaults(suiteName: defaultsDomain)
        // The containing app and the long-lived extension have separate caches.
        // Refresh before constructing each menu, including when the app is closed.
        defaults?.synchronize()
        let language = AppLanguage(rawValue: defaults?.string(forKey: L10n.languageKey) ?? "") ?? .system
        return title(from: defaults?.string(forKey: titleKey), language: language)
    }
}
