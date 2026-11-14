import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, en, ru, de, fr, es, it, pt, uk, zhHans = "zh-Hans", ja

    var id: String { rawValue }
    var nativeName: String {
        switch self {
        case .system: return L10n.text("language.system")
        case .en: return "English"
        case .ru: return "Русский"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .es: return "Español"
        case .it: return "Italiano"
        case .pt: return "Português"
        case .uk: return "Українська"
        case .zhHans: return "简体中文"
        case .ja: return "日本語"
        }
    }

    func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        for identifier in preferredLanguages {
            let code = identifier.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-").first.map(String.init)
            if code == "zh" { return .zhHans }
            if let language = AppLanguage(rawValue: code ?? ""), language != .system { return language }
        }
        return .en
    }
}

extension Notification.Name {
    static let appLanguageChanged = Notification.Name("NewFileAppLanguageChanged")
}

enum L10n {
    static let languageKey = "appLanguage"
    static var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: languageKey) ?? "") ?? .system
    }

    static let translations: [AppLanguage: [String: String]] = {
        var result: [AppLanguage: [String: String]] = [:]
        for language in AppLanguage.allCases where language != .system {
            guard let url = Bundle.main.resourceURL?.appendingPathComponent("\(language.rawValue).lproj/Localizable.strings"),
                  let data = try? Data(contentsOf: url),
                  let table = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else { continue }
            result[language] = table
        }
        return result
    }()

    static func text(_ key: String, language: AppLanguage? = nil) -> String {
        translations[(language ?? self.language).resolved()]?[key] ?? translations[.en]?[key] ?? key
    }

    static func format(_ key: String, _ value: String, language: AppLanguage? = nil) -> String {
        String(format: text(key, language: language), value)
    }
}
