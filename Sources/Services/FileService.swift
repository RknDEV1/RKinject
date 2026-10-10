import Foundation
import ZIPFoundation

enum FileService {
    private static var fm: FileManager { .default }

    static func list(_ dir: URL, showHidden: Bool) throws -> [FileItem] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let urls = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys,
                                              options: showHidden ? [] : [.skipsHiddenFiles])
        return urls.map { item(for: $0) }
    }

    static func item(for url: URL) -> FileItem {
        let v = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
        return FileItem(url: url,
                        isDirectory: v?.isDirectory ?? false,
                        size: Int64(v?.fileSize ?? 0),
                        modified: v?.contentModificationDate)
    }

    /// Recursive name search. Cooperative cancellation, capped by result count and time.
    static func search(root: URL, query: String, showHidden: Bool, limit: Int = 300) async -> [FileItem] {
        guard let e = fm.enumerator(at: root,
                                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                                    options: showHidden ? [] : [.skipsHiddenFiles]) else { return [] }
        var out: [FileItem] = []
        let deadline = Date().addingTimeInterval(4)
        var visited = 0
        while let url = e.nextObject() as? URL {
            visited += 1
            if visited % 200 == 0, Task.isCancelled || Date() > deadline { break }
            if url.lastPathComponent.localizedCaseInsensitiveContains(query) {
                out.append(item(for: url))
                if out.count >= limit { break }
            }
        }
        return out
    }

    static func uniqueURL(_ url: URL) -> URL {
        guard fm.fileExists(atPath: url.path) else { return url }
        let dir = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var n = 2
        while true {
            let name = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            let candidate = dir.appendingPathComponent(name)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }

    private static func ensureNotInside(_ dir: URL, source: URL) throws {
        let d = dir.standardizedFileURL.path
        let s = source.standardizedFileURL.path
        if d == s || d.hasPrefix(s + "/") { throw RakiError.invalidDestination }
    }

    static func copy(_ urls: [URL], to dir: URL) throws {
        for u in urls {
            try ensureNotInside(dir, source: u)
            try fm.copyItem(at: u, to: uniqueURL(dir.appendingPathComponent(u.lastPathComponent)))
        }
    }

    static func move(_ urls: [URL], to dir: URL) throws {
        for u in urls {
            try ensureNotInside(dir, source: u)
            try fm.moveItem(at: u, to: uniqueURL(dir.appendingPathComponent(u.lastPathComponent)))
        }
    }

    @discardableResult
    static func rename(_ url: URL, to newName: String) throws -> URL {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.contains("/"), name != ".", name != ".." else { throw RakiError.invalidName }
        let dest = url.deletingLastPathComponent().appendingPathComponent(name)
        if dest == url { return url }
        if fm.fileExists(atPath: dest.path) { throw RakiError.exists(name) }
        try fm.moveItem(at: url, to: dest)
        return dest
    }

    static func delete(_ url: URL) throws {
        try fm.removeItem(at: url)
    }

    static func makeFolder(named name: String, in dir: URL) throws {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !n.contains("/") else { throw RakiError.invalidName }
        let dest = dir.appendingPathComponent(n, isDirectory: true)
        if fm.fileExists(atPath: dest.path) { throw RakiError.exists(n) }
        try fm.createDirectory(at: dest, withIntermediateDirectories: false)
    }

    static func zip(_ url: URL) throws {
        let base = url.deletingPathExtension().lastPathComponent
        let dest = uniqueURL(url.deletingLastPathComponent().appendingPathComponent(base + ".zip"))
        try fm.zipItem(at: url, to: dest, shouldKeepParent: true, compressionMethod: .deflate)
    }

    static func unzip(_ url: URL) throws {
        let base = url.deletingPathExtension().lastPathComponent
        let dest = uniqueURL(url.deletingLastPathComponent().appendingPathComponent(base, isDirectory: true))
        try fm.createDirectory(at: dest, withIntermediateDirectories: false)
        do {
            try fm.unzipItem(at: url, to: dest)
        } catch {
            try? fm.removeItem(at: dest)
            throw RakiError.unzip
        }
    }
}
