import Foundation
import CryptoKit
import ZIPFoundation

@MainActor @Observable
final class PackageManager {
    var catalog: [CatalogPackage] = []
    var installed: [InstalledRecord] = []
    var activity: [ActivityEntry] = []
    var transient: [String: PackageState] = [:]
    var catalogError: String?
    var isLoadingCatalog = false

    private struct Persisted: Codable {
        var installed: [InstalledRecord]
        var activity: [ActivityEntry]
    }

    init() { load() }

    // MARK: State

    func state(for p: CatalogPackage) -> PackageState {
        if let s = transient[p.id] { return s }
        if let r = installed.first(where: { $0.id == p.id }) {
            return isNewer(p.version, than: r.version) ? .updateAvailable : .installed
        }
        return .notInstalled
    }

    var updates: [CatalogPackage] {
        catalog.filter { p in installed.contains { $0.id == p.id && isNewer(p.version, than: $0.version) } }
    }

    func record(for id: String) -> InstalledRecord? { installed.first { $0.id == id } }

    /// Catalog entry for an installed record; synthesized from the record when the catalog lacks it.
    func package(for r: InstalledRecord) -> CatalogPackage {
        catalog.first { $0.id == r.id }
            ?? CatalogPackage(id: r.id, name: r.name, kind: r.kind, version: r.version, size: r.size,
                              author: r.author, summary: r.summary, url: "", sha256: nil)
    }

    // MARK: Catalog

    func loadCatalog() async {
        isLoadingCatalog = true
        defer { isLoadingCatalog = false }
        catalogError = nil
        let bundled = Self.bundledCatalog()
        let remote = (UserDefaults.standard.string(forKey: "catalogURL") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remote.isEmpty else { catalog = bundled; return }
        do {
            guard let url = URL(string: remote), url.scheme?.hasPrefix("http") == true else { throw RakiError.invalidCatalog }
            let (data, resp) = try await URLSession.shared.data(from: url)
            if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw RakiError.network("HTTP \(http.statusCode)")
            }
            catalog = try JSONDecoder().decode(CatalogFile.self, from: data).packages
        } catch {
            catalog = bundled
            catalogError = RakiError.wrap(error).errorDescription
        }
    }

    private static func bundledCatalog() -> [CatalogPackage] {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(CatalogFile.self, from: data) else { return [] }
        return file.packages
    }

    // MARK: Install / remove

    func install(_ p: CatalogPackage) {
        switch transient[p.id] {
        case .downloading, .installing: return
        default: break
        }
        let wasInstalled = record(for: p.id) != nil
        transient[p.id] = .downloading(0)
        Task {
            var tempZip: URL?
            do {
                let zip = try await fetch(p)
                tempZip = zip
                if let expected = p.sha256?.lowercased(), !expected.isEmpty {
                    let actual = try await Task.detached { try Self.sha256(of: zip) }.value
                    guard actual == expected else { throw RakiError.checksum }
                }
                transient[p.id] = .installing
                let dir = Paths.packageDir(p.id)
                try await Task.detached(priority: .userInitiated) { try Self.extract(zip: zip, to: dir) }.value

                let rec = InstalledRecord(id: p.id, name: p.name, kind: p.kind, version: p.version, size: p.size,
                                          author: p.author, summary: p.summary, installedAt: Date())
                installed.removeAll { $0.id == p.id }
                installed.insert(rec, at: 0)
                transient[p.id] = nil
                log(L(wasInstalled ? "activity.updated" : "activity.installed", p.name, p.version))
            } catch {
                let msg = RakiError.wrap(error).errorDescription ?? ""
                transient[p.id] = .failed(msg)
                log(L("activity.failed", p.name, msg))
            }
            if let tempZip { try? FileManager.default.removeItem(at: tempZip) }
            save()
        }
    }

    func updateAll() {
        for p in updates { install(p) }
    }

    func remove(_ id: String) {
        guard let r = record(for: id) else { return }
        try? FileManager.default.removeItem(at: Paths.packageDir(id))
        installed.removeAll { $0.id == id }
        transient[id] = nil
        log(L("activity.removed", r.name))
        save()
    }

    func dismissFailure(_ id: String) {
        if case .failed = transient[id] { transient[id] = nil }
    }

    // MARK: Internals

    private func fetch(_ p: CatalogPackage) async throws -> URL {
        guard let url = URL(string: p.url) else { throw RakiError.invalidCatalog }
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("raki-\(UUID().uuidString).zip")

        if url.scheme == "bundle" {
            let name = (url.host ?? "") as NSString
            guard let src = Bundle.main.url(forResource: name.deletingPathExtension,
                                            withExtension: name.pathExtension) else { throw RakiError.notFound }
            for i in 1...5 {                       // brief simulated progress for local packages
                try await Task.sleep(for: .milliseconds(120))
                transient[p.id] = .downloading(Double(i) / 5)
            }
            try FileManager.default.copyItem(at: src, to: temp)
            return temp
        }

        let id = p.id
        let downloader = Downloader { [weak self] progress in
            Task { @MainActor in self?.transient[id] = .downloading(progress) }
        }
        return try await downloader.download(url)
    }

    nonisolated private static func sha256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated private static func extract(zip: URL, to dir: URL) throws {
        let fm = FileManager.default
        let staging = dir.deletingLastPathComponent().appendingPathComponent(".staging-\(UUID().uuidString)")
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            try fm.unzipItem(at: zip, to: staging)
        } catch {
            try? fm.removeItem(at: staging)
            throw RakiError.unzip
        }
        if fm.fileExists(atPath: dir.path) { try fm.removeItem(at: dir) }
        try fm.moveItem(at: staging, to: dir)
    }

    private func log(_ text: String) {
        activity.insert(ActivityEntry(date: Date(), text: text), at: 0)
        if activity.count > 30 { activity.removeLast(activity.count - 30) }
    }

    private func load() {
        guard let data = try? Data(contentsOf: Paths.stateFile),
              let p = try? JSONDecoder().decode(Persisted.self, from: data) else { return }
        installed = p.installed
        activity = p.activity
    }

    private func save() {
        let p = Persisted(installed: installed, activity: activity)
        if let data = try? JSONEncoder().encode(p) { try? data.write(to: Paths.stateFile, options: .atomic) }
    }
}
