import Foundation

@main enum SettingsTests {
    static func main() throws {
        let suite = "NewFileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set("ru", forKey: L10n.languageKey)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        var n = 0
        func check(_ value: Bool) { precondition(value); n += 1 }
        let s = FileSettings(defaults: defaults)
        check(!s.templates.isEmpty && s.defaultTemplate == 0)
        check(s.expand("# {name} in {folder}", name: "hello.md", folder: "test") == "# hello.md in test")
        s.dateFormat = "yyyy"
        let year = s.expand("{date}"); check(year.count == 4 && Int(year) != nil)
        let t = FileTemplate(title: "Test", filename: "notes.md", content: "Hello {name}")
        s.templates = [t]
        let loaded = FileSettings(defaults: defaults)
        check(loaded.templates.count == 1 && loaded.templates[0].content == t.content)
        let first = try s.createFile(in: root)
        check(first.lastPathComponent == "notes.md")
        let second = try s.createFile(in: root)
        check(second.lastPathComponent == "notes 2.md")
        let secondContents = try String(contentsOf: second, encoding: .utf8)
        check(secondContents == "Hello notes 2.md")
        let third = try s.createFile(in: root)
        check(third.lastPathComponent == "notes 3.md")
        let selected = FileTemplate(title: "Python", filename: "script.py", content: "# {folder}")
        s.templates.append(selected); s.defaultTemplate = 1
        let python = try s.createFile(in: root)
        check(python.lastPathComponent == "script.py")
        s.defaultTemplate = 100
        let fallback = try s.createFile(in: root)
        check(fallback.lastPathComponent == "notes 4.md")
        s.templates = []
        let emptyFallback = try s.createFile(in: root)
        check(emptyFallback.lastPathComponent == "Новый файл.txt")
        check(s.finderMenuTitle.isEmpty)
        s.finderMenuTitle = "Новый документ…"
        check(FileSettings(defaults: defaults).finderMenuTitle == "Новый документ…")
        check(FinderMenuSettings.title(from: nil) == FinderMenuSettings.defaultTitle)
        check(FinderMenuSettings.title(from: " \n\t ") == FinderMenuSettings.defaultTitle)
        check(FinderMenuSettings.title(from: "  Новый\nфайл\0  ") == "Новый файл")
        check(FinderMenuSettings.title(from: String(repeating: "я", count: 100)).count == 80)
        s.templates = FileSettings.defaultTemplates(language: .ru)
        let originalID = s.templates[0].id
        let custom = FileTemplate(title: "Мой шаблон", filename: "my-file.txt", content: "Custom content")
        s.templates.append(custom)
        s.templates[1].filename = "my-note.md"
        s.defaultTemplate = 1
        s.language = .en
        check(s.templates[0].filename == "New File.txt" && s.templates[0].id == originalID)
        check(s.templates[1].filename == "my-note.md" && s.defaultTemplate == 1)
        check(s.templates.last == custom && s.finderMenuTitle == "Новый документ…")
        check(FileSettings(defaults: defaults).language == .en)
        s.language = .ja
        check(s.templates[0].filename == "新規ファイル.txt" && s.templates.last == custom)
        check(FinderMenuSettings.title(from: "", language: .en) == "Create File")
        check(FinderMenuSettings.title(from: "", language: .ja) == "ファイルを作成")
        check(FinderMenuSettings.title(from: "Моя команда", language: .de) == "Моя команда")
        check(AppLanguage.system.resolved(preferredLanguages: ["de-AT"]) == .de)
        check(AppLanguage.system.resolved(preferredLanguages: ["zh-Hans-CN"]) == .zhHans)
        check(AppLanguage.system.resolved(preferredLanguages: ["nl-NL", "fr-FR"]) == .fr)
        check(AppLanguage.system.resolved(preferredLanguages: ["nl-NL"]) == .en)
        let english = L10n.translations[.en] ?? [:]
        check(english.count == 55 && L10n.translations.count == 10)
        for language in AppLanguage.allCases where language != .system {
            let table = L10n.translations[language] ?? [:]
            check(Set(table.keys) == Set(english.keys) && table.values.allSatisfy { !$0.isEmpty })
            check(english.allSatisfy { key, value in
                table[key]?.components(separatedBy: "%@").count == value.components(separatedBy: "%@").count
            })
            for template in FileSettings.defaultTemplates(language: language) { try FileCreator.validate(template.filename) }
        }
        let legacySuite = suite + "-legacy"
        let legacyDefaults = UserDefaults(suiteName: legacySuite)!
        defer { legacyDefaults.removePersistentDomain(forName: legacySuite) }
        legacyDefaults.set(try JSONEncoder().encode(FileSettings.defaultTemplates(language: .ru)), forKey: "templates")
        legacyDefaults.set("Создать файл…", forKey: FinderMenuSettings.titleKey)
        let migrated = FileSettings(defaults: legacyDefaults)
        check(migrated.language == .system && migrated.finderMenuTitle.isEmpty)
        check(migrated.templates[0].filename == L10n.text("template.text_filename", language: .system))
        print("Passed \(n) settings checks (templates, persistence, dates, numbering, menu title, 10 languages).")
    }
}
