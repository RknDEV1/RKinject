import SwiftUI

// MARK: - Localization helpers

/// Formatted lookup in Localizable.strings.
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: args)
}

extension Int64 {
    var byteString: String { ByteCountFormatter.string(fromByteCount: self, countStyle: .file) }
}

// MARK: - Packages

enum PackageKind: String, Codable, CaseIterable, Identifiable {
    case patch, wallpaper, dialerTheme

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .patch: return "kind.patch"
        case .wallpaper: return "kind.wallpaper"
        case .dialerTheme: return "kind.dialer"
        }
    }

    var symbol: String {
        switch self {
        case .patch: return "wrench.and.screwdriver.fill"
        case .wallpaper: return "photo.fill"
        case .dialerTheme: return "phone.fill"
        }
    }

    var tint: Color {
        switch self {
        case .patch: return .indigo
        case .wallpaper: return .teal
        case .dialerTheme: return .orange
        }
    }
}

struct CatalogPackage: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let kind: PackageKind
    let version: String
    let size: Int64
    let author: String
    let summary: String
    let url: String
    let sha256: String?
}

struct CatalogFile: Codable {
    let packages: [CatalogPackage]
}

struct InstalledRecord: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let kind: PackageKind
    let version: String
    let size: Int64
    let author: String
    let summary: String
    let installedAt: Date
}

enum PackageState: Equatable {
    case notInstalled
    case downloading(Double)
    case installing
    case installed
    case updateAvailable
    case failed(String)
}

struct ActivityEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    let date: Date
    let text: String
}

func isNewer(_ a: String, than b: String) -> Bool {
    a.compare(b, options: .numeric) == .orderedDescending
}

// MARK: - Files

struct FileSource: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let path: String        // empty = unavailable
    let symbol: String
    var isCustom = false

    var isAvailable: Bool { !path.isEmpty }
}

struct FileItem: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let size: Int64
    let modified: Date?

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var ext: String { url.pathExtension.lowercased() }

    var symbol: String {
        if isDirectory { return "folder.fill" }
        switch ext {
        case "plist": return "list.bullet.rectangle"
        case "zip": return "doc.zipper"
        case "png", "jpg", "jpeg", "heic", "gif", "webp": return "photo"
        case "json", "txt", "log", "md", "xml", "strings": return "doc.text"
        case "mp3", "m4a", "wav", "caf": return "waveform"
        case "mp4", "mov": return "play.rectangle"
        case "db", "sqlite", "sqlite3": return "cylinder.split.1x2"
        default: return "doc"
        }
    }

    var detail: String {
        if isDirectory { return L("files.folder") }
        var parts = [size.byteString]
        if let modified { parts.append(modified.formatted(date: .abbreviated, time: .shortened)) }
        return parts.joined(separator: " · ")
    }
}

enum FileSort: String, CaseIterable, Identifiable {
    case name, date, size
    var id: String { rawValue }
    var titleKey: String { "files.sort_\(rawValue)" }
}
