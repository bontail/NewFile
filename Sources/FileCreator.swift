import Foundation
import Darwin

enum FileCreator {
    static func createUnique(in directory: URL, name: String, contents: (String) -> Data = { _ in Data() }) throws -> URL {
        try validate(name)
        for number in 1...10000 {
            let candidate = try numberedName(name, number: number)
            do {
                return try create(in: directory, name: candidate, contents: contents(candidate))
            } catch {
                let error = error as NSError
                guard error.domain == NSPOSIXErrorDomain, error.code == Int(EEXIST) else { throw error }
            }
        }
        throw failure(L10n.text("error.unique"))
    }

    private static func numberedName(_ name: String, number: Int) throws -> String {
        guard number > 1 else { return name }
        let ext = (name as NSString).pathExtension
        let ending = " \(number)" + (ext.isEmpty ? "" : ".\(ext)")
        var base = (name as NSString).deletingPathExtension
        while (base + ending).utf8.count > 255, !base.isEmpty { base.removeLast() }
        let candidate = base + ending
        try validate(candidate)
        return candidate
    }

    static func validate(_ name: String) throws {
        guard !name.isEmpty, name != ".", name != "..",
              !name.contains("/"), !name.contains(":"),
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              name.utf8.count <= 255 else {
            throw failure(L10n.text("error.name"))
        }
    }

    static func create(in directory: URL, name: String, contents: Data = Data()) throws -> URL {
        try validate(name)
        guard directory.isFileURL else { throw failure(L10n.text("error.local")) }
        // Resolve the directory once and create relative to its descriptor.
        // O_EXCL also protects existing files and symbolic links atomically.
        let dir = open(directory.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard dir >= 0 else { throw posixError() }
        defer { close(dir) }
        let fd = openat(dir, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode_t(0o666))
        guard fd >= 0 else {
            if errno == EEXIST {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(EEXIST), userInfo: [
                    NSLocalizedDescriptionKey: L10n.text("error.exists")
                ])
            }
            throw posixError()
        }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        do { try handle.write(contentsOf: contents); try handle.close() }
        catch { unlinkat(dir, name, 0); throw error }
        return directory.appendingPathComponent(name, isDirectory: false)
    }

    private static func posixError() -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    private static func failure(_ message: String) -> NSError {
        NSError(domain: "NewFile", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
