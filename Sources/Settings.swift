import SwiftUI
import Cocoa

struct FileTemplate: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var filename: String
    var content: String
}
final class FileSettings: ObservableObject {
    static let shared = FileSettings()
    @Published var templates: [FileTemplate] { didSet { save() } }
    @Published var defaultTemplate: Int { didSet { save() } }
    @Published var dateFormat: String { didSet { save() } }
    @Published var finderMenuTitle: String { didSet { save() } }
    @Published var language: AppLanguage {
        didSet {
            translateDefaultTemplates(to: language.resolved())
            save()
            NotificationCenter.default.post(name: .appLanguageChanged, object: self)
        }
    }
    private let defaults: UserDefaults
    private var templatesLanguage: AppLanguage
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let d = defaults
        language = AppLanguage(rawValue: d.string(forKey: L10n.languageKey) ?? "") ?? .system
        let decoded = d.data(forKey: "templates").flatMap { try? JSONDecoder().decode([FileTemplate].self, from: $0) }
        let selectedLanguage = AppLanguage(rawValue: d.string(forKey: L10n.languageKey) ?? "") ?? .system
        templatesLanguage = AppLanguage(rawValue: d.string(forKey: "templatesLanguage") ?? "")
            ?? (decoded == nil ? selectedLanguage.resolved() : .ru)
        templates = decoded ?? Self.defaultTemplates(language: selectedLanguage)
        defaultTemplate = d.integer(forKey: "defaultTemplate")
        dateFormat = d.string(forKey: "dateFormat") ?? "yyyy-MM-dd"
        let savedTitle = d.string(forKey: FinderMenuSettings.titleKey) ?? ""
        // Version 3 stored the default label as text. An empty value now means
        // the translated default; custom labels, including user edits, stay intact.
        finderMenuTitle = savedTitle == "Создать файл…" && d.object(forKey: L10n.languageKey) == nil ? "" : savedTitle
        translateDefaultTemplates(to: selectedLanguage.resolved())
        save()
    }
    func save() {
        let d = defaults
        if let data = try? JSONEncoder().encode(templates) { d.set(data, forKey: "templates") }
        d.set(defaultTemplate, forKey: "defaultTemplate")
        d.set(dateFormat, forKey: "dateFormat")
        d.set(finderMenuTitle, forKey: FinderMenuSettings.titleKey)
        d.set(language.rawValue, forKey: L10n.languageKey)
        d.set(templatesLanguage.rawValue, forKey: "templatesLanguage")
    }
    static func defaultTemplates(language: AppLanguage) -> [FileTemplate] {
        [FileTemplate(title: L10n.text("template.text", language: language), filename: L10n.text("template.text_filename", language: language), content: ""),
         FileTemplate(title: "Markdown", filename: L10n.text("template.markdown_filename", language: language), content: "# {name}\n\n"),
         FileTemplate(title: "Python", filename: "script.py", content: "#!/usr/bin/env python3\n\n"),
         FileTemplate(title: L10n.text("template.empty", language: language), filename: L10n.text("template.untitled", language: language), content: "")]
    }

    private func translateDefaultTemplates(to newLanguage: AppLanguage) {
        guard templatesLanguage != newLanguage else { return }
        let oldDefaults = Self.defaultTemplates(language: templatesLanguage)
        let newDefaults = Self.defaultTemplates(language: newLanguage)
        let translated = templates.map { template -> FileTemplate in
            guard let index = oldDefaults.firstIndex(where: {
                $0.title == template.title && $0.filename == template.filename && $0.content == template.content
            }) else { return template }
            var updated = newDefaults[index]
            updated.id = template.id
            return updated
        }
        templatesLanguage = newLanguage
        if translated != templates { templates = translated }
    }

    func expand(_ string: String, name: String = "", folder: String = "") -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: language.resolved().rawValue)
        f.dateFormat = dateFormat
        return string.replacingOccurrences(of: "{date}", with: f.string(from: Date()))
            .replacingOccurrences(of: "{name}", with: name).replacingOccurrences(of: "{folder}", with: folder)
    }
    func createFile(in directory: URL) throws -> URL {
        let template = templates.indices.contains(defaultTemplate) ? templates[defaultTemplate]
            : templates.first ?? Self.defaultTemplates(language: language)[0]
        let name = expand(template.filename, folder: directory.lastPathComponent)
        return try FileCreator.createUnique(in: directory, name: name) { finalName in
            Data(expand(template.content, name: finalName, folder: directory.lastPathComponent).utf8)
        }
    }
}
struct FileSettingsView: View {
    @ObservedObject var settings = FileSettings.shared
    @State private var renameAllowed = FinderRenamer.isTrusted
    private func text(_ key: String) -> String { L10n.text(key, language: settings.language) }
    var body: some View {
        Form {
            Section(text("section.language")) {
                Picker(text("label.language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language == .system ? text("language.system") : language.nativeName).tag(language)
                    }
                }
                Text(text("hint.language")).font(.caption).foregroundColor(.secondary)
            }
            Section(text("section.finder")) {
                TextField(text("label.action"), text: $settings.finderMenuTitle, prompt: Text(text("menu.create")))
                Text(L10n.format("title.preview", FinderMenuSettings.title(from: settings.finderMenuTitle, language: settings.language), language: settings.language))
                    .font(.caption).foregroundColor(.secondary)
                Text(text("hint.finder"))
                    .font(.caption).foregroundColor(.secondary)
                Button(text("button.reset")) { settings.finderMenuTitle = "" }
            }
            Section(text("section.behavior")) {
                Text(text("hint.behavior"))
                TextField(text("label.date"), text: $settings.dateFormat)
                Picker(text("label.default_template"), selection: $settings.defaultTemplate) {
                    ForEach(Array(settings.templates.enumerated()), id: \.element.id) { index, t in Text(t.title).tag(index) }
                }
            }
            Section(text("section.rename")) {
                Text(text(renameAllowed ? "status.trusted" : "permission.hint"))
                    .foregroundColor(renameAllowed ? .secondary : .primary)
                Button(text("button.rename")) { FinderRenamer.requestPermission() }
            }
            Section(text("section.templates")) {
                Text(text("hint.templates")).font(.caption).foregroundColor(.secondary)
                ForEach($settings.templates) { $template in
                    VStack(alignment: .leading) {
                        HStack { TextField(text("label.title"), text: $template.title); TextField(text("label.filename"), text: $template.filename) }
                        TextEditor(text: $template.content).font(.system(.body, design: .monospaced)).frame(height: 80).border(Color.secondary.opacity(0.3))
                        Button(text("button.delete")) { settings.templates.removeAll { $0.id == template.id }; settings.defaultTemplate = 0 }.disabled(settings.templates.count <= 1)
                    }.padding(.vertical, 6)
                }
                Button(text("button.add")) { settings.templates.append(FileTemplate(title: text("template.new"), filename: "file.txt", content: "")) }
            }
        }.formStyle(.grouped).frame(minWidth: 640, minHeight: 660)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                renameAllowed = FinderRenamer.isTrusted
            }
    }
}
