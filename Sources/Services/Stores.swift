import Foundation
import SwiftUI

// MARK: - Toasts

@MainActor @Observable
final class ToastCenter {
    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        let isError: Bool
    }

    var current: Toast?

    func success(_ message: String) { show(message, isError: false) }

    func error(_ error: Error) {
        show(RakiError.wrap(error).errorDescription ?? error.localizedDescription, isError: true)
    }

    private func show(_ message: String, isError: Bool) {
        let t = Toast(message: message, isError: isError)
        current = t
        Task {
            try? await Task.sleep(for: .seconds(isError ? 5 : 2.5))
            if current?.id == t.id { current = nil }
        }
    }
}

// MARK: - Clipboard for copy / move

@MainActor @Observable
final class FileClipboard {
    enum Mode { case copy, move }
    var urls: [URL] = []
    var mode: Mode = .copy

    func set(_ urls: [URL], mode: Mode) { self.urls = urls; self.mode = mode }
    func clear() { urls = [] }
}

// MARK: - Sources

@MainActor @Observable
final class SourcesStore {
    var custom: [FileSource] = []
    private let key = "customSources"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([FileSource].self, from: data) { custom = list }
    }

    var builtin: [FileSource] {
        [
            FileSource(id: "docs", name: L("sources.app_documents"), path: Paths.documents.path, symbol: "doc.on.doc.fill"),
            FileSource(id: "lib", name: L("sources.app_library"), path: Paths.library.path, symbol: "books.vertical.fill"),
            FileSource(id: "imported", name: L("sources.imported"), path: Paths.imported.path, symbol: "square.and.arrow.down.fill"),
            FileSource(id: "installed", name: L("sources.installed_content"), path: Paths.installedRoot.path, symbol: "shippingbox.fill")
        ]
    }

    /// App Group containers listed in Info.plist (RakiAppGroups). Unavailable without the entitlement.
    var groups: [FileSource] {
        let ids = Bundle.main.object(forInfoDictionaryKey: "RakiAppGroups") as? [String] ?? []
        return ids.map { id in
            let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
            return FileSource(id: "group:\(id)", name: id, path: url?.path ?? "", symbol: "person.2.fill")
        }
    }

    func addCustom(name: String, path: String) throws {
        let p = path.trimmingCharacters(in: .whitespacesAndNewlines)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: p, isDirectory: &isDir), isDir.boolValue else { throw RakiError.notFound }
        guard FileManager.default.isReadableFile(atPath: p) else { throw RakiError.permission }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let src = FileSource(id: UUID().uuidString, name: n.isEmpty ? (p as NSString).lastPathComponent : n,
                             path: p, symbol: "folder.badge.gearshape", isCustom: true)
        custom.append(src)
        persist()
    }

    func removeCustom(at offsets: IndexSet) {
        custom.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(custom) { UserDefaults.standard.set(data, forKey: key) }
    }
}
