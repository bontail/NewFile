import Foundation

@main
enum FileCreatorTests {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("NewFileTests-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        var checks = 0
        func expectFailure(_ operation: () throws -> Void) throws {
            do { try operation() } catch { checks += 1; return }
            fatalError("Expected operation to fail")
        }
        for name in ["notes.txt", "скрипт.py", "two words.md", ".gitignore", "no-extension", "a&b#c?.txt"] {
            let file = try FileCreator.create(in: root, name: name)
            let contents = try Data(contentsOf: file)
            precondition(contents.isEmpty)
            checks += 1
        }
        for name in ["", ".", "..", "../escape", "folder/name", "bad:name", "line\nbreak", "null\0byte", String(repeating: "я", count: 128)] {
            try expectFailure { _ = try FileCreator.create(in: root, name: name) }
        }
        let templated = try FileCreator.create(in: root, name: "template.md", contents: Data("# Привет\n".utf8))
        let templateData = try Data(contentsOf: templated)
        precondition(String(data: templateData, encoding: .utf8) == "# Привет\n")
        checks += 1
        let existing = root.appendingPathComponent("keep.txt")
        let original = Data("Do not overwrite".utf8)
        try original.write(to: existing)
        try expectFailure { _ = try FileCreator.create(in: root, name: "keep.txt") }
        let preserved = try Data(contentsOf: existing)
        precondition(preserved == original)
        try fm.createSymbolicLink(atPath: root.appendingPathComponent("link.txt").path, withDestinationPath: existing.path)
        try expectFailure { _ = try FileCreator.create(in: root, name: "link.txt") }
        try expectFailure { _ = try FileCreator.create(in: existing, name: "inside.txt") }
        try expectFailure { _ = try FileCreator.create(in: root.appendingPathComponent("missing"), name: "file.txt") }
        try expectFailure { _ = try FileCreator.create(in: URL(string: "https://example.com")!, name: "file.txt") }
        try fm.createDirectory(at: root.appendingPathComponent("folder"), withIntermediateDirectories: false)
        try expectFailure { _ = try FileCreator.create(in: root, name: "folder") }
        let unique = try FileCreator.createUnique(in: root, name: "keep.txt")
        precondition(unique.lastPathComponent == "keep 2.txt")
        checks += 1
        let linkUnique = try FileCreator.createUnique(in: root, name: "link.txt")
        precondition(linkUnique.lastPathComponent == "link 2.txt")
        checks += 1
        try fm.createSymbolicLink(atPath: root.appendingPathComponent("dangling.txt").path,
                                  withDestinationPath: root.appendingPathComponent("absent").path)
        let danglingUnique = try FileCreator.createUnique(in: root, name: "dangling.txt")
        precondition(danglingUnique.lastPathComponent == "dangling 2.txt")
        checks += 1
        let directoryUnique = try FileCreator.createUnique(in: root, name: "folder")
        precondition(directoryUnique.lastPathComponent == "folder 2")
        checks += 1
        let hiddenUnique = try FileCreator.createUnique(in: root, name: ".gitignore")
        precondition(hiddenUnique.lastPathComponent == ".gitignore 2")
        checks += 1
        let longName = String(repeating: "я", count: 125) + ".txt"
        _ = try FileCreator.createUnique(in: root, name: longName)
        let longUnique = try FileCreator.createUnique(in: root, name: longName)
        precondition(longUnique.lastPathComponent.utf8.count <= 255 && longUnique.pathExtension == "txt")
        checks += 1
        let lock = NSLock()
        var results = Set<URL>()
        var errors: [Error] = []
        DispatchQueue.concurrentPerform(iterations: 20) { _ in
            do {
                let result = try FileCreator.createUnique(in: root, name: "concurrent.txt")
                lock.lock(); results.insert(result); lock.unlock()
            } catch {
                lock.lock(); errors.append(error); lock.unlock()
            }
        }
        precondition(errors.isEmpty && results.count == 20)
        checks += 1
        print("Passed \(checks) checks: creation, names, no overwrite, symlinks, invalid destinations.")
    }
}
